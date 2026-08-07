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
import 'package:temanku/features/child_session/tap_mode_screen.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';

const _childId = 'child_1';
const _module = ModuleId.makanan;

InMemoryPhotoRepository _seedPhotos() {
  final repo = InMemoryPhotoRepository(seed: false);
  repo.addPhoto(
    childId: _childId,
    module: _module,
    localPath: '/fake/target.jpg',
    category: PhotoCategory.target,
    label: 'target_item',
  );
  repo.addPhoto(
    childId: _childId,
    module: _module,
    localPath: '/fake/distractor.jpg',
    category: PhotoCategory.distractor,
    label: 'distractor_item',
  );
  return repo;
}

/// The tappable answer item for [label] — the [InkWell] ancestor of its text,
/// so the tap lands on the actual gesture handler rather than relying on
/// implicit hit-test bubbling.
Finder _answerItemFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

Widget _buildDirectApp({
  required InMemoryChildRepository childRepo,
  required InMemoryPhotoRepository photoRepo,
  AdvancementTracker? tracker,
}) {
  final router = GoRouter(
    initialLocation: '/tap',
    routes: [
      GoRoute(
        path: '/tap',
        builder: (context, state) => const TapModeScreen(childId: _childId, module: _module),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(childRepo),
      photoRepositoryProvider.overrideWithValue(photoRepo),
      if (tracker != null) advancementTrackerProvider.overrideWithValue(tracker),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders the instruction and one tappable answer target per item', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo));
    await tester.pumpAndSettle();

    // LadderPosition.start() → arraySize 2 → exactly the two seeded photos,
    // one target-category item and one distractor-category item.
    expect(find.byType(AnswerTarget), findsNWidgets(2));
    expect(find.text('target_item'), findsOneWidget);
    expect(find.text('distractor_item'), findsOneWidget);
    expect(find.textContaining('tunjuk'), findsOneWidget);
  });

  testWidgets('tapping the target item advances the streak and composes a new trial',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    await tester.tap(_answerItemFor('target_item'));
    // The 500ms feedback beat before the next trial replaces this one.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.tap), 1);
    // A new trial composed from the same two-photo library — still exactly
    // one tappable target per item.
    expect(find.byType(AnswerTarget), findsNWidgets(2));
  });

  testWidgets('tapping the distractor item does not advance the streak', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    await tester.tap(_answerItemFor('distractor_item'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.tap), 0);
  });

  testWidgets('the exit dot pops the session route', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(path: Routes.guardianHome, builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/tap',
          builder: (context, state) => const TapModeScreen(childId: _childId, module: _module),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          childRepositoryProvider.overrideWithValue(childRepo),
          photoRepositoryProvider.overrideWithValue(photoRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsOneWidget);

    router.push('/tap');
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsNothing);

    await tester.tap(find.byType(ExitDot));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });
}
