import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/features/guardian/child_settings_screen.dart';

Widget _buildApp(String childId, InMemoryChildRepository repo) {
  return ProviderScope(
    overrides: [childRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: TemanKuTheme.guardian,
      home: ChildSettingsScreen(childId: childId),
    ),
  );
}

void main() {
  testWidgets('the toggle starts off, matching Child.pronunciationHintEnabled default', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
  });

  testWidgets('turning it on shows a consent dialog first; cancelling leaves it off and unsaved',
      (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // The consent copy — explicit about audio leaving the device for this
    // feature only, distinct from the app's normal on-device-only handling.
    expect(find.textContaining('server luar'), findsOneWidget);
    expect(find.textContaining('foto dan data lain'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isFalse);
  });

  testWidgets('confirming the consent dialog turns it on and persists via ChildRepository',
      (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isTrue);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isTrue);
  });

  testWidgets('turning it back off needs no confirmation dialog', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});
    await repo.updateChild(child.copyWith(pronunciationHintEnabled: true));

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // No dialog appeared, so the tap took effect immediately.
    expect(find.text('Batal'), findsNothing);
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isFalse);
  });
}
