/// Module definitions — **data, not logic** (architecture doc).
///
/// Jointly touched by IT-1 and IT-2. Keep behaviour out of this folder: if a rule
/// lives here instead of in `engine/`, it will be duplicated for the next module.
library;

import 'package:temanku/core/constants/domain_enums.dart';

/// Everything that distinguishes one module from another, declaratively.
class ModuleDefinition {
  const ModuleDefinition({
    required this.id,
    required this.displayName,
    required this.targetCategoryLabel,
    required this.distractorCategoryLabel,
    required this.usesClassifier,
    required this.usesBundledDistractors,
    required this.similarityTierCopy,
    required this.lrffcInstruction,
  });

  final ModuleId id;

  /// Bahasa name shown to the guardian. Never shown to the child as a "level".
  final String displayName;

  /// The binary classification, in the guardian's words (§4.2).
  final String targetCategoryLabel;
  final String distractorCategoryLabel;

  /// Makanan only in MVP (§5.2). Keluarga is **permanently** false — guardian
  /// supplies name and relationship directly; there is no face model, by design.
  final bool usesClassifier;

  /// Keluarga draws distractors from the bundled stranger library (§5.3) rather
  /// than from the child's own photos.
  final bool usesBundledDistractors;

  /// What each similarity tier *means* in this module — Makanan's axis is visual,
  /// Keluarga's is demographic closeness (§4.4). Used for guardian summary copy,
  /// which describes dials, not levels.
  final Map<SimilarityTier, String> similarityTierCopy;

  /// The Step-10 semantic instruction.
  final String lrffcInstruction;
}
