/// Match/drag mode screen — **IT-1, Day 3.**
///
/// Same scaffolding rules as `child_session_placeholder.dart` (tap mode):
/// fixed layout position, always-visible quiet exit, child theme temperature
/// applied locally, §10's "no score, no alarm colour" holding throughout.
///
/// This screen is the UI half of `engine/modes/match/match_mode_controller.dart`
/// — it renders whatever [MatchTrial] the controller composes and reports
/// drops back to it; the tier interpretation, item selection, and correctness
/// rule all live there, not here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/engine/modes/match/match_mode_controller.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/level_indicator_badge.dart';
import 'package:temanku/widgets/mascot.dart';
import 'package:temanku/widgets/mastery_closure_prompt.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// Every photo on this screen — draggable items and the identity-matching
/// tier's zone exemplar alike — renders at this same size, so nothing here
/// reads as "the important one" by virtue of being bigger.
const double _matchImageSize = 112;

class MatchModeScreen extends ConsumerStatefulWidget {
  const MatchModeScreen({super.key, required this.childId, required this.module});

  final String childId;
  final ModuleId module;

  @override
  ConsumerState<MatchModeScreen> createState() => _MatchModeScreenState();
}

class _MatchModeScreenState extends ConsumerState<MatchModeScreen> {
  late final MatchModeController _controller;

  MatchTrial? _trial;
  List<Photo> _photos = [];
  Set<int> _sortedSlots = {};
  List<int> _recentTargetSlots = [];
  List<int> _recentTargetZones = [];
  ({int zoneSlot, bool correct})? _zoneFlash;

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

  /// The mascot's live pose — resting between drops, a beat of
  /// [MascotPose.celebrating] on a correct drop, then back to
  /// [MascotPose.standing]. See [Mascot.reactionTick]'s own doc comment for
  /// why [_mascotReactionTick] exists alongside [_mascotPose]: a "try again"
  /// keeps the pose at `standing`, so the tick is what makes the jump replay
  /// on a second consecutive miss.
  MascotPose _mascotPose = MascotPose.standing;
  int _mascotReactionTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = MatchModeController(
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
          mode: ResponseMode.match,
        );
    _position = position;
    // Null only if the child was deleted mid-session (rare); the badge
    // simply stays off rather than this screen failing to load over it.
    final child = await ref.read(childRepositoryProvider).getChild(widget.childId);
    _levelIndicatorEnabled = child?.levelIndicatorEnabled ?? false;
    _session = await ref.read(sessionRepositoryProvider).startSession(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.match,
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
            mode: ResponseMode.match,
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
        recentTargetZones: _recentTargetZones,
      );
      if (!mounted) return;
      setState(() {
        _trial = trial;
        _position = position;
        _sortedSlots = {};
        _recentTargetSlots = [trial.targetSlot, ..._recentTargetSlots].take(2).toList();
        _recentTargetZones = [
          trial.zoneOrder.indexOf(PhotoCategory.target),
          ..._recentTargetZones,
        ].take(2).toList();
        _loading = false;
        _setupError = null;
      });
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

  Future<void> _handleDrop(int itemSlot, int zoneSlot) async {
    final trial = _trial;
    if (trial == null) return;

    final outcome = _controller.judge(trial, (itemSlot, zoneSlot));
    final correct = outcome == TrialOutcome.correct;

    setState(() {
      _zoneFlash = (zoneSlot: zoneSlot, correct: correct);
      // Correct: the item settles into the zone (removed from the draggable
      // pool). Incorrect: nothing changes here, so the item simply remains
      // exactly where it was — that *is* "returns to its origin position".
      if (correct) _sortedSlots = {..._sortedSlots, itemSlot};
      // Celebrating pops in on a correct drop; a miss stays in `standing`
      // but still bumps the tick so the jump replays (see that field's own
      // doc comment).
      _mascotPose = correct ? MascotPose.celebrating : MascotPose.standing;
      _mascotReactionTick++;
    });
    // Same trigger point as the zone flash above, alongside it rather than
    // replacing it — fire-and-forget, same reasoning as tap mode.
    unawaited(
      correct
          ? ref.read(soundServiceProvider).playCorrect()
          : ref.read(soundServiceProvider).playTryAgain(),
    );
    unawaited(
      Future.delayed(TkMotion.feedbackHold, () {
        if (!mounted) return;
        setState(() {
          _zoneFlash = null;
          // The celebration is a beat, not a held pose.
          if (_mascotPose == MascotPose.celebrating) _mascotPose = MascotPose.standing;
        });
      }),
    );

    // Every drop is one independent response, correct or not — the same
    // per-response granularity a single tap has in tap mode.
    final result = await ref.read(advancementTrackerProvider).recordResponse(
          childId: widget.childId,
          module: widget.module,
          mode: ResponseMode.match,
          correct: correct,
          hintShown: trial.hintShown,
        );

    if (correct && _sortedSlots.length == trial.items.length) {
      // Let the settle animation read before the next trial replaces it.
      await Future.delayed(TkMotion.slow);
      if (!mounted) return;

      // Checked only here, at the trial-completion boundary — not on every
      // drop — so a mid-trial mastery moment never interrupts a partially
      // sorted array with a dialog. The periodic natural-pause counter below
      // counts the same way, once per completed trial rather than once per
      // drop, so "every N trials" means the same thing here as it does in
      // tap/speak mode's per-response granularity.
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
  }

  @override
  Widget build(BuildContext context) {
    return TkChildScreen(
      onExit: () {
        // A quiet exit after the ceiling was already reached this session
        // (guardian chose "Lanjutkan" earlier, then stopped later) still
        // counts as completed — see [_reachedCeiling]'s own doc comment.
        unawaited(_endSession(_reachedCeiling ? SessionOutcome.completed : SessionOutcome.endedEarly));
        context.pop();
      },
      corner: Mascot(size: 128, pose: _mascotPose, reactionTick: _mascotReactionTick),
      debugBadge: _levelIndicatorEnabled ? LevelIndicatorBadge(position: _position) : null,
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
        _ItemRow(trial: trial, sortedSlots: _sortedSlots),
        const SizedBox(height: TkSpace.xxl),
        _ZoneRow(
          trial: trial,
          definition: _definitionFor(widget.module),
          flash: _zoneFlash,
          onDropped: _handleDrop,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.trial, required this.sortedSlots});

  final MatchTrial trial;
  final Set<int> sortedSlots;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TkSpace.sm,
      runSpacing: TkSpace.sm,
      alignment: WrapAlignment.center,
      children: [
        for (var slot = 0; slot < trial.items.length; slot++)
          if (!sortedSlots.contains(slot))
            Draggable<int>(
              data: slot,
              feedback: _ItemCard(photo: trial.items[slot], dragging: true),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _ItemCard(photo: trial.items[slot]),
              ),
              child: _ItemCard(photo: trial.items[slot]),
            ),
      ],
    );
  }
}

