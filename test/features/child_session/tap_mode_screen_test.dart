import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/features/child_session/tap_mode_screen.dart';
import 'package:temanku/widgets/answer_target.dart';
import 'package:temanku/widgets/exit_dot.dart';
import 'package:temanku/widgets/mastery_closure_prompt.dart';
import 'package:temanku/widgets/photo_image.dart';

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

/// One target plus three distractors — enough for an arraySize-4 trial, the
/// ceiling scenario tests below need.
InMemoryPhotoRepository _seedFourPhotos() {
  final repo = InMemoryPhotoRepository(seed: false);
  repo.addPhoto(
    childId: _childId,
    module: _module,
    localPath: '/fake/target.jpg',
    category: PhotoCategory.target,
    label: 'target_item',
  );
  for (final label in ['distractor_1', 'distractor_2', 'distractor_3']) {
    repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/$label.jpg',
      category: PhotoCategory.distractor,
      label: label,
    );
  }
  return repo;
}

/// Two targets plus three distractors: the smallest own-photo library that
/// composes an extended LRFFC array-five tap trial.
InMemoryPhotoRepository _seedFivePhotos() {
  final repo = InMemoryPhotoRepository(seed: false);
  for (final label in ['target_one', 'target_two']) {
    repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/$label.jpg',
      category: PhotoCategory.target,
      label: label,
    );
  }
  for (final label in ['distractor_1', 'distractor_2', 'distractor_3']) {
    repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/$label.jpg',
      category: PhotoCategory.distractor,
      label: label,
    );
  }
  return repo;
}

