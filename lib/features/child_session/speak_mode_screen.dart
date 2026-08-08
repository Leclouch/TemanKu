/// Speak mode screen — **IT-1, Day 4.**
///
/// Same scaffolding rules as `tap_mode_screen.dart`/`match_mode_screen.dart`:
/// fixed layout position, always-visible quiet exit, child theme temperature
/// applied locally, §10's "no score, no alarm colour" holding throughout.
///
/// This screen is the UI half of `engine/modes/speak/speak_mode_controller.dart`
/// — it renders whatever [Trial] the controller composes, starts
/// [VadService.listenForUtterance] for it, and reports the **guardian's**
/// ✅/❌ (or "tidak mencoba") back to the controller; item selection and the
/// (trivial, pass-through) correctness rule both live there, not here.
///
/// ## The pronunciation-hint layer, and the boundary around it
///
/// §6 is the whole point of speak mode: correctness is judged by the
/// guardian, never a model. The optional hint (`speech/pronunciation_hint_service.dart`)
/// is decoration on top of that, not a competing signal —
///   - it is requested **after** VAD confirms the child spoke, **never
///     awaited** before the guardian's buttons become usable;
///   - its result, if and when it arrives, renders as a small secondary
///     line placed *near*, never *inside*, the ✅/❌ cluster;
///   - no code path in this file lets [_hintResult] set [_judge]'s outcome,
///     pre-select a button, or reach [AdvancementTracker] — the only value
///     that ever does is whatever the guardian tapped.
/// Losing the hint (timeout, network error, feature off) is silently
/// identical to never having it: the line just doesn't appear.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/modes/speak/speak_mode_controller.dart';
import 'package:temanku/speech/audio/wav_clip.dart';
import 'package:temanku/speech/audio_segment_recorder.dart';
import 'package:temanku/speech/no_hint_service.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';
import 'package:temanku/speech/articulation_tolerance.dart';
import 'package:temanku/speech/tts/word_audio_service.dart';
import 'package:temanku/speech/vad_service.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/mastery_closure_prompt.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// A brief window after VAD auto-flags silence during which the guardian can
/// still tap ✅/❌ instead — "guardian override for VAD misses" from
/// `speech/vad_service.dart`'s own doc comment, made real. Not shown at all
/// when [VadService.providesAutomaticSilenceDetection] is false: the
/// fallback has no auto-flag to override in the first place.
const _autoAdvanceDelay = Duration(milliseconds: 1800);

class SpeakModeScreen extends ConsumerStatefulWidget {
  const SpeakModeScreen({super.key, required this.childId, required this.module});

  final String childId;
  final ModuleId module;

  @override
  ConsumerState<SpeakModeScreen> createState() => _SpeakModeScreenState();
}

class _SpeakModeScreenState extends ConsumerState<SpeakModeScreen> {
  late final SpeakModeController _controller;
  PronunciationHintService _hintService = const NoHintService();
  AudioSegmentRecorder? _recorder;

  Trial? _trial;
  List<Photo> _photos = [];

  bool _loading = true;
  String? _setupError;

  bool _listening = false;

  /// True while the model word is being spoken. The microphone is closed for
  /// this whole window — see [_runTrialTurn].
  bool _speaking = false;

  PronunciationHintResult? _hintResult;
  Timer? _autoAdvanceTimer;

  /// Speaks the target word — the model half of the echoic trial
  /// (`speech/tts/word_audio_service.dart`).
  WordAudioService _wordAudio = const NoWordAudioService();

  /// The child's current rung, kept because [ArticulationTolerance] needs it
  /// to calibrate the hint and only [_composeTrial] is handed it.
  LadderPosition _position = const LadderPosition.start();

  /// Whether the backend has a target IPA for this trial's word at all. Its
  /// dictionary is small and the app's labels are guardian-typed free text,
  /// so this is false far more often than not — see
  /// [PronunciationHintService.canScore]. When false, no clip is recorded
  /// and nothing is uploaded.
  bool _wordIsScorable = false;

  /// Bumped every time a new trial is composed. A hint request started for
  /// an earlier trial checks this before applying its result, so a slow
  /// response can never paint a stale hint next to the current trial.
  int _trialGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = SpeakModeController(ref.read(vadServiceProvider));
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    unawaited(_controller.vad.cancel());
    unawaited(_recorder?.dispose());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final child = await ref.read(childRepositoryProvider).getChild(widget.childId);
    final hintEnabled = child?.pronunciationHintEnabled ?? false;
    _hintService = ref.read(pronunciationHintServiceProvider(hintEnabled));
    // Same consent flag gates both — they share one external host. See
    // `wordAudioServiceProvider`'s own note on why, and on the asymmetry
    // between sending a word and sending a recording of a child.
    _wordAudio = ref.read(wordAudioServiceProvider(hintEnabled));
    _recorder = hintEnabled ? MicAudioSegmentRecorder() : null;

