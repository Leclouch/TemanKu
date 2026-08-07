/// Photo quality gate — **IT-2, Day 1.**
///
/// Source-of-truth §5.1: every photo, every module, on-device, instant.
/// Blur / lighting / single-subject via **classical CV** (Laplacian variance,
/// luminance) — §11 is explicit that no ML model is needed here.
///
/// Scope boundary that matters: this is about **photo usability, not guardian
/// judgment**. The gate may say "this photo is too dark to play with"; it may
/// never say "this isn't food". Failure copy is a friendly retake prompt with no
/// jargon.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why a photo failed the gate. Each maps to one plain-Bahasa retake prompt —
/// no numbers, no CV vocabulary shown to the guardian.
enum QualityIssue {
  /// Laplacian variance below threshold.
  blurry,

  tooDark,

  tooBright,

  /// Contrast/edge energy too low for a distinguishable subject — a blank
  /// wall, a lens cap, a frame that's mostly empty background. Not about
  /// *which* object is in frame (that's the guardian's call, never this
  /// gate's) — only whether there is a usable subject at all.
  noSubject,
}

/// Guardian-facing retake copy for each [QualityIssue]. Plain Bahasa, no CV
/// jargon, no numbers — mirrors how `content/module_definition.dart`
/// co-locates its Bahasa copy with the domain data it describes, since this
/// codebase has no separate localization/copy layer (flagged as a gap: if a
/// second surface needs this same copy, that's the trigger to build one
/// rather than starting another ad hoc map like this).
const Map<QualityIssue, String> qualityIssueRetakePrompt = {
  QualityIssue.blurry: 'Coba lagi ya, fotonya agak buram.',
  QualityIssue.tooDark: 'Coba lagi ya, fotonya agak gelap. Coba cari tempat yang lebih terang.',
  QualityIssue.tooBright: 'Coba lagi ya, fotonya terlalu terang. Coba jauhi cahaya langsung.',
  QualityIssue.noSubject: 'Coba lagi ya, coba dekatkan kameranya ke bendanya.',
};

class QualityResult {
  const QualityResult.pass()
      : passed = true,
        issue = null;

  const QualityResult.fail(this.issue) : passed = false;

  final bool passed;
  final QualityIssue? issue;
}

abstract class QualityGate {
  /// Runs on-device and returns fast enough to feel instant in the capture flow.
  Future<QualityResult> check(String imagePath);
}

/// Classical CV, no ML model (§11). Order of checks, cheapest first: luminance
/// (mean brightness) → blur (Laplacian variance) → subject presence
/// (contrast/edge energy).
///
/// Threshold constants below are **placeholders pending real-device
/// calibration** against actual guardian-captured photos — same caveat as
/// `advancement/advancement_tracker.dart`'s streak constant. They are picked
/// to be directionally reasonable on a downscaled 8-bit grayscale image, not
/// validated against a labeled dataset.
class ClassicalCvQualityGate implements QualityGate {
  const ClassicalCvQualityGate({
    this.downscaleWidth = 320,
    this.blurVarianceThreshold = 60,
    this.minMeanLuminance = 40,
    this.maxMeanLuminance = 220,
    this.minContrast = 12,
  });

  /// Images are shrunk to this width before any check runs — classical CV
  /// here only needs to be fast, not sharp, and this is most of why `check`
  /// stays instant-feeling on-device.
  final int downscaleWidth;

  /// Variance of the Laplacian below this reads as blurry.
  final double blurVarianceThreshold;

  /// Mean luminance (0–255) below this reads as too dark.
  final double minMeanLuminance;

  /// Mean luminance (0–255) above this reads as too bright.
  final double maxMeanLuminance;

  /// Standard deviation of grayscale intensity below this reads as "no
  /// distinguishable subject" — a near-uniform frame.
  final double minContrast;

  static const _laplacianKernel = <num>[0, 1, 0, 1, -4, 1, 0, 1, 0];

  @override
  Future<QualityResult> check(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return checkBytes(bytes);
  }

  /// The actual CV pipeline, split out from [check] so it is testable against
  /// in-memory bytes without touching the filesystem.
  QualityResult checkBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Not decodable as an image at all. Closest existing failure mode:
      // there is no usable subject to judge.
      return const QualityResult.fail(QualityIssue.noSubject);
    }

    final resized = decoded.width > downscaleWidth
        ? img.copyResize(decoded, width: downscaleWidth)
        : decoded;
    final gray = img.grayscale(resized);

    final luminance = _meanChannel(gray);
    if (luminance < minMeanLuminance) {
      return const QualityResult.fail(QualityIssue.tooDark);
    }
    if (luminance > maxMeanLuminance) {
      return const QualityResult.fail(QualityIssue.tooBright);
    }

    final edgeMap = img.convolution(img.Image.from(gray), filter: _laplacianKernel);
    if (_channelVariance(edgeMap) < blurVarianceThreshold) {
      return const QualityResult.fail(QualityIssue.blurry);
    }

    if (_channelStdDev(gray) < minContrast) {
      return const QualityResult.fail(QualityIssue.noSubject);
    }

    return const QualityResult.pass();
  }

  double _meanChannel(img.Image image) {
    num sum = 0;
    for (final pixel in image) {
      sum += pixel.r;
    }
    return sum / (image.width * image.height);
  }

  double _channelVariance(img.Image image) {
    final mean = _meanChannel(image);
    num sumSquaredDeviation = 0;
    for (final pixel in image) {
      final deviation = pixel.r - mean;
      sumSquaredDeviation += deviation * deviation;
    }
    return sumSquaredDeviation / (image.width * image.height);
  }

  double _channelStdDev(img.Image image) => math.sqrt(_channelVariance(image));
}

/// Permissive stand-in — no longer the default (see `core/service_locator.dart`,
/// now wired to [ClassicalCvQualityGate]), kept for tests and for any future
/// surface that wants the upload flow without the gate in the loop.
class AlwaysPassQualityGate implements QualityGate {
  const AlwaysPassQualityGate();

  @override
  Future<QualityResult> check(String imagePath) async =>
      const QualityResult.pass();
}
