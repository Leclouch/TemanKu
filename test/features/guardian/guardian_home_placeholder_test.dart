import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_pronunciation_hint_log_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_session_repository.dart';
import 'package:temanku/features/guardian/guardian_home_placeholder.dart';

Widget _buildApp(
  String childId,
  InMemoryChildRepository childRepo,
  InMemorySessionRepository sessionRepo, {
  InMemoryPronunciationHintLogRepository? hintLogRepo,
}) {
  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(childRepo),
      sessionRepositoryProvider.overrideWithValue(sessionRepo),
      pronunciationHintLogRepositoryProvider
          .overrideWithValue(hintLogRepo ?? InMemoryPronunciationHintLogRepository(seed: false)),
    ],
    child: MaterialApp(
      theme: TemanKuTheme.guardian,
      home: GuardianHomePlaceholder(childId: childId),
    ),
  );
}

/// Records one session for [childId] — [outcomes] becomes one no-hint
/// [TrialLog] each — and ends it with [observations] as the narrative.
Future<void> _recordSession(
  InMemorySessionRepository sessionRepo,
  String childId, {
  required List<bool> outcomes,
  required List<String> observations,
}) async {
  final session = await sessionRepo.startSession(
    childId: childId,
    module: ModuleId.makanan,
    mode: ResponseMode.tap,
  );
  for (final correct in outcomes) {
    await sessionRepo.appendTrialLog(
      TrialLog(
        sessionId: session.id,
        outcome: correct ? TrialOutcome.correct : TrialOutcome.incorrect,
        latency: const Duration(milliseconds: 1200),
        hintShown: false,
        targetSlot: 0,
        responseSlot: 0,
      ),
    );
  }
  await sessionRepo.endSession(
    sessionId: session.id,
    summary: SessionSummary(
      sessionId: session.id,
      childId: childId,
      module: ModuleId.makanan,
      mode: ResponseMode.tap,
      duration: const Duration(minutes: 2),
      endedAt: DateTime(2026, 1, 1),
      ladderAtEnd: const LadderPosition.start(),
      observations: observations,
    ),
  );
}

void main() {
  testWidgets(
      '"Data lengkap" starts collapsed — the narrative recap sentence is what renders '
      'without any interaction', (tester) async {
    // The cards above "Data lengkap" (Intake/Settings/Unggah foto) alone
    // exceed the default 800×600 test surface, and ListView's sliver
    // machinery only builds children near the viewport — a taller surface
    // here is what actually gets the card built, not a workaround for
    // anything about this feature itself.
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final sessionRepo = InMemorySessionRepository(seed: false);
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true],
      observations: ['Nyaman dengan kelompok kecil.'],
    );

    await tester.pumpWidget(_buildApp(child.id, childRepo, sessionRepo));
    await tester.pumpAndSettle();

    // The narrative sentence is visible without expanding anything — once
    // in the "Ringkasan sesi" card, once in the Riwayat list below it (the
    // same single seeded session, so the same sentence both places).
    expect(find.textContaining('Nyaman dengan kelompok kecil.'), findsWidgets);
    expect(find.text('Data lengkap'), findsOneWidget);

    // Raw-data content is not built/shown yet — collapsed by default.
    expect(find.textContaining('Total percobaan'), findsNothing);
    expect(find.textContaining('percobaan tanpa bantuan berhasil'), findsNothing);
  });

  testWidgets('expanding "Data lengkap" reveals trial counts, the independent-correct '
      'fraction, and the session log — with no percentage anywhere', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final sessionRepo = InMemorySessionRepository(seed: false);
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true, true, false],
      observations: ['Nyaman dengan kelompok kecil.'],
    );

    await tester.pumpWidget(_buildApp(child.id, childRepo, sessionRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Data lengkap'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Total percobaan: 3'), findsOneWidget);
    expect(find.textContaining('2 dari 3 percobaan tanpa bantuan berhasil'), findsOneWidget);
    expect(find.textContaining('01/01/2026'), findsWidgets);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('the pronunciation-hint subsection is entirely absent for a child who never '
      'enabled the feature — not an empty placeholder', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final sessionRepo = InMemorySessionRepository(seed: false);
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true],
      observations: ['Nyaman dengan kelompok kecil.'],
    );

    await tester.pumpWidget(_buildApp(child.id, childRepo, sessionRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Data lengkap'));
    await tester.pumpAndSettle();

    expect(find.text('Saran pengucapan'), findsNothing);
    expect(find.textContaining('Data eksperimental dari fitur saran pengucapan'), findsNothing);
  });

  testWidgets(
      'an opted-in child shows the labelled experimental pronunciation-hint subsection '
      'with raw IPA/edit-distance/target-word values, and never the WIN/TRY AGAIN verdict',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    await childRepo.updateChild(child.copyWith(pronunciationHintEnabled: true));
    final sessionRepo = InMemorySessionRepository(seed: false);
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true],
      observations: ['Nyaman dengan kelompok kecil.'],
    );
    final hintLogRepo = InMemoryPronunciationHintLogRepository(seed: false);
    await hintLogRepo.append(
      PronunciationHintLogEntry(
        childId: child.id,
        module: ModuleId.makanan,
        targetWord: 'pisang',
        ipaTranscription: 'pisaŋ',
        phonemeEditDistance: 0,
        recordedAt: DateTime(2026, 1, 2),
      ),
    );

    await tester.pumpWidget(_buildApp(child.id, childRepo, sessionRepo, hintLogRepo: hintLogRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Data lengkap'));
    await tester.pumpAndSettle();

    expect(find.text('Saran pengucapan'), findsOneWidget);
    expect(
      find.textContaining('Data eksperimental dari fitur saran pengucapan — bukan penilaian resmi.'),
      findsOneWidget,
    );
    expect(find.textContaining('pisang'), findsWidgets);
    expect(find.textContaining('pisaŋ'), findsOneWidget);
    expect(find.textContaining('jarak fonem: 0'), findsOneWidget);
    expect(find.textContaining('WIN'), findsNothing);
    expect(find.textContaining('TRY AGAIN'), findsNothing);
  });
}