/// Items always show their own label — the difficulty progression lives in
/// how the *zone* reveals its identity ([MatchTierKind]), not in whether the
/// child can see what they're holding. [PhotoImage] renders the guardian's
/// actual photo (or the bundled stranger-library asset), falling back to a
/// neutral placeholder only if that path can't be loaded at all.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.photo, this.dragging = false});

  final Photo photo;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 128,
        constraints: const BoxConstraints(
          minHeight: TemanKuMetrics.childTouchTarget,
        ),
        padding: const EdgeInsets.all(TkSpace.xs),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TkRadius.sm,
          // Neutral chrome, never a feedback token: a card the child is
          // *holding* must not be painted in a colour that means "correct"
          // or "try again" before it has been dropped anywhere.
          border: Border.all(
            color: dragging ? colors.borderStrong : colors.border,
            width: dragging ? TkStroke.regular : TkStroke.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _matchImageSize,
              height: _matchImageSize,
              child: PhotoImage(
                localPath: photo.localPath,
                borderRadius: TkRadius.xs,
              ),
            ),
            const SizedBox(height: TkSpace.xxs),
            Text(
              photo.label ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.title.copyWith(color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.trial,
    required this.definition,
    required this.flash,
    required this.onDropped,
  });

  final MatchTrial trial;
  final ModuleDefinition definition;
  final ({int zoneSlot, bool correct})? flash;
  final void Function(int itemSlot, int zoneSlot) onDropped;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var zoneSlot = 0; zoneSlot < trial.zoneOrder.length; zoneSlot++)
          // Bounded rather than content-sized — a long category label must
          // wrap within its own zone's share of the row, never push the row
          // itself wider than the screen.
          Expanded(
            child: _Zone(
              category: trial.zoneOrder[zoneSlot],
              definition: definition,
              // Only the identity-matching tier names a specific exemplar;
              // every later tier is colour+shape only (see match_mode_controller.dart).
              exemplar: trial.tierKind == MatchTierKind.identicalPhoto
                  ? _exemplarFor(trial, trial.zoneOrder[zoneSlot])
                  : null,
              flashCorrect: flash != null && flash!.zoneSlot == zoneSlot ? flash!.correct : null,
              onAccept: (itemSlot) => onDropped(itemSlot, zoneSlot),
            ),
          ),
      ],
    );
  }

  Photo _exemplarFor(MatchTrial trial, PhotoCategory category) {
    if (category == PhotoCategory.target) return trial.target;
    return trial.items.firstWhere((p) => p.category == PhotoCategory.distractor);
  }
}

class _Zone extends StatelessWidget {
  const _Zone({
    required this.category,
    required this.definition,
    required this.exemplar,
    required this.flashCorrect,
    required this.onAccept,
  });

  final PhotoCategory category;
  final ModuleDefinition definition;
  final Photo? exemplar;
  final bool? flashCorrect;
  final ValueChanged<int> onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = category == PhotoCategory.target ? definition.targetStyle : definition.distractorStyle;
    final categoryLabel =
        category == PhotoCategory.target ? definition.targetCategoryLabel : definition.distractorCategoryLabel;

    // Identical visual weight for both outcomes (§10/§12: no alarm colour, no
    // de-emphasised failure state) — only which existing feedback token is
    // used differs, never the treatment around it.
    final flashColor =
        flashCorrect == null ? Colors.transparent : (flashCorrect! ? colors.successFeedback : colors.neutralFeedback);

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: context.motion(TkMotion.base),
          // The gap inside this ring is load-bearing, not spacing — see the
          // same construction in `tap_mode_screen.dart`.
          padding: const EdgeInsets.all(TkSpace.xxs),
          decoration: BoxDecoration(
            borderRadius: TkRadius.xl,
            border: Border.all(color: flashColor, width: TkStroke.feedback),
          ),
          // AnswerTarget always paints colour AND CategoryShape together
          // (widgets/answer_target.dart) — never colour alone. Only the
          // identity-matching tier passes an exemplar at all (see the
          // ternary in _ZoneRow above), and that's exactly the tier where
          // the zone is supposed to show the same photo as one of the
          // items — see match_mode_controller.dart's own doc comment.
          child: AnswerTarget(
            style: style,
            label: exemplar?.label ?? categoryLabel,
            child: exemplar != null
                ? SizedBox(
                    width: _matchImageSize,
                    height: _matchImageSize,
                    child: PhotoImage(
                      localPath: exemplar!.localPath,
                      borderRadius: TkRadius.xs,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
