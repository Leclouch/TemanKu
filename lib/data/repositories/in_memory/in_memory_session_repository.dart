import 'dart:async';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/data/repositories/session_repository.dart';

/// In-memory [SessionRepository] (ADR-3 day-one target).
///
/// The frozen-timer behaviour is modelled honestly rather than stubbed: elapsed
/// time accumulates only across active spans, so a paused session's [Session.elapsed]
/// genuinely does not advance (§7). IT-1 can build pause/resume against this before
/// any real persistence exists.
class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository({bool seed = true}) {
    if (seed) _seed();
  }

  final Map<String, Session> _sessions = {};

  /// Wall-clock instant the current active span began; null while paused/ended.
  final Map<String, DateTime> _activeSince = {};

  final Map<String, List<TrialLog>> _trialLogs = {};
  final Map<String, List<SessionSummary>> _history = {};
  final Map<String, StreamController<List<SessionSummary>>> _historyControllers = {};

  int _idCounter = 0;

  void _seed() {
    // Two past sessions for the seeded child, so the guardian milestone timeline
    // has something to render on day one. Observations are dial-descriptive
    // sentences, never stats (§8).
    _history['child_arif'] = [
      SessionSummary(
        sessionId: 'session_seed_2',
        childId: 'child_arif',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        duration: const Duration(minutes: 4, seconds: 10),
        endedAt: DateTime(2026, 7, 30, 16, 20),
        ladderAtEnd: const LadderPosition(
          arraySize: 3,
          similarityTier: SimilarityTier.sameCategoryDistinct,
        ),
        observations: const [
          'Nyaman dengan kelompok yang lebih besar.',
          'Mulai ragu ketika bendanya mirip satu sama lain.',
        ],
      ),
      SessionSummary(
        sessionId: 'session_seed_1',
        childId: 'child_arif',
        module: ModuleId.keluarga,
        mode: ResponseMode.tap,
        duration: const Duration(minutes: 3, seconds: 5),
        endedAt: DateTime(2026, 7, 29, 17, 5),
        ladderAtEnd: const LadderPosition(
          arraySize: 4,
          similarityTier: SimilarityTier.differentCategory,
        ),
        observations: const [
          'Mengenali anggota keluarga dengan cepat.',
        ],
        endedByDisengagement: true,
      ),
    ];

    // Raw trial logs for the same two sessions — so
    // `features/guardian/session_full_data.dart`'s "Data lengkap" view has
    // real counts to render on day one too, same reasoning as the
    // observations above. Local-only (§11) in a real implementation; kept
    // here only because this fake's `_trialLogs` map already models that.
    _trialLogs['session_seed_1'] = const [
      TrialLog(
        sessionId: 'session_seed_1',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1800),
        hintShown: false,
        targetSlot: 0,
        responseSlot: 0,
      ),
      TrialLog(
        sessionId: 'session_seed_1',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1500),
        hintShown: false,
        targetSlot: 2,
        responseSlot: 2,
      ),
      TrialLog(
        sessionId: 'session_seed_1',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 2100),
        hintShown: false,
        targetSlot: 1,
        responseSlot: 1,
      ),
      TrialLog(
        sessionId: 'session_seed_1',
        outcome: TrialOutcome.incorrect,
        latency: Duration(milliseconds: 900),
        hintShown: false,
        targetSlot: 3,
        responseSlot: 0,
      ),
      TrialLog(
        sessionId: 'session_seed_1',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 2600),
        hintShown: true,
        targetSlot: 0,
        responseSlot: 0,
      ),
    ];
    _trialLogs['session_seed_2'] = const [
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1700),
        hintShown: false,
        targetSlot: 0,
        responseSlot: 0,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1600),
        hintShown: false,
        targetSlot: 1,
        responseSlot: 1,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1400),
        hintShown: false,
        targetSlot: 2,
        responseSlot: 2,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 2000),
        hintShown: false,
        targetSlot: 0,
        responseSlot: 0,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1900),
        hintShown: false,
        targetSlot: 1,
        responseSlot: 1,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 1300),
        hintShown: false,
        targetSlot: 2,
        responseSlot: 2,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.incorrect,
        latency: Duration(milliseconds: 1100),
        hintShown: false,
        targetSlot: 0,
        responseSlot: 1,
      ),
      TrialLog(
        sessionId: 'session_seed_2',
        outcome: TrialOutcome.correct,
        latency: Duration(milliseconds: 2400),
        hintShown: true,
        targetSlot: 1,
        responseSlot: 1,
      ),
    ];
  }

  StreamController<List<SessionSummary>> _controllerFor(String childId) =>
      _historyControllers.putIfAbsent(
        childId,
        () => StreamController<List<SessionSummary>>.broadcast(),
      );

  /// Elapsed time including the currently-running span, if any.
  Duration _elapsedNow(Session s) {
    final since = _activeSince[s.id];
    if (since == null) return s.elapsed;
    return s.elapsed + DateTime.now().difference(since);
  }

  @override
  Future<Session> startSession({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  }) async {
    final session = Session(
      id: 'session_${++_idCounter}',
      childId: childId,
      module: module,
      mode: mode,
      status: SessionStatus.active,
      elapsed: Duration.zero,
    );
    _sessions[session.id] = session;
    _activeSince[session.id] = DateTime.now();
    _trialLogs[session.id] = [];
    return session;
  }

  @override
  Future<Session> pauseSession(String sessionId) async {
    final session = _requireSession(sessionId);
    if (session.status != SessionStatus.active) return session;
    // Bank the elapsed span, then stop the clock. This is the freeze.
    final paused = session.copyWith(
      status: SessionStatus.paused,
      elapsed: _elapsedNow(session),
    );
    _activeSince.remove(sessionId);
    return _sessions[sessionId] = paused;
  }

  @override
  Future<Session> resumeSession(String sessionId) async {
    final session = _requireSession(sessionId);
    if (session.status != SessionStatus.paused) return session;
    // Same id, same accumulated elapsed — a resumed session is not a new one.
    final resumed = session.copyWith(status: SessionStatus.active);
    _activeSince[sessionId] = DateTime.now();
    return _sessions[sessionId] = resumed;
  }

  @override
  Future<void> endSession({
    required String sessionId,
    required SessionSummary summary,
  }) async {
    final session = _requireSession(sessionId);
    _sessions[sessionId] = session.copyWith(
      status: SessionStatus.ended,
      elapsed: _elapsedNow(session),
    );
    _activeSince.remove(sessionId);

    final list = _history.putIfAbsent(summary.childId, () => []);
    list.insert(0, summary); // newest first
    _controllerFor(summary.childId).add(List.of(list));
  }

  @override
  Future<Session?> getActiveSession(String childId) async {
    for (final s in _sessions.values) {
      if (s.childId == childId && s.status != SessionStatus.ended) {
        return s.copyWith(elapsed: _elapsedNow(s));
      }
    }
    return null;
  }

  @override
  Future<void> appendTrialLog(TrialLog log) async {
    // Local-only by construction here; the real implementation must write these
    // to Hive, never to Firestore (§11).
    (_trialLogs[log.sessionId] ??= []).add(log);
  }

  @override
  Future<List<TrialLog>> getTrialLogs(String sessionId) async =>
      List.of(_trialLogs[sessionId] ?? const []);

  @override
  Future<List<SessionSummary>> getSessionHistory(
    String childId, {
    int? limit,
  }) async {
    final list = List.of(_history[childId] ?? const <SessionSummary>[]);
    if (limit == null || limit >= list.length) return list;
    return list.sublist(0, limit);
  }

  @override
  Stream<List<SessionSummary>> watchSessionHistory(String childId) async* {
    yield List.of(_history[childId] ?? const <SessionSummary>[]);
    yield* _controllerFor(childId).stream;
  }

  Session _requireSession(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null) throw StateError('No session with id $sessionId');
    return s;
  }

  /// Not part of the interface — test/teardown convenience only.
  void dispose() {
    for (final c in _historyControllers.values) {
      c.close();
    }
  }
}