    final position = await ref.read(ladderPersistenceProvider).load(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.speak,
        );
    _photos = await ref.read(photoRepositoryProvider).listPhotos(
          childId: widget.childId,
          module: widget.module,
        );
    await _composeTrial(position);
  }

  Future<void> _composeTrial(LadderPosition position) async {
    _autoAdvanceTimer?.cancel();
    _trialGeneration++;
    try {
      final trial = await _controller.nextTrial(
        position: position,
        available: _photos,
        // Nothing rotates in speak mode (§4.4) — both lists are part of the
        // shared ModeController contract only; SpeakModeController ignores
        // them.
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      if (!mounted) return;
      final generation = _trialGeneration;
      final word = trial.target.label ?? '';

      setState(() {
        _trial = trial;
        _position = position;
        _listening = false;
        _speaking = false;
        _hintResult = null;
        _wordIsScorable = false;
        _loading = false;
        _setupError = null;
      });

      // Asked once per trial, off the critical path — the answer only decides
      // whether a clip gets recorded later, and the cached result makes this
      // free after the first trial of a session.
      unawaited(
        _hintService.canScore(word).then((scorable) {
          if (!mounted || generation != _trialGeneration) return;
          setState(() => _wordIsScorable = scorable);
        }),
      );

      unawaited(_runTrialTurn(word, generation));
    } on StateError {
      // Not enough photos to compose a trial — a setup gap, not a child-facing
      // failure. Neutral copy, no alarm colour, same as everywhere else here.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _setupError = 'Foto belum cukup untuk main. Minta wali menambah foto dulu.';
      });
    }
  }

  /// One echoic turn: **model the word, then listen for the echo.**
  ///
  /// The ordering is a correctness property, not presentation. If the
  /// microphone were open while the app speaks, VAD would flag the app's own
  /// synthesised voice as the child's utterance and the clip sent for scoring
  /// would be the app scoring itself — producing an excellent distance for a
  /// child who said nothing at all. [WordAudioService.speak] completes only
  /// when playback has finished, and listening starts strictly after.
  ///
  /// A model that fails to play (offline, muted, consent off) simply doesn't
  /// happen: [speak] resolves false and the turn proceeds straight to
  /// listening. The guardian can always say the word themselves, so nothing
  /// here is allowed to block the trial.
  Future<void> _runTrialTurn(String word, int generation) async {
    if (word.isNotEmpty) {
      setState(() => _speaking = true);
      await _wordAudio.speak(word);
      if (!mounted || generation != _trialGeneration) return;
      setState(() => _speaking = false);
    }
    await _listen();
  }

  /// Replays the model on demand — the "Dengar lagi" affordance.
  ///
  /// Cancels the in-flight listen first, then re-runs the full turn, so a
  /// replay mid-attempt cannot leave two VAD sessions racing for the mic.
  Future<void> _replayWord() async {
    final trial = _trial;
    if (trial == null || _speaking) return;

    _autoAdvanceTimer?.cancel();
    await _controller.vad.cancel();
    unawaited(_recorder?.stop());
    if (!mounted) return;

    // A fresh generation retires the listen that was in flight — its
    // continuation sees the bump and returns without touching state.
    _trialGeneration++;
    setState(() {
      _listening = false;
      _hintResult = null;
    });
    await _runTrialTurn(trial.target.label ?? '', _trialGeneration);
  }

  Future<void> _listen() async {
    final trial = _trial;
    if (trial == null) return;
    final generation = _trialGeneration;

    setState(() => _listening = true);

    // Only record when there is something the backend could actually score.
    // "No audio leaves the device" is strongest when the audio was never
    // captured (§10) — and with a three-word dictionary against free-text
    // labels, not-scorable is the common case, not the edge case.
    final recorder = _wordIsScorable ? _recorder : null;
    if (recorder != null) await recorder.start();

    final event = await _controller.vad.listenForUtterance();

    Uint8List? clip;
    if (recorder != null) clip = await recorder.stop();

    if (!mounted || generation != _trialGeneration) return;
    setState(() => _listening = false);

    if (event.spoke && clip != null && event.onsetLatency != null && event.duration != null) {
      final segment = _extractSegment(clip, event.onsetLatency!, event.duration!);
      if (segment != null) {
        unawaited(_requestHint(segment, trial.target.label ?? '', generation));
      }
    }

    // §6 / speech/vad_service.dart: silence auto-flags "tidak mencoba", but
    // only when this VadService actually detects audio — the fallback has
    // no signal to auto-flag from, so it always waits on the guardian's own
    // three buttons instead.
    if (!event.spoke && _controller.vad.providesAutomaticSilenceDetection) {
      _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
        if (!mounted || generation != _trialGeneration) return;
        _judge(TrialOutcome.notAttempted);
      });
    }
  }

  /// Trimming can throw on a malformed/truncated clip (e.g. the recorder
  /// was interrupted) — treated exactly like any other hint-path failure:
  /// silently skip this trial's hint, never surface anything to the
  /// guardian.
  Uint8List? _extractSegment(Uint8List clip, Duration onsetLatency, Duration duration) {
    try {
      return WavClip.trim(clip, start: onsetLatency, end: onsetLatency + duration);
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestHint(Uint8List clip, String targetWord, int generation) async {
    final result = await _hintService.scorePronunciation(
      audioClip: clip,
      targetWord: targetWord,
      // Calibrated to the child's current rung rather than a fixed constant
      // — see `speech/articulation_tolerance.dart` for why the bar loosens
      // at a fresh tier instead of tightening.
      tolerance: ArticulationTolerance.forPosition(_position),
    );
    if (!mounted || generation != _trialGeneration || result == null) return;
    setState(() => _hintResult = result);

    // Persisted for the guardian's post-session "Data lengkap" experimental
    // subsection only — this is the one and only line in this file that
    // writes the result anywhere beyond the live [_hintResult] line above;
    // it changes nothing about what's rendered here. Fire-and-forget, same
    // "never block or fail the live trial" rule the hint request itself
    // follows.
    unawaited(
      ref.read(pronunciationHintLogRepositoryProvider).append(
            PronunciationHintLogEntry(
              childId: widget.childId,
              module: widget.module,
              targetWord: targetWord,
              predictedIpa: result.predictedIpa,
              distance: result.distance,
              recordedAt: DateTime.now(),
            ),
          ),
    );
  }

  Future<void> _judge(TrialOutcome outcome) async {
    final trial = _trial;
    if (trial == null) return;
    _autoAdvanceTimer?.cancel();

    // Guardian's tap (or the auto-flagged notAttempted) passes straight
    // through — SpeakModeController.judge has nothing to derive, unlike
    // tap/match.
    //
    // **[_hintResult] is deliberately not read here, and must never be.**
    // The hint highlights a button (see [_GuardianJudgeCluster]); the
    // guardian's finger is what commits it. `outcome` arrives from an
    // onTap callback or from the VAD silence timer — never from the model.
    // That is §6, and it is the reason this line takes a parameter instead
    // of consulting state.
    final resolved = _controller.judge(trial, outcome);
    final correct = resolved == TrialOutcome.correct;

    // Same trigger point as the guardian's own ✅/❌/⭘ tap — fire-and-forget,
    // same reasoning as tap/match mode. A notAttempted verdict gets the
    // try-again chime too: it loops back to another attempt exactly like an
    // incorrect one does, never a separate, harsher sound.
    unawaited(
      correct
          ? ref.read(soundServiceProvider).playCorrect()
          : ref.read(soundServiceProvider).playTryAgain(),
    );

    final result = await ref.read(advancementTrackerProvider).recordResponse(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.speak,
          correct: correct,
          hintShown: trial.hintShown,
        );

    // Same settle beat as tap/match mode before the next trial replaces
    // this one.
    await Future.delayed(TkMotion.feedbackHold);
    if (!mounted) return;

    if (result.masteredAtCeiling) {
      final shouldContinue = await showMasteryClosurePrompt(context, ref);
      if (!mounted) return;
      if (!shouldContinue) {
        context.pop();
        return;
      }
    }
    await _composeTrial(result.position);
  }

  @override
  Widget build(BuildContext context) {
    final showJudge = _trial != null && !_loading && _setupError == null;
    return TkChildScreen(
      onExit: () => context.pop(),
      bottomOverlay: showJudge
          ? _GuardianJudgeCluster(
              enabled: !_listening,
              showNotAttempted: !_controller.vad.providesAutomaticSilenceDetection,
              hint: _hintResult,
              onJudge: _judge,
            )
          : null,
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_loading) return const TkLoading();

    if (_setupError != null) return TkChildNotice(message: _setupError!);

    final trial = _trial!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trial.instruction,
          textAlign: TextAlign.center,
          style: context.type.displayLg.copyWith(color: colors.text),
        ),
        const SizedBox(height: TkSpace.xl),
        _Stimulus(target: trial.target, definition: _definitionFor(widget.module)),
        const SizedBox(height: TkSpace.sm),
        _ReplayButton(
          // Disabled only while it is already speaking — never while
          // listening. A child who wants the model again mid-attempt is
          // making a reasonable request, and [_replayWord] cancels the
          // in-flight listen cleanly to serve it.
          onTap: _speaking ? null : _replayWord,
          speaking: _speaking,
        ),
        SizedBox(
          height: TkSpace.xxl,
          // Fixed-height slot so the stimulus above never shifts as the turn
          // moves through its phases — the same no-reflow rule the guardian
          // cluster's reserved space below follows.
          child: Center(
            child: _speaking
                ? Text(
                    'dengarkan…',
                    style: context.type.body.copyWith(color: colors.textMuted),
                  )
                : _listening
                    ? Text(
                        'sekarang giliranmu',
                        // Muted chrome, not a feedback token: this says the
                        // mic is open, and must not read as a verdict on
                        // what was said.
                        style: context.type.body.copyWith(color: colors.textMuted),
                      )
                    : null,
          ),
        ),
        // Reserves the guardian cluster's height so the stimulus above
        // never shifts position when it appears — same fixed-position
        // rule the always-visible exit dot follows.
        const SizedBox(height: 72),
      ],
    );
  }
}

