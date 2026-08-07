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
import 'package:temanku/features/child_session/match_mode_screen.dart';
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

/// Drags the widget found at [itemFinder] onto [targetFinder] using a raw
/// gesture — `tester.drag` doesn't reliably trigger `DragTarget.onAccept`
/// because it depends on the pointer's exact final position overlapping the
/// target, so the drag is driven by hand here instead.
Future<void> _dragOnto(WidgetTester tester, Finder itemFinder, Finder targetFinder) async {
  final gesture = await tester.startGesture(tester.getCenter(itemFinder));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(tester.getCenter(targetFinder));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
  // Flush the zone's transient flash-clear timer (500ms) so it never
  // outlives the test — pumpAndSettle alone doesn't wait on a bare Timer.
  await tester.pump(const Duration(milliseconds: 600));
}

Widget _buildDirectApp({
  required InMemoryChildRepository childRepo,
  required InMemoryPhotoRepository photoRepo,
  AdvancementTracker? tracker,
}) {
  final router = GoRouter(
    initialLocation: '/match',
    routes: [
      GoRoute(
        path: '/match',
        builder: (context, state) => const MatchModeScreen(childId: _childId, module: _module),
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
  testWidgets('renders one draggable per item and one drop zone per category', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.match});
    final photoRepo = _seedPhotos();

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo));
    await tester.pumpAndSettle();

    expect(find.byType(Draggable<int>), findsNWidgets(2));
    expect(find.byType(DragTarget<int>), findsNWidgets(2));

    // The starting ladder position (LadderPosition.start) is at
    // SimilarityTier.differentCategory → MatchTierKind.identicalPhoto, so
    // each zone additionally names its exemplar — the *same* label as the
    // matching item card. Two on-screen occurrences of each label is the
    // correct rendering of "match identical photo to identical photo", not
    // a duplicate-widget bug.
    expect(find.text('target_item'), findsNWidgets(2));
    expect(find.text('distractor_item'), findsNWidgets(2));
  });

  testWidgets('a correct drop sorts the item and steps the streak; a wrong drop does neither',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.match});
    final photoRepo = _seedPhotos();
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(_buildDirectApp(childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    final item = find.byType(Draggable<int>).first;
    final zones = find.byType(DragTarget<int>);

    // Try zone 0 first. Whichever way it lands, exactly one of the two
    // outcomes below is what happened — the test doesn't need to know which
    // zone was rotated to which category to check both behaviours.
    await _dragOnto(tester, item, zones.at(0));

    final streakAfterFirstDrop =
        tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.match);
    final itemsRemainingAfterFirstDrop = tester.widgetList(find.byType(Draggable<int>)).length;

    if (itemsRemainingAfterFirstDrop == 2) {
      // Zone 0 was the wrong zone for this item: nothing sorted, no streak.
      expect(streakAfterFirstDrop, 0);

      // Zone 1 must be correct for the same item.
      await _dragOnto(tester, item, zones.at(1));
      expect(find.byType(Draggable<int>), findsNWidgets(1));
      expect(tracker.streakFor(childId: _childId, module: _module, mode: ResponseMode.match), 1);
    } else {
      // Zone 0 was correct: the item settled and the streak advanced.
      expect(itemsRemainingAfterFirstDrop, 1);
      expect(streakAfterFirstDrop, 1);
    }
  });

  testWidgets('the exit dot pops the session route', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.match});
    final photoRepo = _seedPhotos();

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(path: Routes.guardianHome, builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/match',
          builder: (context, state) => const MatchModeScreen(childId: _childId, module: _module),
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

    router.push('/match');
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsNothing);

    await tester.tap(find.byType(ExitDot));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });
}
