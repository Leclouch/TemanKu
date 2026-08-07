import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:temanku/speech/pronunciation_hint_service.dart';

/// Calls an external articulation-scoring endpoint — **only ever bound in
/// `core/service_locator.dart` for a child whose guardian has explicitly
/// enabled it** (`Child.pronunciationHintEnabled`, set via
/// `features/guardian/child_settings_screen.dart`'s consent screen). Never
/// the default; see [NoHintService] for that.
///
/// §6 boundary, restated because it is the entire point of this file: this
/// class's result is advisory. It is not awaited before the guardian can
/// judge (`speak_mode_screen.dart` fires it and moves on), and nothing here
/// ever reaches [SessionRepository] or `AdvancementTracker` directly — it
/// only ever flows into a UI string.
///
/// Failure handling is uniform and total: a timeout, a non-200, a malformed
/// body, a thrown exception from the HTTP client itself — every one of them
/// is caught here and turned into a null return with a debug-only log line.
/// Nothing from this class is ever allowed to surface as an app error; the
/// worst case a guardian ever sees is the hint line simply not appearing.
class RemoteArticulationHintService implements PronunciationHintService {
  RemoteArticulationHintService({http.Client? client, Uri? endpoint, Duration? timeout})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? _defaultEndpoint,
        _timeout = timeout ?? _defaultTimeout;

  static final Uri _defaultEndpoint =
      Uri.parse('https://scribing-sulfide-backspin.ngrok-free.dev/score');

  /// Hackathon-scoped tripwire, same shape as the other timeouts in this
  /// codebase (`speech/vad_service.dart`'s listen window): a slow or hung
  /// external service must never stall the speak-mode trial loop, so this
  /// number is a hard ceiling, not a target. Overridable only so tests don't
  /// have to burn 3 real seconds to exercise the timeout path — every real
  /// caller gets this default.
  static const Duration _defaultTimeout = Duration(seconds: 3);

  final http.Client _client;
  final Uri _endpoint;
  final Duration _timeout;

  @override
  Future<PronunciationHintResult?> scorePronunciation({
    required Uint8List audioClip,
    required String targetWord,
    int difficulty = defaultPronunciationHintDifficulty,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _endpoint)
        ..fields['target_word'] = targetWord
        ..fields['difficulty'] = difficulty.toString()
        ..files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audioClip,
            filename: 'clip.wav',
          ),
        );

      final streamed = await _client.send(request).timeout(_timeout);
      if (streamed.statusCode != 200) {
        _logFailure('non-200 status ${streamed.statusCode}');
        return null;
      }

      final body = await streamed.stream.bytesToString().timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        _logFailure('response body was not a JSON object');
        return null;
      }

      final closestWord = decoded['closest_word'];
      if (closestWord is! String || closestWord.isEmpty) {
        _logFailure('response missing a usable closest_word');
        return null;
      }

      final confidence = decoded['confidence'];
      return PronunciationHintResult(
        closestWord: closestWord,
        confidence: confidence is num ? confidence.toDouble() : null,
      );
    } on TimeoutException {
      _logFailure('timed out after $_timeout');
      return null;
    } catch (error) {
      // Deliberately broad — network errors, decode errors, anything else
      // the http client or dart:convert can throw. All of it degrades to
      // "no hint this trial", never an error the guardian sees.
      _logFailure('$error');
      return null;
    }
  }

  void _logFailure(String reason) {
    developer.log(
      'pronunciation hint request failed: $reason',
      name: 'RemoteArticulationHintService',
    );
  }
}