/// Seeds a child already sitting at the dial engine's ceiling (arraySize 4,
/// lrffc tier) with the streak already one response short of clearing again
/// — the setup every mastery-at-ceiling test below shares, so only the
/// screen's own tap has to fire the criterion.
Future<AdvancementTracker> _primeAtCeiling(
    InMemoryChildRepository childRepo) async {
  final persistence = LadderPersistence(childRepo);
  await persistence.save(
    childId: _childId,
    module: _module,
    mode: ResponseMode.tap,
    position: const LadderPosition(
        arraySize: 4, similarityTier: SimilarityTier.lrffc),
  );
  final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(), persistence: persistence);
  for (var i = 0; i < requiredStreakForAdvancement - 1; i++) {
    await tracker.recordResponse(
      childId: _childId,
      module: _module,
      mode: ResponseMode.tap,
      correct: true,
      hintShown: false,
    );
  }
  return tracker;
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
        builder: (context, state) =>
            const TapModeScreen(childId: _childId, module: _module),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(childRepo),
      photoRepositoryProvider.overrideWithValue(photoRepo),
      if (tracker != null)
        advancementTrackerProvider.overrideWithValue(tracker),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders the instruction and one tappable answer target per item',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();

    await tester.pumpWidget(
        _buildDirectApp(childRepo: childRepo, photoRepo: photoRepo));
    await tester.pumpAndSettle();

    // LadderPosition.start() → arraySize 2 → exactly the two seeded photos,
    // one target-category item and one distractor-category item.
    expect(find.byType(PhotoImage), findsNWidgets(2));
    expect(find.text('target_item'), findsOneWidget);
    expect(find.text('distractor_item'), findsOneWidget);
    expect(find.textContaining('tunjuk'), findsOneWidget);
  });

  testWidgets(
      'the target and distractor answer cards render with identical chrome — no colour or '
      'shape gives the answer away before the child looks at the photo',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();

    await tester.pumpWidget(
        _buildDirectApp(childRepo: childRepo, photoRepo: photoRepo));
    await tester.pumpAndSettle();

    // AnswerTarget is `match_mode_screen.dart`'s zone widget — it paints
    // `ModuleDefinition.targetStyle`/`distractorStyle` colour+shape, which is
    // correct for a drop zone (the zone *is* the category label) but was a
    // giveaway here, where the tapped card itself is the answer. Its absence
    // is the direct regression guard for that fix — see `_AnswerItem`'s own
    // doc comment in `tap_mode_screen.dart`.
    expect(find.byType(AnswerTarget), findsNothing);

    Color? fillColorFor(String label) {
      final container = tester
          .widgetList<Container>(
            find.descendant(
                of: _answerItemFor(label), matching: find.byType(Container)),
          )
          .firstWhere((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color != null);
      return ((container.decoration!) as BoxDecoration).color;
    }

    final targetFill = fillColorFor('target_item');
    final distractorFill = fillColorFor('distractor_item');
    expect(targetFill, isNotNull);
    // The whole point: the target photo's card and the distractor photo's
    // card are painted in exactly the same colour, so a child can't tell
    // them apart without looking at the photo itself.
    expect(targetFill, equals(distractorFill));
  });

  testWidgets(
      'tapping the target item advances the streak and composes a new trial',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(_buildDirectApp(
        childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    await tester.tap(_answerItemFor('target_item'));
    // The 500ms feedback beat before the next trial replaces this one.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(
        tracker.streakFor(
            childId: _childId, module: _module, mode: ResponseMode.tap),
        1);
    // A new trial composed from the same two-photo library — still exactly
    // one tappable target per item.
    expect(find.byType(PhotoImage), findsNWidgets(2));
  });

  testWidgets('tapping the distractor item does not advance the streak',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();
    final tracker = AdvancementTracker(
      dialEngine: const TwoDialEngine(),
      persistence: LadderPersistence(childRepo),
    );

    await tester.pumpWidget(_buildDirectApp(
        childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    await tester.tap(_answerItemFor('distractor_item'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(
        tracker.streakFor(
            childId: _childId, module: _module, mode: ResponseMode.tap),
        0);
  });

  testWidgets(
      'an array-five trial keeps a found target while a wrong tap awaits the second target',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final persistence = LadderPersistence(childRepo);
    await persistence.save(
      childId: _childId,
      module: _module,
      mode: ResponseMode.tap,
      position: const LadderPosition(
          arraySize: 5, similarityTier: SimilarityTier.lrffc),
    );
    final tracker = AdvancementTracker(
        dialEngine: const TwoDialEngine(), persistence: persistence);

    await tester.pumpWidget(
      _buildDirectApp(
          childRepo: childRepo, photoRepo: _seedFivePhotos(), tracker: tracker),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhotoImage), findsNWidgets(5));

    await tester.tap(_answerItemFor('target_one'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // A correct target is a persistent, non-interactive success, not a
    // completed trial. Removing the `found` branch would make this tappable.
    expect(tester.widget<InkWell>(_answerItemFor('target_one')).onTap, isNull);
    expect(
        tracker.streakFor(
            childId: _childId, module: _module, mode: ResponseMode.tap),
        1);

    await tester.tap(_answerItemFor('distractor_1'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // The miss is recorded, but it cannot replace the two-target trial or
    // unlock the first target before the remaining target is found.
    expect(
        tracker.streakFor(
            childId: _childId, module: _module, mode: ResponseMode.tap),
        0);
    expect(tester.widget<InkWell>(_answerItemFor('target_one')).onTap, isNull);
    expect(
        tester.widget<InkWell>(_answerItemFor('target_two')).onTap, isNotNull);

    await tester.tap(_answerItemFor('target_two'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Only the second target resolves the trial: a newly composed board has
    // no carried-over locked target, and that final response is recorded too.
    expect(
        tester.widget<InkWell>(_answerItemFor('target_one')).onTap, isNotNull);
    expect(
        tester.widget<InkWell>(_answerItemFor('target_two')).onTap, isNotNull);
    expect(
        tracker.streakFor(
            childId: _childId, module: _module, mode: ResponseMode.tap),
        1);
  });

  testWidgets('the exit dot pops the session route', (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedPhotos();

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(
            path: Routes.guardianHome,
            builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/tap',
          builder: (context, state) =>
              const TapModeScreen(childId: _childId, module: _module),
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

  testWidgets(
      'clearing the streak while already at the ceiling offers Lanjutkan/Selesai, '
      'and Selesai ends the session like the exit dot does', (tester) async {
    // arraySize 4 at the ceiling needs more vertical room than the default
    // test surface — a pre-existing layout limit unrelated to this feature,
    // just never exercised by a prior test (every other test here stays at
    // arraySize 2).
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedFourPhotos();
    final tracker = await _primeAtCeiling(childRepo);

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(
            path: Routes.guardianHome,
            builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/tap',
          builder: (context, state) =>
              const TapModeScreen(childId: _childId, module: _module),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          childRepositoryProvider.overrideWithValue(childRepo),
          photoRepositoryProvider.overrideWithValue(photoRepo),
          advancementTrackerProvider.overrideWithValue(tracker),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/tap');
    await tester.pumpAndSettle();

    // One more correct, unhinted tap clears the streak for the second time
    // at this same ceiling position — mastery-at-ceiling, not merely
    // reaching it.
    await tester.tap(_answerItemFor('target_item'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });

  testWidgets(
      'Lanjutkan dismisses the prompt and keeps the session going at the ceiling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final photoRepo = _seedFivePhotos();
    final tracker = await _primeAtCeiling(childRepo);

    await tester.pumpWidget(_buildDirectApp(
        childRepo: childRepo, photoRepo: photoRepo, tracker: tracker));
    await tester.pumpAndSettle();

    final firstTarget = find.text('target_one').evaluate().isNotEmpty
        ? 'target_one'
        : 'target_two';
    await tester.tap(_answerItemFor(firstTarget));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Lanjutkan'), findsOneWidget);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    // Prompt gone, a fresh trial composed — still arraySize 4 at the ceiling,
    // never a new screen.
    expect(find.text('Lanjutkan'), findsNothing);
    expect(find.byType(TapModeScreen), findsOneWidget);
    expect(find.byType(PhotoImage), findsNWidgets(5));
  });

  testWidgets(
      'a natural-pause prompt fires every naturalPauseTrialInterval trials even when the '
      'child never reaches the dial engine\'s ceiling, and Selesai ends the session',
      (tester) async {
    final childRepo = InMemoryChildRepository(seed: false);
    await childRepo
        .createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    // Only two photos → arraySize can never grow past 2, and every tap below
    // is on the distractor, so the streak never clears and the position
    // never moves off `LadderPosition.start()` — nowhere near the ceiling,
    // by construction. If a closure prompt still appears, it can only be
    // the periodic one, not `showMasteryClosurePrompt`.
    final photoRepo = _seedPhotos();

    final router = GoRouter(
      initialLocation: Routes.guardianFor(_childId),
      routes: [
        GoRoute(
            path: Routes.guardianHome,
            builder: (context, state) => const Text('guardian-home')),
        GoRoute(
          path: '/tap',
          builder: (context, state) =>
              const TapModeScreen(childId: _childId, module: _module),
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
    router.push('/tap');
    await tester.pumpAndSettle();

    for (var i = 0; i < naturalPauseTrialInterval - 1; i++) {
      await tester.tap(_answerItemFor('distractor_item'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Titik berhenti alami'), findsNothing);
    }

    await tester.tap(_answerItemFor('distractor_item'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Titik berhenti alami'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('guardian-home'), findsOneWidget);
  });
}
