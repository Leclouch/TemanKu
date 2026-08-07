import 'dart:typed_data';

/// Minimal RIFF/WAVE parsing + re-encoding, just enough to slice a captured
/// clip down to the window `speak_mode_screen.dart` wants to send —
/// [SpeechEvent.onsetLatency] through `onsetLatency + duration`. No
/// resampling here: `speech/audio_segment_recorder.dart` already records
/// directly at 16kHz mono via the `record` package's own config, so this
/// file only ever trims, never converts a sample rate.
abstract final class WavClip {
  /// Returns a new, self-contained WAV (own RIFF/data header) covering
  /// [wavBytes] from [start] to [end]. Clamped to the available audio —
  /// VAD's timestamps and the recorder's actual window can disagree by a
  /// few milliseconds at the edges, and clamping is the harmless response
  /// to that, not an error.
  static Uint8List trim(
    Uint8List wavBytes, {
    required Duration start,
    required Duration end,
  }) {
    final parsed = _WavData.parse(wavBytes);
    final frameSize = parsed.numChannels * (parsed.bitsPerSample ~/ 8);
    final bytesPerSecond = parsed.sampleRate * frameSize;

    int byteOffsetFor(Duration d) {
      final raw = (d.inMicroseconds * bytesPerSecond) ~/ Duration.microsecondsPerSecond;
      // Frame-align — slicing mid-frame would shift channels/produce noise.
      return raw - (raw % frameSize);
    }

    final startByte = byteOffsetFor(start).clamp(0, parsed.data.length);
    final endByte = byteOffsetFor(end).clamp(startByte, parsed.data.length);

    return _encode(
      pcm: parsed.data.sublist(startByte, endByte),
      sampleRate: parsed.sampleRate,
      numChannels: parsed.numChannels,
      bitsPerSample: parsed.bitsPerSample,
    );
  }

  static Uint8List _encode({
    required Uint8List pcm,
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

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
    header.setUint32(16, 16, Endian.little); // fmt chunk size — PCM
    header.setUint16(20, 1, Endian.little); // PCM format tag
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    tag(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    return Uint8List(44 + pcm.length)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + pcm.length, pcm);
  }
}

class _WavData {
  const _WavData({
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required this.data,
  });

  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final Uint8List data;

  /// Walks RIFF chunks rather than assuming a fixed 44-byte header — some
  /// encoders (and some platforms of the `record` package) insert extra
  /// chunks (e.g. `LIST`) before `data`.
  static _WavData parse(Uint8List bytes) {
    if (bytes.length < 12 || _fourCC(bytes, 0) != 'RIFF' || _fourCC(bytes, 8) != 'WAVE') {
      throw const FormatException('Not a RIFF/WAVE clip');
    }
    final view = ByteData.sublistView(bytes);

    var sampleRate = 16000;
    var numChannels = 1;
    var bitsPerSample = 16;
    Uint8List? data;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = _fourCC(bytes, offset);
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkSize;
      if (chunkEnd > bytes.length) break;

      if (chunkId == 'fmt ') {
        numChannels = view.getUint16(chunkStart + 2, Endian.little);
        sampleRate = view.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = view.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        data = bytes.sublist(chunkStart, chunkEnd);
      }

      // Chunks are word-aligned; an odd-sized chunk carries one pad byte.
      offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
    }

    if (data == null) throw const FormatException('WAV clip has no data chunk');
    return _WavData(
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitsPerSample: bitsPerSample,
      data: data,
    );
  }

  static String _fourCC(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
}
