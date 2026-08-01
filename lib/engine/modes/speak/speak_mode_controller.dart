import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/engine/modes/mode_controller.dart';
import 'package:temanku/speech/vad_service.dart';

/// Speak mode — **IT-1, Day 4.** Wires to `speech/`.
///
/// §4.1: **Tact only** — the stimulus stays on screen. Intraverbal is deliberately
/// out of MVP (it becomes cheap later; it is not accidentally missing).
///
/// §4.4: speak mode has **no array; nothing rotates.** [Trial.items] is empty and
/// [Trial.targetSlot] is inert — the array dial does not apply here at all, which
/// is why [DialEngine.advanceForMode] exists.
///
/// §6: **correctness is judged by the guardian, not a model.** [judge] takes the
/// guardian's ✅/❌ from the corner cluster. The [VadService] contributes only
/// *that and when* the child spoke — the honest latency timestamp and the
/// silence-vs-attempt distinction. It never contributes correctness.
class SpeakModeController implements ModeController {
  const SpeakModeController(this._vad);

  // TODO(IT-1): Day 4 wires this in — VAD supplies latency + silence, never text.
  // ignore: unused_field
  final VadService _vad;

  @override
  ResponseMode get mode => ResponseMode.speak;

  @override
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
  }) async {
    // TODO(IT-1): single stimulus, no array. Similarity tier still applies —
    // it governs which items get asked, not what sits beside them.
    throw UnimplementedError('SpeakModeController.nextTrial');
  }

  @override
  TrialOutcome judge(Trial trial, Object response) {
    // TODO(IT-1): response is the guardian's verdict. VAD silence auto-flags
    // TrialOutcome.notAttempted, with a lightweight guardian override for VAD
    // misses (§6) — the common path stays two buttons when VAD is live.
    throw UnimplementedError('SpeakModeController.judge');
  }
}
