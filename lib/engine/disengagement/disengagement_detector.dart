/// Disengagement detection — **IT-2 builds the rules engine (Day 3); IT-1 feeds it
/// signals from the session loop.** Pure Dart.
///
/// Source-of-truth §7. On-device, rules-first, **no camera, no eye-tracking**
/// (a recorded dead end, on privacy and philosophy grounds — not a cost decision).
///
/// Signals:
///   - response-latency drift against a **per-child** baseline
///   - answer randomness
///   - repeated same-position tapping — a *clean* signal only because position
///     rotation (§4.4) removes the innocent explanation
///   - VAD silence duration in speak mode
///
/// **Sole action: discreetly notify the guardian** ("sepertinya mulai lelah").
/// Never auto-escalate stimulation, never end the session on its own authority,
/// never show anything to the child. The guardian decides: pause, switch mode, or
/// stop — progress saves, timer freezes for resume.
///
/// The §4.5 "absolute veto" lives with the *guardian acting on this notice*, not
/// with the detector silently overriding the ladder.
library;

import 'package:temanku/data/models/session.dart';

/// Which signal fired. Surfaced to the guardian as gentle context, never as data.
enum DisengagementSignal {
  latencyDrift,
  answerRandomness,
  repeatedSamePosition,
  vadSilence,
}

class DisengagementNotice {
  const DisengagementNotice({
    required this.signals,
    required this.message,
  });

  final Set<DisengagementSignal> signals;

  /// Guardian-facing Bahasa copy, e.g. "sepertinya mulai lelah". Soft, tentative,
  /// non-clinical — this is an observation offered to a parent, not a readout.
  final String message;
}

abstract class DisengagementDetector {
  /// Called after each trial. Returns a notice when the guardian should be
  /// discreetly prompted, otherwise null.
  ///
  /// Must be conservative: a false positive interrupts a child who was doing
  /// fine, and repeated false positives train guardians to ignore the notice
  /// entirely — which costs more than a missed detection.
  DisengagementNotice? observe(List<TrialLog> sessionTrials);

  /// Per-child latency baseline, learned across sessions (§7) — an absolute
  /// threshold would misread a child who is simply deliberate.
  void primeBaseline(List<TrialLog> historicalTrials);
}

/// TODO(IT-2): implement — Day 3, per the timeline.
///
/// §7 also records the upgrade path: a learned model **only after labeled
/// co-design session data exists**. Rules-first is the deliberate MVP choice, not
/// a placeholder for something smarter.
class RulesDisengagementDetector implements DisengagementDetector {
  @override
  DisengagementNotice? observe(List<TrialLog> sessionTrials) {
    throw UnimplementedError('RulesDisengagementDetector.observe');
  }

  @override
  void primeBaseline(List<TrialLog> historicalTrials) {
    throw UnimplementedError('RulesDisengagementDetector.primeBaseline');
  }
}
