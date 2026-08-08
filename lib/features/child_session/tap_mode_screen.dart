/// Tap mode screen — **IT-1, Day 2** (the first mode end-to-end).
///
/// Same scaffolding rules as `match_mode_screen.dart` (its sibling, built to
/// the identical pattern): fixed layout position, always-visible quiet exit,
/// child theme temperature applied locally, §10's "no score, no alarm colour"
/// holding throughout.
///
/// This screen is the UI half of `engine/modes/tap/tap_mode_controller.dart`
/// — it renders whatever [Trial] the controller composes and reports the
/// tapped slot back to it; item selection and the correctness rule both live
/// there, not here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/modes/tap/tap_mode_controller.dart';
import 'package:temanku/widgets/level_indicator_badge.dart';
import 'package:temanku/widgets/mascot.dart';
import 'package:temanku/widgets/mastery_closure_prompt.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

class TapModeScreen extends ConsumerStatefulWidget {
  const TapModeScreen({super.key, required this.childId, required this.module});

  final String childId;
  final ModuleId module;

  @override
  ConsumerState<TapModeScreen> createState() => _TapModeScreenState();
}

class _TapModeScreenState extends ConsumerState<TapModeScreen> {
  late final TapModeController _controller;

  TapTrial? _trial;
  List<Photo> _photos = [];
  List<int> _recentTargetSlots = [];
  final Set<int> _foundTargets = {};
  ({int slot, bool correct})? _flash;

  /// True between a tap resolving and the next trial replacing it — guards
  /// against a second tap landing mid-transition.
  bool _resolving = false;

  bool _loading = true;
  String? _setupError;

  /// Riwayat wiring — see [_endSession]. Null until [_bootstrap] has loaded a
  /// starting position; [_endSession] no-ops on a guardian exit that lands
  /// before that (loading screen, setup-error notice), since nothing worth
  /// recording happened yet.
  Session? _session;
  DateTime? _sessionStart;
  LadderPosition _position = const LadderPosition.start();

  /// Guardian-only debug/preview flag (`Child.levelIndicatorEnabled`) — see
  /// that field's own doc comment. Loaded once in [_bootstrap]; false until
  /// then, same as every other field this screen only knows after loading.
  bool _levelIndicatorEnabled = false;

  /// True once the dial engine's ceiling was reached at least once this
  /// session — sticky for the rest of the session even if the guardian
  /// chooses "Lanjutkan" and keeps playing, so a later quiet exit still
  /// records [SessionOutcome.completed] rather than losing that fact.
  bool _reachedCeiling = false;

  /// Trials completed since the last closure prompt (mastery- or
  /// interval-triggered) — reset whenever either one fires and the guardian
  /// chooses "Lanjutkan". Drives [showNaturalPausePrompt] independently of
  /// [_reachedCeiling]: see that function's own doc comment for why a
  /// session needs a way to reach a natural pause without ever reaching the
  /// dial engine's ceiling.
  int _trialsSinceLastPause = 0;

