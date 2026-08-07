import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/tflite_classifier.dart';

/// Contract tests for [TfliteClassifier], scoped to what is verifiable
/// without either (a) real trained-distribution sample photos or (b) a
/// working native TFLite runtime in this environment.
///
/// Neither exists in this sandbox: `tflite_flutter`'s Windows desktop native
/// library isn't auto-bundled — it requires a one-time manual drop into the
/// Flutter SDK's own engine-cache folder, a change to the shared SDK install
/// rather than to this repo — and no real photos of the trained categories
/// (pisang, apel, etc.) exist here to assert confidence-threshold behaviour
/// against honestly.
///
/// What *is* fully verifiable here, on every platform, is the load-bearing
/// safety contract: this class must never let a raw exception escape, at any
/// stage — load failure, an uninitialized model, or inference failure all
/// degrade to the same null result [ManualLabelClassifier] always produces,
/// which the upload flow already reads as "ask the guardian" (a normal
/// outcome, not an error).
///
/// TODO: once real sample photos exist under test/assets/ (or this suite
/// runs somewhere `tflite_flutter`'s native library is actually available —
/// e.g. an Android emulator, or this machine with the DLL manually
/// installed), add the confidence-threshold assertions the task brief calls
/// for: a known-category photo returns its label above
/// [classifierConfidenceThreshold], and an off-category photo returns null.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TfliteClassifier — graceful degradation', () {
    test('Keluarga always returns null, regardless of model state', () async {
      final classifier = TfliteClassifier();
      addTearDown(classifier.dispose);

      // Deliberately not calling initialize() first — the Keluarga guard
      // must short-circuit before ever touching the model (§5.3: no face
      // model, permanently).
      final suggestion = await classifier.suggestLabel(
        imagePath: '/does/not/exist.jpg',
        module: ModuleId.keluarga,
      );
      expect(suggestion, isNull);
    });

    test('an uninitialized classifier returns null instead of throwing', () async {
      final classifier = TfliteClassifier();
      addTearDown(classifier.dispose);

      // initialize() was never called — suggestLabel must not assume it was.
      final suggestion = await classifier.suggestLabel(
        imagePath: '/does/not/exist.jpg',
        module: ModuleId.makanan,
      );
      expect(suggestion, isNull);
    });

    test('initialize() never throws, even when the model fails to load', () async {
      final classifier = TfliteClassifier();
      addTearDown(classifier.dispose);

      // In this environment the native TFLite library isn't available (see
      // file doc comment), so this genuinely exercises the load-failure
      // path — the same path a corrupted or missing asset would hit on any
      // platform. The assertion is simply that this completes without
      // throwing; `expect(..., throwsA(...))`'s absence here is the point.
      await classifier.initialize();
    });

    test(
        'suggestLabel degrades to null rather than throwing, even after '
        'initialize() and against a path that cannot be decoded', () async {
      final classifier = TfliteClassifier();
      addTearDown(classifier.dispose);

      await classifier.initialize();
      final suggestion = await classifier.suggestLabel(
        imagePath: '/does/not/exist.jpg',
        module: ModuleId.makanan,
      );
      // Whichever internal path this hits — model unavailable in this
      // environment, or a decode failure against a path that doesn't exist —
      // it must degrade to null, never an uncaught exception.
      expect(suggestion, isNull);
    });

    test('dispose() is safe without ever initializing, and safe to call twice', () async {
      final classifier = TfliteClassifier();
      await classifier.dispose();
      await classifier.dispose();
    });
  });
}
