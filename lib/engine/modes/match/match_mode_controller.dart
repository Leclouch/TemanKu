import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/modes/mode_controller.dart';

/// Match/drag mode — **IT-1, Day 3.**
///
/// §4.1: VP-MTS (visual perception / matching-to-sample), climbing to
/// LRFFC-style categorical sorting.
///
/// §4.4 adds one rule tap mode does not have: **match-mode target zones rotate
/// too**, not just the items. Both sides move.
///
/// Response type for [judge] is `(int itemSlot, int zoneIndex)`.
class MatchModeController implements ModeController {
  const MatchModeController();

  @override
  ResponseMode get mode => ResponseMode.match;

  @override
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
  }) async {
    // TODO(IT-1): compose items AND rotate target zones.
    throw UnimplementedError('MatchModeController.nextTrial');
  }

  @override
  TrialOutcome judge(Trial trial, Object response) {
    // TODO(IT-1): response is (itemSlot, zoneIndex).
    throw UnimplementedError('MatchModeController.judge');
  }
}
