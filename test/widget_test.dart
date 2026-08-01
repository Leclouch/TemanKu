import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temanku/app.dart';

/// Smoke test — the lowest-priority tier per the architecture doc, kept to one
/// case on purpose. It exists to prove the composition root actually boots:
/// ProviderScope → service_locator bindings → go_router → first screen.
///
/// If this breaks, something structural broke. It is not a UI regression test,
/// and it should not grow into one — assert on wiring, not on layout.
void main() {
  testWidgets('app boots to the select-child screen with the seeded child',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TemanKuApp()));
    await tester.pumpAndSettle();

    // Comes from InMemoryChildRepository's seed via childRepositoryProvider.
    expect(find.text('Arif'), findsOneWidget);
  });
}
