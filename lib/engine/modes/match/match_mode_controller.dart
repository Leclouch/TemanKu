/// Match/drag mode — **IT-1, Day 3.**
///
/// §4.1: VP-MTS (visual perception / matching-to-sample), climbing to
/// LRFFC-style categorical sorting.
///
/// §4.4 adds one rule tap mode does not have: **match-mode target zones
/// rotate too**, not just the items. Both sides move — see
/// `engine/rotation/position_rotator.dart`'s `nextTargetZone`.
///
/// ## Mode-aware tier interpretation
///
/// The dial engine is shared, unmodified, and knows nothing about match mode
/// specifically — [SimilarityTier] still just orders four difficulty steps.
/// What match mode adds is entirely local to this file: a mapping from that
/// shared tier to what "matching" means at that step —
///
///   - [SimilarityTier.differentCategory] → match an item to an **identical**
///     photo — the zone shows the same exemplar photo (and its label) as one
///     of the array items, so there is a literal visual twin to find.
///   - [SimilarityTier.sameCategoryDistinct] → the zone drops the named
///     exemplar and shows only its colour+shape identity (§12's
///     [CategoryStyle]) — a "simplified icon" rather than a specific photo.
///   - [SimilarityTier.similar] → same colour+shape-only zone; the dial's
///     array/tier progression is what makes the items themselves harder to
///     tell apart. (This codebase has no per-photo perceptual-feature
///     metadata yet, so tier 2 and tier 3 are visually identical zones —
///     the instruction copy is what carries the distinction until that data
///     exists.)
///   - [SimilarityTier.lrffc] → functional-category sort, named explicitly
///     in the instruction via the module's own category labels.
///
/// `arraySize` keeps its literal, unmodified meaning throughout: how many
/// items must be sorted in the trial. There is no third dial here — only an
/// interpretation layer over the same two.
library;

import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';

/// What a zone's identity looks like at the current tier — the mode-aware
/// interpretation of [SimilarityTier] described in this file's doc comment.
enum MatchTierKind { identicalPhoto, simplifiedIcon, sharedFeature, functionalCategory }

MatchTierKind matchTierKindFor(SimilarityTier tier) => switch (tier) {
      SimilarityTier.differentCategory => MatchTierKind.identicalPhoto,
      SimilarityTier.sameCategoryDistinct => MatchTierKind.simplifiedIcon,
      SimilarityTier.similar => MatchTierKind.sharedFeature,
      SimilarityTier.lrffc => MatchTierKind.functionalCategory,
    };

/// A composed match-mode trial. Extends the shared [Trial] rather than
/// forking it — [Trial.items], [.instruction], and [.hintShown] all mean
/// exactly what they mean for tap mode. [target]/[targetSlot] hold the one
/// designated target-category item (needed to satisfy the shared field, and
/// reused below as the tier-1 zone exemplar); they are not otherwise special
/// to how this trial gets judged.
class MatchTrial extends Trial {
  const MatchTrial({
    required super.target,
    required super.items,
    required super.targetSlot,
    required super.instruction,
    super.hintShown,
    required this.zoneOrder,
    required this.tierKind,
  });

  /// index = on-screen zone slot (after [PositionRotator.nextTargetZone]
  /// rotation), value = the category that slot currently represents. Always
  /// length 2 — [ModuleDefinition]'s classification is binary
  /// (target/distractor) at every tier; only the zone's *visual* treatment
  /// changes with [tierKind], never the zone count.
  final List<PhotoCategory> zoneOrder;

  final MatchTierKind tierKind;
}

