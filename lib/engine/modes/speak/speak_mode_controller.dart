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
///
/// The optional pronunciation-hint layer (`speech/pronunciation_hint_service.dart`)
/// is not wired in here at all, on purpose: it is advisory UI decoration that
/// `features/child_session/speak_mode_screen.dart` fires and displays on its
/// own, entirely downstream of [judge]'s return. Keeping this controller
/// unaware of it is what makes "the hint can never become the verdict"
/// structurally true rather than a convention someone could break later.
class SpeakModeController implements ModeController {
  const SpeakModeController(this._vad);

  final VadService _vad;

  /// Exposed so `speak_mode_screen.dart` can call `listenForUtterance`
  /// directly without re-threading it through this controller's own
  /// interface — [ModeController] has no notion of "listen", only
  /// "compose" and "judge".
  VadService get vad => _vad;

  @override
  ResponseMode get mode => ResponseMode.speak;

  @override
  Future<Trial> nextTrial({
    required LadderPosition position,
    required List<Photo> available,
    required List<int> recentTargetSlots,
    required List<int> recentTargetZones,
  }) async {
    // Single stimulus, no array — §4.4. The similarity tier still governs
    // which photos are eligible targets (below LRFFC the instruction names
    // the photo's own label, same rule TapModeController uses), it just
    // never places anything beside the target because there is nothing to
    // place. Neither recent-history list is consulted: nothing rotates here.
    final requiresLabel = position.similarityTier != SimilarityTier.lrffc;
    final targets = available
        .where((p) => p.category == PhotoCategory.target && (!requiresLabel || p.label != null))
        .toList()
      ..shuffle();
    if (targets.isEmpty) {
      throw StateError('Not enough target photos to compose a speak trial.');
    }
    final targetPhoto = targets.first;

    return Trial(
      target: targetPhoto,
      items: const [],
      // Inert by construction (§4.4's doc comment on Trial.targetSlot) — no
      // array means no slot for this value to ever be read against.
      targetSlot: 0,
      instruction: _instructionFor(targetPhoto, position.similarityTier),
    );
  }

  @override
  TrialOutcome judge(Trial trial, Object response) {
    // The guardian's verdict, passed straight through — §6: there is no
    // target/response comparison to make here (unlike tap/match, there is
    // only ever one stimulus on screen), so unlike those controllers this
    // one has nothing to derive. `speak_mode_screen.dart`'s three-button
    // cluster (or two, when VadService.providesAutomaticSilenceDetection)
    // is the only thing that ever produces this value; VAD silence may
    // pre-select TrialOutcome.notAttempted in that UI, but the guardian can
    // always override before this is called, and the pronunciation-hint
    // layer never reaches this call at all.
    return response as TrialOutcome;
  }

  String _instructionFor(Photo targetPhoto, SimilarityTier tier) {
    if (tier == SimilarityTier.lrffc) {
      // No mixed array exists to react to here, but the module's fixed
      // semantic prompt still reads naturally as a thing to say aloud —
      // same LRFFC copy tap mode names, no speak-mode-specific string
      // needed.
      return targetPhoto.label == null
          ? 'ucapkan nama benda ini'
          : 'ucapkan ${targetPhoto.label}';
    }
    return 'ucapkan ${targetPhoto.label}';
  }
}
