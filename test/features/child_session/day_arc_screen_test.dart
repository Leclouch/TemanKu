import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/features/child_session/day_arc_screen.dart';
import 'package:temanku/widgets/exit_dot.dart';

const _kantinFraming = 'Yuk lihat jajanan di kantin';
const _rumahFraming = 'Sekarang waktunya sama keluarga';

/// A scoped router (not the shared `appRouter` singleton — its routing state
/// would leak between tests, see `intake_screen_test.dart`'s sibling
/// comment) with lightweight stub destinations at the exact tap/match/speak
/// paths `DayArcScreen` builds routes for. Using stubs here rather than the
/// real mode screens isolates what this test actually checks — *which*
/// route `DayArcScreen` picked — from needing seeded photos, a working VAD,
/// or any of the real screens' own setup.
///
/// [childId] must be whatever `InMemoryChildRepository.createChild` actually
/// returned — it mints its own id (`child_<n>_<name>`), never the caller's
/// guess, and `DayArcScreen` (unlike tap/match/speak) genuinely looks the
/// child up by id to read their name and modes, so a mismatched id here
/// silently renders the "profile not found" branch instead of the real one.
Widget _buildApp(InMemoryChildRepository childRepo, String childId) {
  final router = GoRouter(
    initialLocation: '/day-arc',
    routes: [
      GoRoute(
        path: '/day-arc',
        builder: (context, state) => DayArcScreen(childId: childId),
      ),
      GoRoute(
        path: Routes.tapSession,
        builder: (context, state) => Text('tap-screen:${state.pathParameters['module']}'),
      ),
      GoRoute(
        path: Routes.matchSession,
        builder: (context, state) => Text('match-screen:${state.pathParameters['module']}'),
      ),
      GoRoute(
        path: Routes.speakSession,
        builder: (context, state) => Text('speak-screen:${state.pathParameters['module']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [childRepositoryProvider.overrideWithValue(childRepo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the heading with the child\'s real name and both module cards, '
      'kantin before rumah', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(
      name: 'Sari',
      availableModes: {ResponseMode.tap, ResponseMode.match, ResponseMode.speak},
    );

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    // Exact match, not `textContaining` — the mascot's story-beat line
    // (`lib/story/`, on by the offline default `NoStorytellerService`) also
    // mentions the child's name in a full sentence, so a substring match now
    // finds two widgets. The headline itself is still a literal, findable
    // `Text(child.name)` (see `day_arc_screen.dart`'s own doc comment on why
    // that stayed a separate widget rather than a `TextSpan`).
    expect(find.text('Sari'), findsOneWidget);
    expect(find.text(_kantinFraming), findsOneWidget);
    expect(find.text(_rumahFraming), findsOneWidget);

    // Fixed order — kantin (Makanan) rendered above rumah (Keluarga).
    final kantinY = tester.getCenter(find.text(_kantinFraming)).dy;
    final rumahY = tester.getCenter(find.text(_rumahFraming)).dy;
    expect(kantinY, lessThan(rumahY));
  });

  testWidgets(
      'shows the four planned modules as dimmed cards below the two real doorways, '
      'each with no tap target at all', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Sari', availableModes: {ResponseMode.tap});

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    const plannedLabels = [
      'Uang',
      'Sampah',
      'Pengenalan Keamanan',
      'Pengenalan Orang Terpercaya',
    ];
    for (final label in plannedLabels) {
      expect(find.text(label), findsOneWidget);
    }
    // "Belum tersedia" appears once per planned card — never a badge object,
    // just the same caption-role text repeated (see `_PlaceholderModuleCard`).
    expect(find.text('Belum tersedia'), findsNWidgets(plannedLabels.length));

    // Unlike `_ModuleCard` (which stays wrapped in an `InkWell` even while
    // dimmed, since intake completion can make it tappable later), a planned
    // module never gets one — there is nothing behind it, ever, on this
    // screen. See `_PlaceholderModuleCard`'s own doc comment.
    for (final label in plannedLabels) {
      final ancestorInkWell = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(ancestorInkWell, findsNothing);
    }
  });

  testWidgets('a child with only tap enabled routes into tap mode for Makanan', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_kantinFraming));
    await tester.pumpAndSettle();

    expect(find.text('tap-screen:makanan'), findsOneWidget);
  });

  testWidgets('a child with tap AND match enabled prefers tap (tap→match→speak priority)',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.tap, ResponseMode.match},
    );

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_rumahFraming));
    await tester.pumpAndSettle();

    expect(find.text('tap-screen:keluarga'), findsOneWidget);
  });

  testWidgets('a child with tap excluded (match + speak enabled) never routes into tap — '
      'goes to match instead', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.match, ResponseMode.speak},
    );

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_kantinFraming));
    await tester.pumpAndSettle();

    expect(find.text('tap-screen:makanan'), findsNothing);
    expect(find.text('match-screen:makanan'), findsOneWidget);
  });

  testWidgets('a child with only speak enabled routes into speak mode, never tap or match',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_rumahFraming));
    await tester.pumpAndSettle();

    expect(find.text('speak-screen:keluarga'), findsOneWidget);
    expect(find.text('tap-screen:keluarga'), findsNothing);
    expect(find.text('match-screen:keluarga'), findsNothing);
  });

  testWidgets('a child with no modes enabled sees inert cards and an explanatory note — '
      'tapping navigates nowhere', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada mode yang aktif'), findsOneWidget);

    await tester.tap(find.text(_kantinFraming));
    await tester.pumpAndSettle();

    // Still on the day-arc screen — no stub destination appeared.
    expect(find.text(_kantinFraming), findsOneWidget);
    expect(find.text('tap-screen:makanan'), findsNothing);
  });

  testWidgets('no story-beat pill when Child.storytellerEnabled is false (the default)',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    expect(child.storytellerEnabled, isFalse);

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    // NoStorytellerService (the offline default) always has *something* it
    // could say — this asserts the day-arc screen never even asks it to,
    // per `_loadStoryBeat`'s own consent-gate comment. A regression here
    // would mean the guardian's "Cerita maskot" toggle stopped doing
    // anything until an API key also existed.
    expect(find.textContaining('petualangan'), findsNothing);
    expect(find.textContaining(child.name), findsOneWidget);
  });

  testWidgets('shows a mascot story-beat pill once the guardian opts in', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final created = await childRepo.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.tap},
    );
    final child = created.copyWith(storytellerEnabled: true);
    await childRepo.updateChild(child);

    await tester.pumpWidget(_buildApp(childRepo, child.id));
    await tester.pumpAndSettle();

    // Content comes from NoStorytellerService's own templates
    // (`lib/story/no_storyteller_service.dart`) — checking for "Arif"
    // appearing a second time (beyond the headline) is enough to prove the
    // pill rendered, without coupling this test to exact template wording.
    expect(find.textContaining(child.name), findsNWidgets(2));
  });

  testWidgets('the exit dot pops the session route', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});

    final router = GoRouter(
      initialLocation: Routes.guardianFor(child.id),
      routes: [
        GoRoute(path: Routes.guardianHome, builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/day-arc',
          builder: (context, state) => DayArcScreen(childId: child.id),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [childRepositoryProvider.overrideWithValue(childRepo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsOneWidget);

    router.push('/day-arc');
    await tester.pumpAndSettle();
    expect(find.text('guardian-home'), findsNothing);

    await tester.tap(find.byType(ExitDot));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });
}
