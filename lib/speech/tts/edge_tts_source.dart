import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:temanku/speech/articulation_backend.dart';
import 'package:temanku/speech/tts/word_audio_service.dart';

/// Fetches spoken-word audio from the backend's `GET /tts` endpoint.
///
/// The endpoint wraps Microsoft Edge's neural TTS and streams back
/// `audio/mpeg` — verified against the running service: 24kHz mono MP3,
/// roughly 10KB for a single word.
///
/// Unlike `POST /score`, this has **no dictionary constraint**: any string
/// can be synthesised. That asymmetry is worth knowing when reading speak
/// mode — a word can be modelled aloud even when it cannot be scored, which
/// is the common case given the backend's three-word `TARGET_DICT` against
/// guardian-typed labels. The echoic exercise still works; only the advisory
/// hint drops out.
class EdgeTtsSource implements WordAudioSource {
  EdgeTtsSource({http.Client? client, Uri? baseUrl, Duration? timeout, String? voice})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ArticulationBackend.baseUrl,
        _timeout = timeout ?? _defaultTimeout,
        _voice = voice ?? defaultVoice;

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

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;
  final String _voice;

  @override
  Future<Uint8List?> fetch(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = _baseUrl.resolve('tts').replace(
        queryParameters: {'text': trimmed, 'voice': _voice},
      );
      final response =
          await _client.get(uri, headers: ArticulationBackend.headers).timeout(_timeout);
      if (response.statusCode != 200) {
        _log('non-200 status ${response.statusCode} for "$trimmed"');
        return null;
      }
      if (response.bodyBytes.isEmpty) {
        _log('empty audio body for "$trimmed"');
        return null;
      }
      return response.bodyBytes;
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
