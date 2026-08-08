import 'dart:typed_data';

import 'package:temanku/speech/tts/word_audio_service.dart';

WordAudioSource createWordAudioSource() => const _NullWordAudioSource();

/// Web has no `EdgeTtsSource` (see `word_audio_source_impl.dart`) — this
/// degrades exactly like a failed fetch always has: [WordAudioService.speak]
/// resolves false, no audio plays, and the trial proceeds unmodelled. The
/// guardian can always say the word themselves; see `word_audio_service.dart`.
class _NullWordAudioSource implements WordAudioSource {
  const _NullWordAudioSource();

  @override
  Future<Uint8List?> fetch(String word) async => null;
}
