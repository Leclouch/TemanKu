/// Live smoke test for the articulation backend — **run by hand, never in CI.**
///
/// ```
/// dart run tool/smoke_articulation_backend.dart
/// ```
///
/// The unit tests around `RemoteArticulationHintService` and `EdgeTtsSource`
/// all run against mocked clients, which proves the parsing but cannot prove
/// the *wire format* — and the wire format is exactly what was wrong before
/// (the file field was named `audio`; FastAPI wanted `file`, and every
/// request 422'd silently for the life of the feature). This script exercises
/// the real services against the real host so that class of bug cannot hide
/// behind a passing mock again.
///
/// It talks to an ngrok tunnel that is up only while the backend is being
/// demoed, so it is deliberately not a `test/` file: a normal `flutter test`
/// run must never depend on someone's laptop being on.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:temanku/speech/remote_articulation_hint_service.dart';
import 'package:temanku/speech/tts/edge_tts_source.dart';

/// A second of 220Hz tone at 16kHz mono, 16-bit — the format the backend
/// asserts on (`assert sr == 16000`). Not speech, so the phoneme model finds
/// nothing in it; that is fine, because what is under test here is the
/// round trip, not the score.
Uint8List _probeWav() {
  const sampleRate = 16000;
  const samples = sampleRate;
  final pcm = Uint8List(samples * 2);
  final view = ByteData.sublistView(pcm);
  for (var i = 0; i < samples; i++) {
    view.setInt16(
      i * 2,
      (3000 * math.sin(2 * math.pi * 220 * i / sampleRate)).round(),
      Endian.little,
    );
  }

  final header = ByteData(44);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return Uint8List(44 + pcm.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm.length, pcm);
}

Future<void> main() async {
  var failures = 0;
  void check(String label, bool ok, [String detail = '']) {
    stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $label${detail.isEmpty ? '' : '  — $detail'}');
    if (!ok) failures++;
  }

  final hints = RemoteArticulationHintService(
    // The real model is a ~1.2GB wav2vec2 forward pass on CPU behind a
    // tunnel; a cold first call is slow enough to need more headroom than
    // the in-app ceiling gives it.
    timeout: const Duration(seconds: 120),
  );

  stdout.writeln('--- canScore (GET /) ---');
  final knownWord = await hints.canScore('apel');
  check('a dictionary word is reported scorable', knownWord);

  final unknownWord = await hints.canScore('pisang');
  check('a non-dictionary word is reported unscorable', !unknownWord);

  if (!knownWord) {
    stdout.writeln('\nBackend unreachable — skipping the rest.');
    exit(1);
  }

  stdout.writeln('\n--- scorePronunciation (POST /score) ---');
  final result = await hints.scorePronunciation(
    audioClip: _probeWav(),
    targetWord: 'apel',
    tolerance: 2,
  );
  check(
    'a dictionary word returns a parsed result (not null)',
    result != null,
    result == null
        ? 'null means the wire format is wrong again — check the "file" field name'
        : 'ipa="${result.predictedIpa}" distance=${result.distance} '
            'tolerance=${result.tolerance} suggests=${result.suggestedOutcome.name}',
  );

  final rejected = await hints.scorePronunciation(
    audioClip: _probeWav(),
    targetWord: 'pisang',
    tolerance: 2,
  );
  check(
    'a non-dictionary word degrades to null (200-with-error path)',
    rejected == null,
  );

  stdout.writeln('\n--- EdgeTtsSource (GET /tts) ---');
  final source = EdgeTtsSource(timeout: const Duration(seconds: 30));

  final audio = await source.fetch('apel');
  check(
    'a dictionary word synthesises',
    audio != null && audio.isNotEmpty,
    audio == null ? 'null' : '${audio.length} bytes',
  );

  // The asymmetry that makes the echoic exercise usable at all: TTS has no
  // dictionary, so a word can be modelled aloud even when it cannot be scored.
  final freeText = await source.fetch('Kakak Sari');
  check(
    'a NON-dictionary word still synthesises (no TARGET_DICT on /tts)',
    freeText != null && freeText.isNotEmpty,
    freeText == null ? 'null' : '${freeText.length} bytes',
  );

  stdout.writeln('\n${failures == 0 ? 'All checks passed.' : '$failures check(s) failed.'}');
  exit(failures == 0 ? 0 : 1);
}
