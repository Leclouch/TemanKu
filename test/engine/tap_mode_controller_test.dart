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
import 'package:temanku/engine/modes/tap/tap_mode_controller.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';

/// Records what it was asked for, so tests can assert the controller passed
/// the right tier/age-group through without needing real bundled assets —
/// mirrors `match_mode_controller_test.dart`'s fake.
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

List<Photo> _photos({required int targets, required int distractors, bool labelled = true}) => [
      for (var i = 0; i < targets; i++)
        Photo(
          id: 'target_$i',
          childId: 'child_1',
          module: ModuleId.makanan,
          localPath: '/fake/target_$i.jpg',
          category: PhotoCategory.target,
          label: labelled ? 'target_$i' : null,
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
  group('TapModeController.nextTrial', () {
    final controller = TapModeController(
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

    test('exactly one item in the array is a target-category photo', () async {
      const position = LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.items.where((p) => p.category == PhotoCategory.target), hasLength(1));
    });

    test('below LRFFC the instruction names the target photo\'s own label', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 1, distractors: 3),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.instruction, 'tunjuk target_0');
    });

    test('at LRFFC the instruction is the module\'s fixed semantic copy', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.instruction, makananModule.lrffcInstruction);
    });

    test('below LRFFC an unlabelled target photo is skipped', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: [
          ..._photos(targets: 0, distractors: 3),
          const Photo(
            id: 'unlabelled',
            childId: 'child_1',
            module: ModuleId.makanan,
            localPath: '/fake/unlabelled.jpg',
            category: PhotoCategory.target,
          ),
          const Photo(
            id: 'labelled',
            childId: 'child_1',
            module: ModuleId.makanan,
            localPath: '/fake/labelled.jpg',
            category: PhotoCategory.target,
            label: 'pisang',
          ),
        ],
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.instruction, 'tunjuk pisang');
    });

    test('at LRFFC an unlabelled target photo is still eligible', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc);
      final TapTrial trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5, labelled: false),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.target.category, PhotoCategory.target);
    });

    test(
        'at extended LRFFC composes two distinct targets in their target slots',
        () async {
      const position =
          LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5, labelled: false),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      final targetSlots = trial.targetSlots;
      final targetItems = [for (final slot in targetSlots) trial.items[slot]];
      expect(targetSlots, hasLength(2));
      expect(targetSlots.toSet(), hasLength(2));
      expect(
          targetItems.every((photo) => photo.category == PhotoCategory.target),
          isTrue,
      );
      expect(targetItems.map((photo) => photo.id).toSet(), hasLength(2));
      expect(
          trial.items.where((photo) => photo.category == PhotoCategory.target),
          hasLength(2),
      );
    });

    test('at extended LRFFC requires two eligible target photos', () async {
      const position =
          LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc);

      expect(
        () => controller.nextTrial(
          position: position,
          available: _photos(targets: 1, distractors: 5, labelled: false),
          recentTargetSlots: const [],
          recentTargetZones: const [],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Two target photos are needed to compose a tap trial.',
          ),
        ),
      );
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

  group('TapModeController.judge', () {
    final controller = TapModeController(
      dialEngine: const TwoDialEngine(),
      rotator: GuardedPositionRotator(),
      definition: makananModule,
    );

    test('correct when the tapped slot holds the target-category photo', () async {
      const position = LadderPosition(arraySize: 3, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      final targetSlot = trial.items.indexWhere((p) => p.category == PhotoCategory.target);
      expect(controller.judge(trial, targetSlot), TrialOutcome.correct);
    });

    test('incorrect when the tapped slot holds a distractor-category photo', () async {
      const position = LadderPosition(arraySize: 3, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      final distractorSlot = trial.items.indexWhere((p) => p.category == PhotoCategory.distractor);
      expect(controller.judge(trial, distractorSlot), TrialOutcome.incorrect);
    });
  });

  group('advancement driven from tap mode', () {
    test('the shared streak/dial machinery steps correctly when fed from TapModeController.judge',
        () async {
      const childId = 'child_1';
      const module = ModuleId.makanan;
      const dialEngine = TwoDialEngine();
      final controller = TapModeController(
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

      for (var i = 0; i < requiredStreakForAdvancement; i++) {
        final trial = await controller.nextTrial(
          position: position,
          available: photos,
          recentTargetSlots: recentSlots,
          recentTargetZones: const [],
        );
        recentSlots = [trial.targetSlot, ...recentSlots].take(2).toList();

        // Tap the target slot every time — an unbroken independent-correct
        // streak.
        final targetSlot = trial.items.indexWhere((p) => p.category == PhotoCategory.target);
        final outcome = controller.judge(trial, targetSlot);
        expect(outcome, TrialOutcome.correct);

        position = (await tracker.recordResponse(
          childId: childId,
          module: module,
          mode: ResponseMode.tap,
          correct: true,
          hintShown: false,
        ))
            .position;
      }

      // TwoDialEngine.advanceForMode for a non-speak mode is the ordinary
      // array-then-tier step — proof the shared dial engine, not a tap-mode
      // fork, is what actually moved.
      expect(position, dialEngine.advance(const LadderPosition.start()));
      expect(tracker.streakFor(childId: childId, module: module, mode: ResponseMode.tap), 0);
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
      final controller = TapModeController(
        dialEngine: const TwoDialEngine(),
        rotator: GuardedPositionRotator(),
        definition: keluargaModule,
        strangerLibrary: fakeLibrary,
      );
      const position = LadderPosition(arraySize: 3, similarityTier: SimilarityTier.similar);

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
      final controller = TapModeController(
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
      final controller = TapModeController(
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
      final controller = TapModeController(
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
