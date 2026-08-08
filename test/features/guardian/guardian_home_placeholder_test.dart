import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
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
  SessionOutcome sessionOutcome = SessionOutcome.completed,
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
      outcome: sessionOutcome,
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

  testWidgets(
      'the Modul card lists both active modules and four muted "Belum tersedia" '
      'placeholders, and tapping a placeholder never navigates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});

    await tester.pumpWidget(_buildApp(child.id, childRepo, InMemorySessionRepository(seed: false)));
    await tester.pumpAndSettle();

    expect(find.text('Uang'), findsOneWidget);
    expect(find.text('Sampah'), findsOneWidget);
    expect(find.text('Pengenalan Keamanan'), findsOneWidget);
    expect(find.text('Pengenalan Orang Terpercaya'), findsOneWidget);
    // Same shared badge, once per placeholder row — see `_BelumTersediaBadge`.
    expect(find.text('Belum tersedia'), findsNWidgets(4));

    // A placeholder tap is inert: it only ever surfaces the snackbar below,
    // never a route change — the AppBar title staying put is the proof.
    await tester.tap(find.text('Uang'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Modul ini sedang dikembangkan'), findsOneWidget);
    expect(find.text('Catatan wali'), findsOneWidget);
  });

  testWidgets('Riwayat shows a distinct status badge for a completed session vs one the '
      'guardian ended early', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final childRepo = InMemoryChildRepository(seed: false);
    final child = await childRepo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
    final sessionRepo = InMemorySessionRepository(seed: false);
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true],
      observations: ['Sudah menguasai babak ini.'],
      sessionOutcome: SessionOutcome.completed,
    );
    await _recordSession(
      sessionRepo,
      child.id,
      outcomes: [true],
      observations: ['Berhenti sebelum mencapai batas atas.'],
      sessionOutcome: SessionOutcome.endedEarly,
    );

    await tester.pumpWidget(_buildApp(child.id, childRepo, sessionRepo));
    await tester.pumpAndSettle();

    // One badge per session, both visible in the Riwayat list at once — this
    // is the fact that was entirely missing before: a guardian could not
    // previously tell a mastery session from an early exit at a glance.
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Berhenti di tengah'), findsOneWidget);
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
        predictedIpa: 'pisaŋ',
        distance: 0,
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
