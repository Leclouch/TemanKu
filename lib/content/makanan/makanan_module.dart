import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';

/// Makanan — MVP module 1 (source-of-truth §4.2).
///
/// Content source: photos of the child's real snacks and foods.
/// Classification: edible / not edible.
///
/// Chosen for MVP because it has zero unresolved design debt, instant judge
/// legibility, and the worked difficulty table in §4.4 (target: pisang).
const makananModule = ModuleDefinition(
  id: ModuleId.makanan,
  displayName: 'Makanan',
  targetCategoryLabel: 'boleh dimakan',
  distractorCategoryLabel: 'bukan makanan',
  // Brand palette only (`core/design/tokens.dart` → TkPalette). Colour is
  // always paired with a shape and never carries meaning alone.
  targetStyle: CategoryStyle(
    color: TkPalette.green,
    shape: CategoryShape.circle,
  ),
  distractorStyle: CategoryStyle(
    color: TkPalette.pink,
    shape: CategoryShape.diamond,
  ),
  usesClassifier: true,
  usesBundledDistractors: false,
  similarityTierCopy: {
    SimilarityTier.differentCategory: 'benda yang jelas berbeda',
    SimilarityTier.sameCategoryDistinct: 'makanan lain yang mudah dibedakan',
    SimilarityTier.similar: 'benda yang bentuknya mirip',
    SimilarityTier.lrffc: 'memilih berdasarkan fungsi, bukan nama',
  },
  lrffcInstruction: 'tunjuk yang boleh dimakan',
);
