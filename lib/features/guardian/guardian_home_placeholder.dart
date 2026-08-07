import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/features/guardian/pronunciation_hint_full_data.dart';
import 'package:temanku/features/guardian/session_full_data.dart';
import 'package:temanku/features/guardian/session_recap.dart';

/// Guardian home — **IT-2.**
///
/// Reads tokens from the same `core/theme/` source as the child screen, at the
/// guardian temperature — that shared source is the thing this file is proving.
///
/// The five surfaces below, with their source-of-truth constraints:
///   - **Intake** (§8) — per-child, one behavioural question per mode, selecting
///     available *modes*, never predicting levels. Never a report, never a score.
///   - **Upload flow** (§5) — quality gate, variety coaching toward five varied
///     photos as a **soft nudge, never a hard gate**, label prompt on low
///     classifier confidence. Home of the "photo becomes the task" moment (§12).
///   - **Post-session summary** ([_SessionRecapCard], §8) — the latest session's
///     [buildSessionRecap] sentence: descriptive, **notebook not dashboard**.
///     Duration, mode, dial-specific observations. No percentages, no accuracy
///     stats.
///   - **Data lengkap** ([_FullDataCard], §8) — collapsed by default, right
///     alongside [_SessionRecapCard]'s narrative sentence, which stays the
///     primary/first thing shown. Expanding it surfaces the raw counts behind
///     that sentence: per-(module, mode) trial counts, independent-correct
///     tallies as two counts (never a percentage), the current tier in plain
///     language, the dates each tier was reached, and a flat session-by-
///     session log. See `session_full_data.dart`'s own doc comment for why no
///     single score appears anywhere in it either.
///   - **Milestone timeline** ([_MilestoneTimeline], §8) — one categorical
///     mastered/emerging line per active (module, mode), read straight off the
///     current [LadderPosition] and the module's own [ModuleDefinition.similarityTierCopy].
///     Not a performance graph, and not a history of past positions — there is
///     nowhere in this codebase that persists a position's *prior* values, only
///     its current one, so "over time" here means "as of now," honestly.
class GuardianHomePlaceholder extends ConsumerWidget {
  const GuardianHomePlaceholder({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan wali')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IntakeEntryPoint(childId: childId),
          _SettingsEntryPoint(childId: childId),
          _UploadEntryPoint(childId: childId),
          _SessionRecapCard(childId: childId),
          _FullDataCard(childId: childId),
          _MilestoneTimeline(childId: childId),
          const SizedBox(height: 8),
          Text('Riwayat (dari repository)', style: context.type.display),
          const SizedBox(height: 8),
          // Proves the session repository wiring end-to-end against the in-memory
          // fake. Renders duration + dials, deliberately no score of any kind.
          FutureBuilder<List<SessionSummary>>(
            future: sessions.getSessionHistory(childId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                );
              }
              final history = snapshot.data!;
              if (history.isEmpty) {
                return Text('Belum ada sesi.', style: context.type.body);
              }
              return Column(
                children: [
                  for (final s in history)
                    ListTile(
                      title: Text(
                        '${s.module.name} · ${s.mode.name}',
                        style: context.type.body,
                      ),
                      subtitle: Text(
                        buildSessionRecap(s),
                        style: context.type.body,
                      ),
                      trailing: Text(
                        // Timestamps are the mono role's only job (§12).
                        '${s.endedAt.day}/${s.endedAt.month}',
                        style: context.type.mono,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _displayNameFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule.displayName,
      ModuleId.keluarga => keluargaModule.displayName,
    };

/// The "Intake" card's real entry point (§8) — hands off to [IntakeScreen].
/// Selects modes only; never sets a starting difficulty.
class _IntakeEntryPoint extends StatelessWidget {
  const _IntakeEntryPoint({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intake', style: context.type.display.copyWith(color: colors.text)),
            const SizedBox(height: 6),
            Text(
              'Satu pertanyaan per mode. Memilih mode yang tersedia — bukan '
              'memperkirakan level.',
              style: context.type.body.copyWith(color: colors.text),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push(Routes.intakeFor(childId)),
              child: const Text('Isi intake'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Pengaturan anak" card's entry point — today just the pronunciation-
/// hint consent toggle (`features/guardian/child_settings_screen.dart`).
/// Kept as its own doorway rather than a stub because that screen carries a
/// real consent flow, not placeholder copy.
class _SettingsEntryPoint extends StatelessWidget {
  const _SettingsEntryPoint({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengaturan anak', style: context.type.display.copyWith(color: colors.text)),
            const SizedBox(height: 6),
            Text(
              'Saran pengucapan (eksperimental) dan pengaturan lain per anak.',
              style: context.type.body.copyWith(color: colors.text),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push(Routes.childSettingsFor(childId)),
              child: const Text('Buka pengaturan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Unggah foto" card's real entry point (§5.1/§5.2) — picks a module,
/// then hands off to [PhotoUploadScreen]. Quality gate, variety nudge, and the
/// no-network-call guarantee all live there; this card is just the doorway.
class _UploadEntryPoint extends StatelessWidget {
  const _UploadEntryPoint({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unggah foto', style: context.type.display.copyWith(color: colors.text)),
            const SizedBox(height: 6),
            Text(
              'Quality gate, ajakan variasi (lima foto berbeda — anjuran, bukan '
              'syarat). Pilih modulnya:',
              style: context.type.body.copyWith(color: colors.text),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final module in ModuleId.values)
                  OutlinedButton(
                    onPressed: () =>
                        context.push(Routes.photoUploadFor(childId, module)),
                    child: Text(_displayNameFor(module)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Lihat, ubah nama, atau hapus foto yang sudah tersimpan (§5.5):',
              style: context.type.body.copyWith(color: colors.text),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final module in ModuleId.values)
                  TextButton.icon(
                    onPressed: () =>
                        context.push(Routes.photoLibraryFor(childId, module)),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_displayNameFor(module)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// Day/month/year — the "Data lengkap" section's own date format, distinct
/// from the day/month-only trailing timestamp the Riwayat list below uses.
/// This section is meant to stand alone as a reference table (a teacher
/// might read it long after the session, possibly a year on), so the year
/// stays explicit rather than assumed.
String _formatFullDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Shared card chrome — same border/shape every guardian card on this screen
/// uses, factored out once both real (non-stub) cards needed a FutureBuilder
/// wrapped in it.
class _GuardianCard extends StatelessWidget {
  const _GuardianCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.type.display.copyWith(color: colors.text)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

/// The "Ringkasan sesi" card (§8 post-session summary) — the most recent
/// session's [buildSessionRecap] sentence. Descriptive only, same as every
/// row in the "Riwayat" list below; this card just surfaces the latest one
/// without the guardian having to scroll to find it.
class _SessionRecapCard extends ConsumerWidget {
  const _SessionRecapCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sessions = ref.watch(sessionRepositoryProvider);
    return _GuardianCard(
      title: 'Ringkasan sesi',
      child: FutureBuilder<List<SessionSummary>>(
        future: sessions.getSessionHistory(childId, limit: 1),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          final latest = snapshot.data!;
          final text = latest.isEmpty
              ? 'Belum ada sesi.'
              : buildSessionRecap(latest.first);
          return Text(text, style: context.type.body.copyWith(color: colors.text));
        },
      ),
    );
  }
}

/// The "Data lengkap" card (§8) — raw counts and dates behind
/// [_SessionRecapCard]'s narrative sentence, for a teacher or therapist who
/// wants the receipts. Collapsed by default via [ExpansionTile]'s own
/// default ([ExpansionTile.initiallyExpanded] left false) — the narrative
/// above stays the first, primary thing a guardian sees; this is opt-in.
///
/// Every number rendered here is a plain count or two counts shown side by
/// side — see `session_full_data.dart`'s doc comment for why nothing in this
/// file, including this expanded view, ever reduces to one score. The
/// pronunciation-hint subsection at the bottom follows the same rule and
/// only exists at all for a child with `Child.pronunciationHintEnabled`
/// true — see `pronunciation_hint_full_data.dart`.
class _FullDataCard extends ConsumerWidget {
  const _FullDataCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.background,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        // ExpansionTile paints its divider/icon from the ambient Material
        // theme, not TemanKuColors — scoped to just this card rather than
        // adding a guardian-wide override for one collapsible section.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: colors.text,
          collapsedIconColor: colors.text,
          title: Text(
            'Data lengkap',
            style: context.type.display.copyWith(color: colors.text, fontSize: 18),
          ),
          subtitle: Text(
            'Jumlah percobaan mentah dan tanggal — bukan skor.',
            style: context.type.body.copyWith(color: colors.neutralFeedback),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            FutureBuilder<_FullDataCardData>(
              future: _loadFullDataCard(ref, childId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                final data = snapshot.data!;
                final stats = data.stats;
                if (stats.isEmpty && data.hintEntries == null) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Belum ada data.', style: context.type.body.copyWith(color: colors.text)),
                  );
                }

                // Flattened from `stats` rather than a second repository
                // call — every session already lives in one `stats[i].sessions`
                // list or another.
                final allSessions = [for (final s in stats) ...s.sessions]
                  ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in stats) ...[
                      _ModuleModeDataBlock(stats: s),
                      const SizedBox(height: 12),
                    ],
                    if (allSessions.isNotEmpty) ...[
                      Divider(color: colors.neutralFeedback, height: 24),
                      Text(
                        'Log sesi',
                        style: context.type.display.copyWith(color: colors.text, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      // Deliberately monospace for the whole row here, not
                      // just the date — this is the one place in the app
                      // meant to read as a raw data table rather than prose,
                      // unlike the Riwayat list below where mono stays
                      // timestamp-only (§12).
                      for (final s in allSessions)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${_formatFullDate(s.endedAt)} · ${_displayNameFor(s.module)} · '
                            '${modeLabel(s.mode)} · ${s.duration.inMinutes} menit',
                            style: context.type.mono.copyWith(color: colors.text),
                          ),
                        ),
                    ],
                    if (data.hintEntries != null) ...[
                      Divider(color: colors.neutralFeedback, height: 24),
                      _PronunciationHintDataSection(entries: data.hintEntries!),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FullDataCardData {
  const _FullDataCardData({required this.stats, required this.hintEntries});

  final List<ModuleModeStats> stats;

  /// Null when the child hasn't opted into pronunciation-hint — see
  /// [loadPronunciationHintFullData]'s own doc comment for the null-vs-empty
  /// distinction this preserves all the way to the widget layer.
  final List<PronunciationHintLogEntry>? hintEntries;
}

Future<_FullDataCardData> _loadFullDataCard(WidgetRef ref, String childId) async {
  final stats = await loadFullData(ref.read(sessionRepositoryProvider), childId);
  final hintEntries = await loadPronunciationHintFullData(
    ref.read(childRepositoryProvider),
    ref.read(pronunciationHintLogRepositoryProvider),
    childId,
  );
  return _FullDataCardData(stats: stats, hintEntries: hintEntries);
}

/// The pronunciation-hint experimental subsection inside [_FullDataCard] —
/// only ever built when [entries] is non-null upstream (the child opted in);
/// this widget itself doesn't re-check that, it just renders whatever list
/// it's handed, including the empty-but-opted-in case.
class _PronunciationHintDataSection extends StatelessWidget {
  const _PronunciationHintDataSection({required this.entries});

  final List<PronunciationHintLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saran pengucapan',
          style: context.type.display.copyWith(color: colors.text, fontSize: 16),
        ),
        const SizedBox(height: 4),
        // Constraint 4: labelled experimental/advisory every time it's
        // shown, consistent with the opt-in consent copy in
        // `child_settings_screen.dart` — never presented as an official
        // assessment.
        Text(
          'Data eksperimental dari fitur saran pengucapan — bukan penilaian resmi.',
          style: context.type.body.copyWith(color: colors.neutralFeedback, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          Text('Belum ada data pengucapan.', style: context.type.body.copyWith(color: colors.text))
        else
          // Same deliberate raw-table monospace treatment as "Log sesi"
          // above — target word, IPA, and phoneme distance are technical
          // values for a professional reader, never a WIN/TRY AGAIN label
          // (that field is never even parsed — see
          // `speech/pronunciation_hint_service.dart`).
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${_formatFullDate(entry.recordedAt)} · ${_displayNameFor(entry.module)} · '
                'target "${entry.targetWord}" · IPA: ${entry.ipaTranscription ?? '—'} · '
                'jarak fonem: ${entry.phonemeEditDistance ?? '—'}',
                style: context.type.mono.copyWith(color: colors.text, fontSize: 12),
              ),
            ),
      ],
    );
  }
}

/// One (module, mode) pair's block inside [_FullDataCard] — trial counts,
/// the independent-correct fraction, current tier, and every tier-reached
/// date on record for that pair.
class _ModuleModeDataBlock extends StatelessWidget {
  const _ModuleModeDataBlock({required this.stats});

  final ModuleModeStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final definition = _definitionFor(stats.module);
    final position = stats.currentPosition;

    // Array size doesn't apply to speak mode at all (§4.4: no array there) —
    // stated only for tap/match, where it is the second, independent dial.
    final positionText = stats.mode == ResponseMode.speak
        ? 'Tahap saat ini: ${tierLabel(position.similarityTier)}'
        : 'Tahap saat ini: ${tierLabel(position.similarityTier)} '
            '(ukuran susunan ${position.arraySize})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${definition.displayName} · ${modeLabel(stats.mode)}',
          style: context.type.body.copyWith(color: colors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Total percobaan: ${stats.totalTrials}', style: context.type.body.copyWith(color: colors.text)),
        Text(
          '${stats.independentCorrect} dari ${stats.independentAttempts} percobaan tanpa bantuan berhasil',
          style: context.type.body.copyWith(color: colors.text),
        ),
        Text(positionText, style: context.type.body.copyWith(color: colors.text)),
        if (stats.tierMilestones.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Tanggal tiap tahap tercapai:',
            style: context.type.body.copyWith(color: colors.text),
          ),
          for (final milestone in stats.tierMilestones)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '${_formatFullDate(milestone.reachedAt)} — ${tierLabel(milestone.tier)}',
                style: context.type.mono.copyWith(color: colors.neutralFeedback, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}

/// The "Perjalanan" card (§8 milestone timeline) — one categorical line per
/// active (module, mode): "sedang berlatih dengan ..." or, once the dial
/// engine's ceiling is reached, "sudah menguasai ...". Read straight off the
/// current [LadderPosition] via the same [ModuleDefinition.similarityTierCopy]
/// the child screen's own instruction copy uses — never a level number, never
/// a percentage, never a graph axis.
class _MilestoneTimeline extends ConsumerWidget {
  const _MilestoneTimeline({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return _GuardianCard(
      title: 'Perjalanan',
      child: FutureBuilder<List<_MilestoneEntry>>(
        future: _loadMilestones(ref, childId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Text(
              'Belum ada mode aktif untuk anak ini.',
              style: context.type.body.copyWith(color: colors.text),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${entry.moduleLabel} · ${entry.modeLabel}: ${entry.statusText}',
                    style: context.type.body.copyWith(color: colors.text),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<List<_MilestoneEntry>> _loadMilestones(WidgetRef ref, String childId) async {
    final child = await ref.read(childRepositoryProvider).getChild(childId);
    if (child == null) return const [];

    final persistence = ref.read(ladderPersistenceProvider);
    final dialEngine = ref.read(dialEngineProvider);

    final entries = <_MilestoneEntry>[];
    for (final module in ModuleId.values) {
      final definition = _definitionFor(module);
      for (final mode in child.availableModes) {
        final position = await persistence.load(childId: childId, module: module, mode: mode);
        final tierCopy = definition.similarityTierCopy[position.similarityTier];
        final statusText = dialEngine.isAtCeiling(position, mode)
            ? 'sudah menguasai — $tierCopy'
            : 'sedang berlatih dengan $tierCopy';
        entries.add(
          _MilestoneEntry(
            moduleLabel: definition.displayName,
            modeLabel: modeLabel(mode),
            statusText: statusText,
          ),
        );
      }
    }
    return entries;
  }
}

class _MilestoneEntry {
  const _MilestoneEntry({
    required this.moduleLabel,
    required this.modeLabel,
    required this.statusText,
  });

  final String moduleLabel;
  final String modeLabel;
  final String statusText;
}
