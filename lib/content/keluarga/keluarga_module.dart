import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';

/// Keluarga — MVP module 2 (source-of-truth §4.2).
///
/// Content source: photos of actual family members.
/// Classification: my family / not my family.
///
/// Chosen for MVP because it is **structurally impossible without
/// personalization** — the strongest single proof of the own-photo thesis — and
/// requires no vision model at all (§6), making it cheap. This is the demo's
/// closing beat.
///
/// Its similarity axis is **demographic closeness of the stranger** (§4.4):
/// different age group at the easy end, same-age same-gender at the hard end,
/// forcing genuine recognition over superficial cues.
const keluargaModule = ModuleDefinition(
  id: ModuleId.keluarga,
  displayName: 'Keluarga',
  targetCategoryLabel: 'keluargaku',
  distractorCategoryLabel: 'bukan keluarga',
  // Brand palette only (`core/design/tokens.dart` → TkPalette). Colour is
  // always paired with a shape and never carries meaning alone.
  targetStyle: CategoryStyle(
    color: TkPalette.blue,
    shape: CategoryShape.circle,
  ),
  distractorStyle: CategoryStyle(
    color: TkPalette.paleYellow,
    shape: CategoryShape.square,
  ),
  // Permanently false: guardian supplies name/relationship directly — the only
  // valid source for that data (§5.3). This is not a deferred feature.
  usesClassifier: false,
  usesBundledDistractors: true,
  similarityTierCopy: {
    SimilarityTier.differentCategory: 'orang dari kelompok usia berbeda',
    SimilarityTier.sameCategoryDistinct: 'orang dewasa lain',
    SimilarityTier.similar: 'usia dan jenis kelamin yang sama',
    SimilarityTier.lrffc: 'mengenali keluarga di antara banyak orang',
  },
  lrffcInstruction: 'tunjuk keluargamu',
);
