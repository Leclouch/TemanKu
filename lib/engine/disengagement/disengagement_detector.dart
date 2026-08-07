/// Disengagement signal collection — **IT-2 builds the rules engine; IT-1
/// feeds it signals from the session loop.** Pure Dart.
///
/// Source-of-truth §7. On-device, rules-first, **no camera, no eye-tracking**
/// (a recorded dead end, on privacy and philosophy grounds — not a cost
/// decision), and no timing signal beyond what tap/drag events already give
/// us — no new sensor, no new permission.
///
/// Scope of this pass: **tap and match modes only.** Speak mode's VAD-silence
/// signal is Day 4 work and deliberately not stubbed here beyond leaving
/// [DisengagementSignal.vadSilence] in the enum so it slots in later without
/// a shape change.
///
/// Signals, all per-child rather than against a fixed global number (§7 — an
/// absolute threshold misreads a child who is simply deliberate):
///   - response-latency drift against a rolling baseline of that child's own
///     recent trials
///   - answer randomness — a run of fast, wrong responses with no sign of
///     actually engaging with the question
///   - repeated same-position responding — the same [TrialLog.responseSlot]
///     several trials running, regardless of where the target was. This is a
///     *clean* signal only because `engine/rotation/` guarantees a slot can't
///     just be "happening" to be correct three times running — see that
///     folder's ≤2-consecutive-repeat guard.
///
/// **Sole action: emit a signal.** This detector never pauses, ends, or
/// otherwise acts on a session — §4.5's "absolute veto" belongs to the
/// *guardian* acting on the notice, never to this class acting on its own
/// authority. Building what a guardian sees is a separate, later task
/// (`features/guardian/`) — this file stops at producing the signal.
library;

import 'dart:async';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/session.dart';

/// Which signal fired. Surfaced to the guardian as gentle context, never as
/// data — and, via [DisengagementDetector.debugSignalStream], to developers
/// for debugging before any guardian UI exists to consume it.
enum DisengagementSignal {
  latencyDrift,
  answerRandomness,
  repeatedSamePosition,

  /// Day 4, speak mode. Not produced by anything in this file yet — kept in
  /// the enum now so [DisengagementNotice.signals] doesn't need a breaking
  /// shape change when it arrives.
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

  /// Fires once per heuristic that trips during [observe], independently of
  /// whether the overall call produced a [DisengagementNotice] — debugging
  /// visibility only. No guardian-facing consumer is built in this file; for
  /// now, wire it to `debugPrint` (or a similarly trivial callback) wherever
  /// this detector is constructed:
  /// ```dart
  /// detector.debugSignalStream.listen((s) => debugPrint('disengagement: $s'));
  /// ```
  Stream<DisengagementSignal> get debugSignalStream;
}

/// Rules-first implementation (§7: a learned model is explicitly a later
/// upgrade, only after labeled co-design session data exists — this is not a
/// placeholder for something smarter, it is the deliberate MVP choice).
///
/// All thresholds below are **placeholders pending real-session calibration**
/// — same caveat as `engine/advancement/advancement_tracker.dart`'s streak
/// constant. They are picked to be directionally reasonable, not validated
/// against labeled data.
class RulesDisengagementDetector implements DisengagementDetector {
  RulesDisengagementDetector({
    this.baselineWindow = 10,
    this.minBaselineSamples = 5,
    this.latencyDriftMultiplier = 1.8,
    this.randomnessWindow = 4,
    this.randomnessFastFraction = 0.5,
    this.repeatedPositionRun = 3,
  });

  /// How many recent latencies make up the rolling baseline.
  final int baselineWindow;

  /// Below this many known latencies, there isn't a real baseline yet — stay
  /// silent rather than call a small sample "drift".
  final int minBaselineSamples;

  /// A response taking longer than baseline × this reads as latency drift.
  final double latencyDriftMultiplier;

  /// How many of the most recent trials the randomness check looks at.
  final int randomnessWindow;

  /// A response faster than baseline × this fraction, inside an all-wrong
  /// window, reads as guessing rather than genuine difficulty.
  final double randomnessFastFraction;

