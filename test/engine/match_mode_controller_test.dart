import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/engine/modes/match/match_mode_controller.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';

/// Records what it was asked for, so tests can assert the controller passed
/// the right tier/age-group through without needing real bundled assets —
/// `photo_pipeline/stranger_library_test.dart` already covers the real
/// [BundledStrangerLibrary] against the actual asset bundle.
class _FakeStrangerLibrary implements StrangerLibrary {
  final calls = <({int count, AgeGroup targetAgeGroup, SimilarityTier tier})>[];

  @override
  Future<List<StrangerImage>> pickDistractors({
    required int count,
    required AgeGroup targetAgeGroup,
    required SimilarityTier tier,
  }) async {
    calls.add((count: count, targetAgeGroup: targetAgeGroup, tier: tier));
    return [
      for (var i = 0; i < count; i++)
        StrangerImage(assetPath: 'assets/stranger_library/fake_$i.png', ageGroup: targetAgeGroup),
    ];
  }
}

List<Photo> _photos({required int targets, required int distractors}) => [
      for (var i = 0; i < targets; i++)
        Photo(
          id: 'target_$i',
          childId: 'child_1',
          module: ModuleId.makanan,
          localPath: '/fake/target_$i.jpg',
          category: PhotoCategory.target,
          label: 'target_$i',
        ),
      for (var i = 0; i < distractors; i++)
        Photo(
          id: 'distractor_$i',
          childId: 'child_1',
          module: ModuleId.makanan,
          localPath: '/fake/distractor_$i.jpg',
          category: PhotoCategory.distractor,
          label: 'distractor_$i',
        ),
    ];

