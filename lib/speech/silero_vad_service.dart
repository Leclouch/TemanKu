import 'package:temanku/speech/vad_service.dart';

/// Primary VAD implementation — Silero-class, on-device (source-of-truth §11).
///
/// TODO(IT-1): implement. Target is Day 4 morning, per the timeline.
///
/// Scope guard, restated because it is easy to drift: this detects *that and when*
/// the child spoke. It must never produce a transcript. §11 also flags
/// "verify Flutter/ONNX integration at build time" — that verification is the
/// first task here, before any engine wiring depends on it.
///
/// **Tripwire: Day 4 midday.** If integration is still fighting back by lunch,
/// stop and swap `vadServiceProvider` back to `ThreeButtonFallback` in
/// `core/service_locator.dart`. That decision is pre-made; don't relitigate it
/// while the clock runs.
class SileroVadService implements VadService {
  @override
  bool get providesAutomaticSilenceDetection => true;

  @override
  Future<void> initialize() async {
    // TODO(IT-1): load the Silero ONNX model, request microphone permission,
    // open the audio stream.
    throw UnimplementedError('SileroVadService.initialize');
  }

  @override
  Future<SpeechEvent> listenForUtterance({Duration timeout = const Duration(seconds: 10)}) async {
    // TODO(IT-1): run frames through the VAD, return onset latency + duration.
    // Silence for the whole window → SpeechEvent.notAttempted(), which is what
    // auto-flags "tidak mencoba" (§6). Guardian override stays available for
    // VAD misses — the model is never the last word.
    throw UnimplementedError('SileroVadService.listenForUtterance');
  }

  @override
  Future<void> cancel() async {
    // TODO(IT-1)
  }

  @override
  Future<void> dispose() async {
    // TODO(IT-1)
  }
}
