import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/speech/articulation_tolerance.dart';

LadderPosition _at(SimilarityTier tier, int arraySize) =>
    LadderPosition(similarityTier: tier, arraySize: arraySize);

void main() {
  group('ArticulationTolerance', () {
    test('a child at the start of the ladder gets the most forgiving bar', () {
      expect(
        ArticulationTolerance.forPosition(const LadderPosition.start()),
        ArticulationTolerance.maxTolerance,
      );
    });

    test('the bar tightens as the similarity tier advances', () {
      // Read at the entry array size so only the tier is varying.
      final byTier = [
        for (final tier in SimilarityTier.values)
          ArticulationTolerance.forPosition(_at(tier, ArraySize.min)),
      ];

      expect(byTier[0], greaterThan(byTier[1]));
      expect(byTier[1], greaterThan(byTier[2]));
      // lrffc holds at the floor rather than dropping below it — by Step 10
      // the word is familiar and only the instruction changed, which is not
      // an articulation problem.
      expect(byTier[3], byTier[2]);
    });

    test('settling into a tier (array size above the minimum) tightens by one', () {
      for (final tier in SimilarityTier.values) {
        final entry = ArticulationTolerance.forPosition(_at(tier, ArraySize.min));
        final settled = ArticulationTolerance.forPosition(_at(tier, ArraySize.min + 1));
        expect(
          settled,
          lessThanOrEqualTo(entry),
          reason: '$tier got easier as the array grew',
        );
      }
    });

    test('never falls below the floor, at any position', () {
      // Below the floor, ordinary childhood articulation variation — and the
      // wav2vec2 model's own error on child speech, which is not small —
      // would start reading as failure.
      for (final tier in SimilarityTier.values) {
        for (var size = ArraySize.min; size <= ArraySize.max; size++) {
          expect(
            ArticulationTolerance.forPosition(_at(tier, size)),
            greaterThanOrEqualTo(ArticulationTolerance.minTolerance),
            reason: 'tier $tier, array $size fell through the floor',
          );
        }
      }
    });

    test('never exceeds the ceiling, at any position', () {
      for (final tier in SimilarityTier.values) {
        for (var size = ArraySize.min; size <= ArraySize.max; size++) {
          expect(
            ArticulationTolerance.forPosition(_at(tier, size)),
            lessThanOrEqualTo(ArticulationTolerance.maxTolerance),
          );
        }
      }
    });

    test('stepping UP a similarity tier never tightens the bar mid-step', () {
      // §4.5's one-dial-at-a-time rule, applied to articulation. When the
      // engine steps similarity up it also resets the array to its minimum
      // (§4.4), so this is the transition a child actually experiences —
      // and it must not charge them twice for one step. The bar at the new
      // tier's entry must be at least as forgiving as it was at the old
      // tier's *settled* end.
      const tiers = SimilarityTier.values;
      for (var i = 0; i < tiers.length - 1; i++) {
        final settledAtOldTier =
            ArticulationTolerance.forPosition(_at(tiers[i], ArraySize.max));
        final entryAtNewTier =
            ArticulationTolerance.forPosition(_at(tiers[i + 1], ArraySize.min));
        expect(
          entryAtNewTier,
          greaterThanOrEqualTo(settledAtOldTier),
          reason: 'stepping ${tiers[i].name} → ${tiers[i + 1].name} '
              'tightened articulation at the same moment discrimination got harder',
        );
      }
    });
  });
}
