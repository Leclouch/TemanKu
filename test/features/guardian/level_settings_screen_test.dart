import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/features/guardian/level_settings_screen.dart';

Widget _buildApp({
  required String childId,
  required InMemoryChildRepository repository,
  required LadderPersistence persistence,
  required AdvancementTracker tracker,
}) {
  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(repository),
      ladderPersistenceProvider.overrideWithValue(persistence),
      advancementTrackerProvider.overrideWithValue(tracker),
    ],
    child: MaterialApp(
      theme: TemanKuTheme.guardian,
      home: LevelSettingsScreen(childId: childId),
    ),
  );
}

void main() {
  testWidgets('groups each module in a collapsed dropdown', (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.tap},
    );
    final persistence = LadderPersistence(repository);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );

    await tester.pumpWidget(
      _buildApp(
        childId: child.id,
        repository: repository,
        persistence: persistence,
        tracker: tracker,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('Keluarga'), findsOneWidget);
    expect(find.text('Tahap 1'), findsNothing);

    await tester.tap(find.text('Makanan'));
    await tester.pumpAndSettle();

    expect(find.text('Tahap 1'), findsOneWidget);
    // Only one mode available for this child — nothing to choose between, so
    // no mode selector at all (see _ModuleLevelDropdown's own doc comment).
    expect(find.text('Mode aktif untuk modul ini:'), findsNothing);
  });

  testWidgets(
      'a child with more than one available mode shows a mode selector, and picking one '
      'persists immediately with no Terapkan tap needed', (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.tap, ResponseMode.match},
    );
    final persistence = LadderPersistence(repository);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );

    await tester.pumpWidget(
      _buildApp(
        childId: child.id,
        repository: repository,
        persistence: persistence,
        tracker: tracker,
      ),
    );
    await tester.pumpAndSettle();

    // Visible without expanding the ExpansionTile at all — the mode
    // selector sits above it in the same card, by design (the guardian
    // shouldn't need to open the level detail just to switch modes). Both
    // Makanan and Keluarga show their own selector, since `availableModes`
    // is child-wide rather than per-module, so scope every finder to the
    // Keluarga card specifically to avoid ambiguity with Makanan's copy.
    final keluargaCard = find.ancestor(
      of: find.text('Keluarga'),
      matching: find.byType(TkCard),
    );
    // No override yet — priority order means tap ("Ketuk") is the resolved
    // active mode, same as `day_arc_screen.dart` would route into.
    expect(
      find.descendant(of: keluargaCard, matching: find.text('Mode aktif untuk modul ini:')),
      findsOneWidget,
    );
    expect(find.descendant(of: keluargaCard, matching: find.text('Ketuk')), findsOneWidget);
    expect(find.descendant(of: keluargaCard, matching: find.text('Seret')), findsOneWidget);

    final seretTile = find.descendant(of: keluargaCard, matching: find.text('Seret'));
    await tester.ensureVisible(seretTile);
    await tester.tap(seretTile);
    await tester.pumpAndSettle();

    final reloaded = await repository.getChild(child.id);
    expect(reloaded!.activeModeByModule, {ModuleId.keluarga: ResponseMode.match});
    // Makanan was never touched — its own selector, if opened, would still
    // resolve to the priority-order fallback rather than inheriting this pick.
    expect(reloaded.activeModeByModule.containsKey(ModuleId.makanan), isFalse);
  });

  testWidgets(
      'applying a different step persists it and clears only that block streak',
      (tester) async {
    final repository = InMemoryChildRepository(seed: false);
    final child = await repository.createChild(
      name: 'Arif',
      availableModes: {ResponseMode.tap},
    );
    final persistence = LadderPersistence(repository);
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: persistence,
    );
    await tracker.recordResponse(
      childId: child.id,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      correct: true,
      hintShown: false,
    );
    await tracker.recordResponse(
      childId: child.id,
      module: ModuleId.keluarga,
      mode: ResponseMode.tap,
      correct: true,
      hintShown: false,
    );

    await tester.pumpWidget(
      _buildApp(
        childId: child.id,
        repository: repository,
        persistence: persistence,
        tracker: tracker,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tahap 2').first);
    await tester.ensureVisible(find.text('Terapkan').first);
    await tester.tap(find.text('Terapkan').first);
    await tester.pumpAndSettle();

    expect(
      await repository.getLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      ),
      const LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.differentCategory,
      ),
    );
    expect(
      tracker.streakFor(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      ),
      0,
    );
    expect(
      tracker.streakFor(
        childId: child.id,
        module: ModuleId.keluarga,
        mode: ResponseMode.tap,
      ),
      1,
    );
  });
}
