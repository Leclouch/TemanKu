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

/// Why a photo failed the gate. Each maps to one plain-Bahasa retake prompt —
/// no numbers, no CV vocabulary shown to the guardian.
enum QualityIssue {
  /// Laplacian variance below threshold.
  blurry,

  tooDark,

  tooBright,

  /// More than one plausible subject — ambiguous which object is the target.
  multipleSubjects,
}

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

/// TODO(IT-2): implement — Day 1, per the timeline.
///
/// Suggested order of work, cheapest signal first: luminance (mean brightness)
/// → blur (Laplacian variance) → single-subject (contour/saliency heuristic).
/// The third is the one to cut if Day 1 runs long; the first two carry most of
/// the real-world value.
class ClassicalCvQualityGate implements QualityGate {
  @override
  Future<QualityResult> check(String imagePath) async {
    // TODO(IT-2): decode, downscale, compute luminance + Laplacian variance.
    throw UnimplementedError('ClassicalCvQualityGate.check');
  }
}

/// Permissive stand-in so the upload flow can be built before the real gate lands.
/// Wired as the default in `core/service_locator.dart`.
class AlwaysPassQualityGate implements QualityGate {
  @override
  Future<QualityResult> check(String imagePath) async =>
      const QualityResult.pass();
}
