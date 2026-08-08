/// How close an utterance has to be, at each rung of the ladder.
///
/// The scoring backend returns a **raw Levenshtein distance** between the
/// target word's IPA and the phonemes it heard. A raw distance is not a
/// verdict — 2 is excellent for a child working on a hard contrast and
/// mediocre for one repeating a word they have said fifty times. Turning that
/// number into "close enough" is a calibration decision, and this file is
/// where it lives.
///
/// **Deliberately client-side.** The backend also computes its own
/// WIN/TRY AGAIN from a `difficulty` field, and this policy is what fills
/// that field — so the two agree. But the app keeps the raw distance and
/// re-derives the judgement locally as well, for three reasons: the mapping
/// is unit-testable here and not over HTTP, tuning it needs no redeploy, and
/// the guardian-facing copy can explain *why* something was tolerated
/// (`speak_mode_screen.dart` shows the tolerance next to the distance).
///
/// **This is advisory input, not an outcome.** Nothing here decides a trial.
/// §6 holds: the guardian's tap is the only thing that reaches
/// `engine/advancement/advancement_tracker.dart`. See
/// [PronunciationHintResult.suggestedOutcome] for the exact boundary.
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';

/// Maps a [LadderPosition] to the phoneme-distance the app treats as "close
/// enough" at that point.
///
/// ## Why the numbers loosen as the ladder gets harder
///
/// The two dials (§4.4) measure **visual/categorical discrimination** —
/// telling a banana from a toothbrush, then from an apple. Articulation is a
/// separate skill on a separate developmental track. A child who has just
/// been stepped up to a harder similarity tier is already doing something new
/// and harder; tightening the pronunciation bar at the same moment charges
/// them twice for one step, which is exactly the compounding-difficulty
/// failure §4.5's one-dial-at-a-time rule exists to prevent.
///
/// So the tolerance is **generous at a fresh tier and tightens as the child
/// settles into it** — the array-size dial, which is the within-tier
/// progression, is what tightens it. [SimilarityTier.lrffc] is the exception:
/// it holds at the tightest setting, because by then the word itself is long
/// familiar and only the instruction has changed.
///
/// Numbers here are a starting point, chosen to be easy to move — they are
/// not derived from published norms, and the honest description is "a
/// reasonable first calibration to tune against real sessions", not
/// "validated thresholds".
abstract final class ArticulationTolerance {
  /// The most forgiving setting — a fresh similarity tier at the smallest
  /// array. Four phoneme edits is a lot; that is intentional at the start.
  static const int maxTolerance = 4;

  /// The floor. Below this, ordinary childhood articulation variation
  /// (and the wav2vec2 model's own error on child speech, which is not
  /// small) would start reading as failure.
  static const int minTolerance = 2;

  /// Tolerance for [position], as a phoneme-distance ceiling.
  ///
  /// Sent to the backend as its `difficulty` field **and** used locally to
  /// interpret the returned distance. Both paths use this one function, so
  /// the app and the server can never disagree about the threshold.
  static int forPosition(LadderPosition position) {
    final base = switch (position.similarityTier) {
      SimilarityTier.differentCategory => 4,
      SimilarityTier.sameCategoryDistinct => 3,
      SimilarityTier.similar => 2,
      // Holds at the floor rather than dropping below it — see the class
      // doc comment. The word is familiar by Step 10; the instruction is
      // what got harder, and that is not an articulation problem.
      SimilarityTier.lrffc => 2,
    };

    // Within a tier, the array-size dial is the child settling in. Tighten
    // by one once they are past the entry array size, never below the floor.
    final settled = position.arraySize > ArraySize.min ? base - 1 : base;
    return settled.clamp(minTolerance, maxTolerance);
  }
}
