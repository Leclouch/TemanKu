import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temanku/speech/no_hint_service.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';
import 'package:temanku/speech/remote_articulation_hint_service.dart';

final _clip = Uint8List.fromList([0, 1, 2, 3]);

void main() {
  group('NoHintService', () {
    test('always returns null, and never throws', () async {
      const service = NoHintService();
      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });
  });

  group('RemoteArticulationHintService', () {
    test('a 200 with a usable body returns a PronunciationHintResult', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'closest_word': 'apel', 'confidence': 0.87}), 200);
        }),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNotNull);
      expect(result!.closestWord, 'apel');
      expect(result.confidence, 0.87);
    });

    test('parses ipa and phoneme_edit_distance when the endpoint supplies them', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'closest_word': 'apel',
              // http.Response defaults to latin1 unless the content-type
              // header says otherwise — the explicit header below is what
              // lets these actual IPA codepoints round-trip.
              'ipa': 'ʔapəl',
              'phoneme_edit_distance': 2,
              // The endpoint's own pass/fail verdict — must never surface
              // anywhere, so this test proves it as a non-existent field on
              // the result, not just an unrendered one.
              'result': 'WIN',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result!.ipaTranscription, 'ʔapəl');
      expect(result.phonemeEditDistance, 2);
    });

    test('ipa and phoneme_edit_distance are null when the endpoint omits them', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'closest_word': 'apel'}), 200);
        }),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result!.ipaTranscription, isNull);
      expect(result.phonemeEditDistance, isNull);
    });

    test('sends target_word and difficulty as multipart fields, and the audio as a file', () async {
      String? sentTargetWord;
      String? sentDifficulty;
      var sawAudioFile = false;

      final service = RemoteArticulationHintService(
        client: MockClient.streaming((request, bodyStream) async {
          final multipart = request as http.MultipartRequest;
          sentTargetWord = multipart.fields['target_word'];
          sentDifficulty = multipart.fields['difficulty'];
          sawAudioFile = multipart.files.any((f) => f.field == 'audio');
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'closest_word': 'roti'}))),
            200,
          );
        }),
      );

      await service.scorePronunciation(audioClip: _clip, targetWord: 'roti', difficulty: 2);

      expect(sentTargetWord, 'roti');
      expect(sentDifficulty, '2');
      expect(sawAudioFile, isTrue);
    });

    test('a non-200 status returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => http.Response('server error', 500)),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });

    test('a malformed (non-JSON) body returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => http.Response('not json at all {{{', 200)),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });

    test('a JSON body missing closest_word returns null, never throws', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => http.Response(jsonEncode({'confidence': 0.5}), 200)),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });

    test('a client that throws returns null, never propagates the exception', () async {
      final service = RemoteArticulationHintService(
        client: MockClient((request) async => throw Exception('network unreachable')),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });

    test('a slow server past the timeout returns null instead of hanging the caller', () async {
      final service = RemoteArticulationHintService(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return http.Response(jsonEncode({'closest_word': 'apel'}), 200);
        }),
      );

      final result = await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(result, isNull);
    });

    test('difficulty defaults to defaultPronunciationHintDifficulty when not overridden', () async {
      String? sentDifficulty;
      final service = RemoteArticulationHintService(
        client: MockClient.streaming((request, bodyStream) async {
          sentDifficulty = (request as http.MultipartRequest).fields['difficulty'];
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'closest_word': 'apel'}))),
            200,
          );
        }),
      );

      await service.scorePronunciation(audioClip: _clip, targetWord: 'apel');
      expect(sentDifficulty, defaultPronunciationHintDifficulty.toString());
    });
  });
}
