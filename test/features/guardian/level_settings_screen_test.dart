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
