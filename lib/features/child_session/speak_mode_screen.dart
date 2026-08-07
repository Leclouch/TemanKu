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

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/modes/speak/speak_mode_controller.dart';
import 'package:temanku/speech/audio/wav_clip.dart';
import 'package:temanku/speech/audio_segment_recorder.dart';
import 'package:temanku/speech/no_hint_service.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';
import 'package:temanku/speech/vad_service.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';
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
  PronunciationHintResult? _hintResult;
  Timer? _autoAdvanceTimer;

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
      setState(() {
        _trial = trial;
        _listening = false;
        _hintResult = null;
        _loading = false;
        _setupError = null;
      });
      unawaited(_listen());
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

  Future<void> _listen() async {
    final trial = _trial;
    if (trial == null) return;
    final generation = _trialGeneration;

    setState(() => _listening = true);

    final recorder = _recorder;
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
      // Fixed for now — deliberately not wired to the dial engine's tiers
      // yet (task scope, see `pronunciation_hint_service.dart`).
      difficulty: defaultPronunciationHintDifficulty,
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
              ipaTranscription: result.ipaTranscription,
              phonemeEditDistance: result.phonemeEditDistance,
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
    // tap/match. The hint result, if any, is never consulted here.
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
    await Future.delayed(const Duration(milliseconds: 500));
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
    return Theme(
      data: TemanKuTheme.child,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(child: _buildBody(context)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ExitDot(onExit: () => context.pop()),
                  ),
                  if (_trial != null && !_loading && _setupError == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: Center(
                        child: _GuardianJudgeCluster(
                          enabled: !_listening,
                          showNotAttempted: !_controller.vad.providesAutomaticSilenceDetection,
                          hint: _hintResult,
                          onJudge: _judge,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_loading) return const CircularProgressIndicator();

    if (_setupError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _setupError!,
          textAlign: TextAlign.center,
          style: context.type.body.copyWith(color: colors.text),
        ),
      );
    }

    final trial = _trial!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trial.instruction,
              textAlign: TextAlign.center,
              style: context.type.display.copyWith(color: colors.text),
            ),
            const SizedBox(height: 24),
            _Stimulus(target: trial.target, definition: _definitionFor(widget.module)),
            const SizedBox(height: 16),
            SizedBox(
              height: 24,
              child: _listening
                  ? Text(
                      'mendengarkan…',
                      style: context.type.body.copyWith(color: colors.neutralFeedback),
                    )
                  : null,
            ),
            // Reserves the guardian cluster's height so the stimulus above
            // never shifts position when it appears — same fixed-position
            // rule the always-visible exit dot follows.
            const SizedBox(height: 72),
          ],
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
      labelFontSize: 26,
      child: SizedBox(
        width: 160,
        height: 160,
        child: PhotoImage(localPath: target.localPath, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// The guardian's ✅/❌ corner cluster (§6) — small and muted, "positioned
/// to read as *not for you* to the child" (`speech/vad_service.dart`'s own
/// phrase for it). [hint], when present, renders as a strictly secondary
/// line under the buttons: smaller type, muted colour, never inside a
/// button, never able to change which button is enabled or pre-tapped.
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _JudgeButton(
              icon: Icons.check_circle_outline,
              // Success feedback token — never a plain green Icons colour
              // pulled from Material directly (core/theme/ rule).
              color: colors.successFeedback,
              semanticLabel: 'Benar',
              enabled: enabled,
              onTap: () => onJudge(TrialOutcome.correct),
            ),
            const SizedBox(width: 12),
            _JudgeButton(
              icon: Icons.replay_circle_filled_outlined,
              // §12: equal visual weight to success — neutralFeedback, never
              // an alarm/red token.
              color: colors.neutralFeedback,
              semanticLabel: 'Coba lagi',
              enabled: enabled,
              onTap: () => onJudge(TrialOutcome.incorrect),
            ),
            if (showNotAttempted) ...[
              const SizedBox(width: 12),
              _JudgeButton(
                icon: Icons.remove_circle_outline,
                color: colors.neutralFeedback,
                semanticLabel: 'Tidak mencoba',
                enabled: enabled,
                onTap: () => onJudge(TrialOutcome.notAttempted),
              ),
            ],
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              // Guardian-facing advisory copy only — never rendered as a
              // verdict, never near child-facing colour tokens.
              "Sistem: mirip '${hint!.closestWord}'",
              style: context.type.mono.copyWith(color: colors.neutralFeedback, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _JudgeButton extends StatelessWidget {
  const _JudgeButton({
    required this.icon,
    required this.color,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: TemanKuMetrics.minTouchTarget / 2,
        child: SizedBox(
          width: TemanKuMetrics.minTouchTarget,
          height: TemanKuMetrics.minTouchTarget,
          child: Center(
            child: Icon(icon, size: 22, color: enabled ? color : color.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
