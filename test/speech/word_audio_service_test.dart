import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/audio/sound_service.dart';
import 'package:temanku/speech/tts/cached_word_audio_service.dart';
import 'package:temanku/speech/tts/edge_tts_source.dart';
import 'package:temanku/speech/tts/word_audio_service.dart';

/// Minimal MP3-ish payload — the services only ever move these bytes around,
/// never decode them, so the contents are irrelevant to everything under test.
final _audio = Uint8List.fromList(utf8.encode('ID3-fake-mp3'));

/// Records what was asked for, so cache and dedup behaviour is observable
/// without an HTTP layer.
class _FakeSource implements WordAudioSource {
  _FakeSource({this.result, this.delay = Duration.zero});

  final Uint8List? result;
  final Duration delay;
  final List<String> requested = [];

  @override
  Future<Uint8List?> fetch(String word) async {
    requested.add(word);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

/// `FlutterEdgeTts.synthesize` isn't mockable through an injected transport
/// — the real call is a raw `dart:io` WebSocket, unlike the backend-routed
/// version this replaced (which mocked `package:http`). Neither the class
/// nor the method is `final`, so a subclass override is the seam instead.
class _FakeEdgeTts extends FlutterEdgeTts {
  _FakeEdgeTts({this.result, this.error, this.delay = Duration.zero})
      : super(voice: 'test-voice');

  final Uint8List? result;
  final Object? error;
  final Duration delay;
  String? lastText;

  @override
  Future<EdgeTtsSynthesisResult> synthesize(
    String text, {
    EdgeTtsProsody prosody = const EdgeTtsProsody(),
    EdgeTtsConfig? config,
    bool escapeText = true,
  }) async {
    lastText = text;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final err = error;
    if (err != null) throw err;
    return EdgeTtsSynthesisResult(
      audioBytes: result ?? Uint8List(0),
      metadata: const [],
      requestId: 'test-request',
    );
  }
}

class _FakeSound implements SoundService {
  _FakeSound({bool muted = false, double volume = 0.6})
      : _muted = muted,
        _volume = volume;

  bool _muted;
  double _volume;

  @override
  bool get isMuted => _muted;
  @override
  double get volume => _volume;
  @override
  void setMuted(bool muted) => _muted = muted;
  @override
  void setVolume(double volume) => _volume = volume;
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playTryAgain() async {}
  @override
  Future<void> playSessionComplete() async {}
}

void main() {
  group('NoWordAudioService', () {
    test('is silent, instant, and never throws', () async {
      const service = NoWordAudioService();
      expect(await service.speak('apel'), isFalse);
      await service.prefetch('apel');
      await service.dispose();
    });
  });

  group('EdgeTtsSource', () {
    test('sends the trimmed word to the Edge TTS client and returns its audio', () async {
      final client = _FakeEdgeTts(result: _audio);
      final source = EdgeTtsSource(client: client);

      final bytes = await source.fetch('apel');
      expect(bytes, _audio);
      expect(client.lastText, 'apel');
    });

    test('unlike /score, it accepts any word — there is no dictionary here', () async {
      // The asymmetry that makes the echoic exercise work at all: a word can
      // be modelled aloud even when it cannot be scored, which is the common
      // case given the backend's three-word TARGET_DICT.
      final source = EdgeTtsSource(client: _FakeEdgeTts(result: _audio));
      expect(await source.fetch('Kakak Sari'), isNotNull);
    });

    test('an empty or whitespace word never reaches the client', () async {
      final client = _FakeEdgeTts(result: _audio);
      final source = EdgeTtsSource(client: client);

      expect(await source.fetch('   '), isNull);
      expect(client.lastText, isNull);
    });

    test('an empty audio result returns null rather than zero-length audio', () async {
      final source = EdgeTtsSource(client: _FakeEdgeTts(result: Uint8List(0)));
      expect(await source.fetch('apel'), isNull);
    });

    test('a timeout returns null instead of stalling the child\'s turn', () async {
      final source = EdgeTtsSource(
        timeout: const Duration(milliseconds: 50),
        client: _FakeEdgeTts(
          result: _audio,
          delay: const Duration(milliseconds: 400),
        ),
      );
      expect(await source.fetch('apel'), isNull);
    });

    test('a throwing client returns null, never propagates', () async {
      final source = EdgeTtsSource(
        client: _FakeEdgeTts(error: Exception('offline')),
      );
      expect(await source.fetch('apel'), isNull);
    });
  });

  group('CachedWordAudioService', () {
    test('a muted guardian causes no network traffic at all', () async {
      // Checked before the fetch, not after — audio that will never be played
      // should not be downloaded.
      final source = _FakeSource(result: _audio);
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(muted: true),
      );

      expect(await service.speak('apel'), isFalse);
      expect(source.requested, isEmpty);
    });

    test('prefetch fetches once and speak reuses it', () async {
      final source = _FakeSource(result: _audio);
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(),
      );

      await service.prefetch('apel');
      await service.prefetch('apel');
      expect(source.requested, ['apel']);
    });

    test('case and surrounding whitespace collapse to one cache entry', () async {
      final source = _FakeSource(result: _audio);
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(),
      );

      await service.prefetch('Apel');
      await service.prefetch('  apel ');
      await service.prefetch('APEL');
      expect(source.requested, ['apel']);
    });

    test('concurrent requests for one word share a single fetch', () async {
      // Exactly what happens when a trial composes (prefetch) and the child
      // taps replay immediately (speak) — one request, not two.
      final source = _FakeSource(
        result: _audio,
        delay: const Duration(milliseconds: 30),
      );
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(),
      );

      await Future.wait([
        service.prefetch('apel'),
        service.prefetch('apel'),
        service.prefetch('apel'),
      ]);
      expect(source.requested, ['apel']);
    });

    test('a failed fetch is not cached, so the next attempt retries', () async {
      final source = _FakeSource(result: null);
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(),
      );

      await service.prefetch('apel');
      await service.prefetch('apel');
      expect(source.requested, ['apel', 'apel']);
    });

    test('speak returns false when the source has nothing, and never throws', () async {
      // The trial must proceed regardless — a turn with no model still runs,
      // because the guardian can always say the word themselves.
      final service = CachedWordAudioService(
        source: _FakeSource(result: null),
        soundService: _FakeSound(),
      );
      expect(await service.speak('apel'), isFalse);
    });

    test('an empty word is a no-op in both directions', () async {
      final source = _FakeSource(result: _audio);
      final service = CachedWordAudioService(
        source: source,
        soundService: _FakeSound(),
      );

      expect(await service.speak('  '), isFalse);
      await service.prefetch('');
      expect(source.requested, isEmpty);
    });
  });
}
