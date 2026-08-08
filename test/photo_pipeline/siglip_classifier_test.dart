import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/siglip_classifier.dart';

/// A real file on disk — `http.MultipartFile.fromPath` reads bytes off the
/// filesystem, so a nonexistent path throws before any request is even
/// built. Any bundled asset does; this one just happens to already exist for
/// `stranger_library_test.dart`.
const _imagePath = 'assets/stranger_library/stranger_child_01.png';

/// The shape the live backend actually returns from `POST /classify`,
/// verified against the running service with real photos in `assets/test/`.
/// [topScore] and [secondScore] drive [SiglipClassifier]'s margin check;
/// [extra] pads out `all_scores` the way 60+ real candidate labels would,
/// without needing every test to spell all of them out.
String _classifyBody({
  String topLabel = 'banana',
  double topScore = 0.51,
  double secondScore = 0.00007,
}) =>
    jsonEncode({
      'top_label': topLabel,
      'confidence': topScore,
      'all_scores': [
        {'label': topLabel, 'score': topScore},
        {'label': 'apple', 'score': secondScore},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SiglipClassifier — graceful degradation', () {
    test('Keluarga always returns null, regardless of initialize state', () async {
      final classifier = SiglipClassifier(
        client: MockClient((request) async => http.Response(_classifyBody(), 200)),
      );
      addTearDown(classifier.dispose);

      await classifier.initialize();
      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.keluarga,
      );
      expect(suggestion, isNull);
    });

    test('a non-200 status returns null, never throws', () async {
      final classifier = SiglipClassifier(
        client: MockClient((request) async => http.Response('server error', 500)),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a malformed (non-JSON) body returns null, never throws', () async {
      final classifier = SiglipClassifier(
        client: MockClient((request) async => http.Response('not json {{{', 200)),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a JSON body missing all_scores returns null, never throws', () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(jsonEncode({'top_label': 'banana'}), 200),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('an empty all_scores list returns null, never throws', () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(jsonEncode({'all_scores': <dynamic>[]}), 200),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a client that throws returns null, never propagates the exception', () async {
      final classifier = SiglipClassifier(
        client: MockClient((request) async => throw Exception('network unreachable')),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a slow server past the timeout returns null instead of hanging the caller',
        () async {
      final classifier = SiglipClassifier(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return http.Response(_classifyBody(), 200);
        }),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test(
        'a top score within siglipMarginThreshold of the runner-up returns null '
        '— this is what a nonsense photo looks like, not a real match', () async {
      // Live negative controls (an app icon, a child's face — see
      // siglip_classifier.dart's doc comment) landed the top two candidates
      // within ~1.2x of each other. This mock reproduces that shape exactly
      // at the boundary.
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topScore: 0.0012, secondScore: 0.001),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a top score below the noise floor returns null even with an infinite margin',
        () async {
      // Guards the float-noise edge case: two near-zero scores can still
      // produce a huge ratio (1e-13 vs 1e-14 is "10x") without meaning
      // anything. See _minTopScore's doc comment.
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topScore: 1e-9, secondScore: 0),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a winning "empty background" label returns null, never a suggestion', () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topLabel: 'empty background', topScore: 0.3, secondScore: 0.001),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('a top label outside the known vocabulary returns null rather than throwing',
        () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topLabel: 'spaceship', topScore: 0.3, secondScore: 0.001),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });
  });

  group('SiglipClassifier — request shape and success path', () {
    test('POSTs multipart to /classify with file and English labels', () async {
      Uri? sentUrl;
      String? sentLabels;
      var sawFileField = false;

      final classifier = SiglipClassifier(
        client: MockClient.streaming((request, bodyStream) async {
          sentUrl = request.url;
          final multipart = request as http.MultipartRequest;
          sentLabels = multipart.fields['labels'];
          sawFileField = multipart.files.any((f) => f.field == 'file');
          return http.StreamedResponse(Stream.value(utf8.encode(_classifyBody())), 200);
        }),
      );
      addTearDown(classifier.dispose);

      await classifier.suggestLabel(imagePath: _imagePath, module: ModuleId.makanan);

      expect(sentUrl!.path, endsWith('/classify'));
      expect(sawFileField, isTrue);
      // English, not Indonesian — see _labelVocabulary's doc comment for
      // why: SigLIP2's text tower performs far worse against raw Indonesian
      // label strings, verified live against real photos in assets/test/.
      expect(sentLabels, contains('donut'));
      expect(sentLabels, contains('toothbrush'));
      expect(sentLabels, contains('boiled egg'));
      expect(sentLabels, contains('empty background'));
      expect(sentLabels!.split(',').length, greaterThan(60));
    });

    test('a clear margin over the runner-up returns the Indonesian translation', () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topLabel: 'banana', topScore: 0.51, secondScore: 0.00007),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.label, 'Pisang');
      expect(suggestion.confidence, 0.51);
    });

    test(
        'a weak but clearly-dominant absolute score still returns a suggestion '
        '— low confidence alone is not disqualifying', () async {
      // Reproduces the live "shoe photographed at an odd angle" case: top
      // score only 0.0001, but ~31x the runner-up. Confirms the margin
      // check, not the absolute value, is what gates this.
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            _classifyBody(topLabel: 'shoe', topScore: 0.0001, secondScore: 0.0001 / 31),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.label, 'Sepatu');
    });

    test('a single-candidate response (no runner-up) is treated as an infinite margin',
        () async {
      final classifier = SiglipClassifier(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'top_label': 'banana',
              'confidence': 0.51,
              'all_scores': [
                {'label': 'banana', 'score': 0.51},
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(classifier.dispose);

      final suggestion = await classifier.suggestLabel(
        imagePath: _imagePath,
        module: ModuleId.makanan,
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.label, 'Pisang');
    });

    test('dispose() is safe without ever initializing, and safe to call twice', () async {
      final classifier = SiglipClassifier(
        client: MockClient((request) async => http.Response(_classifyBody(), 200)),
      );
      await classifier.dispose();
      await classifier.dispose();
    });
  });
}
