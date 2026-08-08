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
  /// index (0 = target, 1..arraySize-1 = distractors), with the target placed
  /// at [targetSlot].
  List<int> shuffleSlots({
    required int arraySize,
    required int targetSlot,
  });

  /// Assigns distinct slots for multiple target items. The first target uses
  /// the standard repeat guard; the remaining targets fill unused slots.
  List<int> nextTargetSlots({
    required int arraySize,
    required int count,
    required List<int> recentPrimaryTargetSlots,
  });

  /// A full shuffled slot assignment for a trial with multiple targets.
  /// Target item indices 0..targetSlots.length-1 are placed at [targetSlots].
  List<int> shuffleSlotsMulti({
    required int arraySize,
    required List<int> targetSlots,
  });

  /// Match-mode target *zone* rotation (§4.4: "match-mode target zones rotate
  /// too", not just the items). Kept as its own function because the item
  /// array and the drop zones rotate independently, but the guard is the same
  /// ≤2-consecutive-repeat rule against [recentTargetZones] (most recent first).
  int nextTargetZone({
    required int zoneCount,
    required List<int> recentTargetZones,
  });
}

/// The guard case tested explicitly: given recent slots [1, 1], slot 1 must be
/// excluded from the candidate set. Given [1], it must still be allowed.
class GuardedPositionRotator implements PositionRotator {
  @override
  int nextTargetSlot({
    required int arraySize,
    required List<int> recentTargetSlots,
  }) =>
      _nextSlot(slotCount: arraySize, recentSlots: recentTargetSlots);

  @override
  List<int> shuffleSlots({required int arraySize, required int targetSlot}) {
    final distractorIndices = List<int>.generate(arraySize - 1, (i) => i + 1)
      ..shuffle();

    final slots = List<int>.filled(arraySize, -1);
    slots[targetSlot] = 0;
    var next = 0;
    for (var slot = 0; slot < arraySize; slot++) {
      if (slot == targetSlot) continue;
      slots[slot] = distractorIndices[next++];
    }
    return slots;
  }

  @override
  List<int> nextTargetSlots({
    required int arraySize,
    required int count,
    required List<int> recentPrimaryTargetSlots,
  }) {
    final firstTargetSlot = nextTargetSlot(
      arraySize: arraySize,
      recentTargetSlots: recentPrimaryTargetSlots,
    );
    final remainingSlots = [
      for (var slot = 0; slot < arraySize; slot++)
        if (slot != firstTargetSlot) slot,
    ]..shuffle();
    return [firstTargetSlot, ...remainingSlots.take(count - 1)];
  }

  @override
  List<int> shuffleSlotsMulti({
    required int arraySize,
    required List<int> targetSlots,
  }) {
    final targetSlotSet = targetSlots.toSet();
    final remainingItemIndices = [
      for (var index = targetSlots.length; index < arraySize; index++) index,
    ]..shuffle();

    final slots = List<int>.filled(arraySize, -1);
    for (var itemIndex = 0; itemIndex < targetSlots.length; itemIndex++) {
      slots[targetSlots[itemIndex]] = itemIndex;
    }
    var nextItem = 0;
    for (var slot = 0; slot < arraySize; slot++) {
      if (targetSlotSet.contains(slot)) continue;
      slots[slot] = remainingItemIndices[nextItem++];
    }
    return slots;
  }

  @override
  int nextTargetZone({
    required int zoneCount,
    required List<int> recentTargetZones,
  }) =>
      _nextSlot(slotCount: zoneCount, recentSlots: recentTargetZones);

  /// Shared ≤2-consecutive-repeat guard: a slot is excluded from the candidate
  /// pool only when it is already the most recent *two* assignments in a row —
  /// a single repeat is allowed, a third in a row is not.
  int _nextSlot({required int slotCount, required List<int> recentSlots}) {
    final excluded = <int>{};
    if (recentSlots.length >= 2 && recentSlots[0] == recentSlots[1]) {
      excluded.add(recentSlots[0]);
    }

    final candidates = [
      for (var slot = 0; slot < slotCount; slot++)
        if (!excluded.contains(slot)) slot,
    ]..shuffle();
    return candidates.first;
  }
}
