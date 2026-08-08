import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/repositories/child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/features/onboarding/select_child_screen.dart';

/// A scoped router with just [Routes.selectChild] — the two new placeholder
/// cards never navigate anywhere, so nothing else needs a route; tapping a
/// real child's card isn't under test here.
Widget _buildApp({required ChildRepository repository}) {
  final router = GoRouter(
    initialLocation: Routes.selectChild,
    routes: [
      GoRoute(path: Routes.selectChild, builder: (context, state) => const SelectChildScreen()),
    ],
  );

  return ProviderScope(
    overrides: [childRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: TemanKuTheme.guardian, routerConfig: router),
  );
}

void main() {
  testWidgets(
      'shows two dimmed "Anak baru" placeholder slots alongside a real child, each with a '
      '"Belum tersedia" badge, and tapping one never navigates', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo.createChild(name: 'Sari', availableModes: {ResponseMode.tap});

    await tester.pumpWidget(_buildApp(repository: childRepo));
    await tester.pumpAndSettle();

    expect(find.text('Sari'), findsOneWidget);
    expect(find.text('Anak baru'), findsNWidgets(2));
    expect(find.text('Belum tersedia'), findsNWidgets(2));

    await tester.tap(find.text('Anak baru').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profil anak ini belum tersedia'), findsOneWidget);
    // Still on the select-child screen — no route change.
    expect(find.text('Sari'), findsOneWidget);
  });

  testWidgets('the two placeholder slots still show even with zero real profiles',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);

    await tester.pumpWidget(_buildApp(repository: childRepo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada profil anak'), findsOneWidget);
    expect(find.text('Anak baru'), findsNWidgets(2));
  });
}
