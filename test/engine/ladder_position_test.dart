import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';

/// `test/engine/` — **IT-1's priority.** The architecture doc is explicit that
/// this folder gets real unit tests while UI tests are the first thing to cut:
/// "a visual bug is easy to catch by hand in a 5-minute run-through; a wrong
/// dial-engine transition is not."
///
/// These are trivial tests over the ladder value object — enough to establish the
/// folder and keep `flutter test` green from day one. The substantive tests
/// (dial reset on similarity step-up, ≤2-repeat rotation guard, independent-
/// correct streak edge cases) arrive with the implementations on Day 2, and the
/// TODOs at the bottom name them so they don't get forgotten.
void main() {
  group('LadderPosition', () {
    test('everyone starts at array 2, different-category distractors', () {
      // §4.5: no placement quiz — Step 1 of every eligible mode+module.
      const start = LadderPosition.start();
      expect(start.arraySize, ArraySize.min);
      expect(start.similarityTier, SimilarityTier.differentCategory);
    });

    test('has value equality, so engine transitions are directly assertable', () {
      const a = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      );
      const b = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith moves one dial at a time', () {
      // §4.4: the two dials are independent and moved one at a time.
      const start = LadderPosition.start();
      final arrayGrown = start.copyWith(arraySize: 3);
      expect(arrayGrown.arraySize, 3);
      expect(arrayGrown.similarityTier, start.similarityTier);
    });

    test('similarity tiers are ordered easiest to hardest', () {
      // The engine relies on this declaration order to step the dial up.
      expect(SimilarityTier.values, [
        SimilarityTier.differentCategory,
        SimilarityTier.sameCategoryDistinct,
        SimilarityTier.similar,
        SimilarityTier.lrffc,
      ]);
    });
  });

  // TODO(IT-1) Day 2 — the tests that actually matter:
  //   - dial_engine: 2→3→4 within a tier, never skipping
  //   - dial_engine: advancing at array 4 steps similarity up AND resets array to 2
  //   - dial_engine: lrffc + array 4 + advance → unchanged (top of ladder)
  //   - dial_engine: speak mode never touches the array dial
  //   - rotation: recent slots [1, 1] excludes slot 1; [1] does not
  //   - advancement: a correct answer WITH the hint breaks the independent run
  //   - advancement: notAttempted is handled distinctly from incorrect
}
