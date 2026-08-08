import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/speech/no_hint_service.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';
import 'package:temanku/speech/remote_articulation_hint_service.dart';

final _clip = Uint8List.fromList([0, 1, 2, 3]);

/// The shape the live backend actually returns from `POST /score`, verified
/// against the running service. Kept as one helper so a future wire-format
/// change has a single place to update.
String _scoreBody({String ipa = 'ˈapəl', int distance = 1}) =>
    jsonEncode({'result': 'WIN', 'predicted_ipa': ipa, 'distance': distance});

/// A 200 carrying [body] as **UTF-8 bytes**.
///
/// Not `http.Response(body, 200)`: that constructor encodes latin-1 when the
/// headers carry no charset, and IPA is full of characters latin-1 cannot
/// represent (ˈ, ə, ŋ, tʃ) — the encode throws and the service degrades to
/// null, which looks exactly like a real failure. The service reads with
/// `bytesToString()`, which is UTF-8, so bytes are what the wire actually
/// carries and what the test should supply.
http.Response _utf8Response(String body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(body), status);

/// `GET /` — the word-availability probe.
String _healthBody({List<String> words = const ['apel', 'buku', 'kucing']}) =>
    jsonEncode({'status': 'ok', 'message': 'ok', 'kata_tersedia': words});

