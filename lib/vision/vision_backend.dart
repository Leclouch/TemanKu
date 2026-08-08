/// Where the vision (object classification) backend lives, and the one
/// header it needs.
///
/// Used only by `photo_pipeline/siglip_classifier.dart` (`POST /classify`).
/// Self-hosted SigLIP2 zero-shot classifier — FastAPI + uvicorn behind a
/// static ngrok domain — replacing both the bundled Teachable Machine TFLite
/// model (`photo_pipeline/tflite_classifier.dart`) and Google ML Kit's
/// on-device labeler (`photo_pipeline/mlkit_classifier.dart`). See
/// `core/service_locator.dart`'s swap table for why neither of those held
/// up, and `photo_pipeline/siglip_classifier.dart`'s doc comment for why
/// this one needs no translation map: labels are passed at request time in
/// the app's own Indonesian domain vocabulary, and the response echoes back
/// whichever of those strings scored highest.
library;

/// A **static** ngrok domain (`--domain=...`, not a plain `ngrok http`run) —
/// it does not rotate when the tunnel restarts, unlike
/// `speech/articulation_backend.dart`'s. Still a development address in the
/// same sense that one is: it belongs behind a real domain before this ships
/// to anyone, at which point this constant becomes build config.
const String _host = 'https://nonoppressive-mirna-oversilently.ngrok-free.dev';

abstract final class VisionBackend {
  /// Trailing slash is load-bearing — see `speech/articulation_backend.dart`'s
  /// identical note. Every call site resolves against this with
  /// `.resolve('classify')`.
  static final Uri baseUrl = Uri.parse('$_host/');

  /// Same ngrok free-tier interstitial bypass as
  /// `speech/articulation_backend.dart` — without it, a request that looks
  /// like it came from a browser gets an HTML warning page back instead of
  /// JSON.
  static const Map<String, String> headers = {
    'ngrok-skip-browser-warning': 'true',
  };
}
