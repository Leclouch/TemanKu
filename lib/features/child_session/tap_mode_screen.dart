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
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/modes/tap/tap_mode_controller.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';
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

  Trial? _trial;
  List<Photo> _photos = [];
  List<int> _recentTargetSlots = [];
  ({int slot, bool correct})? _flash;

  /// True between a tap resolving and the next trial replacing it — guards
  /// against a second tap landing mid-transition.
  bool _resolving = false;

  bool _loading = true;
  String? _setupError;

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
        // Tap mode has no zones — the shared ModeController contract still
        // takes this list, but TapModeController never consults it.
        recentTargetZones: const [],
      );
      if (!mounted) return;
      setState(() {
        _trial = trial;
        _flash = null;
        _resolving = false;
        _recentTargetSlots = [trial.targetSlot, ..._recentTargetSlots].take(2).toList();
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

  Future<void> _handleTap(int itemSlot) async {
    final trial = _trial;
    if (trial == null || _resolving) return;

    final outcome = _controller.judge(trial, itemSlot);
    final correct = outcome == TrialOutcome.correct;

    setState(() {
      _resolving = true;
      _flash = (slot: itemSlot, correct: correct);
    });

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
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    // Child surface runs a different theme temperature, applied locally —
    // same rule as `match_mode_screen.dart`.
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
      // every other child session screen.
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
            _AnswerRow(
              trial: trial,
              definition: _definitionFor(widget.module),
              flash: _flash,
              onTap: _handleTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.trial,
    required this.definition,
    required this.flash,
    required this.onTap,
  });

  final Trial trial;
  final ModuleDefinition definition;
  final ({int slot, bool correct})? flash;
  final void Function(int itemSlot) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var slot = 0; slot < trial.items.length; slot++)
          _AnswerItem(
            photo: trial.items[slot],
            definition: definition,
            flashCorrect: flash != null && flash!.slot == slot ? flash!.correct : null,
            onTap: () => onTap(slot),
          ),
      ],
    );
  }
}

/// One tappable slot. Shows the category's colour+shape (never colour
/// alone, §12) plus the actual photo via [PhotoImage] — same shared
/// component `match_mode_screen.dart`'s item card uses.
class _AnswerItem extends StatelessWidget {
  const _AnswerItem({
    required this.photo,
    required this.definition,
    required this.flashCorrect,
    required this.onTap,
  });

  final Photo photo;
  final ModuleDefinition definition;
  final bool? flashCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = photo.category == PhotoCategory.target ? definition.targetStyle : definition.distractorStyle;

    // Identical visual weight for both outcomes (§10/§12: no alarm colour, no
    // de-emphasised failure state) — only which existing feedback token is
    // used differs, never the treatment around it.
    final flashColor =
        flashCorrect == null ? Colors.transparent : (flashCorrect! ? colors.successFeedback : colors.neutralFeedback);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: flashColor, width: 4),
          ),
          // AnswerTarget always paints colour AND CategoryShape together
          // (widgets/answer_target.dart) — never colour alone.
          child: AnswerTarget(
            style: style,
            label: photo.label,
            child: SizedBox(
              width: 48,
              height: 48,
              child: PhotoImage(localPath: photo.localPath, borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}
