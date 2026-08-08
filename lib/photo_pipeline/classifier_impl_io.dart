import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/siglip_classifier.dart';

// Promoted over both prior attempts — see photo_pipeline/siglip_classifier.dart's
// doc comment for the full comparison against TfliteClassifier (locked to a
// bundled ~14-class model) and MlKitClassifier (on-device, but too generic
// for food photos). SiglipClassifier calls a self-hosted SigLIP2 zero-shot
// model over HTTPS instead, with this app's own label list sent at request
// time. See core/service_locator.dart's tripwire note.
ClassifierService createClassifier() => SiglipClassifier();
