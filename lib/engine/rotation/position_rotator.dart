/// Position rotation — **IT-1, Day 2.** Pure Dart.
///
/// Source-of-truth §4.4: "every item's slot reassigns every trial — targets *and*
/// distractors; match-mode target zones rotate too. Guard: **no slot repeats more
/// than twice consecutively.** Speak mode has no array; nothing rotates."
///
/// This is not cosmetic. Rotation is what makes repeated same-position tapping a
/// *clean* disengagement signal (§7) — without it, a child tapping slot 1 every
/// time might simply be right. Weakening the guard quietly weakens the detector.
library;

abstract class PositionRotator {
  /// Assigns the target to a slot in an array of [arraySize], honouring the
  /// ≤2-consecutive-repeat guard against [recentTargetSlots] (most recent first).
  int nextTargetSlot({
    required int arraySize,
    required List<int> recentTargetSlots,
  });

  /// A full shuffled slot assignment for one trial: index = slot, value = item
  /// index, with the target placed at [nextTargetSlot]'s result.
  List<int> shuffleSlots({
    required int arraySize,
    required int targetSlot,
  });
}

/// TODO(IT-1): implement — Day 2, unit-tested in `test/engine/`.
///
/// The guard case to test explicitly: given recent slots [1, 1], slot 1 must be
/// excluded from the candidate set. Given [1], it must still be allowed.
class GuardedPositionRotator implements PositionRotator {
  @override
  int nextTargetSlot({
    required int arraySize,
    required List<int> recentTargetSlots,
  }) {
    throw UnimplementedError('GuardedPositionRotator.nextTargetSlot');
  }

  @override
  List<int> shuffleSlots({required int arraySize, required int targetSlot}) {
    throw UnimplementedError('GuardedPositionRotator.shuffleSlots');
  }
}
