import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_session_repository.dart';
import 'package:temanku/features/guardian/session_full_data.dart';

const _childId = 'child_1';

/// Ends a session with the given [ladderAtEnd]/[endedAt] and appends [logs]
/// against it — the shape a real mode-screen session would produce, built
/// through the repository's own public lifecycle methods rather than poking
/// at storage directly.
Future<void> _recordSession(
  InMemorySessionRepository repo, {
  required ModuleId module,
  required ResponseMode mode,
  required LadderPosition ladderAtEnd,
  required DateTime endedAt,
  required Duration duration,
  List<TrialLog> logs = const [],
}) async {
  final session = await repo.startSession(childId: _childId, module: module, mode: mode);
  for (final log in logs) {
    await repo.appendTrialLog(
      TrialLog(
        sessionId: session.id,
        outcome: log.outcome,
        latency: log.latency,
        hintShown: log.hintShown,
        targetSlot: log.targetSlot,
        responseSlot: log.responseSlot,
      ),
    );
  }
  await repo.endSession(
    sessionId: session.id,
    summary: SessionSummary(
      sessionId: session.id,
      childId: _childId,
      module: module,
      mode: mode,
      duration: duration,
      endedAt: endedAt,
      ladderAtEnd: ladderAtEnd,
      observations: const [],
      outcome: SessionOutcome.completed,
    ),
  );
}

TrialLog _log({required TrialOutcome outcome, required bool hintShown}) => TrialLog(
      sessionId: 'placeholder', // overwritten by _recordSession
      outcome: outcome,
      latency: const Duration(milliseconds: 1500),
      hintShown: hintShown,
      targetSlot: 0,
      responseSlot: 0,
    );

void main() {
  test('a child with no sessions produces no stats', () async {
    final repo = InMemorySessionRepository(seed: false);
    expect(await loadFullData(repo, _childId), isEmpty);
  });

  test('trial counts and the independent-correct tally are raw counts, never a ratio field',
      () async {
    final repo = InMemorySessionRepository(seed: false);
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition(arraySize: 2, similarityTier: SimilarityTier.differentCategory),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
      logs: [
        _log(outcome: TrialOutcome.correct, hintShown: false), // independent, correct
        _log(outcome: TrialOutcome.correct, hintShown: false), // independent, correct
        _log(outcome: TrialOutcome.incorrect, hintShown: false), // independent, wrong
        _log(outcome: TrialOutcome.correct, hintShown: true), // hinted — excluded from independent tally
      ],
    );

    final stats = await loadFullData(repo, _childId);
    expect(stats, hasLength(1));
    final s = stats.single;
    expect(s.totalTrials, 4);
    expect(s.independentAttempts, 3);
    expect(s.independentCorrect, 2);
  });

  test('tier milestones record the date each new tier was first reached, oldest first',
      () async {
    final repo = InMemorySessionRepository(seed: false);
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      // Same tier again — must not add a second milestone entry.
      ladderAtEnd: const LadderPosition(arraySize: 4, similarityTier: SimilarityTier.differentCategory),
      endedAt: DateTime(2026, 1, 2),
      duration: const Duration(minutes: 2),
    );
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition(arraySize: 2, similarityTier: SimilarityTier.sameCategoryDistinct),
      endedAt: DateTime(2026, 1, 5),
      duration: const Duration(minutes: 2),
    );

    final stats = (await loadFullData(repo, _childId)).single;
    expect(stats.tierMilestones, hasLength(2));
    expect(stats.tierMilestones[0].tier, SimilarityTier.differentCategory);
    expect(stats.tierMilestones[0].reachedAt, DateTime(2026, 1, 1));
    expect(stats.tierMilestones[1].tier, SimilarityTier.sameCategoryDistinct);
    expect(stats.tierMilestones[1].reachedAt, DateTime(2026, 1, 5));
    expect(stats.currentPosition.similarityTier, SimilarityTier.sameCategoryDistinct);
  });

  test('different (module, mode) pairs are aggregated separately and sorted by '
      'ModuleId then ResponseMode', () async {
    final repo = InMemorySessionRepository(seed: false);
    await _recordSession(
      repo,
      module: ModuleId.keluarga,
      mode: ResponseMode.match,
      ladderAtEnd: const LadderPosition.start(),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition.start(),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.speak,
      ladderAtEnd: const LadderPosition.start(),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );

    final stats = await loadFullData(repo, _childId);
    expect(
      stats.map((s) => (s.module, s.mode)),
      [
        (ModuleId.makanan, ResponseMode.tap),
        (ModuleId.makanan, ResponseMode.speak),
        (ModuleId.keluarga, ResponseMode.match),
      ],
    );
  });

  test('sessions list per pair is newest first, for the session-by-session log', () async {
    final repo = InMemorySessionRepository(seed: false);
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition.start(),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      ladderAtEnd: const LadderPosition.start(),
      endedAt: DateTime(2026, 1, 10),
      duration: const Duration(minutes: 3),
    );

    final stats = (await loadFullData(repo, _childId)).single;
    expect(stats.sessions.map((s) => s.endedAt), [DateTime(2026, 1, 10), DateTime(2026, 1, 1)]);
  });

  test('speak mode has no array dial — arraySize on its LadderPosition is simply unused, '
      'not something loadFullData needs to special-case', () async {
    final repo = InMemorySessionRepository(seed: false);
    await _recordSession(
      repo,
      module: ModuleId.makanan,
      mode: ResponseMode.speak,
      ladderAtEnd: const LadderPosition(arraySize: 2, similarityTier: SimilarityTier.lrffc),
      endedAt: DateTime(2026, 1, 1),
      duration: const Duration(minutes: 2),
    );

    final stats = (await loadFullData(repo, _childId)).single;
    expect(stats.currentPosition.similarityTier, SimilarityTier.lrffc);
  });

  test('tierLabel gives a distinct, non-empty plain-language string per tier, '
      'and spells out LRFFC by name rather than inventing a VB-MAPP milestone number', () {
    final labels = SimilarityTier.values.map(tierLabel).toSet();
    expect(labels, hasLength(SimilarityTier.values.length));
    for (final label in labels) {
      expect(label, isNotEmpty);
    }
    expect(tierLabel(SimilarityTier.lrffc), contains('LRFFC'));
  });
}
