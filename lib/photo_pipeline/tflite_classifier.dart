import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';

/// Primary label extraction — small closed-set on-device classifier
/// (MobileNetV3-class, TFLite). Source-of-truth §11.
///
/// TODO(IT-2): implement. Started Day 2, continued Day 3, per the timeline.
///
/// §11 records that a **pretrained food/object classifier is an acceptable
/// fallback within this implementation** — guardian confirmation catches misses,
/// so a general-purpose model that names "pisang" correctly most of the time is
/// good enough. Do not spend Day 3 training a custom model; that is not where the
/// remaining risk is.
///
/// Confidence handling is the load-bearing part: below threshold, return **null**
/// and let the guardian answer *"apa nama benda ini?"* Do not surface a
/// low-confidence guess as if it were certain.
///
/// **Tripwire: Day 3 evening.** Not reliably usable by then → swap
/// `classifierServiceProvider` back to `ManualLabelClassifier` in
/// `core/service_locator.dart`. Decide once, move on.
class TfliteClassifier implements ClassifierService {
  @override
  bool get canSuggestLabels => true;

  @override
  Future<void> initialize() async {
    // TODO(IT-2): load the .tflite model + label map from assets.
    throw UnimplementedError('TfliteClassifier.initialize');
  }

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async {
    // TODO(IT-2): decode + resize the image, run inference, map to the closed set.
    //
    // Two guards that must survive implementation:
    //   1. module == ModuleId.keluarga  → return null unconditionally. There is
    //      no face model, by design and permanently (§5.3).
    //   2. confidence < threshold       → return null, not a guess (§5.2).
    throw UnimplementedError('TfliteClassifier.suggestLabel');
  }

  @override
  Future<void> dispose() async {
    // TODO(IT-2)
  }
}
