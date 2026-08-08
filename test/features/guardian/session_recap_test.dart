import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/features/guardian/session_recap.dart';

// Not `const` — `DateTime`'s constructor isn't const-evaluable.
final _summary = SessionSummary(
  sessionId: 'session_test',
  childId: 'child_arif',
  module: ModuleId.makanan,
  mode: ResponseMode.tap,
  duration: const Duration(minutes: 3),
  endedAt: DateTime(2026, 1, 1),
  ladderAtEnd: const LadderPosition(
    arraySize: 3,
    similarityTier: SimilarityTier.sameCategoryDistinct,
  ),
  observations: const [],
  outcome: SessionOutcome.completed,
);

void main() {
  group('sessionOutcomeLabel', () {
    test('completed reads as "Selesai"', () {
      expect(sessionOutcomeLabel(SessionOutcome.completed), 'Selesai');
    });

    test('endedEarly reads as "Berhenti di tengah" — never as a failure word', () {
      final label = sessionOutcomeLabel(SessionOutcome.endedEarly);
      expect(label, 'Berhenti di tengah');
      // §10/§12: an early exit is normal, expected — the badge must never
      // read as "gagal"/"salah" or any other alarm-adjacent word.
      expect(label.toLowerCase(), isNot(contains('gagal')));
      expect(label.toLowerCase(), isNot(contains('salah')));
    });
  });

  group('buildSessionRecap', () {
    test('falls back to the module tier copy when there are no observations', () {
      final recap = buildSessionRecap(_summary);
      expect(recap, contains('3 menit'));
      expect(recap, contains('ketuk'));
      final tierCopy = makananModule.similarityTierCopy[SimilarityTier.sameCategoryDistinct]!;
      expect(recap, contains(tierCopy));
    });

    test('prefers recorded observations over the tier-copy fallback', () {
      final withObservations = SessionSummary(
        sessionId: _summary.sessionId,
        childId: _summary.childId,
        module: _summary.module,
        mode: _summary.mode,
        duration: _summary.duration,
        endedAt: _summary.endedAt,
        ladderAtEnd: _summary.ladderAtEnd,
        observations: const ['Sering ragu saat benda mirip.'],
        outcome: _summary.outcome,
      );
      expect(buildSessionRecap(withObservations), contains('Sering ragu saat benda mirip.'));
    });

    test('the recap sentence itself does not vary by outcome — status is the badge\'s job, '
        'not the sentence\'s', () {
      final endedEarly = SessionSummary(
        sessionId: _summary.sessionId,
        childId: _summary.childId,
        module: _summary.module,
        mode: _summary.mode,
        duration: _summary.duration,
        endedAt: _summary.endedAt,
        ladderAtEnd: _summary.ladderAtEnd,
        observations: _summary.observations,
        outcome: SessionOutcome.endedEarly,
      );
      expect(buildSessionRecap(endedEarly), buildSessionRecap(_summary));
    });
  });
}
