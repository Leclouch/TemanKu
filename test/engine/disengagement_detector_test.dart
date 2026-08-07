import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/engine/disengagement/disengagement_detector.dart';

TrialLog _trial({
  TrialOutcome outcome = TrialOutcome.correct,
  int latencyMs = 800,
  int targetSlot = 0,
  int responseSlot = 0,
}) =>
    TrialLog(
      sessionId: 'session_1',
      outcome: outcome,
      latency: Duration(milliseconds: latencyMs),
      hintShown: false,
      targetSlot: targetSlot,
      responseSlot: responseSlot,
    );

void main() {
  group('RulesDisengagementDetector — latency drift', () {
    test('flags a genuine outlier well past the child\'s own baseline', () {
      final detector = RulesDisengagementDetector();
      final trials = [
        for (var i = 0; i < 6; i++) _trial(latencyMs: 800, responseSlot: i % 4),
        _trial(latencyMs: 4000, responseSlot: 5), // ~5x baseline
      ];

      final notice = detector.observe(trials);

      expect(notice, isNotNull);
      expect(notice!.signals, contains(DisengagementSignal.latencyDrift));
    });

    test('does not flag ordinary trial-to-trial variance', () {
      final detector = RulesDisengagementDetector();
      // Latencies wander between 700-950ms — normal human variance, no trend.
      final latencies = [800, 750, 900, 700, 850, 950, 820];
      final trials = [
        for (var i = 0; i < latencies.length; i++)
          _trial(latencyMs: latencies[i], responseSlot: i % 4),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNull);
    });

    test('stays quiet before enough baseline samples exist', () {
      final detector = RulesDisengagementDetector();
      // Only 2 prior trials — far below minBaselineSamples (default 5) — even
      // though the latest trial is dramatically slower.
      final trials = [
        _trial(latencyMs: 800, responseSlot: 0),
        _trial(latencyMs: 800, responseSlot: 1),
        _trial(latencyMs: 5000, responseSlot: 2),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNull);
    });

    test('primeBaseline seeds the baseline from past sessions so drift can '
        'be caught from the first trial of a new one', () {
      final detector = RulesDisengagementDetector();
      detector.primeBaseline([
        for (var i = 0; i < 8; i++) _trial(latencyMs: 800, responseSlot: i % 4),
      ]);

      final notice = detector.observe([_trial(latencyMs: 4000, responseSlot: 0)]);

      expect(notice, isNotNull);
      expect(notice!.signals, contains(DisengagementSignal.latencyDrift));
    });
  });

  group('RulesDisengagementDetector — answer randomness', () {
    test('never flags a slow-but-correct child, no matter how many trials', () {
      final detector = RulesDisengagementDetector();
      final trials = [
        for (var i = 0; i < 10; i++)
          _trial(outcome: TrialOutcome.correct, latencyMs: 2500, responseSlot: i % 4),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNull);
    });

    test('does not flag wrong answers given at a normal, unhurried pace — that reads '
        'as genuine difficulty, not disengagement', () {
      final detector = RulesDisengagementDetector();
      final baseline = [for (var i = 0; i < 6; i++) _trial(latencyMs: 800, responseSlot: i % 4)];
      final strugglingRun = [
        for (var i = 0; i < 4; i++)
          _trial(outcome: TrialOutcome.incorrect, latencyMs: 900, responseSlot: i % 4),
      ];

      final notice = detector.observe([...baseline, ...strugglingRun]);

      expect(notice, isNull);
    });

    test('flags a run of fast, wrong responses — guessing, not engaging', () {
      final detector = RulesDisengagementDetector();
      final baseline = [for (var i = 0; i < 6; i++) _trial(latencyMs: 800, responseSlot: i % 4)];
      final rapidFireRun = [
        for (var i = 0; i < 4; i++)
          _trial(outcome: TrialOutcome.incorrect, latencyMs: 150, responseSlot: i % 4),
      ];

      final notice = detector.observe([...baseline, ...rapidFireRun]);

      expect(notice, isNotNull);
      expect(notice!.signals, contains(DisengagementSignal.answerRandomness));
    });
  });

  group('RulesDisengagementDetector — repeated position', () {
    test('does not flag a normal few-in-a-row-correct streak, where rotation moves '
        'the response slot each time', () {
      final detector = RulesDisengagementDetector();
      // Correct every time, but position_rotator's guard means the target
      // (and so the correct response slot) can't sit still — simulated here
      // as a varying slot per trial, same as a real rotated array would give.
      final trials = [
        _trial(outcome: TrialOutcome.correct, targetSlot: 0, responseSlot: 0),
        _trial(outcome: TrialOutcome.correct, targetSlot: 2, responseSlot: 2),
        _trial(outcome: TrialOutcome.correct, targetSlot: 1, responseSlot: 1),
        _trial(outcome: TrialOutcome.correct, targetSlot: 3, responseSlot: 3),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNull);
    });

    test('allows two consecutive repeats — the same guard tap mode itself allows', () {
      final detector = RulesDisengagementDetector();
      final trials = [
        _trial(responseSlot: 1),
        _trial(responseSlot: 1),
        _trial(responseSlot: 2),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNull);
    });

    test('flags three consecutive identical response slots regardless of correctness', () {
      final detector = RulesDisengagementDetector();
      final trials = [
        _trial(outcome: TrialOutcome.correct, targetSlot: 1, responseSlot: 1),
        _trial(outcome: TrialOutcome.incorrect, targetSlot: 3, responseSlot: 1),
        _trial(outcome: TrialOutcome.incorrect, targetSlot: 0, responseSlot: 1),
      ];

      final notice = detector.observe(trials);

      expect(notice, isNotNull);
      expect(notice!.signals, contains(DisengagementSignal.repeatedSamePosition));
    });
  });

  group('RulesDisengagementDetector — debugSignalStream', () {
    test('emits each heuristic that fired, for debugging only — no guardian UI here', () async {
      final detector = RulesDisengagementDetector();
      addTearDown(detector.dispose);

      final emitted = <DisengagementSignal>[];
      final subscription = detector.debugSignalStream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final trials = [
        _trial(responseSlot: 4),
        _trial(responseSlot: 4),
        _trial(responseSlot: 4),
      ];
      detector.observe(trials);
      await Future<void>.delayed(Duration.zero); // let the broadcast stream flush

      expect(emitted, [DisengagementSignal.repeatedSamePosition]);
    });

    test('stays silent when nothing fires', () async {
      final detector = RulesDisengagementDetector();
      addTearDown(detector.dispose);

      final emitted = <DisengagementSignal>[];
      final subscription = detector.debugSignalStream.listen(emitted.add);
      addTearDown(subscription.cancel);

      detector.observe([_trial()]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });
  });

  group('RulesDisengagementDetector — notice shape', () {
    test('the message is soft, non-clinical guardian copy, not a diagnostic label', () {
      final detector = RulesDisengagementDetector();
      final trials = [_trial(responseSlot: 9), _trial(responseSlot: 9), _trial(responseSlot: 9)];

      final notice = detector.observe(trials);

      expect(notice!.message, 'sepertinya mulai lelah');
    });

    test('an empty trial list never throws and never flags anything', () {
      final detector = RulesDisengagementDetector();
      expect(detector.observe(const []), isNull);
    });
  });
}
