import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/modes/mode_controller.dart';

/// Tap mode — **IT-1, Day 2** (the first mode end-to-end, on Makanan).
///
/// §4.1: Listener Responding, climbing to LRFFC. The child taps the item named
/// by the instruction; at the top tier the instruction becomes semantic
/// ("tunjuk yang boleh dimakan") over a mixed array.
///
/// Response type for [judge] is the tapped slot index (`int`).
class TapModeController implements ModeController {
  const TapModeController();

  @override
  ResponseMode get mode => ResponseMode.tap;

  @override
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
  }) async {
    // TODO(IT-1): pick target + distractors by similarity tier, size the array
    // from position.arraySize, place via PositionRotator.
    throw UnimplementedError('TapModeController.nextTrial');
  }

  @override
  TrialOutcome judge(Trial trial, Object response) {
    // TODO(IT-1): response is the tapped slot index.
    throw UnimplementedError('TapModeController.judge');
  }
}
