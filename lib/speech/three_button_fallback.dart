import 'package:temanku/speech/vad_service.dart';

/// Pre-approved VAD fallback (ADR-4) — **wired as the default for this scaffold.**
///
/// No audio detection at all. The guardian's corner cluster gains a third button
/// ("tidak mencoba") and does the job VAD would have done. Per the timeline's
/// fallback table the only thing lost is clean latency timestamps, and only for
/// speak mode.
///
/// This is the default in `core/service_locator.dart` on purpose: the scaffold
/// should run with zero native dependencies, and Day 4's swap to
/// [SileroVadService] is then a one-line promotion rather than a rescue.
class ThreeButtonFallback implements VadService {
  /// False — which is what makes the guardian UI render the third button.
  @override
  bool get providesAutomaticSilenceDetection => false;

  @override
  Future<void> initialize() async {
    // Nothing to load. No mic permission is requested, which is also a small
    // privacy win while the fallback is active.
  }

  @override
  Future<SpeechEvent> listenForUtterance({Duration timeout = const Duration(seconds: 10)}) async {
    // There is no detection to perform. The guardian's judgement arrives through
    // the UI, not through this service, so the engine treats this as "no
    // automatic signal available" and waits on the button cluster instead.
    return const SpeechEvent.notAttempted();
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
