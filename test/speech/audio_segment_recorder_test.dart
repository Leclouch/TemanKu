import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/speech/audio_segment_recorder.dart';

/// The `record` plugin's method channel. Mocked here rather than left
/// unregistered: an unregistered channel makes the plugin's own internal,
/// un-awaited setup future reject as an *unhandled* zone error before this
/// test's own `try`/`catch` paths ever get a chance at it — a Dart Future
/// timing quirk, not something `AudioSegmentRecorder` can or should guard
/// against. Mocking `hasPermission` to return false instead exercises the
/// realistic case this class exists to survive: a guardian declines the mic
/// permission prompt.
const _channel = MethodChannel('com.llfbandit.record/messages');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async {
        switch (call.method) {
          case 'hasPermission':
            return false;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  });

  test('a denied mic permission makes start() a no-op and stop() reports "nothing captured"',
      () async {
    final recorder = MicAudioSegmentRecorder();

    await recorder.start();
    final clip = await recorder.stop();

    expect(clip, isNull);

    await recorder.dispose();
  });

  test('stop() without a preceding start() also returns null rather than throwing', () async {
    final recorder = MicAudioSegmentRecorder();
    final clip = await recorder.stop();
    expect(clip, isNull);
    await recorder.dispose();
  });
}
