// Chooses the correct classifier implementation for the current platform.
// On web, `dart.library.html` is available and we export the web stub.
// On non-web (IO) platforms we export the native TFLite implementation.
export 'classifier_impl_io.dart'
    if (dart.library.html) 'classifier_impl_web.dart';