  /// The mascot's live pose — resting between taps, a beat of
  /// [MascotPose.celebrating] on a correct answer, then back to
  /// [MascotPose.standing]. See [Mascot.reactionTick]'s own doc comment for
  /// why [_mascotReactionTick] exists alongside [_mascotPose]: a "try again"
  /// keeps the pose at `standing`, so the tick is what makes the jump replay
  /// on a second consecutive miss.
  MascotPose _mascotPose = MascotPose.standing;
  int _mascotReactionTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = TapModeController(
      dialEngine: ref.read(dialEngineProvider),
      rotator: ref.read(positionRotatorProvider),
      definition: _definitionFor(widget.module),
      // Harmless to supply for every module — only consulted when the
      // module's own usesBundledDistractors flag is set.
      strangerLibrary: ref.read(strangerLibraryProvider),
    );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final position = await ref.read(ladderPersistenceProvider).load(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.tap,
        );
    _position = position;
    // Null only if the child was deleted mid-session (rare); the badge
    // simply stays off rather than this screen failing to load over it.
    final child =
        await ref.read(childRepositoryProvider).getChild(widget.childId);
    _levelIndicatorEnabled = child?.levelIndicatorEnabled ?? false;
    _session = await ref.read(sessionRepositoryProvider).startSession(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.tap,
        );
    _sessionStart = DateTime.now();
    _photos = await ref.read(photoRepositoryProvider).listPhotos(
          childId: widget.childId,
          module: widget.module,
        );
    await _composeTrial(position);
  }

  /// Persists whatever happened this session to Riwayat — the one call site
  /// missing before this file existed with a session repository at all (see
  /// `data/repositories/session_repository.dart`'s own doc comment). Fire-
  /// and-forget from both call sites (same reasoning as the sound-effect
  /// calls elsewhere in this file): a guardian's exit must never wait on a
  /// write completing.
  Future<void> _endSession(SessionOutcome outcome) async {
    final session = _session;
    final start = _sessionStart;
    if (session == null || start == null) return;
    await ref.read(sessionRepositoryProvider).endSession(
          sessionId: session.id,
          summary: SessionSummary(
            sessionId: session.id,
            childId: widget.childId,
            module: widget.module,
            mode: ResponseMode.tap,
            duration: DateTime.now().difference(start),
            endedAt: DateTime.now(),
            ladderAtEnd: _position,
            observations: const [],
            outcome: outcome,
          ),
        );
  }

  Future<void> _composeTrial(LadderPosition position) async {
    try {
      final trial = await _controller.nextTrial(
        position: position,
        available: _photos,
        recentTargetSlots: _recentTargetSlots,
        // Tap mode has no zones — the shared ModeController contract still
        // takes this list, but TapModeController never consults it.
        recentTargetZones: const [],
      );
      if (!mounted) return;
      setState(() {
        _trial = trial;
        _position = position;
        _flash = null;
        _foundTargets.clear();
        _resolving = false;
        _recentTargetSlots =
            [trial.targetSlot, ..._recentTargetSlots].take(2).toList();
        _loading = false;
        _setupError = null;
      });
    } on StateError {
      // Not enough photos to compose a trial — a setup gap, not a child-facing
      // failure. Neutral copy, no alarm colour, same as everywhere else here.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _setupError =
            'Foto belum cukup untuk main. Minta wali menambah foto dulu.';
      });
    }
  }

  Future<void> _handleTap(int itemSlot) async {
    final trial = _trial;
    if (trial == null || _resolving) return;

    if (trial.targetSlots.length > 1) {
      await _handleMultiTargetTap(trial, itemSlot);
      return;
    }

    final outcome = _controller.judge(trial, itemSlot);
    final correct = outcome == TrialOutcome.correct;

    setState(() {
      _resolving = true;
      _flash = (slot: itemSlot, correct: correct);
      // Celebrating pops in on a correct answer; a miss stays in `standing`
      // but still bumps the tick so the jump replays (see that field's own
      // doc comment). Reset to `standing` after the feedback hold below, so
      // the celebration is a beat, not a held pose.
      _mascotPose = correct ? MascotPose.celebrating : MascotPose.standing;
      _mascotReactionTick++;
    });
    // Same trigger point as the flash above, alongside it rather than
    // replacing it — fire-and-forget so a slow/failing sound never delays
    // the 500ms settle beat below.
    unawaited(
      correct
          ? ref.read(soundServiceProvider).playCorrect()
          : ref.read(soundServiceProvider).playTryAgain(),
    );

    // One tap is one complete, independent response in tap mode — unlike
    // match mode's incremental sort, there is nothing left to keep trying
    // within this trial once the tap lands.
    final result = await ref.read(advancementTrackerProvider).recordResponse(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.tap,
          correct: correct,
          hintShown: trial.hintShown,
        );

    // Let the feedback read before the next trial replaces it — same beat as
    // match mode's settle animation.
    await Future.delayed(TkMotion.feedbackHold);
    if (!mounted) return;
    if (_mascotPose == MascotPose.celebrating) {
      setState(() => _mascotPose = MascotPose.standing);
    }

    if (result.masteredAtCeiling) {
      _reachedCeiling = true;
      _trialsSinceLastPause = 0;
      final shouldContinue = await showMasteryClosurePrompt(context, ref);
      if (!mounted) return;
      if (!shouldContinue) {
        unawaited(_endSession(SessionOutcome.completed));
        context.pop();
        return;
      }
    } else if (++_trialsSinceLastPause >= naturalPauseTrialInterval) {
      _trialsSinceLastPause = 0;
      final shouldContinue = await showNaturalPausePrompt(context, ref);
      if (!mounted) return;
      if (!shouldContinue) {
        unawaited(_endSession(SessionOutcome.completed));
        context.pop();
        return;
      }
    }
    await _composeTrial(result.position);
  }

  Future<void> _handleMultiTargetTap(TapTrial trial, int itemSlot) async {
    if (_foundTargets.contains(itemSlot)) return;

    final outcome = _controller.judge(trial, itemSlot);
    final correct = outcome == TrialOutcome.correct;
    final allTargetsFound =
        correct && _foundTargets.length + 1 == trial.targetSlots.length;

    setState(() {
      _resolving = true;
      _flash = (slot: itemSlot, correct: correct);
      if (correct) _foundTargets.add(itemSlot);
      _mascotPose = correct ? MascotPose.celebrating : MascotPose.standing;
      _mascotReactionTick++;
    });
    unawaited(
      correct
          ? ref.read(soundServiceProvider).playCorrect()
          : ref.read(soundServiceProvider).playTryAgain(),
    );

    // Every tap still contributes an independent response to the ladder,
    // but only finding every target can resolve this extended trial.
    final result = await ref.read(advancementTrackerProvider).recordResponse(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.tap,
          correct: correct,
          hintShown: trial.hintShown,
        );

    await Future.delayed(TkMotion.feedbackHold);
    if (!mounted) return;
    if (_mascotPose == MascotPose.celebrating) {
      setState(() => _mascotPose = MascotPose.standing);
    }

    if (!allTargetsFound) {
      setState(() {
        _flash = null;
        _resolving = false;
      });
      return;
    }

    if (result.masteredAtCeiling) {
      _reachedCeiling = true;
      _trialsSinceLastPause = 0;
      final shouldContinue = await showMasteryClosurePrompt(context, ref);
      if (!mounted) return;
      if (!shouldContinue) {
        unawaited(_endSession(SessionOutcome.completed));
        context.pop();
        return;
      }
    } else if (++_trialsSinceLastPause >= naturalPauseTrialInterval) {
      _trialsSinceLastPause = 0;
      final shouldContinue = await showNaturalPausePrompt(context, ref);
      if (!mounted) return;
      if (!shouldContinue) {
        unawaited(_endSession(SessionOutcome.completed));
        context.pop();
        return;
      }
    }
    await _composeTrial(result.position);
  }

  @override
  Widget build(BuildContext context) {
    // TkChildScreen carries the child theme, the always-visible quiet exit,
    // the bounded content column and the fixed centred task position — the
    // four things every child screen used to re-declare for itself.
    return TkChildScreen(
      onExit: () {
        // A quiet exit after the ceiling was already reached this session
        // (guardian chose "Lanjutkan" earlier, then stopped later) still
        // counts as completed — see [_reachedCeiling]'s own doc comment.
        unawaited(_endSession(_reachedCeiling
            ? SessionOutcome.completed
            : SessionOutcome.endedEarly));
        context.pop();
      },
      corner: Mascot(
          size: 128, pose: _mascotPose, reactionTick: _mascotReactionTick),
      debugBadge: _levelIndicatorEnabled
          ? LevelIndicatorBadge(position: _position)
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
        const SizedBox(height: TkSpace.xxl),
        _AnswerRow(
          trial: trial,
          foundTargets: _foundTargets,
          flash: _flash,
          onTap: _handleTap,
        ),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.trial,
    required this.foundTargets,
    required this.flash,
    required this.onTap,
  });

  final TapTrial trial;
  final Set<int> foundTargets;
  final ({int slot, bool correct})? flash;
  final void Function(int itemSlot) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TkSpace.sm,
      runSpacing: TkSpace.sm,
      alignment: WrapAlignment.center,
      children: [
        for (var slot = 0; slot < trial.items.length; slot++)
          _AnswerItem(
            photo: trial.items[slot],
            found: foundTargets.contains(slot),
            flashCorrect:
                flash != null && flash!.slot == slot ? flash!.correct : null,
            onTap: () => onTap(slot),
          ),
      ],
    );
  }
}

