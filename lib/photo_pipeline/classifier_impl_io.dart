import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/tflite_classifier.dart';

ClassifierService createClassifier() => TfliteClassifier();
