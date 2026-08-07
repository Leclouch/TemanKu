import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';

/// Lifecycle of a session. `paused` exists because §7 requires the timer to
/// **freeze** on pause — a session resumed later is the same session, not a new one.
enum SessionStatus {
  active,
  paused,
  ended,
}

/// A live session handle. Held in memory during play; only the aggregated
/// [SessionSummary] is ever persisted remotely (§11: "aggregated telemetry in
/// Firestore; raw trial logs local-only").
class Session {
  const Session({
    required this.id,
    required this.childId,
    required this.module,
    required this.mode,
    required this.status,
    required this.elapsed,
  });

  final String id;
  final String childId;
  final ModuleId module;
  final ResponseMode mode;
  final SessionStatus status;

  /// Accumulated *active* time — does not advance while [status] is `paused`.
  final Duration elapsed;

  Session copyWith({SessionStatus? status, Duration? elapsed}) => Session(
        id: id,
        childId: childId,
        module: module,
        mode: mode,
        status: status ?? this.status,
        elapsed: elapsed ?? this.elapsed,
      );
}

/// What the guardian actually sees, and the only session artefact that leaves
/// the device.
///
/// §8: "descriptive sentences, notebook not dashboard. Duration, mode,
/// dial-specific observations. **No percentages, no accuracy stats.**" There is
/// deliberately no `accuracy` or `score` field on this class — if one appears in
/// a PR, that is a design regression, not a feature.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.childId,
    required this.module,
    required this.mode,
    required this.duration,
    required this.endedAt,
    required this.ladderAtEnd,
    required this.observations,
    this.endedByDisengagement = false,
    this.photoToReview,
  });

  final String sessionId;
  final String childId;
  final ModuleId module;
  final ResponseMode mode;
  final Duration duration;
  final DateTime endedAt;

  /// Where the two dials sat when the session ended — summaries describe dials,
  /// not levels (§4.4).
  final LadderPosition ladderAtEnd;

  /// Descriptive Bahasa sentences, e.g. "sering ragu saat benda mirip, tapi
  /// nyaman dengan kelompok besar."
  final List<String> observations;

  /// True when the disengagement detector's veto (§4.5) ended the session.
  /// Surfaced to the guardian as context, never as a failure.
  final bool endedByDisengagement;

  /// §5.5 standing correction path: a specific photo the child repeatedly
  /// hesitates on, so "bad exemplar" stays distinguishable from "doesn't
  /// understand the category".
  final String? photoToReview;
}

/// A single trial record. **Local-only** (§11) — never written to Firestore.
/// Feeds the disengagement detector's per-child latency baseline (§7).
class TrialLog {
  const TrialLog({
    required this.sessionId,
    required this.outcome,
    required this.latency,
    required this.hintShown,
    required this.targetSlot,
    required this.responseSlot,
  });

  final String sessionId;
  final TrialOutcome outcome;
  final Duration latency;

  /// Advancement counts only *independent* correct responses — correct **without
  /// the hint** (§4.5).
  final bool hintShown;

  /// Which slot the target occupied — for the ≤2-consecutive-repeat guard.
  final int targetSlot;

  /// Which slot the child actually responded to — the tapped slot in tap
  /// mode, the zone dropped into in match mode. Distinct from [targetSlot]
  /// on purpose: the repeated-same-position disengagement signal (§7) is
  /// about where the *child* keeps landing regardless of where the target
  /// was, which `targetSlot` alone cannot tell you once a response is wrong.
  final int responseSlot;
}