/// One tappable slot. Deliberately **neutral chrome, no category colour or
/// shape** — unlike `match_mode_screen.dart`'s `_Zone` (which legitimately
/// paints [ModuleDefinition.targetStyle]/`distractorStyle`, since a drop
/// zone *is* the category label). Tap mode has no separate zone: the item
/// card the child taps is itself the answer, so painting it in the target
/// category's colour+shape would hand the answer to the child through the
/// card's chrome before they ever look at the photo — the same failure mode
/// `match_mode_screen.dart`'s `_ItemCard` already avoids for its draggable
/// items ("a card the child is holding must not be painted in a colour that
/// means correct... before it has been dropped anywhere"), just applied to
/// tap mode's "before it has been tapped" instead. Same neutral-surface/
/// hairline-border chrome as that sibling card, so both modes read as one
/// visual language.
class _AnswerItem extends StatelessWidget {
  const _AnswerItem({
    required this.photo,
    required this.found,
    required this.flashCorrect,
    required this.onTap,
  });

  final Photo photo;
  final bool found;
  final bool? flashCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Identical visual weight for both outcomes (§10/§12: no alarm colour, no
    // de-emphasised failure state) — only which existing feedback token is
    // used differs, never the treatment around it.
    final flashColor = found
        ? colors.successFeedback
        : flashCorrect == null
            ? Colors.transparent
            : (flashCorrect! ? colors.successFeedback : colors.neutralFeedback);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: TkRadius.lg,
        onTap: found ? null : onTap,
        child: AnimatedContainer(
          duration: context.motion(TkMotion.base),
          padding: const EdgeInsets.all(TkSpace.xxs),
          decoration: BoxDecoration(
            borderRadius: TkRadius.lg,
            border: Border.all(color: flashColor, width: TkStroke.feedback),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: TemanKuMetrics.childTouchTarget,
              minHeight: TemanKuMetrics.childTouchTarget,
            ),
            child: Container(
              padding: const EdgeInsets.all(TkSpace.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: TkRadius.md,
                border:
                    Border.all(color: colors.border, width: TkStroke.hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bigger image + label than a neutral match-mode item card
                  // (and only here plus speak mode's stimulus) — tap mode's
                  // array is the child's main visual read of the trial, so
                  // it gets the larger size.
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: PhotoImage(
                        localPath: photo.localPath, borderRadius: TkRadius.xs),
                  ),
                  if (photo.label != null) ...[
                    const SizedBox(height: TkSpace.xxs),
                    Text(
                      photo.label!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.titleLg.copyWith(color: colors.text),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
