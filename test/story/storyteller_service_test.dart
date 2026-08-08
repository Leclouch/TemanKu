import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/story/claude_storyteller_service.dart';
import 'package:temanku/story/no_storyteller_service.dart';
import 'package:temanku/story/storyteller_service.dart';

const _practiceContext = StoryContext(
  childName: 'Arif',
  module: makananModule,
  tierCopy: 'makanan lain yang mudah dibedakan',
  mastered: false,
);

const _masteredContext = StoryContext(
  childName: 'Arif',
  module: makananModule,
  tierCopy: 'memilih berdasarkan fungsi, bukan nama',
  mastered: true,
);

String _messageBody(String text) => jsonEncode({
      'id': 'msg_test',
      'type': 'message',
      'role': 'assistant',
      'content': [
        {'type': 'text', 'text': text},
      ],
    });

http.Response _utf8Response(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('NoStorytellerService', () {
    const service = NoStorytellerService();

    test('never returns null — the offline default has no failure path', () async {
      expect(await service.nextBeat(_practiceContext), isNotNull);
      expect(await service.nextBeat(_masteredContext), isNotNull);
    });

    test('interpolates the child name and module into the line', () async {
      final beat = await service.nextBeat(_practiceContext);
      expect(beat, contains('Arif'));
      expect(beat, contains(makananModule.displayName));
    });

    test('the same context always resolves to the same line — stable across rebuilds',
        () async {
      final first = await service.nextBeat(_practiceContext);
      final second = await service.nextBeat(_practiceContext);
      expect(first, second);
    });

    test('a different tier can resolve to a different line than mastery', () async {
      final practicing = await service.nextBeat(_practiceContext);
      final mastered = await service.nextBeat(_masteredContext);
      // Not a strict inequality requirement (hashing could coincide), but the
      // mastered pool and practice pool are disjoint template sets, so the
      // two must differ whenever both are drawn from real templates.
      expect(practicing == mastered, isFalse);
    });
  });

  group('ClaudeStorytellerService', () {
    test('a 200 with a text block returns the trimmed text', () async {
      final service = ClaudeStorytellerService(
        apiKey: 'test-key',
        client: MockClient((request) async => _utf8Response(_messageBody('  Babak baru dimulai!  '))),
      );

      final beat = await service.nextBeat(_practiceContext);
      expect(beat, 'Babak baru dimulai!');
    });

    test('sends the API key and version headers Anthropic requires', () async {
      String? sentKey;
      String? sentVersion;
      final service = ClaudeStorytellerService(
        apiKey: 'sk-ant-test',
        client: MockClient((request) async {
          sentKey = request.headers['x-api-key'];
          sentVersion = request.headers['anthropic-version'];
          return _utf8Response(_messageBody('ok'));
        }),
      );

      await service.nextBeat(_practiceContext);
      expect(sentKey, 'sk-ant-test');
      expect(sentVersion, '2023-06-01');
    });

    test('a non-200 response returns null, never throws', () async {
      final service = ClaudeStorytellerService(
        apiKey: 'test-key',
        client: MockClient((request) async => http.Response('rate limited', 429)),
      );
      expect(await service.nextBeat(_practiceContext), isNull);
    });

    test('malformed JSON returns null, never throws', () async {
      final service = ClaudeStorytellerService(
        apiKey: 'test-key',
        client: MockClient((request) async => http.Response('not json {{{', 200)),
      );
      expect(await service.nextBeat(_practiceContext), isNull);
    });

    test('an empty content array (e.g. a pre-output refusal) returns null, never crashes '
        'on content[0]', () async {
      final service = ClaudeStorytellerService(
        apiKey: 'test-key',
        client: MockClient((request) async => _utf8Response(jsonEncode({
              'id': 'msg_test',
              'type': 'message',
              'role': 'assistant',
              'content': <dynamic>[],
            }))),
      );
      expect(await service.nextBeat(_practiceContext), isNull);
    });

    test('a network failure returns null, never throws', () async {
      final service = ClaudeStorytellerService(
        apiKey: 'test-key',
        client: MockClient((request) async => throw Exception('network unreachable')),
      );
      expect(await service.nextBeat(_practiceContext), isNull);
    });
  });
}