void main() {
  group('NoHintService', () {
    test('always returns null, and never throws', () async {
      const service = NoHintService();
      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('canScore is always false — nothing is recorded when the feature is off',
        () async {
      const service = NoHintService();
      expect(await service.canScore('apel'), isFalse);
    });
  });

  group('PronunciationHintResult', () {
    test('withinTolerance compares distance against the stated ceiling', () {
      const inside = PronunciationHintResult(
        predictedIpa: 'apəl',
        distance: 2,
        tolerance: 2,
      );
      const outside = PronunciationHintResult(
        predictedIpa: 'apəl',
        distance: 3,
        tolerance: 2,
      );
      expect(inside.withinTolerance, isTrue);
      expect(outside.withinTolerance, isFalse);
    });

    test('suggests correct inside tolerance, incorrect outside it', () {
      expect(
        const PronunciationHintResult(predictedIpa: 'apəl', distance: 1, tolerance: 2)
            .suggestedOutcome,
        TrialOutcome.correct,
      );
      expect(
        const PronunciationHintResult(predictedIpa: 'buku', distance: 5, tolerance: 2)
            .suggestedOutcome,
        TrialOutcome.incorrect,
      );
    });

    test('empty IPA suggests notAttempted, not incorrect', () {
      // No phonemes resolved means the model heard nothing it could parse.
      // §6 already treats "did not try" and "said it wrong" as different
      // things, and the distance in this case is meaningless — it is just
      // the length of the target.
      const silence = PronunciationHintResult(
        predictedIpa: '',
        distance: 4,
        tolerance: 2,
      );
      expect(silence.suggestedOutcome, TrialOutcome.notAttempted);
    });
  });

  group('RemoteArticulationHintService', () {
    test('a 200 with a usable body returns a PronunciationHintResult', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => _utf8Response(_scoreBody())),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNotNull);
      expect(result!.predictedIpa, 'ˈapəl');
      expect(result.distance, 1);
      expect(result.tolerance, 2);
      expect(result.withinTolerance, isTrue);
    });

    test('sends the audio under the field name "file", which is what FastAPI expects',
        () async {
      // Regression guard on a bug that shipped: the field was named `audio`,
      // FastAPI's parameter is `file`, and every request 422'd. The blanket
      // failure handling turned that into a silent "no hint", so the feature
      // looked unhelpful rather than broken for its whole life.
      String? sentTargetWord;
      String? sentDifficulty;
      var sawFileField = false;

      final service = RemoteArticulationHintService(
        client: MockClient.streaming((request, bodyStream) async {
          final multipart = request as http.MultipartRequest;
          sentTargetWord = multipart.fields['target_word'];
          sentDifficulty = multipart.fields['difficulty'];
          sawFileField = multipart.files.any((f) => f.field == 'file');
          return http.StreamedResponse(
            Stream.value(utf8.encode(_scoreBody())),
            200,
          );
        }),
      );

      await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'roti',
        tolerance: 3,
      );

      expect(sawFileField, isTrue, reason: 'must be "file", never "audio"');
      expect(sentTargetWord, 'roti');
      expect(sentDifficulty, '3');
    });

    test('POSTs to /score, not to the base URL', () async {
      Uri? sentUrl;
      final service = RemoteArticulationHintService(
        client: MockClient.streaming((request, bodyStream) async {
          sentUrl = request.url;
          return http.StreamedResponse(Stream.value(utf8.encode(_scoreBody())), 200);
        }),
      );

      await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(sentUrl!.path, endsWith('/score'));
    });

    test('the tolerance passed in is what goes out as difficulty', () async {
      // The app and the backend must never disagree about the threshold —
      // one number, computed once by ArticulationTolerance, used for both
      // the request and the local interpretation.
      String? sentDifficulty;
      final service = RemoteArticulationHintService(
        client: MockClient.streaming((request, bodyStream) async {
          sentDifficulty = (request as http.MultipartRequest).fields['difficulty'];
          return http.StreamedResponse(Stream.value(utf8.encode(_scoreBody())), 200);
        }),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 4,
      );
      expect(sentDifficulty, '4');
      expect(result!.tolerance, 4);
    });

    test('an unknown word comes back 200-with-error and returns null', () async {
      // Not an edge case: the backend dictionary is three words and the
      // app's labels are guardian-typed free text, so this is the common
      // path. It is a 200, so status-code checking alone would sail past it
      // and then fail to find a distance.
      final service = RemoteArticulationHintService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': "'pisang' belum ada di TARGET_DICT.",
              'kata_tersedia': ['apel', 'buku', 'kucing'],
            }),
            200,
          ),
        ),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'pisang',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('an empty predicted_ipa is preserved, not rejected', () async {
      // The backend returns "" for audio it cannot resolve into phonemes.
      // That is a meaningful answer (silence/noise) and drives the
      // notAttempted suggestion — dropping it would lose that distinction.
      final service = RemoteArticulationHintService(
        client: MockClient(
          (request) async => _utf8Response(_scoreBody(ipa: '', distance: 4)),
        ),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNotNull);
      expect(result!.predictedIpa, isEmpty);
      expect(result.suggestedOutcome, TrialOutcome.notAttempted);
    });

    test('a non-200 status returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => http.Response('server error', 500)),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('a malformed (non-JSON) body returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => http.Response('not json at all {{{', 200)),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('a JSON body missing a distance returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient(
          (request) async => http.Response(jsonEncode({'predicted_ipa': 'apəl'}), 200),
        ),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('a client that throws returns null, never propagates the exception', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => throw Exception('network unreachable')),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    test('a slow server past the timeout returns null instead of hanging the caller',
        () async {
      final service = RemoteArticulationHintService(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return _utf8Response(_scoreBody());
        }),
      );

      final result = await service.scorePronunciation(
        audioClip: _clip,
        targetWord: 'apel',
        tolerance: 2,
      );
      expect(result, isNull);
    });

    group('canScore', () {
      test('reads kata_tersedia from the health endpoint, case-insensitively', () async {
        final service = RemoteArticulationHintService(
          client: MockClient((request) async => _utf8Response(_healthBody())),
        );

        expect(await service.canScore('apel'), isTrue);
        expect(await service.canScore('  Apel  '), isTrue);
        expect(await service.canScore('pisang'), isFalse);
      });

      test('caches, so repeated trials do not re-probe the backend', () async {
        var calls = 0;
        final service = RemoteArticulationHintService(
          client: MockClient((request) async {
            calls++;
            return _utf8Response(_healthBody());
          }),
        );

        await service.canScore('apel');
        await service.canScore('buku');
        await service.canScore('kucing');
        expect(calls, 1);
      });

      test('deduplicates concurrent probes into one request', () async {
        var calls = 0;
        final service = RemoteArticulationHintService(
          client: MockClient((request) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return _utf8Response(_healthBody());
          }),
        );

        await Future.wait([
          service.canScore('apel'),
          service.canScore('buku'),
          service.canScore('kucing'),
        ]);
        expect(calls, 1);
      });

      test('an unreachable backend answers false, never throws', () async {
        final service = RemoteArticulationHintService(
          client: MockClient((request) async => throw Exception('offline')),
        );
        expect(await service.canScore('apel'), isFalse);
      });
    });
  });
}
