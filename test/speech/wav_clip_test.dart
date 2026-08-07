import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/speech/audio/wav_clip.dart';

/// Builds a synthetic 16kHz mono PCM16 WAV whose sample values count up
/// (0, 1, 2, ...) so a trimmed slice can be checked by value, not just by
/// length.
Uint8List _syntheticWav({required int sampleRate, required int sampleCount}) {
  const bytesPerSample = 2;
  final pcm = ByteData(sampleCount * bytesPerSample);
  for (var i = 0; i < sampleCount; i++) {
    pcm.setInt16(i * bytesPerSample, i, Endian.little);
  }

  final header = ByteData(44);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  final dataLength = pcm.lengthInBytes;
  tag(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  header.setUint16(32, bytesPerSample, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  return Uint8List(44 + dataLength)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + dataLength, pcm.buffer.asUint8List());
}

List<int> _samplesOf(Uint8List wav) {
  // Header is always 44 bytes for the synthetic clips this test builds (no
  // extra chunks), so this is safe here even though WavClip.trim itself
  // walks chunks generically.
  final data = ByteData.sublistView(wav, 44);
  return [for (var i = 0; i < data.lengthInBytes ~/ 2; i++) data.getInt16(i * 2, Endian.little)];
}

void main() {
  group('WavClip.trim', () {
    test('slices exactly the requested time window, sample-accurate', () {
      // 1 second of audio at 16kHz → sample index == millisecond * 16.
      final wav = _syntheticWav(sampleRate: 16000, sampleCount: 16000);

      final trimmed = WavClip.trim(
        wav,
        start: const Duration(milliseconds: 100),
        end: const Duration(milliseconds: 200),
      );

      final samples = _samplesOf(trimmed);
      expect(samples.length, 1600); // 100ms of 16kHz audio
      expect(samples.first, 1600); // sample index at 100ms
      expect(samples.last, 3199); // sample index just before 200ms
    });

    test('the trimmed clip is itself a valid, re-parseable WAV', () {
      final wav = _syntheticWav(sampleRate: 16000, sampleCount: 16000);
      final trimmed = WavClip.trim(
        wav,
        start: Duration.zero,
        end: const Duration(milliseconds: 500),
      );

      // Re-trimming the output (the whole thing) proves the header WavClip
      // wrote is itself correctly formed — WavClip.parse would throw on a
      // malformed RIFF/WAVE/fmt/data structure.
      final reparsed = WavClip.trim(trimmed, start: Duration.zero, end: const Duration(seconds: 10));
      expect(_samplesOf(reparsed).length, _samplesOf(trimmed).length);
    });

    test('clamps a start/end window that runs past the available audio', () {
      final wav = _syntheticWav(sampleRate: 16000, sampleCount: 1600); // 100ms total

      final trimmed = WavClip.trim(
        wav,
        start: const Duration(milliseconds: 50),
        end: const Duration(seconds: 5), // far past the clip's actual end
      );

      expect(_samplesOf(trimmed).length, 800); // clamped to the remaining 50ms
    });

    test('an end before start clamps to an empty (but still valid) clip', () {
      final wav = _syntheticWav(sampleRate: 16000, sampleCount: 1600);

      final trimmed = WavClip.trim(
        wav,
        start: const Duration(milliseconds: 80),
        end: const Duration(milliseconds: 10),
      );

      expect(_samplesOf(trimmed), isEmpty);
    });

    test('throws on a non-WAV input rather than producing garbage', () {
      final notWav = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(
        () => WavClip.trim(notWav, start: Duration.zero, end: const Duration(seconds: 1)),
        throwsFormatException,
      );
    });
  });
}
