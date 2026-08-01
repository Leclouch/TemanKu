import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';

/// Pre-approved classifier fallback (ADR-4) — **wired as the default for this
/// scaffold.**
///
/// No model at all. Always returns null, which the upload flow reads as "ask the
/// guardian" and renders the *"apa nama benda ini?"* field. Per the timeline's
/// fallback table this loses one silent-AI moment and nothing else; the pipeline
/// stays honest because the guardian was always the authority on the label anyway.
///
/// Default in `core/service_locator.dart` so the scaffold runs with no TFLite
/// dependency. Day 3's promotion to [TfliteClassifier] is one line.
class ManualLabelClassifier implements ClassifierService {
  /// False — the upload flow opens the manual-entry field straight away rather
  /// than waiting on a suggestion that will never come.
  @override
  bool get canSuggestLabels => false;

  @override
  Future<void> initialize() async {
    // No model to load.
  }

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async {
    // Always null: prompt the guardian. Not an error — this is the designed
    // fallback path.
    return null;
  }

  @override
  Future<void> dispose() async {}
}
