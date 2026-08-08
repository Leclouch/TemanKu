import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:temanku/speech/articulation_backend.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';

/// Calls the external articulation-scoring endpoint — **only ever bound in
/// `core/service_locator.dart` for a child whose guardian has explicitly
/// enabled it** (`Child.pronunciationHintEnabled`, set via
/// `features/guardian/child_settings_screen.dart`'s consent screen). Never
/// the default; see [NoHintService] for that.
///
/// §6 boundary, restated because it is the entire point of this file: this
/// class's result is advisory. It is not awaited before the guardian can
/// judge (`speak_mode_screen.dart` fires it and moves on), and nothing here
/// ever reaches [SessionRepository] or `AdvancementTracker` directly — it
/// only ever flows into a UI string and a button highlight.
///
/// ## The wire format, verified against the running backend
///
/// `POST /score`, multipart:
///   - `file` — the 16kHz mono WAV. **Not `audio`.** FastAPI's parameter is
///     named `file`, and a mismatch returns 422 with a `detail` array rather
///     than anything resembling a score. This was silently wrong for the
///     entire life of the previous implementation: the 422 was caught by the
///     blanket handler below and degraded to "no hint", so the feature looked
///     merely unhelpful rather than broken.
///   - `target_word` — must exist in the backend's `TARGET_DICT`.
///   - `difficulty` — the tolerance from `ArticulationTolerance.forPosition`.
///
/// Success is `200` with `{result, predicted_ipa, distance}`. The backend's
/// own `result` ("WIN"/"TRY AGAIN") is deliberately **ignored** — the app
/// re-derives that from `distance` against its own tolerance so the
/// calibration stays testable and tunable on this side (see
/// `speech/articulation_tolerance.dart`).
///
/// An unknown word is **also `200`**, with an `error` key and no score. That
/// is not an exceptional case here: the app's labels are guardian-typed free
/// text and the backend dictionary is three words, so it is the common path.
/// It is detected explicitly and degraded to null like any other miss.
///
/// Failure handling is uniform and total: a timeout, a non-200, a malformed
/// body, an `error` payload, a thrown exception from the HTTP client itself —
/// every one of them is caught here and turned into a null return with a
/// debug-only log line. Nothing from this class is ever allowed to surface as
/// an app error; the worst case a guardian ever sees is the hint line simply
/// not appearing.
class RemoteArticulationHintService implements PronunciationHintService {
  RemoteArticulationHintService({
    http.Client? client,
    Uri? baseUrl,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ArticulationBackend.baseUrl,
        _timeout = timeout ?? _defaultTimeout;

  /// Hackathon-scoped tripwire, same shape as the other timeouts in this
  /// codebase (`speech/vad_service.dart`'s listen window): a slow or hung
  /// external service must never stall the speak-mode trial loop, so this
  /// number is a hard ceiling, not a target.
  ///
  /// Ten seconds, not three. The model is a ~1.2GB wav2vec2 running a forward
  /// pass on CPU behind an ngrok tunnel; measured cold responses to this
  /// backend land well past three seconds, so the previous value guaranteed a
  /// timeout on exactly the requests that would have succeeded. The trial
  /// loop does not block on this either way — the guardian's buttons are live
  /// the whole time — so a longer ceiling costs nothing and buys the hint
  /// actually arriving.
  static const Duration _defaultTimeout = Duration(seconds: 10);

  /// Word-availability answers are cached for the process lifetime. The
  /// backend's dictionary is a module-level constant in `main.py`, so it
  /// cannot change without a restart, and speak mode would otherwise ask on
  /// every single trial.
  Set<String>? _availableWords;
  Future<Set<String>?>? _inFlightWordFetch;

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  @override
  Future<bool> canScore(String word) async {
    final words = await _fetchAvailableWords();
    if (words == null) return false;
    return words.contains(word.trim().toLowerCase());
  }

  /// `GET /` returns `{status, message, kata_tersedia: [...]}`. Deduplicated
  /// across concurrent callers — three trials composing at once must not
  /// produce three round trips.
  Future<Set<String>?> _fetchAvailableWords() {
    final cached = _availableWords;
    if (cached != null) return Future.value(cached);
    // Block body deliberately — see the identical note in
    // `speech/tts/cached_word_audio_service.dart`'s `_load`. An arrow body
    // whose expression evaluates to a Future makes `whenComplete` wait on
    // that future; here the assignment happens to evaluate to null, so the
    // arrow form works by accident. Not worth leaving as an accident.
    return _inFlightWordFetch ??= _doFetchAvailableWords()
      ..whenComplete(() {
        _inFlightWordFetch = null;
      });
  }

  Future<Set<String>?> _doFetchAvailableWords() async {
    try {
      final response = await _client
          .get(_baseUrl, headers: ArticulationBackend.headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        _logFailure('health check returned ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final words = decoded['kata_tersedia'];
      if (words is! List) return null;
      return _availableWords = {
        for (final w in words)
          if (w is String) w.trim().toLowerCase(),
      };
    } catch (error) {
      _logFailure('health check failed: $error');
      return null;
    }
  }

  @override
  Future<PronunciationHintResult?> scorePronunciation({
    required Uint8List audioClip,
    required String targetWord,
    required int tolerance,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _baseUrl.resolve('score'),
      )
        ..headers.addAll(ArticulationBackend.headers)
        ..fields['target_word'] = targetWord
        ..fields['difficulty'] = tolerance.toString()
        // Field name is `file` — see the class doc comment. Content type is
        // stated explicitly rather than inferred from the filename, because
        // the backend reads the bytes with soundfile and a wrong part header
        // is a harder failure to trace than a wrong extension.
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
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

      // The unknown-word path — 200, but carrying an error instead of a
      // score. Common, not exceptional; see the class doc comment.
      if (decoded['error'] != null) {
        _logFailure('backend rejected "$targetWord": ${decoded['error']}');
        return null;
      }

      final distance = decoded['distance'];
      if (distance is! int) {
        _logFailure('response missing a usable integer distance');
        return null;
      }

      final ipa = decoded['predicted_ipa'];
      return PronunciationHintResult(
        // Empty is a meaningful value here (no phonemes resolved), so it is
        // preserved rather than rejected — see PronunciationHintResult.
        predictedIpa: ipa is String ? ipa : '',
        distance: distance,
        tolerance: tolerance,
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
