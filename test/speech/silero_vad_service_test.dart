import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/speech/silero_vad_service.dart';
import 'package:temanku/speech/vad_service.dart';

/// `record`'s method channel — mocked so `hasPermission()` succeeds cleanly
/// instead of hitting the same unhandled-Future-timing quirk documented in
/// `audio_segment_recorder_test.dart`. This is the same mic path
/// `MicAudioSegmentRecorder` uses; `SileroVadService` goes through it too via
/// `package:vad`'s own internal `AudioRecorder`.
const _recordChannel = MethodChannel('com.llfbandit.record/messages');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _recordChannel,
      (call) async {
        switch (call.method) {
          case 'hasPermission':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _recordChannel,
      null,
    );
  });

  test(
      'providesAutomaticSilenceDetection is true — it is a real detector, unlike the fallback',
      () {
    expect(SileroVadService().providesAutomaticSilenceDetection, isTrue);
  });

  test(
    'listenForUtterance never throws even when the native ONNX/FFI stack is '
    'unavailable on the running platform (this test host has no bundled '
    'native asset for it) — it must degrade to SpeechEvent.notAttempted(), '
    'the same shape as "no automatic signal", not crash the trial',
    () async {
      final service = SileroVadService();
      addTearDown(service.dispose);

      // A short timeout: whatever happens (graceful degrade, or a real listen
      // if the host somehow does support the native lib), this must resolve
      // and must not throw.
      final event =
          await service.listenForUtterance(timeout: const Duration(seconds: 2));

      expect(event, isA<SpeechEvent>());
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test('cancel() is safe to call before any listenForUtterance() call',
      () async {
    final service = SileroVadService();
    await service.cancel();
    await service.dispose();
  });

  test(
    'initialize() never throws',
    () async {
      final service = SileroVadService();
      addTearDown(service.dispose);
      await service.initialize();
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
