import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/features/onboarding/intake_screen.dart';

const _confirmationCopy =
    'Kami akan mulai dari sini, dan menyesuaikan setelah beberapa sesi bersama.';

/// A scoped router with just the two routes this flow needs, rather than the
/// app's shared global `appRouter` singleton — go_router's routing state
/// lives on that instance, so reusing it across tests would leak navigation
/// state between them. See `photo_upload_screen_test.dart` for the sibling
/// pattern of testing a routed screen without the shared router at all; this
/// screen needs one because it calls `context.go` itself on completion.
Widget _buildApp({required String childId, required ChildRepository repository}) {
  final router = GoRouter(
    initialLocation: Routes.intakeFor(childId),
    routes: [
      GoRoute(
        path: Routes.intake,
        builder: (context, state) =>
            IntakeScreen(childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: Routes.guardianHome,
        builder: (context, state) =>
            Text('guardian-home:${state.pathParameters['childId']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [childRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: TemanKuTheme.guardian, routerConfig: router),
  );
}

Future<void> _answer(WidgetTester tester, String optionLabel) async {
  await tester.tap(find.text(optionLabel));
  await tester.pumpAndSettle();
}

Future<void> _tapNext(WidgetTester tester, {String label = 'Lanjut'}) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'answering all four questions saves modes + diagnosis status and shows the confirmation copy',
      (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    await _answer(tester, 'Ya, biasanya bisa'); // tap
    await _tapNext(tester);
    await _answer(tester, 'Kadang-kadang'); // match
    await _tapNext(tester);
    await _answer(tester, 'Belum'); // speak — excluded
    await _tapNext(tester);
    await _answer(tester, 'Sudah'); // diagnosis
    await _tapNext(tester, label: 'Selesai isi intake');

    expect(find.text(_confirmationCopy), findsOneWidget);
    expect(find.textContaining('level', findRichText: true), findsNothing);
    expect(find.textContaining('skor', findRichText: true), findsNothing);

    final saved = await repository.getChild(child.id);
    expect(saved!.availableModes, {ResponseMode.tap, ResponseMode.match});
    expect(saved.diagnosisStatus, DiagnosisStatus.diagnosed);
  });

  testWidgets('answering "Belum" to all three mode questions saves an empty mode set',
      (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    await _answer(tester, 'Belum');
    await _tapNext(tester);
    await _answer(tester, 'Belum');
    await _tapNext(tester);
    await _answer(tester, 'Belum');
    await _tapNext(tester);
    await _answer(tester, 'Saya tidak yakin');
    await _tapNext(tester, label: 'Selesai isi intake');

    final saved = await repository.getChild(child.id);
    expect(saved!.availableModes, isEmpty);
    expect(saved.diagnosisStatus, DiagnosisStatus.unsure);
  });

  testWidgets('the Lanjut button stays disabled until an option is picked', (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    final lanjutButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'));
    expect(lanjutButton.onPressed, isNull);

    await _answer(tester, 'Ya, biasanya bisa');

    final enabledButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'));
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('Kembali returns to the previous question with its answer still selected',
      (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    await _answer(tester, 'Kadang-kadang');
    await _tapNext(tester);
    expect(find.text('Bisakah ia mencocokkan dua gambar yang sama persis?'), findsOneWidget);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    expect(
      find.text('Kalau kamu sebutkan nama benda yang ia kenal, apakah ia bisa menunjuk '
          'atau mengetuk benda itu?'),
      findsOneWidget,
    );
    final selectedIcon = tester.widgetList<Icon>(find.byIcon(Icons.radio_button_checked));
    expect(selectedIcon, hasLength(1));
  });

  testWidgets('completing intake navigates back to guardian home', (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    for (final label in ['Ya, biasanya bisa', 'Ya, biasanya bisa', 'Ya, biasanya bisa']) {
      await _answer(tester, label);
      await _tapNext(tester);
    }
    await _answer(tester, 'Belum');
    await _tapNext(tester, label: 'Selesai isi intake');
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home:${child.id}'), findsOneWidget);
  });

  testWidgets(
      'a mode newly enabled by intake still starts at LadderPosition.start on first session',
      (tester) async {
    // §4.5/§6 of the task brief: intake never sets a starting difficulty.
    // This is true by construction (ladder_persistence.dart falls through to
    // LadderPosition.start for anything with no stored position) — this test
    // exists to catch a future regression, not because intake_screen.dart
    // does anything special to make it true.
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(name: 'Sari', availableModes: {});

    await tester.pumpWidget(_buildApp(childId: child.id, repository: repository));
    await tester.pumpAndSettle();

    await _answer(tester, 'Belum');
    await _tapNext(tester);
    await _answer(tester, 'Belum');
    await _tapNext(tester);
    await _answer(tester, 'Ya, biasanya bisa'); // speak newly enabled
    await _tapNext(tester);
    await _answer(tester, 'Belum');
    await _tapNext(tester, label: 'Selesai isi intake');

    final position = await repository.getLadderPosition(
      childId: child.id,
      module: ModuleId.makanan,
      mode: ResponseMode.speak,
    );
    expect(position, const LadderPosition.start());
  });
}
