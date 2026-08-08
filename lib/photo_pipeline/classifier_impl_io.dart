import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/mlkit_classifier.dart';

// TfliteClassifier (photo_pipeline/tflite_classifier.dart) is the documented
// ADR-4 revert if MlKitClassifier ever proves unreliable — see that class's
// tripwire note in core/service_locator.dart.
ClassifierService createClassifier() => MlKitClassifier();