/// Composes the existing [DialEngine] and [PositionRotator] — no stepping,
/// streak, or rotation-guard logic is reimplemented here. Advancement itself
/// is driven by `engine/advancement/advancement_tracker.dart` from outside
/// this class, exactly as for any other mode: this controller only composes
/// one trial and judges one response.
///
/// Distractor *sourcing* is generic over [ModuleDefinition.usesBundledDistractors]
/// rather than special-cased per module: when true (Keluarga today, any
/// future module tomorrow), distractors come from [strangerLibrary] instead
/// of [Photo]s in `available` — see [nextTrial]. A module that sets the flag
/// without supplying a library is a configuration error, not something to
/// silently fall back from.
class MatchModeController implements ModeController {
  const MatchModeController({
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

  /// Match mode's classification is always binary (target zone / distractor
  /// zone) regardless of module or tier — the same two categories every
  /// [ModuleDefinition] already declares.
  static const int zoneCount = 2;

  @override
  ResponseMode get mode => ResponseMode.match;

  @override
  Future<MatchTrial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
    required List<int> recentTargetZones,
  }) async {
    final targets = available.where((p) => p.category == PhotoCategory.target).toList()
      ..shuffle();
    if (targets.isEmpty) {
      throw StateError('Not enough target photos to compose a ${_definition.id.name} match trial.');
    }
    final targetPhoto = targets.first;

    final distractorCount = _dialEngine.distractorCountFor(position, mode);
    final chosenDistractors = _definition.usesBundledDistractors
        ? await _bundledDistractors(targetPhoto, position.similarityTier, distractorCount)
        : _ownPhotoDistractors(available, distractorCount);

    // Item layout — identical composition to tap mode's array: one target
    // slot placed via the guarded rotator, the rest shuffled around it.
    final targetSlot = _rotator.nextTargetSlot(
      arraySize: position.arraySize,
      recentTargetSlots: recentTargetSlots,
    );
    final itemOrder = _rotator.shuffleSlots(arraySize: position.arraySize, targetSlot: targetSlot);
    final items = [
      for (final itemIndex in itemOrder)
        itemIndex == 0 ? targetPhoto : chosenDistractors[itemIndex - 1],
    ];

    // Zone layout — same guard, independent history, applied to 2 zones
    // instead of N item slots.
    final targetZoneSlot = _rotator.nextTargetZone(
      zoneCount: zoneCount,
      recentTargetZones: recentTargetZones,
    );
    final zoneOrder = List<PhotoCategory>.filled(zoneCount, PhotoCategory.distractor);
    zoneOrder[targetZoneSlot] = PhotoCategory.target;

    final tierKind = matchTierKindFor(position.similarityTier);

    return MatchTrial(
      target: targetPhoto,
      items: items,
      targetSlot: targetSlot,
      instruction: _instructionFor(tierKind),
      zoneOrder: zoneOrder,
      tierKind: tierKind,
    );
  }

  /// The "own photo library" path — Makanan today, any module that hasn't
  /// opted into bundled distractors.
  List<Photo> _ownPhotoDistractors(List<Photo> available, int distractorCount) {
    final distractors = available.where((p) => p.category == PhotoCategory.distractor).toList()
      ..shuffle();
    if (distractors.length < distractorCount) {
      throw StateError(
        'Not enough distractor photos to compose a ${_definition.id.name} match trial '
        '(need $distractorCount).',
      );
    }
    return distractors.take(distractorCount).toList();
  }

  /// The bundled-asset path — Keluarga today. Wraps each [StrangerImage] as a
  /// synthetic distractor [Photo] purely so the rest of this file (and every
  /// UI that renders a [Trial]) can stay generic over "where did this item's
  /// picture come from" — nothing downstream of this point needs to know.
  Future<List<Photo>> _bundledDistractors(
    Photo targetPhoto,
    SimilarityTier tier,
    int distractorCount,
  ) async {
    final library = _strangerLibrary;
    if (library == null) {
      throw StateError(
        '${_definition.id.name} sets usesBundledDistractors but no StrangerLibrary '
        'was supplied to MatchModeController.',
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
    if (trial is! MatchTrial) {
      throw ArgumentError.value(trial, 'trial', 'MatchModeController.judge requires a MatchTrial');
    }
    final (itemSlot, zoneSlot) = response as (int, int);
    final droppedCategory = trial.items[itemSlot].category;
    final zoneCategory = trial.zoneOrder[zoneSlot];
    return droppedCategory == zoneCategory ? TrialOutcome.correct : TrialOutcome.incorrect;
  }

  String _instructionFor(MatchTierKind kind) => switch (kind) {
        MatchTierKind.identicalPhoto => 'Seret benda yang sama persis ke kotaknya.',
        MatchTierKind.simplifiedIcon => 'Seret ke kotak yang cocok dengan bentuknya.',
        MatchTierKind.sharedFeature => 'Seret yang mirip ke kotak yang sama.',
        MatchTierKind.functionalCategory =>
          'Seret ke kelompok: ${_definition.targetCategoryLabel} atau ${_definition.distractorCategoryLabel}.',
      };
}
