import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';

void main() {
  late AdvancementTracker tracker;
  const childId = 'child_1';
  const module = ModuleId.makanan;
  const mode = ResponseMode.tap;

  setUp(() {
    tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(InMemoryChildRepository(seed: false)),
    );
  });

  test(
      'advances one step after requiredStreakForAdvancement correct-without-hint responses',
      () async {
    AdvancementResult? result;
    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      result = await tracker.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }

    const expected = LadderPosition(
      arraySize: 3,
      similarityTier: SimilarityTier.differentCategory,
    );
    expect(result?.position, expected);
    expect(result?.masteredAtCeiling, false);
    expect(tracker.streakFor(childId: childId, module: module, mode: mode), 0);
  });

  test('does not advance before the streak is met', () async {
    AdvancementResult? result;
    for (var i = 0; i < requiredStreakForAdvancement - 1; i++) {
      result = await tracker.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }

    expect(result?.position, const LadderPosition.start());
    expect(result?.masteredAtCeiling, false);
    expect(
      tracker.streakFor(childId: childId, module: module, mode: mode),
      requiredStreakForAdvancement - 1,
    );
  });

  test('an incorrect response resets the streak', () async {
    await tracker.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: true,
      hintShown: false,
    );
    await tracker.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: false,
      hintShown: false,
    );

    expect(tracker.streakFor(childId: childId, module: module, mode: mode), 0);
  });

  test(
      'a correct-but-hinted response resets the streak — it does not extend it',
      () async {
    await tracker.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: true,
      hintShown: false,
    );
    await tracker.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: true,
      hintShown: true,
    );

    expect(tracker.streakFor(childId: childId, module: module, mode: mode), 0);
  });

  test('a miss never steps the ladder back down — only resets the streak',
      () async {
    final persistence = LadderPersistence(InMemoryChildRepository(seed: false));
    await persistence.save(
      childId: childId,
      module: module,
      mode: mode,
      position: const LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      ),
    );
    final trackerAtMidLadder = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );

    final result = await trackerAtMidLadder.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: false,
      hintShown: false,
    );

    const expected = LadderPosition(
      arraySize: 3,
      similarityTier: SimilarityTier.sameCategoryDistinct,
    );
    expect(result.position, expected);
    expect(result.masteredAtCeiling, false);
  });

  test('advancement is persisted immediately through the ChildRepository',
      () async {
    final repository = InMemoryChildRepository(seed: false);
    final trackerWithSharedRepo = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(repository),
    );

    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      await trackerWithSharedRepo.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }

    final persisted = await repository.getLadderPosition(
      childId: childId,
      module: module,
      mode: mode,
    );
    const expected = LadderPosition(
      arraySize: 3,
      similarityTier: SimilarityTier.differentCategory,
    );
    expect(persisted, expected);
  });

  test('streaks for different (childId, module, mode) keys are independent',
      () async {
    await tracker.recordResponse(
      childId: childId,
      module: module,
      mode: mode,
      correct: true,
      hintShown: false,
    );
    await tracker.recordResponse(
      childId: 'child_2',
      module: module,
      mode: mode,
      correct: true,
      hintShown: false,
    );
    await tracker.recordResponse(
      childId: 'child_2',
      module: module,
      mode: mode,
      correct: true,
      hintShown: false,
    );

    final childStreak =
        tracker.streakFor(childId: childId, module: module, mode: mode);
    final child2Streak =
        tracker.streakFor(childId: 'child_2', module: module, mode: mode);
    expect(childStreak, 1);
    expect(child2Streak, 2);
  });

  test('only clearing a streak at LRFFC array 4 triggers mastery', () async {
    final persistence = LadderPersistence(InMemoryChildRepository(seed: false));
    // Array four is the celebrated milestone despite the extended practice.
    await persistence.save(
      childId: childId,
      module: module,
      mode: mode,
      position: const LadderPosition(
          arraySize: 4, similarityTier: SimilarityTier.lrffc),
    );
    final trackerAtCeiling = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );

    AdvancementResult? result;
    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      result = await trackerAtCeiling.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }
    expect(
        result?.position,
        const LadderPosition(
            arraySize: 5, similarityTier: SimilarityTier.lrffc));
    expect(result?.masteredAtCeiling, true);

    // LRFFC arrays five and six do not trigger mastery again.
    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      result = await trackerAtCeiling.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }
    expect(
        result?.position,
        const LadderPosition(
            arraySize: 6, similarityTier: SimilarityTier.lrffc));
    expect(result?.masteredAtCeiling, false);

    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      result = await trackerAtCeiling.recordResponse(
        childId: childId,
        module: module,
        mode: mode,
        correct: true,
        hintShown: false,
      );
    }
    expect(
        result?.position,
        const LadderPosition(
            arraySize: 6, similarityTier: SimilarityTier.lrffc));
    expect(result?.masteredAtCeiling, false);
  });

  test('speak mode is at ceiling on similarity alone, array size ignored',
      () async {
    final persistence = LadderPersistence(InMemoryChildRepository(seed: false));
    await persistence.save(
      childId: childId,
      module: module,
      mode: ResponseMode.speak,
      // arraySize is irrelevant to speak mode (§4.4 has no array) — 2, not 4.
      position: const LadderPosition(
          arraySize: 2, similarityTier: SimilarityTier.lrffc),
    );
    final speakTracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );

    AdvancementResult? result;
    for (var i = 0; i < requiredStreakForAdvancement; i++) {
      result = await speakTracker.recordResponse(
        childId: childId,
        module: module,
        mode: ResponseMode.speak,
        correct: true,
        hintShown: false,
      );
    }

    expect(result?.masteredAtCeiling, true);
  });
}
