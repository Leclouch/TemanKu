import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:temanku/photo_pipeline/quality_gate/quality_gate.dart';

/// Builds a flat, single-luminance test image — every check but blur (which a
/// perfectly flat image always fails, by definition of zero edge variance) can
/// be exercised against it.
img.Image _uniformImage(int luminance, {int width = 64, int height = 64}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, luminance, luminance, luminance);
    }
  }
  return image;
}

/// A checkerboard has both strong edges (passes blur) and a wide spread of
/// pixel values (passes the contrast/subject check) around a mid luminance.
img.Image _checkerboard({int width = 64, int height = 64, int squareSize = 4}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final isLight = ((x ~/ squareSize) + (y ~/ squareSize)).isEven;
      final v = isLight ? 200 : 60;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

void main() {
  group('ClassicalCvQualityGate.checkBytes', () {
    test('a near-black uniform photo fails as tooDark', () {
      const gate = ClassicalCvQualityGate();
      final bytes = img.encodePng(_uniformImage(10));

      final result = gate.checkBytes(bytes);

      expect(result.passed, isFalse);
      expect(result.issue, QualityIssue.tooDark);
    });

    test('a near-white uniform photo fails as tooBright', () {
      const gate = ClassicalCvQualityGate();
      final bytes = img.encodePng(_uniformImage(250));

      final result = gate.checkBytes(bytes);

      expect(result.passed, isFalse);
      expect(result.issue, QualityIssue.tooBright);
    });

    test(
        'a well-lit but perfectly flat photo fails as blurry (zero edge variance)',
        () {
      const gate = ClassicalCvQualityGate();
      final bytes = img.encodePng(_uniformImage(128));

      final result = gate.checkBytes(bytes);

      expect(result.passed, isFalse);
      expect(result.issue, QualityIssue.blurry);
    });

    test(
        'a well-lit, low-contrast photo fails as noSubject once blur is not the blocker',
        () {
      // Isolate the contrast/subject check by configuring the blur threshold
      // so a perfectly flat image (variance 0) still passes it — the same
      // technique dial_engine tests use: hold every variable but the one
      // under test fixed via direct construction rather than fragile pixel
      // art that happens to sit exactly between two thresholds.
      const gate = ClassicalCvQualityGate(blurVarianceThreshold: -1);
      final bytes = img.encodePng(_uniformImage(128));

      final result = gate.checkBytes(bytes);

      expect(result.passed, isFalse);
      expect(result.issue, QualityIssue.noSubject);
    });

    test('a well-lit, high-contrast, sharp-edged photo passes', () {
      const gate = ClassicalCvQualityGate();
      final bytes = img.encodePng(_checkerboard());

      final result = gate.checkBytes(bytes);

      expect(result.passed, isTrue);
      expect(result.issue, isNull);
    });

    test('undecodable bytes fail as noSubject rather than throwing', () {
      const gate = ClassicalCvQualityGate();
      final garbage = Uint8List.fromList(List<int>.filled(16, 0));

      final result = gate.checkBytes(garbage);

      expect(result.passed, isFalse);
      expect(result.issue, QualityIssue.noSubject);
    });
  });

  group('qualityIssueRetakePrompt', () {
    test('every QualityIssue has a Bahasa retake prompt', () {
      for (final issue in QualityIssue.values) {
        expect(qualityIssueRetakePrompt, contains(issue));
        expect(qualityIssueRetakePrompt[issue], isNotEmpty);
      }
    });

    test('prompts stay free of CV jargon — friendly copy, not a diagnostic',
        () {
      final jargon = RegExp(
        r'variance|laplacian|luminance|threshold|contrast|pixel',
        caseSensitive: false,
      );
      for (final prompt in qualityIssueRetakePrompt.values) {
        final matchesJargon = jargon.hasMatch(prompt);
        expect(matchesJargon, isFalse, reason: 'leaked jargon: $prompt');
      }
    });
  });

  group('AlwaysPassQualityGate', () {
    test('always passes without touching the filesystem', () async {
      const gate = AlwaysPassQualityGate();
      final result = await gate.check('/path/that/does/not/exist.jpg');
      expect(result.passed, isTrue);
    });
  });
}
