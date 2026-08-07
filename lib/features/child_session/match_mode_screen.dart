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
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/modes/match/match_mode_controller.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';
import 'package:temanku/widgets/mastery_closure_prompt.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

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
    _photos = await ref.read(photoRepositoryProvider).listPhotos(
          childId: widget.childId,
          module: widget.module,
        );
    await _composeTrial(position);
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
    });
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _zoneFlash = null);
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
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // Checked only here, at the trial-completion boundary — not on every
      // drop — so a mid-trial mastery moment never interrupts a partially
      // sorted array with a dialog.
      if (result.masteredAtCeiling) {
        final shouldContinue = await showMasteryClosurePrompt(context);
        if (!mounted) return;
        if (!shouldContinue) {
          context.pop();
          return;
        }
      }
      await _composeTrial(result.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Child surface runs a different theme temperature, applied locally —
    // same rule as `child_session_placeholder.dart`, both sourced from
    // core/theme/.
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
      // Bounded, not fixed — phone-first, tablet free (§11), same rule as
      // the tap-mode placeholder.
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
            _ItemRow(trial: trial, sortedSlots: _sortedSlots),
            const SizedBox(height: 32),
            _ZoneRow(
              trial: trial,
              definition: _definitionFor(widget.module),
              flash: _zoneFlash,
              onDropped: _handleDrop,
            ),
          ],
        ),
      ),
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
      spacing: 12,
      runSpacing: 12,
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
        constraints: const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.neutralFeedback, width: dragging ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: PhotoImage(
                localPath: photo.localPath,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              photo.label ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.body.copyWith(color: colors.text),
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: flashColor, width: 4),
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
                    width: 76,
                    height: 76,
                    child: PhotoImage(
                      localPath: exemplar!.localPath,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
