import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Captures raw audio for the pronunciation-hint call — a concern
/// deliberately kept **separate from `speech/vad_service.dart`.** VAD's own
/// doc comment is explicit that its contract stays narrow ("detects *that
/// and when* the child spoke... never a transcript... no text field
/// anywhere for exactly that reason"); threading raw audio bytes through it
/// would be exactly the kind of scope creep that comment warns against.
///
/// So this is a parallel, independently-gated capture path. It only ever
/// runs for a trial where the guardian has explicitly turned the
/// pronunciation-hint feature on for this child (`Child.pronunciationHintEnabled`,
/// wired in `core/service_locator.dart`) — never as a side effect of which
/// [VadService] implementation happens to be bound. `speak_mode_screen.dart`
/// starts this alongside `VadService.listenForUtterance` and, once that
/// resolves, uses the returned [SpeechEvent]'s onset/duration timestamps
/// (`speech/audio/wav_clip.dart`) to slice out just the speech segment
/// before anything is sent anywhere.
abstract class AudioSegmentRecorder {
  /// Begins capturing to 16kHz mono WAV. Every failure mode (denied mic
  /// permission, no input device, platform error) is swallowed here — the
  /// visible effect is just that [stop] later returns null, same as any
  /// other "no hint this trial" outcome in this feature.
  Future<void> start();

  /// Stops capture and returns the whole window as 16kHz mono WAV bytes, or
  /// null if nothing was captured — including the case where [start] never
  /// actually began recording.
  Future<Uint8List?> stop();

  Future<void> dispose();
}

class MicAudioSegmentRecorder implements AudioSegmentRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// WAV (pcm16 + header) directly at the rate the hint API requires — see
  /// `remote_articulation_hint_service.dart`. Recording at this rate up
  /// front means `wav_clip.dart` only ever needs to trim, never resample.
  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  @override
  Future<void> start() async {
    _path = null;
    try {
      if (!await _recorder.hasPermission()) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/hint_clip_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(_config, path: path);
      _path = path;
    } catch (_) {
      // No mic, permission plumbing failed, platform error — leave _path
      // null, which stop() already treats as "nothing captured".
    }
  }

  @override
  Future<Uint8List?> stop() async {
    try {
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _path;
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      unawaited(_deleteQuietly(file));
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _path = null;
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } catch (_) {
      // Temp-directory cleanup only — a leftover file here is never worth
      // surfacing.
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
