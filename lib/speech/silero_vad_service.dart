import 'dart:async';
import 'dart:developer' as developer;

import 'package:vad/vad.dart' as vad_pkg;

import 'package:temanku/speech/vad_service.dart';

/// Primary VAD implementation — Silero, on-device (source-of-truth §11).
///
/// Backed by `package:vad` (FFI bindings to ONNX Runtime, running the Silero
/// legacy/v4 model locally — see [_baseAssetPath]'s doc comment for why it's
/// bundled as an asset instead of the package's CDN default). Scope guard,
/// restated because it is easy to drift and this file is exactly the place
/// that drift would happen: this detects *that and when* the child spoke. It
/// must never produce a transcript, and nothing here reads or forwards the
/// actual audio bytes `package:vad` hands back on speech-end — only the
/// timing of the events. `speech/vad_service.dart`'s "no text field anywhere
/// for exactly that reason" applies equally to audio content, not just text.
///
/// ## Why `listenForUtterance` alone carries the whole lifecycle
///
/// `features/child_session/speak_mode_screen.dart` never calls [initialize]
/// — it only calls [listenForUtterance] (once per trial) and [cancel] (once,
/// from `dispose()`). Rather than add a hook point the screen doesn't call,
/// this class starts the underlying listener lazily, on the first
/// [listenForUtterance], which — because that's called the moment a trial
/// appears — already satisfies "request the mic at speak-mode entry, not app
/// launch" without the screen needing to know this class has a setup step at
/// all. [cancel] releases the mic (`VadHandler.stopListening`) without
/// discarding the loaded model, so re-entering speak mode later restarts
/// quickly rather than reloading the ONNX session from scratch.
class SileroVadService implements VadService {
  vad_pkg.VadHandler? _handler;
  bool _listening = false;
  Future<void>? _startFuture;

  _PendingUtterance? _pending;

  @override
  bool get providesAutomaticSilenceDetection => true;

  @override
  Future<void> initialize() => _ensureStarted();

  @override
  Future<SpeechEvent> listenForUtterance({Duration timeout = const Duration(seconds: 10)}) async {
    await _ensureStarted();

    // Not started (e.g. permission denied, model failed to load) — nothing
    // will ever fire, so there is no automatic signal for this trial. Same
    // shape as the fallback: the guardian's own buttons are what's left.
    final handler = _handler;
    if (handler == null || !_listening) {
      return const SpeechEvent.notAttempted();
    }

    final completer = Completer<SpeechEvent>();
    final stopwatch = Stopwatch()..start();
    Duration? onset;

    late final StreamSubscription<void> realStartSub;
    late final StreamSubscription<List<double>> endSub;
    late final StreamSubscription<String> errorSub;
    late final Timer timeoutTimer;

    void finish(SpeechEvent event) {
      if (completer.isCompleted) return;
      timeoutTimer.cancel();
      realStartSub.cancel();
      endSub.cancel();
      errorSub.cancel();
      _pending = null;
      completer.complete(event);
    }

    // onSpeechStart is deliberately not used here — it can misfire (see
    // onVADMisfire below); onRealSpeechStart is package:vad's own "this met
    // the minimum-frames bar" confirmation, which is the more honest onset
    // timestamp for §7's latency baseline.
    realStartSub = handler.onRealSpeechStart.listen((_) {
      onset = stopwatch.elapsed;
    });

    endSub = handler.onSpeechEnd.listen((_) {
      final onsetLatency = onset;
      if (onsetLatency == null) {
        // An end with no matching real-start isn't a shape this package
        // documents as possible, but resolving safely here rather than
        // asserting keeps the "never throw" guarantee unconditional.
        finish(const SpeechEvent.notAttempted());
        return;
      }
      finish(
        SpeechEvent(
          spoke: true,
          onsetLatency: onsetLatency,
          duration: stopwatch.elapsed - onsetLatency,
        ),
      );
    });

    // onVADMisfire is intentionally not subscribed: a misfire means "keep
    // waiting", not "resolve" — the child may still speak again before the
    // timeout.
    errorSub = handler.onError.listen((message) {
      developer.log('VAD error mid-listen: $message', name: 'SileroVadService');
      finish(const SpeechEvent.notAttempted());
    });

    timeoutTimer = Timer(timeout, () => finish(const SpeechEvent.notAttempted()));

    _pending = _PendingUtterance(finish: finish);
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _pending?.finish(const SpeechEvent.notAttempted());
    _pending = null;

    if (!_listening) return;
    final handler = _handler;
    _listening = false;
    if (handler == null) return;
    try {
      await handler.stopListening();
    } catch (error) {
      developer.log('stopListening failed: $error', name: 'SileroVadService');
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
    try {
      await _handler?.dispose();
    } catch (error) {
      developer.log('dispose failed: $error', name: 'SileroVadService');
    } finally {
      _handler = null;
      _startFuture = null;
    }
  }

  /// The model asset's directory, trailing slash required — `package:vad`
  /// appends the model filename itself (`silero_vad_legacy.onnx` for the
  /// default 'v4' model — see `pubspec.yaml`'s asset entry). Any path that
  /// doesn't start with `http(s)://` is loaded via Flutter's `rootBundle`
  /// rather than fetched, which is what keeps this fully offline (§11) —
  /// the package's own default is a jsdelivr CDN URL, which this
  /// deliberately overrides.
  static const _baseAssetPath = 'assets/models/';

  Future<void> _ensureStarted() {
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    try {
      final handler = _handler ??= vad_pkg.VadHandler.create();
      // No `model:` argument — defaults to 'v4' (the legacy Silero model),
      // which is the task's explicit choice over v5 under time pressure.
      // Every other parameter is left at package:vad's own v4-tuned
      // defaults too.
      await handler.startListening(baseAssetPath: _baseAssetPath);
      _listening = true;
    } catch (error) {
      // Model failed to load, mic permission plumbing failed, no input
      // device — whatever it is, this must never throw out of a VadService
      // method. listenForUtterance()'s caller (speak_mode_screen.dart) has
      // no try/catch around it, so an escaped exception here would hang a
      // trial rather than degrade to "no automatic signal", same failure
      // class the hint layer is built to avoid.
      developer.log('startListening failed: $error', name: 'SileroVadService');
      _listening = false;
    } finally {
      _startFuture = null;
    }
  }
}

/// Lets [SileroVadService.cancel] resolve an in-flight [listenForUtterance]
/// immediately (e.g. the guardian exits mid-listen via the exit dot) instead
/// of leaving that call's Future dangling until a timeout that will never
/// matter to a disposed screen.
class _PendingUtterance {
  const _PendingUtterance({required this.finish});

  final void Function(SpeechEvent event) finish;
}
