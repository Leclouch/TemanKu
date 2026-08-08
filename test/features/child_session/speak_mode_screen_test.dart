import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/features/child_session/speak_mode_screen.dart';
import 'package:temanku/speech/tts/word_audio_service.dart';
import 'package:temanku/speech/vad_service.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';

const _childId = 'child_1';
const _module = ModuleId.makanan;

/// A [WordAudioService] whose [speak] hangs until [release] is called — lets
/// a test hold the screen in its "model still speaking" window on demand,
/// the same window a real network-bound `EdgeTtsSource` fetch sits in for
/// however long that takes in the field.
class _GatedWordAudioService implements WordAudioService {
  final _gate = Completer<bool>();
  int speakCalls = 0;

  @override
  Future<bool> speak(String word) {
    speakCalls++;
    return _gate.future;
  }

  void release() {
    if (!_gate.isCompleted) _gate.complete(true);
  }

  @override
  Future<void> prefetch(String word) async {}

  @override
  Future<void> dispose() async {}
}

/// Fully controllable [VadService] fake — resolves [listenForUtterance]
/// with whatever [nextEvent] is set to, instantly (no real audio, no real
/// timers), so tests don't depend on Silero/fallback timing at all.
class _FakeVad implements VadService {
  _FakeVad({this.providesAutomaticSilenceDetection = true});

  @override
  final bool providesAutomaticSilenceDetection;

  SpeechEvent nextEvent = const SpeechEvent(spoke: true);
  int listenCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<SpeechEvent> listenForUtterance({Duration timeout = const Duration(seconds: 10)}) async {
    listenCalls++;
    return nextEvent;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

InMemoryPhotoRepository _seedPhotos() {
  final repo = InMemoryPhotoRepository(seed: false);
  repo.addPhoto(
    childId: _childId,
    module: _module,
    localPath: '/fake/target.jpg',
    category: PhotoCategory.target,
    label: 'target_item',
  );
  return repo;
}

Widget _buildDirectApp({
  required InMemoryChildRepository childRepo,
  required InMemoryPhotoRepository photoRepo,
  required _FakeVad vad,
  AdvancementTracker? tracker,
  WordAudioService? wordAudio,
}) {
  final router = GoRouter(
    initialLocation: '/speak',
    routes: [
      GoRoute(
        path: '/speak',
        builder: (context, state) => const SpeakModeScreen(childId: _childId, module: _module),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(childRepo),
      photoRepositoryProvider.overrideWithValue(photoRepo),
      vadServiceProvider.overrideWithValue(vad),
      if (tracker != null) advancementTrackerProvider.overrideWithValue(tracker),
      // Speak mode reads this keyed on `Child.pronunciationHintEnabled` —
      // both `true` and `false` are overridden so the test doesn't have to
      // track which one the seeded child actually resolves to.
      if (wordAudio != null) ...[
        wordAudioServiceProvider(true).overrideWithValue(wordAudio),
        wordAudioServiceProvider(false).overrideWithValue(wordAudio),
      ],
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders the instruction and the single stimulus — no array (§4.4)', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad()..nextEvent = const SpeechEvent(spoke: true);

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, vad: vad));
    await tester.pumpAndSettle();

    expect(find.byType(AnswerTarget), findsOneWidget);
    expect(find.textContaining('ucapkan'), findsOneWidget);
    expect(find.text('target_item'), findsOneWidget);
  });

  testWidgets('the guardian tapping ✅ advances the streak and composes a new trial', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad()..nextEvent = const SpeechEvent(spoke: true);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(
      _buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, vad: vad, tracker: tracker),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Benar'));
    // The 500ms feedback beat before the next trial replaces this one.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 1);
    expect(find.byType(AnswerTarget), findsOneWidget);
  });

  testWidgets(
      'the judge cluster is disabled while the model is still speaking — regression test for '
      'the race where an early tap fires a second speak() onto the still-playing first one',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad()..nextEvent = const SpeechEvent(spoke: true);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );
    final wordAudio = _GatedWordAudioService();

