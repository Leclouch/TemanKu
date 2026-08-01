/// Voice activity detection — ADR-4 swappable interface. **IT-1 owns this folder.**
///
/// Source-of-truth §6, and this is the whole point: **VAD, not ASR.** The service
/// detects *that and when* the child spoke — never *what* was said. Correctness in
/// speak mode is judged by the guardian's ✅/❌, because a live guardian who knows
/// their child's articulation outperforms any ASR on neurodivergent Indonesian
/// child speech.
///
/// If a future implementation of this interface returns a transcript, that is not
/// an enhancement — it is the punishing-feedback failure mode the design forbids.
/// The interface has no text field anywhere for exactly that reason.
///
/// Two implementations, decided up front:
///   - [SileroVadService]    — primary
///   - [ThreeButtonFallback] — fallback (guardian's third button does VAD's job)
///
/// Timeline tripwire: **Day 4 midday.** If Flutter/ONNX integration is still
/// fighting back by lunch, swap to the fallback in `core/service_locator.dart`.
/// One line. No debate.
library;

/// What VAD produces for one trial. Two facts, no content.
class SpeechEvent {
  const SpeechEvent({
    required this.spoke,
    this.onsetLatency,
    this.duration,
  });

  /// The child produced a vocalisation. False means silence, which is what
  /// auto-flags "tidak mencoba" (§6) — distinct from a wrong answer.
  final bool spoke;

  /// Time from prompt end to speech onset.
  ///
  /// This is the honest response-latency timestamp, **uncontaminated by guardian
  /// reaction time** — which is exactly why it is worth having VAD at all. It
  /// feeds the disengagement detector's per-child latency baseline (§7).
  /// Null under the fallback, where only the guardian's tap timing exists.
  final Duration? onsetLatency;

  final Duration? duration;

  /// The fallback's shape: no audio detection, so no latency and no silence
  /// signal — the guardian's third button supplies `spoke` directly.
  const SpeechEvent.notAttempted()
      : spoke = false,
        onsetLatency = null,
        duration = null;
}

abstract class VadService {
  /// True when this implementation actually detects audio.
  ///
  /// The UI reads this to decide whether to show the two-button cluster (✅/❌)
  /// or the three-button cluster (✅/❌/tidak mencoba). §6: "the common path stays
  /// two buttons" when VAD is live; the third button is the fallback's job.
  bool get providesAutomaticSilenceDetection;

  /// Prepare the detector (load model, request mic permission).
  Future<void> initialize();

  /// Listen for one trial's worth of speech, resolving on silence-after-speech
  /// or on [timeout].
  Future<SpeechEvent> listenForUtterance({Duration timeout});

  /// Stop listening early — e.g. the guardian judged before the timeout, or the
  /// session was paused.
  Future<void> cancel();

  Future<void> dispose();
}
