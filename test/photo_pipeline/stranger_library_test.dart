import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('acceptableDistractorAgeGroups', () {
    test('tier 1 (differentCategory) picks the group farthest from the target', () {
      expect(
        acceptableDistractorAgeGroups(
          targetAgeGroup: AgeGroup.child,
          tier: SimilarityTier.differentCategory,
        ),
        [AgeGroup.elderly],
      );
      expect(
        acceptableDistractorAgeGroups(
          targetAgeGroup: AgeGroup.elderly,
          tier: SimilarityTier.differentCategory,
        ),
        [AgeGroup.child],
      );
    });

    test('tier 2 (sameCategoryDistinct) picks neighbouring group(s), never the target itself', () {
      final forChild = acceptableDistractorAgeGroups(
        targetAgeGroup: AgeGroup.child,
        tier: SimilarityTier.sameCategoryDistinct,
      );
      expect(forChild, [AgeGroup.teen]);

      final forTeen = acceptableDistractorAgeGroups(
        targetAgeGroup: AgeGroup.teen,
        tier: SimilarityTier.sameCategoryDistinct,
      );
      expect(forTeen.toSet(), {AgeGroup.child, AgeGroup.adult});
      expect(forTeen, isNot(contains(AgeGroup.teen)));
    });

    test('tier 3 (similar) and lrffc both pick the same group as the target', () {
      for (final tier in [SimilarityTier.similar, SimilarityTier.lrffc]) {
        final result = acceptableDistractorAgeGroups(targetAgeGroup: AgeGroup.adult, tier: tier);
        expect(result, [AgeGroup.adult]);
      }
    });

    test('every age group has a non-empty candidate set at every tier', () {
      for (final target in AgeGroup.values) {
        for (final tier in SimilarityTier.values) {
          final result = acceptableDistractorAgeGroups(targetAgeGroup: target, tier: tier);
          expect(result, isNotEmpty, reason: '$target at $tier');
        }
      }
    });
  });

  group('BundledStrangerLibrary', () {
    final library = BundledStrangerLibrary();

    test('picks distractors tagged with an acceptable age group for the tier', () async {
      final picked = await library.pickDistractors(
        count: 3,
        targetAgeGroup: AgeGroup.adult,
        tier: SimilarityTier.similar, // same-group tier — every pick must be adult.
      );

      expect(picked, hasLength(3));
      for (final image in picked) {
        expect(image.ageGroup, AgeGroup.adult);
        expect(image.assetPath, startsWith('assets/stranger_library/'));
      }
    });

    test('tier 1 for a child target returns only elderly-tagged images', () async {
      final picked = await library.pickDistractors(
        count: 2,
        targetAgeGroup: AgeGroup.child,
        tier: SimilarityTier.differentCategory,
      );

      expect(picked, isNotEmpty);
      for (final image in picked) {
        expect(image.ageGroup, AgeGroup.elderly);
      }
    });

    test('never reads outside assets/stranger_library/', () async {
      final picked = await library.pickDistractors(
        count: 5,
        targetAgeGroup: AgeGroup.teen,
        tier: SimilarityTier.lrffc,
      );
      for (final image in picked) {
        expect(image.assetPath, startsWith('assets/stranger_library/'));
      }
    });
  });
}
