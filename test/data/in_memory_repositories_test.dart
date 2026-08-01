import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_session_repository.dart';

/// `test/data/` — **IT-2's priority** (architecture doc: repository contract tests).
///
/// These cover the seeded fakes IT-1 develops against, plus the two behaviours
/// that are easy to get wrong and expensive to discover late: the frozen pause
/// timer, and the local-only trial log.
void main() {
  group('seeded fakes give IT-1 something to build against on day one', () {
    test('one child, both MVP modules, mid-ladder positions', () async {
      final repo = InMemoryChildRepository();
      addTearDown(repo.dispose);

      final children = await repo.listChildren();
      expect(children.length, 1);
      expect(children.single.name, 'Arif');

      final positions = await repo.getAllLadderPositions('child_arif');
      expect(positions.keys.map((k) => k.$1), contains(ModuleId.makanan));
      expect(positions.keys.map((k) => k.$1), contains(ModuleId.keluarga));
    });

    test('an unplayed module+mode still reads as the start position', () async {
      final repo = InMemoryChildRepository();
      addTearDown(repo.dispose);

      // Keluarga/speak was deliberately left out of the seed.
      final position = await repo.getLadderPosition(
        childId: 'child_arif',
        module: ModuleId.keluarga,
        mode: ResponseMode.speak,
      );
      expect(position, const LadderPosition.start());
    });

    test('photo library has both categories in both modules', () async {
      final repo = InMemoryPhotoRepository();
      addTearDown(repo.dispose);

      for (final module in ModuleId.values) {
        final counts = await repo.countByCategory(
          childId: 'child_arif',
          module: module,
        );
        expect(counts[PhotoCategory.target], greaterThan(0));
        expect(counts[PhotoCategory.distractor], greaterThan(0));
      }
    });

    test('Makanan meets the §5.4 variety target of five per category', () async {
      final repo = InMemoryPhotoRepository();
      addTearDown(repo.dispose);

      final counts = await repo.countByCategory(
        childId: 'child_arif',
        module: ModuleId.makanan,
      );
      // Soft nudge in the product, hard expectation in the fixture — the seed
      // should model a well-stocked library so array size 4 is composable.
      expect(counts[PhotoCategory.target], greaterThanOrEqualTo(5));
      expect(counts[PhotoCategory.distractor], greaterThanOrEqualTo(5));
    });
  });

  group('session lifecycle', () {
    test('pause freezes the timer; resume keeps the same session', () async {
      final repo = InMemorySessionRepository(seed: false);
      addTearDown(repo.dispose);

      final started = await repo.startSession(
        childId: 'child_arif',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );
      expect(started.status, SessionStatus.active);

      final paused = await repo.pauseSession(started.id);
      expect(paused.status, SessionStatus.paused);

      // §7: "progress saves, timer freezes for resume." Elapsed must not move
      // while paused, however long we wait.
      final frozen = paused.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final stillPaused = await repo.getActiveSession('child_arif');
      expect(stillPaused!.elapsed, frozen);

      final resumed = await repo.resumeSession(started.id);
      expect(resumed.status, SessionStatus.active);
      // Same session, not a new one.
      expect(resumed.id, started.id);
      expect(resumed.elapsed, frozen);
    });

    test('ending a session records a summary in history', () async {
      final repo = InMemorySessionRepository(seed: false);
      addTearDown(repo.dispose);

      final session = await repo.startSession(
        childId: 'child_arif',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );

      await repo.endSession(
        sessionId: session.id,
        summary: SessionSummary(
          sessionId: session.id,
          childId: 'child_arif',
          module: ModuleId.makanan,
          mode: ResponseMode.tap,
          duration: const Duration(minutes: 4),
          endedAt: DateTime(2026, 8, 1),
          ladderAtEnd: const LadderPosition.start(),
          observations: const ['Nyaman dengan kelompok kecil.'],
        ),
      );

      final history = await repo.getSessionHistory('child_arif');
      expect(history.length, 1);
      expect(history.single.observations, isNotEmpty);
      expect(await repo.getActiveSession('child_arif'), isNull);
    });

    test('trial logs are retrievable per session and stay out of the summary',
        () async {
      // §11: aggregated telemetry in Firestore, raw trial logs local-only.
      // The interface keeps them on separate methods so the split survives
      // implementation; this asserts they are in fact separate stores.
      final repo = InMemorySessionRepository(seed: false);
      addTearDown(repo.dispose);

      final session = await repo.startSession(
        childId: 'child_arif',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );

      await repo.appendTrialLog(
        TrialLog(
          sessionId: session.id,
          outcome: TrialOutcome.correct,
          latency: const Duration(milliseconds: 900),
          hintShown: false,
          targetSlot: 1,
        ),
      );

      expect((await repo.getTrialLogs(session.id)).length, 1);
      expect(await repo.getSessionHistory('child_arif'), isEmpty);
    });
  });

  group('photo repository', () {
    test('removing a photo drops it from the library', () async {
      final repo = InMemoryPhotoRepository(seed: false);
      addTearDown(repo.dispose);

      final photo = await repo.addPhoto(
        childId: 'child_arif',
        module: ModuleId.makanan,
        localPath: '/tmp/pisang.jpg',
        category: PhotoCategory.target,
        label: 'pisang',
      );

      await repo.removePhoto(photo.id);

      expect(
        await repo.listPhotos(
          childId: 'child_arif',
          module: ModuleId.makanan,
        ),
        isEmpty,
      );
    });

    test('re-tagging a photo persists — the §5.5 standing correction path',
        () async {
      final repo = InMemoryPhotoRepository(seed: false);
      addTearDown(repo.dispose);

      final photo = await repo.addPhoto(
        childId: 'child_arif',
        module: ModuleId.makanan,
        localPath: '/tmp/unknown.jpg',
        category: PhotoCategory.target,
      );

      await repo.updatePhoto(photo.copyWith(label: 'roti'));

      final reloaded = await repo.listPhotos(
        childId: 'child_arif',
        module: ModuleId.makanan,
      );
      expect(reloaded.single.label, 'roti');
    });
  });
}
