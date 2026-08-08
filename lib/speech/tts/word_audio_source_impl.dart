// Chooses the correct WordAudioSource implementation for the current
// platform — same pattern and same reason as
// `photo_pipeline/classifier_impl.dart`. `EdgeTtsSource` is built on
// `package:flutter_edge_tts`, which opens a raw `dart:io` WebSocket; that
// library is unavailable on web, so a web build needs a different (silent)
// implementation rather than a compile failure.
export 'word_audio_source_impl_io.dart' if (dart.library.html) 'word_audio_source_impl_web.dart';
