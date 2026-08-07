// Manual check — not part of the app. Run with:
//   dart run tool/demo_disengagement_detector.dart
//
// Feeds a few hand-picked scenarios through RulesDisengagementDetector and
// prints what it decides, so you can eyeball the behaviour without writing
// a test or wiring up UI (there isn't any yet — that's a separate task).
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/engine/disengagement/disengagement_detector.dart';

TrialLog trial({
  TrialOutcome outcome = TrialOutcome.correct,
  int latencyMs = 800,
  int targetSlot = 0,
  int responseSlot = 0,
}) =>
    TrialLog(
      sessionId: 'demo',
      outcome: outcome,
      latency: Duration(milliseconds: latencyMs),
      hintShown: false,
      targetSlot: targetSlot,
      responseSlot: responseSlot,
    );

void run(String label, List<TrialLog> trials) {
  final detector = RulesDisengagementDetector();
  detector.debugSignalStream.listen((s) => print('    debug signal: $s'));

  final notice = detector.observe(trials);
  print(label);
  print('  outcome: ${notice == null ? 'no notice' : notice.signals}');
  print('');
  detector.dispose();
}

void main() async {
  run('1. Normal play — steady latency, correct, rotated positions', [
    trial(latencyMs: 800, responseSlot: 0),
    trial(latencyMs: 750, responseSlot: 2),
    trial(latencyMs: 900, responseSlot: 1),
    trial(latencyMs: 820, responseSlot: 3),
    trial(latencyMs: 780, responseSlot: 0),
  ]);

  run('2. Sudden slow response — latency drift', [
    for (var i = 0; i < 6; i++) trial(latencyMs: 800, responseSlot: i % 4),
    trial(latencyMs: 4200, responseSlot: 1),
  ]);

  run('3. Struggling but trying — wrong answers, normal pace (should NOT flag)', [
    for (var i = 0; i < 6; i++) trial(latencyMs: 800, responseSlot: i % 4),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 900, responseSlot: 0),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 950, responseSlot: 1),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 880, responseSlot: 2),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 910, responseSlot: 3),
  ]);

  run('4. Rapid-fire mashing — wrong answers, very fast (answer randomness)', [
    for (var i = 0; i < 6; i++) trial(latencyMs: 800, responseSlot: i % 4),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 150, responseSlot: 0),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 140, responseSlot: 1),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 160, responseSlot: 2),
    trial(outcome: TrialOutcome.incorrect, latencyMs: 130, responseSlot: 3),
  ]);

  run('5. Always tapping the same spot — repeated position', [
    trial(outcome: TrialOutcome.correct, targetSlot: 2, responseSlot: 2),
    trial(outcome: TrialOutcome.incorrect, targetSlot: 0, responseSlot: 2),
    trial(outcome: TrialOutcome.incorrect, targetSlot: 3, responseSlot: 2),
  ]);

  // Give the debug-stream microtasks a moment to print before exiting.
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
