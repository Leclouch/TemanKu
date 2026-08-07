import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/session.dart';

/// Session lifecycle and history.
///
/// **ADR-3 contract — shared file.** See [ChildRepository] for the ownership rule.
///
/// Storage split is deliberate and load-bearing (§11): aggregated [SessionSummary]
/// objects may go to Firestore; [TrialLog] entries are **local-only** and must
/// never be written remotely. The interface keeps them on separate methods so the
/// distinction survives implementation.
abstract class SessionRepository {
  // --- Lifecycle ---------------------------------------------------------------

  Future<Session> startSession({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  });

  /// Freezes the timer. §7: the guardian decides — pause, switch mode, or stop —
  /// and "progress saves, timer freezes for resume". [Session.elapsed] must not
  /// advance while paused.
  Future<Session> pauseSession(String sessionId);

  /// Resumes a frozen session. The resumed session keeps its id and accumulated
  /// [Session.elapsed]; it is not a new session.
  Future<Session> resumeSession(String sessionId);

  /// Ends the session and persists [summary].
  ///
  /// [SessionSummary.endedByDisengagement] carries the §4.5 veto: "the
  /// disengagement detector has absolute veto — sessions end gracefully
  /// regardless of ladder position."
  Future<void> endSession({
    required String sessionId,
    required SessionSummary summary,
  });

  Future<Session?> getActiveSession(String childId);

  // --- Trial logs (LOCAL ONLY — §11) -------------------------------------------

  /// Append a raw trial record. Feeds the disengagement detector's per-child
  /// latency baseline (§7) and the advancement streak (§4.5).
  ///
  /// Implementations must keep these on-device. The Firestore implementation of
  /// this interface should write these to Hive, not to Firestore.
  Future<void> appendTrialLog(TrialLog log);

  /// Trials for one session, oldest first — used to build the summary at
  /// session end, and, aggregated across sessions, the raw trial-count/
  /// independent-correct tallies in `features/guardian/session_full_data.dart`'s
  /// "Data lengkap" view. That view only ever shows counts and dates read
  /// straight off these records (§8: never a percentage, never a score) — it
  /// is the one deliberate exception to "not surfaced to the guardian raw";
  /// nothing else in the app reads these directly.
  Future<List<TrialLog>> getTrialLogs(String sessionId);

  // --- History -----------------------------------------------------------------

  /// Session summaries for one child, newest first.
  ///
  /// §8: the longitudinal view is a **milestone timeline, not a performance
  /// graph** — categories reached independent mastery, shown categorically over
  /// time. This returns the raw material for that; it is not an analytics feed.
  Future<List<SessionSummary>> getSessionHistory(
    String childId, {
    int? limit,
  });

  Stream<List<SessionSummary>> watchSessionHistory(String childId);
}
