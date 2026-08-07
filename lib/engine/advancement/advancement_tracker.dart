/// Streak-based advancement tracking — pure Dart.
///
/// Source-of-truth §4.5: advance on a short consecutive run of correct
/// responses **without the hint** (independent responding). On a miss —
/// incorrect, not attempted, or correct-but-hinted — the run resets. It is a
/// reset, not a demotion: the ladder never steps back down. Repetition at the
/// same position happens via rotated content (`rotation/`), not by lowering
/// the tier.
///
/// The streak count and the current step number are internal bookkeeping.
/// Neither is ever surfaced to any UI meant for the child (§4.5: "nothing
/// about levels, scores, or thresholds is ever visible to the child").
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';

/// How many consecutive independent-correct responses advance the ladder one
/// step.
///
/// PLACEHOLDER — not a final number. This is a stand-in pending co-design
/// calibration with the SLB teachers/therapists the source-of-truth doc
/// references; do not treat `3` as validated.
const int requiredStreakForAdvancement = 3;

/// Result of [AdvancementTracker.recordResponse].
class AdvancementResult {
  const AdvancementResult({
    required this.position,
    required this.masteredAtCeiling,
  });

  /// The resulting ladder position — unchanged unless this call was the one
  /// that met the streak.
  final LadderPosition position;

  /// True exactly when this call was the one that *cleared* the streak
  /// criterion while [position] was already sitting at [DialEngine.isAtCeiling]
  /// — never merely for reaching the ceiling, only for demonstrating the
  /// criterion again once already there. A mode screen uses this as the
  /// mastery-triggered graceful-closure signal (§4.5's top of the ladder);
  /// nothing here decides what happens next — that stays the guardian's call.
  final bool masteredAtCeiling;
}

/// Tracks the consecutive correct-without-hint streak per (childId, moduleId,
/// mode) and drives the [DialEngine] + [LadderPersistence] when the streak
/// criterion is met.
class AdvancementTracker {
  AdvancementTracker({
    required DialEngine dialEngine,
    required LadderPersistence persistence,
  })  : _dialEngine = dialEngine,
        _persistence = persistence;

  final DialEngine _dialEngine;
  final LadderPersistence _persistence;

  final Map<(String, ModuleId, ResponseMode), int> _streaks = {};

  /// Current streak for (childId, module, mode). Internal/testing use only —
  /// never wire this to child-facing UI.
  int streakFor({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  }) =>
      _streaks[(childId, module, mode)] ?? 0;

  /// Records the outcome of one trial. Only a correct response given without
  /// a hint extends the streak; anything else resets it.
  ///
  /// When the streak meets [requiredStreakForAdvancement], the dial engine
  /// advances one step, the streak resets, and the new position is persisted
  /// immediately (never batched). See [AdvancementResult] for what's returned.
  Future<AdvancementResult> recordResponse({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
    required bool correct,
    required bool hintShown,
  }) async {
    final key = (childId, module, mode);
    final current = await _persistence.load(
      childId: childId,
      module: module,
      mode: mode,
    );

    if (!correct || hintShown) {
      _streaks[key] = 0;
      return AdvancementResult(position: current, masteredAtCeiling: false);
    }

    final streak = (_streaks[key] ?? 0) + 1;
    if (streak < requiredStreakForAdvancement) {
      _streaks[key] = streak;
      return AdvancementResult(position: current, masteredAtCeiling: false);
    }

    _streaks[key] = 0;
    // Checked against the position *before* advancing — reaching the
    // ceiling this same call must not count (§4.5: only demonstrating the
    // criterion again once already there triggers mastery closure).
    final masteredAtCeiling = _dialEngine.isAtCeiling(current, mode);
    final next = _dialEngine.advanceForMode(current, mode);
    await _persistence.save(
      childId: childId,
      module: module,
      mode: mode,
      position: next,
    );
    return AdvancementResult(position: next, masteredAtCeiling: masteredAtCeiling);
  }
}
