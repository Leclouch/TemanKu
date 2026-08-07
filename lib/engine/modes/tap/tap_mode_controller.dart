import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';

/// Tap mode — **IT-1, Day 2** (the first mode end-to-end, on Makanan).
///
/// §4.1: Listener Responding, climbing to LRFFC. The child taps the item named
/// by the instruction; at the top tier the instruction becomes semantic
/// ("tunjuk yang boleh dimakan") over a mixed array.
///
/// ## Composition, deliberately identical in shape to match mode
///
/// Every tier composes the *same* array — one target-category photo plus
/// `arraySize - 1` distractor-category photos, placed via the shared
/// [PositionRotator] guard — exactly `MatchModeController`'s approach. "Mixed
/// array" at the LRFFC tier describes the *instruction* no longer naming one
/// specific exemplar, not a change in how many target-category items are on
/// screen: [PositionRotator] and the shared trial log's single `targetSlot`
/// have no notion of more than one target slot, so a second "which target"
/// axis is not something this pass invents. This mirrors exactly how match
/// mode's own LRFFC tier only changes zone naming, never item composition —
/// see `engine/modes/match/match_mode_controller.dart`.
///
/// Response type for [judge] is the tapped slot index (`int`).
class TapModeController implements ModeController {
  const TapModeController({
    required DialEngine dialEngine,
    required PositionRotator rotator,
    required ModuleDefinition definition,
    StrangerLibrary? strangerLibrary,
  })  : _dialEngine = dialEngine,
        _rotator = rotator,
        _definition = definition,
        _strangerLibrary = strangerLibrary;

  final DialEngine _dialEngine;
  final PositionRotator _rotator;
  final ModuleDefinition _definition;
  final StrangerLibrary? _strangerLibrary;

  @override
  ResponseMode get mode => ResponseMode.tap;

  @override
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
    required List<int> recentTargetZones,
  }) async {
    // Below LRFFC the instruction names the target by its own label ("tunjuk
    // pisang") — a photo with no label yet can't be the target of that
    // sentence. At LRFFC the instruction is the module's fixed semantic copy
    // instead, so an unlabelled photo is fine there.
    final requiresLabel = position.similarityTier != SimilarityTier.lrffc;
    final targets = available
        .where((p) => p.category == PhotoCategory.target && (!requiresLabel || p.label != null))
        .toList()
      ..shuffle();
    if (targets.isEmpty) {
      throw StateError('Not enough target photos to compose a ${_definition.id.name} tap trial.');
    }
    final targetPhoto = targets.first;

    final distractorCount = _dialEngine.distractorCountFor(position, mode);
    final chosenDistractors = _definition.usesBundledDistractors
        ? await _bundledDistractors(targetPhoto, position.similarityTier, distractorCount)
        : _ownPhotoDistractors(available, distractorCount);

    // Item layout — identical composition to match mode's array: one target
    // slot placed via the guarded rotator, the rest shuffled around it. Tap
    // mode has no zones, so recentTargetZones (part of the shared
    // ModeController contract) is simply never consulted here.
    final targetSlot = _rotator.nextTargetSlot(
      arraySize: position.arraySize,
      recentTargetSlots: recentTargetSlots,
    );
    final itemOrder = _rotator.shuffleSlots(arraySize: position.arraySize, targetSlot: targetSlot);
    final items = [
      for (final itemIndex in itemOrder)
        itemIndex == 0 ? targetPhoto : chosenDistractors[itemIndex - 1],
    ];

    return Trial(
      target: targetPhoto,
      items: items,
      targetSlot: targetSlot,
      instruction: _instructionFor(targetPhoto, position.similarityTier),
    );
  }

  /// The "own photo library" path — Makanan today, any module that hasn't
  /// opted into bundled distractors. Identical to
  /// `MatchModeController._ownPhotoDistractors`.
  List<Photo> _ownPhotoDistractors(List<Photo> available, int distractorCount) {
    final distractors = available.where((p) => p.category == PhotoCategory.distractor).toList()
      ..shuffle();
    if (distractors.length < distractorCount) {
      throw StateError(
        'Not enough distractor photos to compose a ${_definition.id.name} tap trial '
        '(need $distractorCount).',
      );
    }
    return distractors.take(distractorCount).toList();
  }

  /// The bundled-asset path — Keluarga today. Identical to
  /// `MatchModeController._bundledDistractors`; see that file for why each
  /// [StrangerImage] is wrapped as a synthetic distractor [Photo].
  Future<List<Photo>> _bundledDistractors(
    Photo targetPhoto,
    SimilarityTier tier,
    int distractorCount,
  ) async {
    final library = _strangerLibrary;
    if (library == null) {
      throw StateError(
        '${_definition.id.name} sets usesBundledDistractors but no StrangerLibrary '
        'was supplied to TapModeController.',
      );
    }
    final targetAgeGroup = targetPhoto.ageGroup;
    if (targetAgeGroup == null) {
      throw StateError(
        'Target photo ${targetPhoto.id} has no age group — required to pick '
        'demographically-appropriate stranger distractors (§4.4).',
      );
    }

    final strangers = await library.pickDistractors(
      count: distractorCount,
      targetAgeGroup: targetAgeGroup,
      tier: tier,
    );
    return [
      for (final stranger in strangers)
        Photo(
          id: 'stranger_${stranger.assetPath}',
          childId: targetPhoto.childId,
          module: _definition.id,
          localPath: stranger.assetPath,
          category: PhotoCategory.distractor,
          ageGroup: stranger.ageGroup,
        ),
    ];
  }

  @override
  TrialOutcome judge(Trial trial, Object response) {
    final tappedSlot = response as int;
    final tappedCategory = trial.items[tappedSlot].category;
    return tappedCategory == PhotoCategory.target ? TrialOutcome.correct : TrialOutcome.incorrect;
  }

  String _instructionFor(Photo targetPhoto, SimilarityTier tier) {
    if (tier == SimilarityTier.lrffc) return _definition.lrffcInstruction;
    return 'tunjuk ${targetPhoto.label}';
  }
}
