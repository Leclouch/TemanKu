/// Where the articulation backend lives, and the one header it needs.
///
/// Shared by `remote_articulation_hint_service.dart` (`POST /score`) and
/// `speech/tts/edge_tts_service.dart` (`GET /tts`) — two services against one
/// host, so the host is declared once here rather than twice as a default
/// argument.
///
/// **This is the only outbound network destination in the app.** Everything
/// else — photos, ladder positions, session logs, the classifier, VAD — is
/// on-device by design (§10/§11). Both services that use this host are gated
/// behind `Child.pronunciationHintEnabled`, the guardian's explicit consent,
/// and the consent copy in `features/guardian/child_settings_screen.dart`
/// names exactly what leaves the device.
library;

/// The FastAPI service in `main.py` — wav2vec2 phoneme scoring plus Edge TTS.
///
/// An ngrok tunnel, which means it is a **development address that changes
/// whenever the tunnel restarts**. When the demo backend moves, this is the
/// single line to edit. It is not a secret and does not belong in
/// `--dart-define` for that reason; it belongs behind a real domain before
/// this ships to anyone, at which point this constant becomes a build config.
const String _host = 'https://scribing-sulfide-backspin.ngrok-free.dev';

abstract final class ArticulationBackend {
  /// Trailing slash is load-bearing: every call site uses
  /// `baseUrl.resolve('score')`, and `Uri.resolve` against a path without a
  /// trailing slash replaces the last segment instead of appending to it.
  static final Uri baseUrl = Uri.parse('$_host/');

  /// ngrok's free tier serves a browser interstitial to anything that looks
  /// like a browser, and returns the real response otherwise. Dart's client
  /// currently sends its own user agent and is not intercepted, but that is
  /// ngrok's behaviour rather than a guarantee — this header opts out of the
  /// interstitial explicitly so a future client-header change cannot start
  /// silently returning HTML where the app expects JSON.
  static const Map<String, String> headers = {
    'ngrok-skip-browser-warning': 'true',
  };
}
