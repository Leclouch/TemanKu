/// Label extraction — ADR-4 swappable interface. **IT-2 owns this folder.**
///
/// Source-of-truth §5, step 2: a closed-set on-device classifier names the object
/// for game text and speech. **Makanan only in MVP.**
///
/// The governing principle is §5's first line: **trust the guardian.** The
/// guardian's module choice *is* the categorization. This service never verifies,
/// second-guesses, or overrides that — it only offers a *name* for an object the
/// guardian has already categorized. There is deliberately no method here that
/// answers "is this really food?", because AI category-verification of guardian
/// uploads is a recorded dead end (§11).
///
/// When unconfident it stays quiet and the UI asks *"apa nama benda ini?"* —
/// framed as the AI needing help, not the guardian being checked.
///
/// Two implementations, decided up front:
///   - [TfliteClassifier]       — primary (MobileNetV3-class, TFLite)
///   - [ManualLabelClassifier]  — fallback (guardian types the label, no model)
///
/// Timeline tripwire: **Day 3 evening.** If the classifier isn't reliably usable,
/// swap in `core/service_locator.dart`. Cost per the fallback table: "loses one
/// 'silent AI' moment, pipeline stays honest."
library;

import 'package:temanku/core/constants/domain_enums.dart';

/// A proposed name for a photographed object.
class LabelSuggestion {
  const LabelSuggestion({
    required this.label,
    required this.confidence,
  });

  final String label;

  /// 0.0–1.0. Below the implementation's threshold, [ClassifierService.suggestLabel]
  /// returns null rather than a low-confidence guess — silence is the designed
  /// behaviour, not a failure path.
  final double confidence;
}

abstract class ClassifierService {
  /// True when this implementation can produce labels without asking the guardian.
  ///
  /// The upload flow reads this to decide whether to open the manual-entry field
  /// immediately or only on a null suggestion.
  bool get canSuggestLabels;

  Future<void> initialize();

  /// Propose a name for the object at [imagePath].
  ///
  /// Returns **null** when unconfident, or when this implementation has no model
  /// at all. Null is the signal to prompt the guardian — it is a normal outcome,
  /// not an error.
  ///
  /// [module] is passed because the answer is module-scoped: Keluarga must always
  /// return null (§5.3 — guardian supplies name and relationship directly; there
  /// is no model for faces, by design and permanently).
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  });

  Future<void> dispose();
}