/// "Dengar lagi" — replays the model word.
///
/// Child-facing and deliberately large: unlike the guardian's ✅/❌ cluster,
/// which is styled to read as *not for you*, this one is for the child, and
/// asking to hear the word again is a self-advocacy move worth making easy.
/// Sized to [TemanKuMetrics.childTouchTarget] for that reason.
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.onTap, required this.speaking});

  final VoidCallback? onTap;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Dengar lagi',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: TkRadius.pill,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: TemanKuMetrics.childTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: TkSpace.lg,
              vertical: TkSpace.sm,
            ),
            decoration: BoxDecoration(
              color: speaking ? c.primaryAccentWash : c.surface,
              borderRadius: TkRadius.pill,
              border: Border.all(
                color: speaking ? c.primaryAccent : c.borderStrong,
                width: TkStroke.regular,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  speaking ? LucideIcons.volume2 : LucideIcons.rotateCcw,
                  size: 26,
                  color: speaking ? c.primaryAccent : c.text,
                ),
                const SizedBox(width: TkSpace.xs),
                Text(
                  'Dengar lagi',
                  style: context.type.titleLg.copyWith(color: c.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one stimulus speak mode ever shows (§4.1 tact-only, §4.4 no array) —
/// stays on screen for the whole trial, unlike tap/match's per-item cards.
class _Stimulus extends StatelessWidget {
  const _Stimulus({required this.target, required this.definition});

  final Photo target;
  final ModuleDefinition definition;

  @override
  Widget build(BuildContext context) {
    // Bigger than AnswerTarget's default (and only here plus tap mode's
    // array) — speak mode has nothing else on screen competing for space, so
    // the single stimulus gets the largest treatment of any mode.
    return AnswerTarget(
      style: definition.targetStyle,
      label: target.label,
      labelStyle: context.type.titleLg,
      child: SizedBox(
        width: 160,
        height: 160,
        child: PhotoImage(localPath: target.localPath, borderRadius: TkRadius.sm),
      ),
    );
  }
}

/// The guardian's ✅/❌ corner cluster (§6) — small and muted, "positioned
/// to read as *not for you* to the child" (`speech/vad_service.dart`'s own
/// phrase for it).
///
/// ## What the hint is allowed to do here
///
/// [hint], when present, does two things and no others: it **outlines** the
/// button its [PronunciationHintResult.suggestedOutcome] points at, and it
/// renders a secondary line underneath with the phonemes heard, the distance,
/// and the tolerance that distance was measured against.
///
/// What it never does: press anything, disable anything, reorder anything, or
/// change what a tap means. Every button stays live and equally reachable
/// whether the hint agrees with the guardian or not — a suggestion the
/// guardian has to fight is worse than no suggestion, so disagreeing costs
/// exactly one tap, the same as agreeing.
///
/// The outline is drawn in [TemanKuColors.info], deliberately **not** in the
/// feedback tokens the buttons themselves carry. A green ring around the
/// green ✅ would read as "this answer was correct"; a blue ring reads as
/// "the system is pointing here", which is what it means.
class _GuardianJudgeCluster extends StatelessWidget {
  const _GuardianJudgeCluster({
    required this.enabled,
    required this.showNotAttempted,
    required this.hint,
    required this.onJudge,
  });

  final bool enabled;
  final bool showNotAttempted;
  final PronunciationHintResult? hint;
  final ValueChanged<TrialOutcome> onJudge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A quiet plate under the cluster. It does two jobs: it groups the
        // three buttons as one guardian control rather than three loose
        // glyphs, and it separates them from the child's own surface — the
        // "not for you" read §6 asks for is much stronger when the cluster
        // sits on its own ground.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TkSpace.xs,
            vertical: TkSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TkRadius.pill,
            border: Border.all(color: colors.border, width: TkStroke.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _JudgeButton(
                icon: LucideIcons.circleCheck,
                // Success feedback token — never a plain green Icons colour
                // pulled from Material directly (core/design/ rule).
                color: colors.successFeedback,
                semanticLabel: 'Benar',
                enabled: enabled,
                suggested: _suggests(TrialOutcome.correct),
                onTap: () => onJudge(TrialOutcome.correct),
              ),
              const SizedBox(width: TkSpace.xs),
              _JudgeButton(
                icon: LucideIcons.rotateCcw,
                // §12: equal visual weight to success — neutralFeedback, never
                // an alarm/red token.
                color: colors.neutralFeedback,
                semanticLabel: 'Coba lagi',
                enabled: enabled,
                suggested: _suggests(TrialOutcome.incorrect),
                onTap: () => onJudge(TrialOutcome.incorrect),
              ),
              if (showNotAttempted) ...[
                const SizedBox(width: TkSpace.xs),
                _JudgeButton(
                  // Not an outcome the child produced — muted chrome, so it
                  // never reads as a third verdict alongside the two above.
                  icon: LucideIcons.circleMinus,
                  color: colors.textMuted,
                  semanticLabel: 'Tidak mencoba',
                  enabled: enabled,
                  suggested: _suggests(TrialOutcome.notAttempted),
                  onTap: () => onJudge(TrialOutcome.notAttempted),
                ),
              ],
            ],
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: TkSpace.xxs),
            child: Text(
              // Guardian-facing advisory copy only — never rendered as a
              // verdict, never near child-facing colour tokens.
              //
              // All three numbers are shown together on purpose. A bare
              // distance is unreadable without its threshold, and the IPA is
              // the part that actually helps: it says *what* the model heard,
              // so a guardian can tell "said it fine, mic clipped it" from
              // "genuinely dropped the final consonant" — and overrule
              // accordingly.
              _hintLine(hint!),
              textAlign: TextAlign.center,
              style: context.type.caption.copyWith(color: colors.textMuted),
            ),
          ),
      ],
    );
  }

  /// True when the hint points at [outcome]. Null-safe by design: no hint
  /// means nothing is suggested, which is the same state as the feature
  /// being off — speak mode has one code path for both.
  bool _suggests(TrialOutcome outcome) => hint?.suggestedOutcome == outcome;

  String _hintLine(PronunciationHintResult result) {
    if (result.predictedIpa.isEmpty) {
      return 'Sistem: tidak ada bunyi yang terbaca';
    }
    return 'Sistem: /${result.predictedIpa}/ · '
        'jarak ${result.distance} (toleransi ≤${result.tolerance})';
  }
}

class _JudgeButton extends StatelessWidget {
  const _JudgeButton({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.enabled,
    required this.suggested,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final bool enabled;

  /// The articulation model points at this button. A ring, nothing more —
  /// see [_GuardianJudgeCluster]'s doc comment for the boundary.
  final bool suggested;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      // Announced, not just drawn. A guardian using a screen reader gets the
      // same suggestion a sighted one does.
      hint: suggested ? 'Disarankan sistem' : null,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: TemanKuMetrics.minTouchTarget / 2,
        child: Container(
          width: TemanKuMetrics.minTouchTarget,
          height: TemanKuMetrics.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // info, not a feedback token — "the system is pointing here",
            // not "this answer was correct". See the cluster's doc comment.
            color: suggested ? c.info.withValues(alpha: 0.10) : null,
            border: suggested
                ? Border.all(color: c.info, width: TkStroke.regular)
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? color : color.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