    await tester.pumpWidget(
      _buildDirectApp(
        childRepo: childRepo,
        photoRepo: photoRepo,
        vad: vad,
        tracker: tracker,
        wordAudio: wordAudio,
      ),
    );
    // Deliberately not pumpAndSettle: `speak()` is gated and never resolves
    // on its own, so settling would hang. A few pumps are enough to get
    // through trial composition into the "speaking" window.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(wordAudio.speakCalls, 1);

    // The cluster is disabled — this tap must be a no-op, not a second
    // speak() call and not a streak change.
    await tester.tap(find.bySemanticsLabel('Benar'), warnIfMissed: false);
    await tester.pump();
    expect(wordAudio.speakCalls, 1);
    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 0);

    // Now let the model finish "speaking" — VAD resolves instantly (spoke:
    // true), so the cluster becomes tappable and a real tap advances things
    // exactly once.
    wordAudio.release();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Benar'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 1);
    // Exactly one more speak() call for the one new trial composed above —
    // never two, which is what the race used to produce.
    expect(wordAudio.speakCalls, 2);
  });

  testWidgets('the guardian tapping "coba lagi" does not advance the streak', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad()..nextEvent = const SpeechEvent(spoke: true);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(
      _buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, vad: vad, tracker: tracker),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Coba lagi'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 0);
  });

  testWidgets(
      'with automatic silence detection, the two-button cluster is shown and silence '
      'auto-advances as notAttempted after the guardian-override window', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad(providesAutomaticSilenceDetection: true)
      ..nextEvent = const SpeechEvent(spoke: true);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(
      _buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, vad: vad, tracker: tracker),
    );
    await tester.pumpAndSettle();

    // Automatic detection is live — no third button.
    expect(find.bySemanticsLabel('Tidak mencoba'), findsNothing);

    // Build a streak of 1 first, so the reset below is actually observable.
    // The next trial's own _listen() call fires synchronously once judging
    // settles, so nextEvent must already read "silence" before that happens
    // — set it right after the tap, before pumping the settle beat forward.
    await tester.tap(find.bySemanticsLabel('Benar'));
    vad.nextEvent = const SpeechEvent(spoke: false);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 1);

    // The trial now on screen already resolved VAD as silence — with
    // automatic detection, this auto-flags notAttempted after the
    // guardian-override delay, without any tap.
    await tester.pump(const Duration(milliseconds: 1900)); // past _autoAdvanceDelay
    await tester.pump(const Duration(milliseconds: 600)); // the settle beat after judging
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.speak), 0);
  });

  testWidgets('without automatic silence detection, the three-button cluster is shown '
      'and nothing auto-advances', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad(providesAutomaticSilenceDetection: false)
      ..nextEvent = const SpeechEvent(spoke: false); // the fallback's only possible event

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, vad: vad));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Benar'), findsOneWidget);
    expect(find.bySemanticsLabel('Coba lagi'), findsOneWidget);
    expect(find.bySemanticsLabel('Tidak mencoba'), findsOneWidget);

    // No auto-flag possible from the fallback — waiting well past the
    // guardian-override delay must change nothing.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.bySemanticsLabel('Benar'), findsOneWidget);
  });

  testWidgets('the exit dot pops the session route', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final photoRepo = _seedPhotos();
    final vad = _FakeVad()..nextEvent = const SpeechEvent(spoke: true);

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(path: Routes.guardianHome, builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/speak',
          builder: (context, state) => const SpeakModeScreen(childId: _childId, module: _module),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          childRepositoryProvider.overrideWithValue(childRepo),
          photoRepositoryProvider.overrideWithValue(photoRepo),
          vadServiceProvider.overrideWithValue(vad),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsOneWidget);

    router.push('/speak');
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsNothing);

    await tester.tap(find.byType(ExitDot));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });
}
