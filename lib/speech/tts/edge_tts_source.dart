import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_edge_tts/flutter_edge_tts.dart';

import 'package:temanku/speech/tts/word_audio_service.dart';

/// Fetches spoken-word audio **directly from Microsoft's Edge "Read Aloud"
/// TTS service** — no backend hop.
///
/// This used to call the FastAPI backend's `GET /tts`, which was itself
/// just a proxy in front of the same Microsoft service (Python's `edge-tts`
/// library). Calling it from the device instead removes that hop entirely:
/// one less network round trip, and the oldlaptop's resource contention
/// between this and the wav2vec2 scoring model no longer touches the
/// TTS path at all. Scoring (`POST /score`,
/// `remote_articulation_hint_service.dart`) is unaffected and still runs on
/// that backend — this class never imports `articulation_backend.dart`.
///
/// **This talks to Microsoft, not to the articulation backend.** It is the
/// second, separate external destination the consent copy in
/// `features/guardian/child_settings_screen.dart` names explicitly — see
/// that file's doc comment for why both still ride one consent toggle even
/// though the hosts differ.
///
/// Same wire facts as the backend-routed version: 24kHz mono MP3, one word
/// at a time, `id-ID-GadisNeural` — a Microsoft voice ID, unaffected by
/// which client calls it. `package:flutter_edge_tts` is a Dart port of the
/// same reverse-engineered protocol the backend's Python `edge-tts` used, so
/// the same caveat applies here as there: **this is not an official
/// Microsoft API.** Pin the package version (see `pubspec.yaml`); if
/// Microsoft changes an auth header, every TTS request fails at once, and
/// that all-at-once pattern — not one bad word — is the signal to check for
/// a `flutter_edge_tts` update rather than to suspect this file.
class EdgeTtsSource implements WordAudioSource {
  EdgeTtsSource({FlutterEdgeTts? client, Duration? timeout, String? voice})
      : _client = client ??
            FlutterEdgeTts(
              voice: voice ?? defaultVoice,
              outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
            ),
        _timeout = timeout ?? _defaultTimeout;

  /// Indonesian, female, neural. The child hears one consistent voice for the
  /// whole app — a model that changes speaker between trials is teaching the
  /// child to match a moving target, and voice consistency is one of the
  /// predictability properties this audience's design guidance asks for.
  static const String defaultVoice = 'id-ID-GadisNeural';

  /// Shorter than the scoring timeout: TTS is a fast cloud call with no model
  /// inference behind it, and it sits *in front of* the child's turn rather
  /// than after it. A long stall here is dead air the child waits through, so
  /// the ceiling is tight and the failure (silence) is cheap.
  static const Duration _defaultTimeout = Duration(seconds: 6);

  final FlutterEdgeTts _client;
  final Duration _timeout;

  @override
  Future<Uint8List?> fetch(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    try {
      final result = await _client.synthesize(trimmed).timeout(_timeout);
      if (result.audioBytes.isEmpty) {
        _log('empty audio for "$trimmed"');
        return null;
      }
      return result.audioBytes;
    } on TimeoutException {
      _log('timed out after $_timeout for "$trimmed"');
      return null;
    } catch (error) {
      _log('$error');
      return null;
    }
  }

  void _log(String reason) =>
      developer.log('tts fetch failed: $reason', name: 'EdgeTtsSource');
}
