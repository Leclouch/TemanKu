import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';

void main() {
  const engine = TwoDialEngine();

  group('TwoDialEngine.advance', () {
    test('2 -> 3 -> 4 within a tier, never skipping', () {
      const start = LadderPosition.start();
      const atThreeExpected = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.differentCategory,
      );
      const atFourExpected = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.differentCategory,
      );

      final atThree = engine.advance(start);
      expect(atThree, atThreeExpected);

      final atFour = engine.advance(atThree);
      expect(atFour, atFourExpected);
    });

    test('array 4 + advance steps similarity up and resets array to 2', () {
      const atFour = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.differentCategory,
      );
      const expected = LadderPosition(
        arraySize: 2,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      );

      expect(engine.advance(atFour), expected);
    });

    test('reset also fires between sameCategoryDistinct and similar', () {
      const atFour = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      );
      const expected = LadderPosition(
        arraySize: 2,
        similarityTier: SimilarityTier.similar,
      );

      expect(engine.advance(atFour), expected);
    });

    test('array 4 at similar tier steps up into lrffc, array resets to 2', () {
      const atFour = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.similar,
      );
      const expected = LadderPosition(
        arraySize: 2,
        similarityTier: SimilarityTier.lrffc,
      );

      expect(engine.advance(atFour), expected);
    });

    test('lrffc extends from array 4 through 6, then holds', () {
      const celebratedMilestone = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.lrffc,
      );
      const atFive = LadderPosition(
        arraySize: 5,
        similarityTier: SimilarityTier.lrffc,
      );
      const extendedCeiling = LadderPosition(
        arraySize: 6,
        similarityTier: SimilarityTier.lrffc,
      );

      expect(engine.advance(celebratedMilestone), atFive);
      expect(engine.advance(atFive), extendedCeiling);
      expect(engine.advance(extendedCeiling), extendedCeiling);
    });
  });

  group('TwoDialEngine.advanceForMode', () {
    test('speak mode advances similarity only, array untouched', () {
      const start = LadderPosition.start();
      const expected = LadderPosition(
        arraySize: ArraySize.min,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      );

      expect(engine.advanceForMode(start, ResponseMode.speak), expected);
    });

    test('speak mode at lrffc is also a fixed point', () {
      const top = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.lrffc,
      );

      expect(engine.advanceForMode(top, ResponseMode.speak), top);
    });

    test('tap and match modes delegate to the normal two-dial advance', () {
      const start = LadderPosition.start();

      expect(
        engine.advanceForMode(start, ResponseMode.tap),
        engine.advance(start),
      );
      expect(
        engine.advanceForMode(start, ResponseMode.match),
        engine.advance(start),
      );
    });
  });

  group('TwoDialEngine.distractorCountFor', () {
    test('speak mode has zero distractors regardless of array size', () {
      const position = LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.similar,
      );

      expect(engine.distractorCountFor(position, ResponseMode.speak), 0);
    });

    test('tap/match distractor count is array size minus the target', () {
      const position = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.differentCategory,
      );

      expect(engine.distractorCountFor(position, ResponseMode.tap), 2);
      expect(engine.distractorCountFor(position, ResponseMode.match), 2);
    });

    test('lrffc tap at extended array sizes has two targets', () {
      const position = LadderPosition(
        arraySize: 5,
        similarityTier: SimilarityTier.lrffc,
      );

      expect(engine.targetCountFor(position, ResponseMode.tap), 2);
      expect(engine.distractorCountFor(position, ResponseMode.tap), 3);
    });
  });
}
