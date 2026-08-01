/// Advancement / placement policy — **IT-1, Day 2.** Pure Dart.
///
/// Source-of-truth §4.5:
///   - Everyone starts at Step 1 of every eligible mode+module. **No placement
///     quiz, no calibration screen** — the advancement criterion doubles as
///     placement from trial one.
///   - Advance on a short consecutive run of correct responses **without the
///     hint** (independent responding). The criterion is qualitative and
///     per-child — deliberately **never a fixed percentage**.
///   - Fast learners may clear multiple steps in one sitting; no artificial floor.
///   - Repeat with rotated photos **across sessions** (spaced, never crammed into
///     one sitting) when the criterion isn't met.
///   - The disengagement detector has **absolute veto**.
///   - Nothing about levels, scores, or thresholds is ever visible to the child.
///
/// Note what this policy must *not* grow: no percentage accuracy, no score, no
/// cross-module gate (§4.2 — "no cross-module gating, ever").
library;

import 'package:temanku/data/models/session.dart';

/// The engine's verdict after a trial.
enum AdvancementDecision {
  /// Criterion met — move one step up the ladder.
  advance,

  /// Keep playing at this position.
  hold,

  /// Criterion missed enough that the position should be revisited next session
  /// with rotated photos. Not a demotion — spacing, not punishment.
  repeatNextSession,
}

abstract class AdvancementPolicy {
  /// Decide from the trial history of the current session.
  ///
  /// Only trials with `hintShown == false` count toward the run — that is what
  /// "independent responding" means, and it is the whole criterion.
  AdvancementDecision evaluate(List<TrialLog> sessionTrials);

  /// Length of the current independent-correct run.
  int independentCorrectStreak(List<TrialLog> sessionTrials);
}

/// TODO(IT-1): implement — Day 2, unit-tested in `test/engine/`.
///
/// Edge cases worth a test each:
///   - a correct answer *with* the hint breaks the run (does not extend it)
///   - `notAttempted` is not the same as `incorrect` (§6) — decide and document
///     which one it breaks the run as, because speak mode will hit this constantly
///   - multiple advancements within one sitting are allowed (no floor)
class StreakAdvancementPolicy implements AdvancementPolicy {
  const StreakAdvancementPolicy();

  @override
  AdvancementDecision evaluate(List<TrialLog> sessionTrials) {
    throw UnimplementedError('StreakAdvancementPolicy.evaluate');
  }

  @override
  int independentCorrectStreak(List<TrialLog> sessionTrials) {
    throw UnimplementedError('StreakAdvancementPolicy.independentCorrectStreak');
  }
}