void main() {
  group('matchTierKindFor', () {
    test('maps every SimilarityTier to its match-mode interpretation', () {
      expect(matchTierKindFor(SimilarityTier.differentCategory), MatchTierKind.identicalPhoto);
      expect(matchTierKindFor(SimilarityTier.sameCategoryDistinct), MatchTierKind.simplifiedIcon);
      expect(matchTierKindFor(SimilarityTier.similar), MatchTierKind.sharedFeature);
      expect(matchTierKindFor(SimilarityTier.lrffc), MatchTierKind.functionalCategory);
    });
  });

  group('MatchModeController.nextTrial', () {
    final controller = MatchModeController(
      dialEngine: const TwoDialEngine(),
      rotator: GuardedPositionRotator(),
      definition: makananModule,
    );

    test('composes exactly arraySize items', () async {
      const position = LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.items, hasLength(4));
    });

    test('zoneOrder always has length 2 with exactly one target and one distractor', () async {
      const position = LadderPosition.start();
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.zoneOrder, hasLength(2));
      expect(trial.zoneOrder.toSet(), {PhotoCategory.target, PhotoCategory.distractor});
    });

    test('tierKind matches the ladder position\'s similarity tier', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.tierKind, MatchTierKind.functionalCategory);
    });

    test('the functional-category instruction names the module\'s own category labels', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.instruction, contains(makananModule.targetCategoryLabel));
      expect(trial.instruction, contains(makananModule.distractorCategoryLabel));
    });

    test('throws when there are not enough photos to fill the array', () async {
      const position = LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory);
      expect(
        () => controller.nextTrial(
          position: position,
          available: _photos(targets: 1, distractors: 1),
          recentTargetSlots: const [],
          recentTargetZones: const [],
        ),
        throwsStateError,
      );
    });
  });

  group('MatchModeController.judge', () {
    final controller = MatchModeController(
      dialEngine: const TwoDialEngine(),
      rotator: GuardedPositionRotator(),
      definition: makananModule,
    );

    test('correct when the dropped item\'s category matches the zone\'s category', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      for (var itemSlot = 0; itemSlot < trial.items.length; itemSlot++) {
        final itemCategory = trial.items[itemSlot].category;
        final correctZoneSlot = trial.zoneOrder.indexOf(itemCategory);
        final outcome = controller.judge(trial, (itemSlot, correctZoneSlot));
        expect(outcome, TrialOutcome.correct);
      }
    });

    test('incorrect when the dropped item\'s category does not match the zone', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      for (var itemSlot = 0; itemSlot < trial.items.length; itemSlot++) {
        final itemCategory = trial.items[itemSlot].category;
        final wrongZoneSlot = trial.zoneOrder.indexWhere((c) => c != itemCategory);
        final outcome = controller.judge(trial, (itemSlot, wrongZoneSlot));
        expect(outcome, TrialOutcome.incorrect);
      }
    });
  });

  group('advancement driven from match mode', () {
    test('the shared streak/dial machinery steps correctly when fed from MatchModeController.judge',
        () async {
      const childId = 'child_1';
      const module = ModuleId.makanan;
      const dialEngine = TwoDialEngine();
      final controller = MatchModeController(
        dialEngine: dialEngine,
        rotator: GuardedPositionRotator(),
        definition: makananModule,
      );
      final tracker = AdvancementTracker(
        dialEngine: dialEngine,
        persistence: LadderPersistence(InMemoryChildRepository(seed: false)),
      );
      final photos = _photos(targets: 3, distractors: 5);

      var position = const LadderPosition.start();
      var recentSlots = <int>[];
      var recentZones = <int>[];

      for (var i = 0; i < requiredStreakForAdvancement; i++) {
        final trial = await controller.nextTrial(
          position: position,
          available: photos,
          recentTargetSlots: recentSlots,
          recentTargetZones: recentZones,
        );
        recentSlots = [trial.targetSlot, ...recentSlots].take(2).toList();
        recentZones = [
          trial.zoneOrder.indexOf(PhotoCategory.target),
          ...recentZones,
        ].take(2).toList();

        // Drop the target item on its correct zone every time — an
        // unbroken independent-correct streak.
        final targetSlot = trial.items.indexOf(trial.target);
        final correctZoneSlot = trial.zoneOrder.indexOf(PhotoCategory.target);
        final outcome = controller.judge(trial, (targetSlot, correctZoneSlot));
        expect(outcome, TrialOutcome.correct);

        position = (await tracker.recordResponse(
          childId: childId,
          module: module,
          mode: ResponseMode.match,
          correct: true,
          hintShown: false,
        ))
            .position;
      }

      // TwoDialEngine.advanceForMode for a non-speak mode is the ordinary
      // array-then-tier step — proof the shared dial engine, not a match-mode
      // fork, is what actually moved.
      expect(position, dialEngine.advance(const LadderPosition.start()));
      expect(tracker.streakFor(childId: childId, module: module, mode: ResponseMode.match), 0);
    });
  });

  group('Keluarga (usesBundledDistractors) — the generic fix', () {
    Photo targetPhoto({AgeGroup? ageGroup}) => Photo(
          id: 'ibu',
          childId: 'child_1',
          module: ModuleId.keluarga,
          localPath: '/fake/ibu.jpg',
          category: PhotoCategory.target,
          label: 'Ibu',
          ageGroup: ageGroup,
        );

    test('distractors come from the StrangerLibrary, never from `available`', () async {
      final fakeLibrary = _FakeStrangerLibrary();
      final controller = MatchModeController(
        dialEngine: const TwoDialEngine(),
        rotator: GuardedPositionRotator(),
        definition: keluargaModule,
        strangerLibrary: fakeLibrary,
      );
      const position = LadderPosition(arraySize: 3, similarityTier: SimilarityTier.similar);

      // `available` has only the target — exactly what
      // InMemoryPhotoRepository's Keluarga seed looks like now: no
      // distractor-category photos stored per-child at all.
      final trial = await controller.nextTrial(
        position: position,
        available: [targetPhoto(ageGroup: AgeGroup.adult)],
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      expect(trial.items, hasLength(3));
      expect(fakeLibrary.calls, hasLength(1));
      expect(fakeLibrary.calls.single.count, 2); // distractorCount = arraySize - 1
      expect(fakeLibrary.calls.single.targetAgeGroup, AgeGroup.adult);
      expect(fakeLibrary.calls.single.tier, SimilarityTier.similar);

      final distractorItems = trial.items.where((p) => p.category == PhotoCategory.distractor);
      expect(distractorItems, hasLength(2));
      for (final item in distractorItems) {
        expect(item.localPath, startsWith('assets/stranger_library/'));
      }
    });

    test('throws a clear setup error when usesBundledDistractors but no library was supplied',
        () async {
      final controller = MatchModeController(
        dialEngine: const TwoDialEngine(),
        rotator: GuardedPositionRotator(),
        definition: keluargaModule,
        // strangerLibrary intentionally omitted.
      );

      expect(
        () => controller.nextTrial(
          position: const LadderPosition.start(),
          available: [targetPhoto(ageGroup: AgeGroup.adult)],
          recentTargetSlots: const [],
          recentTargetZones: const [],
        ),
        throwsStateError,
      );
    });

    test('throws when the target photo has no age group tagged', () async {
      final controller = MatchModeController(
        dialEngine: const TwoDialEngine(),
        rotator: GuardedPositionRotator(),
        definition: keluargaModule,
        strangerLibrary: _FakeStrangerLibrary(),
      );

      expect(
        () => controller.nextTrial(
          position: const LadderPosition.start(),
          available: [targetPhoto()], // no ageGroup
          recentTargetSlots: const [],
          recentTargetZones: const [],
        ),
        throwsStateError,
      );
    });

    test('Makanan is unaffected — still sources distractors from `available`', () async {
      final fakeLibrary = _FakeStrangerLibrary();
      final controller = MatchModeController(
        dialEngine: const TwoDialEngine(),
        rotator: GuardedPositionRotator(),
        definition: makananModule,
        strangerLibrary: fakeLibrary, // supplied but must go unused
      );
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);

      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      expect(trial.items, hasLength(2));
      expect(fakeLibrary.calls, isEmpty);
    });
  });
}
