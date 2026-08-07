import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';

void main() {
  final rotator = GuardedPositionRotator();

  group('GuardedPositionRotator.nextTargetSlot', () {
    test('excludes a slot that was the last two consecutive assignments', () {
      for (var i = 0; i < 20; i++) {
        final slot = rotator.nextTargetSlot(
          arraySize: 3,
          recentTargetSlots: const [1, 1],
        );
        expect(slot, isNot(1));
      }
    });

    test('allows a single repeat — [1] alone does not exclude slot 1', () {
      final seen = <int>{};
      for (var i = 0; i < 50; i++) {
        final slot = rotator.nextTargetSlot(
          arraySize: 3,
          recentTargetSlots: const [1],
        );
        seen.add(slot);
      }
      expect(seen, contains(1));
    });

    test('with no history, any slot is a valid candidate', () {
      final seen = <int>{};
      for (var i = 0; i < 100; i++) {
        final slot = rotator.nextTargetSlot(
          arraySize: 4,
          recentTargetSlots: const [],
        );
        seen.add(slot);
      }
      expect(seen, {0, 1, 2, 3});
    });
  });

  group('GuardedPositionRotator.shuffleSlots', () {
    test('places the target item (index 0) at targetSlot', () {
      final slots = rotator.shuffleSlots(arraySize: 4, targetSlot: 2);
      expect(slots[2], 0);
    });

    test('every other item index 1..arraySize-1 appears exactly once', () {
      final slots = rotator.shuffleSlots(arraySize: 4, targetSlot: 0);
      expect(slots.toSet(), {0, 1, 2, 3});
      expect(slots.length, 4);
    });
  });

  group('GuardedPositionRotator.nextTargetZone', () {
    test('honours the same ≤2-consecutive-repeat guard as target slots', () {
      for (var i = 0; i < 20; i++) {
        final zone = rotator.nextTargetZone(
          zoneCount: 3,
          recentTargetZones: const [2, 2],
        );
        expect(zone, isNot(2));
      }
    });

    test('a single repeat does not exclude the zone', () {
      final seen = <int>{};
      for (var i = 0; i < 50; i++) {
        final zone = rotator.nextTargetZone(
          zoneCount: 3,
          recentTargetZones: const [2],
        );
        seen.add(zone);
      }
      expect(seen, contains(2));
    });

    test('a long simulated run never repeats a zone 3+ times consecutively', () {
      // Match-mode zone rotation feeding itself over many trials — the guard
      // must hold under real sequential use, not just for one hand-picked
      // history, and independently of item-slot rotation (only zone history
      // is tracked here).
      var recentZones = <int>[];
      var consecutiveRun = 1;

      for (var i = 0; i < 500; i++) {
        final zone = rotator.nextTargetZone(zoneCount: 2, recentTargetZones: recentZones);

        if (recentZones.isNotEmpty && recentZones.first == zone) {
          consecutiveRun += 1;
        } else {
          consecutiveRun = 1;
        }
        expect(consecutiveRun, lessThan(3));

        recentZones = [zone, ...recentZones].take(2).toList();
      }
    });
  });
}
