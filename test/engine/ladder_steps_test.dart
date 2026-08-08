import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/dial_engine/ladder_steps.dart';

void main() {
  const dialEngine = TwoDialEngine();

  test('tap steps include canonical extended LRFFC arrays through six', () {
    final steps = ladderStepsFor(
      dialEngine: dialEngine,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
    );

    expect(
      steps,
      containsAllInOrder(const [
        LadderPosition(arraySize: 4, similarityTier: SimilarityTier.lrffc),
        LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc),
        LadderPosition(arraySize: 6, similarityTier: SimilarityTier.lrffc),
      ]),
    );
    expect(
      steps.last,
      const LadderPosition(
        arraySize: 6,
        similarityTier: SimilarityTier.lrffc,
      ),
    );
  });

  test('speak steps advance through tiers without array growth', () {
    final steps = ladderStepsFor(
      dialEngine: dialEngine,
      module: ModuleId.keluarga,
      mode: ResponseMode.speak,
    );

    expect(
      steps,
      const [
        LadderPosition(
          arraySize: 2,
          similarityTier: SimilarityTier.differentCategory,
        ),
        LadderPosition(
          arraySize: 2,
          similarityTier: SimilarityTier.sameCategoryDistinct,
        ),
        LadderPosition(arraySize: 2, similarityTier: SimilarityTier.similar),
        LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc),
      ],
    );
  });
}
