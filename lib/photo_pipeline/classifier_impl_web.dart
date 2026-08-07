import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/manual_label_classifier.dart';

ClassifierService createClassifier() => ManualLabelClassifier();
