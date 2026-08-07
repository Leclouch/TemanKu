import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/engine/modes/speak/speak_mode_controller.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/speech/three_button_fallback.dart';

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
  group('SpeakModeController.nextTrial', () {
    final controller = SpeakModeController(ThreeButtonFallback());

    test('composes a single stimulus — items is always empty (§4.4 no array)', () async {
      const position = LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.items, isEmpty);
      expect(trial.target.category, PhotoCategory.target);
    });

    test('below LRFFC the instruction names the target photo\'s own label', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 1, distractors: 3),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.instruction, 'ucapkan target_0');
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
      expect(trial.instruction, 'ucapkan pisang');
    });

    test('at LRFFC an unlabelled target photo is still eligible', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 3, distractors: 5, labelled: false),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );
      expect(trial.target.category, PhotoCategory.target);
    });

    test('throws when there are no target photos to compose a trial', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      expect(
        () => controller.nextTrial(
          position: position,
          available: _photos(targets: 0, distractors: 3),
          recentTargetSlots: const [],
          recentTargetZones: const [],
        ),
        throwsStateError,
      );
    });
  });

  group('SpeakModeController.judge', () {
    final controller = SpeakModeController(ThreeButtonFallback());

    test('the guardian\'s verdict passes straight through, unmodified', () async {
      const position = LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory);
      final trial = await controller.nextTrial(
        position: position,
        available: _photos(targets: 1, distractors: 1),
        recentTargetSlots: const [],
        recentTargetZones: const [],
      );

      expect(controller.judge(trial, TrialOutcome.correct), TrialOutcome.correct);
      expect(controller.judge(trial, TrialOutcome.incorrect), TrialOutcome.incorrect);
      expect(controller.judge(trial, TrialOutcome.notAttempted), TrialOutcome.notAttempted);
    });
  });

  test('SpeakModeController.vad exposes the injected VadService for the screen to drive', () {
    final vad = ThreeButtonFallback();
    final controller = SpeakModeController(vad);
    expect(controller.vad, same(vad));
  });

  group('advancement driven from speak mode', () {
    test('the shared streak/dial machinery steps correctly when fed from SpeakModeController.judge',
        () async {
      const childId = 'child_1';
      const module = ModuleId.makanan;
      const dialEngine = TwoDialEngine();
      final controller = SpeakModeController(ThreeButtonFallback());
      final tracker = AdvancementTracker(
        dialEngine: dialEngine,
        persistence: LadderPersistence(InMemoryChildRepository(seed: false)),
      );
      final photos = _photos(targets: 3, distractors: 5);

      var position = const LadderPosition.start();

      for (var i = 0; i < requiredStreakForAdvancement; i++) {
        final trial = await controller.nextTrial(
          position: position,
          available: photos,
          recentTargetSlots: const [],
          recentTargetZones: const [],
        );

        final outcome = controller.judge(trial, TrialOutcome.correct);
        expect(outcome, TrialOutcome.correct);

        position = (await tracker.recordResponse(
          childId: childId,
          module: module,
          mode: ResponseMode.speak,
          correct: true,
          hintShown: false,
        ))
            .position;
      }

      // Speak mode's advanceForMode moves similarity only and leaves the
      // (inapplicable) array value untouched — proof this test is exercising
      // DialEngine.advanceForMode's speak-mode branch, not the tap/match
      // advance() path.
      expect(position, dialEngine.advanceForMode(const LadderPosition.start(), ResponseMode.speak));
      expect(position.arraySize, ArraySize.min);
      expect(tracker.streakFor(childId: childId, module: module, mode: ResponseMode.speak), 0);
    });

    test('a notAttempted verdict resets the streak, same as incorrect', () async {
      const childId = 'child_1';
      const module = ModuleId.makanan;
      final tracker = AdvancementTracker(
        dialEngine: const TwoDialEngine(),
        persistence: LadderPersistence(InMemoryChildRepository(seed: false)),
      );

      await tracker.recordResponse(
        childId: childId,
        module: module,
        mode: ResponseMode.speak,
        correct: true,
        hintShown: false,
      );
      expect(tracker.streakFor(childId: childId, module: module, mode: ResponseMode.speak), 1);

      await tracker.recordResponse(
        childId: childId,
        module: module,
        mode: ResponseMode.speak,
        correct: false, // TrialOutcome.notAttempted maps to correct: false at the call site.
        hintShown: false,
      );
      expect(tracker.streakFor(childId: childId, module: module, mode: ResponseMode.speak), 0);
    });
  });
}
