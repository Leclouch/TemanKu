/// Shared contract for the three response modes — **IT-1.** Pure Dart.
///
/// Source-of-truth §4.1: **response mode and skill domain are separate axes.**
/// The instruction, not the motor channel, determines the skill. That is why the
/// three modes share one contract and differ only in how a response arrives —
/// tap a slot, drag to a zone, or speak and let the guardian judge.
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';

/// One composed trial, ready to render. Built by the mode controller from the
/// ladder position, the child's photo library, and the rotator.
class Trial {
  const Trial({
    required this.target,
    required this.items,
    required this.targetSlot,
    required this.instruction,
    this.hintShown = false,
  });

  final Photo target;

  /// Everything on screen, in slot order. Length == array size. Empty in speak
  /// mode, where the stimulus stays on screen alone and there is no array.
  final List<Photo> items;

  final int targetSlot;

  /// Bahasa instruction copy, e.g. "tunjuk pisang" or, at the LRFFC tier,
  /// "tunjuk yang boleh dimakan".
  final String instruction;

  /// Errorless prompting (§3). Hint frequency decreases with demonstrated
  /// independence, always subordinate to the disengagement detector — if fading
  /// produces frustration signals, back off, never push through (§8).
  final bool hintShown;
}

abstract class ModeController {
  ResponseMode get mode;

  /// Compose the next trial at [position] from [available] photos.
  ///
  /// [recentTargetSlots] and [recentTargetZones] are the caller's rotation
  /// history (most recent first), fed straight to [PositionRotator] — the
  /// same shape for every mode so the session loop never branches by mode to
  /// assemble them. A mode with nothing to rotate on one axis (e.g. tap mode
  /// has no zones) simply ignores that list.
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
    required List<int> recentTargetZones,
  });

  /// Interpret a raw response into an outcome.
  ///
  /// In speak mode this is the **guardian's** ✅/❌ (§6) — never a model's
  /// judgement. The signature is shared so the session loop does not branch by
  /// mode; who supplies the answer is the implementation's business.
  TrialOutcome judge(Trial trial, Object response);
}