  /// A response slot repeated this many trials running (regardless of
  /// correctness) reads as disengagement. 3 is not arbitrary: it is one past
  /// the rotation guard's own ≤2-consecutive-repeat limit, so a *target*
  /// slot literally cannot repeat this many times on its own — only the
  /// child choosing the same spot independent of the target can.
  final int repeatedPositionRun;

  List<Duration> _historicalLatencies = const [];

  final StreamController<DisengagementSignal> _signalController =
      StreamController<DisengagementSignal>.broadcast();

  @override
  Stream<DisengagementSignal> get debugSignalStream => _signalController.stream;

  @override
  void primeBaseline(List<TrialLog> historicalTrials) {
    _historicalLatencies = historicalTrials.map((t) => t.latency).toList();
  }

  @override
  DisengagementNotice? observe(List<TrialLog> sessionTrials) {
    if (sessionTrials.isEmpty) return null;

    final signals = <DisengagementSignal>{};

    if (_latencyDrifted(sessionTrials)) signals.add(DisengagementSignal.latencyDrift);
    if (_answersLookRandom(sessionTrials)) signals.add(DisengagementSignal.answerRandomness);
    if (_positionRepeated(sessionTrials)) signals.add(DisengagementSignal.repeatedSamePosition);

    for (final signal in signals) {
      _signalController.add(signal);
    }

    if (signals.isEmpty) return null;
    return DisengagementNotice(signals: signals, message: 'sepertinya mulai lelah');
  }

  /// Baseline pool for the trial *before* [sessionTrials.last] — historical
  /// latencies plus this session's own trials so far, most recent
  /// [baselineWindow] of them. The trial being judged is never counted
  /// toward its own baseline.
  List<Duration> _baselinePool(List<TrialLog> sessionTrials) {
    final priorThisSession = sessionTrials.sublist(0, sessionTrials.length - 1).map((t) => t.latency);
    final pool = [..._historicalLatencies, ...priorThisSession];
    if (pool.length <= baselineWindow) return pool;
    return pool.sublist(pool.length - baselineWindow);
  }

  Duration? _averageOf(List<Duration> latencies) {
    if (latencies.isEmpty) return null;
    final totalMicros = latencies.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicros ~/ latencies.length);
  }

  bool _latencyDrifted(List<TrialLog> sessionTrials) {
    final pool = _baselinePool(sessionTrials);
    if (pool.length < minBaselineSamples) return false;

    final baseline = _averageOf(pool)!;
    final latest = sessionTrials.last.latency;
    return latest.inMicroseconds > baseline.inMicroseconds * latencyDriftMultiplier;
  }

  /// A run of trials that are both **wrong** and **fast** — genuine
  /// difficulty reads as wrong-but-normal-or-slow (thinking hard about a
  /// hard trial takes time), so requiring both keeps this from firing on a
  /// child who is simply struggling.
  bool _answersLookRandom(List<TrialLog> sessionTrials) {
    if (sessionTrials.length < randomnessWindow) return false;

    final window = sessionTrials.sublist(sessionTrials.length - randomnessWindow);
    if (window.any((t) => t.outcome != TrialOutcome.incorrect)) return false;

    final pool = _baselinePool(sessionTrials);
    if (pool.length < minBaselineSamples) return false;
    final baseline = _averageOf(pool)!;
    final fastCutoff = baseline.inMicroseconds * randomnessFastFraction;

    return window.every((t) => t.latency.inMicroseconds < fastCutoff);
  }

  /// The same response slot, [repeatedPositionRun] trials in a row,
  /// regardless of whether each one was correct.
  bool _positionRepeated(List<TrialLog> sessionTrials) {
    if (sessionTrials.length < repeatedPositionRun) return false;

    final window = sessionTrials.sublist(sessionTrials.length - repeatedPositionRun);
    final firstSlot = window.first.responseSlot;
    return window.every((t) => t.responseSlot == firstSlot);
  }

  /// Not part of the interface — session-teardown convenience only, same
  /// convention as the in-memory repositories' `dispose()`.
  void dispose() => _signalController.close();
}
