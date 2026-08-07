import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';

const String _modelAsset = 'assets/models/makanan_classifier.tflite';
const String _labelsAsset = 'assets/models/makanan_labels.txt';

/// Below this, [TfliteClassifier.suggestLabel] returns null rather than a
/// guess (§5.2) — named and top-level so it is one obvious place to tune,
/// not a magic number buried in a method body.
const double classifierConfidenceThreshold = 0.7;

/// Primary label extraction — small closed-set on-device classifier
/// (MobileNet-class, exported from Teachable Machine as TFLite). Source-of-truth §11.
///
/// §11 records that a **pretrained food/object classifier is an acceptable
/// fallback within this implementation** — guardian confirmation catches misses,
/// so a general-purpose model that names "pisang" correctly most of the time is
/// good enough.
///
/// Confidence handling is the load-bearing part: below [classifierConfidenceThreshold],
/// this returns **null** and lets the guardian answer *"apa nama benda ini?"*
/// It never surfaces a low-confidence guess as if it were certain.
///
/// Model/label loading failure and inference failure both degrade to the same
/// place as [ManualLabelClassifier] — a null suggestion — rather than ever
/// throwing out to the upload flow. That flow already treats null as the
/// normal "ask the guardian" outcome, so this is a graceful downgrade, not a
/// special error path.
///
/// **Tripwire: Day 3 evening.** Not reliably usable by then → swap
/// `classifierServiceProvider` back to `ManualLabelClassifier` in
/// `core/service_locator.dart`. Decide once, move on.
class TfliteClassifier implements ClassifierService {
  Interpreter? _interpreter;
  List<String>? _labels;
  int _inputHeight = 0;
  int _inputWidth = 0;

  @override
  bool get canSuggestLabels => true;

  @override
  Future<void> initialize() async {
    try {
      final interpreter = await Interpreter.fromAsset(_modelAsset);

      // Input dimensions come from the model itself, not a hardcoded guess —
      // Teachable Machine typically exports at 224x224, but this reads
      // whatever the bundled .tflite actually declares.
      final inputTensor = interpreter.getInputTensor(0);
      final inputShape = inputTensor.shape; // [1, height, width, 3]
      if (inputShape.length != 4 || inputShape[3] != 3) {
        throw StateError('Unexpected classifier input shape: $inputShape');
      }
      if (inputTensor.type != TensorType.float32) {
        // Teachable Machine's floating-point export (the one this classifier
        // is built for) takes 0-1 normalized float input. A quantized/uint8
        // export needs different preprocessing this class doesn't implement.
        throw StateError('Unsupported classifier input tensor type: ${inputTensor.type}');
      }

      final labels = _parseLabels(await rootBundle.loadString(_labelsAsset));
      final outputClasses = interpreter.getOutputTensor(0).shape.last;
      if (outputClasses != labels.length) {
        throw StateError(
          'Label count (${labels.length}) does not match model output classes ($outputClasses) — '
          'is $_labelsAsset stale relative to $_modelAsset?',
        );
      }

      _interpreter = interpreter;
      _labels = labels;
      _inputHeight = inputShape[1];
      _inputWidth = inputShape[2];
    } catch (error, stackTrace) {
      // Never let a load failure surface to the guardian — canSuggestLabels
      // stays true (the interface contract), but suggestLabel below reads
      // _interpreter == null and returns null, which the upload flow already
      // treats as "ask the guardian" (the same outcome ManualLabelClassifier
      // always produces).
      developer.log(
        'TfliteClassifier failed to load; falling back to manual entry.',
        name: 'TfliteClassifier',
        error: error,
        stackTrace: stackTrace,
      );
      _interpreter?.close();
      _interpreter = null;
      _labels = null;
    }
  }

  /// Teachable Machine's exported label file prefixes each line with its
  /// class index ("0 Pisang"). The index is redundant with line position (the
  /// file is already index-matched to the model's output, per its own
  /// header) — this strips the prefix so the label text handed back to
  /// callers is exactly "Pisang", never "0 Pisang". This is the *only* place
  /// that parses the file; nothing else in this codebase should ever
  /// duplicate a label string outside it.
  List<String> _parseLabels(String raw) => [
        for (final line in raw.split('\n'))
          if (line.trim().isNotEmpty) _stripIndexPrefix(line.trim()),
      ];

  static final RegExp _indexPrefix = RegExp(r'^\d+\s+(.*)$');

  String _stripIndexPrefix(String line) => _indexPrefix.firstMatch(line)?.group(1) ?? line;

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async {
    // No face model, by design and permanently (§5.3) — and more generally,
    // this classifier only ever knows the Makanan label set.
    if (module != ModuleId.makanan) return null;

    final interpreter = _interpreter;
    final labels = _labels;
    if (interpreter == null || labels == null) {
      // Model never loaded (missing asset, load failure) — same "ask the
      // guardian" outcome as ManualLabelClassifier, not an error.
      return null;
    }

    try {
      final input = await _preprocess(imagePath);
      final output = [List<double>.filled(labels.length, 0.0)];
      interpreter.run(input, output);

      var bestIndex = 0;
      var bestScore = output[0][0];
      for (var i = 1; i < output[0].length; i++) {
        if (output[0][i] > bestScore) {
          bestScore = output[0][i];
          bestIndex = i;
        }
      }

      if (bestScore < classifierConfidenceThreshold) return null;
      return LabelSuggestion(label: labels[bestIndex], confidence: bestScore);
    } catch (error, stackTrace) {
      developer.log(
        'TfliteClassifier inference failed; treating as no suggestion.',
        name: 'TfliteClassifier',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Decode → resize to the model's own input dimensions → normalize to
  /// Teachable Machine's 0-1 float training range. Returns a 4D nested list
  /// shaped `[1, height, width, 3]`, matching the input tensor exactly —
  /// `tflite_flutter`'s `run` consumes nested lists directly rather than a
  /// flat buffer.
  Future<List<List<List<List<double>>>>> _preprocess(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image at $imagePath');
    }
    final resized = img.copyResize(decoded, width: _inputWidth, height: _inputHeight);

    return [
      List.generate(
        _inputHeight,
        (y) => List.generate(_inputWidth, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    ];
  }

  @override
  Future<void> dispose() async {
    // Avoid leaking the native interpreter — closed exactly once regardless
    // of whether initialize() ever succeeded.
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }
}
