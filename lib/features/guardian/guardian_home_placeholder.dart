import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/features/guardian/session_recap.dart';

/// Guardian home — **IT-2.**
///
/// Reads tokens from the same `core/design/` source as the child screen, at
/// the guardian temperature — that shared source is the thing this file is
/// proving.
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
///   - **Milestone timeline** ([_MilestoneTimeline], §8) — one categorical
///     mastered/emerging line per active (module, mode), read straight off the
///     current [LadderPosition] and the module's own [ModuleDefinition.similarityTierCopy].
///     Not a performance graph, and not a history of past positions — there is
///     nowhere in this codebase that persists a position's *prior* values, only
///     its current one, so "over time" here means "as of now," honestly.
///
/// **Layout note.** The five cards are grouped under two [TkSection] headings
/// rather than stacked flat. Five equally-weighted cards in one column give a
/// guardian no way to tell setup ("things I do once") from observation
/// ("things I come back to read"), and an undifferentiated wall of options is
/// the specific pattern the ADHD guidance flags as a freeze trigger.
class GuardianHomePlaceholder extends ConsumerWidget {
  const GuardianHomePlaceholder({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TkScreen(
      title: 'Catatan wali',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TkSection(
            label: 'Persiapan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IntakeEntryPoint(childId: childId),
                _UploadEntryPoint(childId: childId),
                _SettingsEntryPoint(childId: childId),
              ],
            ),
          ),
          const SizedBox(height: TkSpace.lg),
          TkSection(
            label: 'Catatan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionRecapCard(childId: childId),
                _MilestoneTimeline(childId: childId),
                _SessionHistory(childId: childId),
              ],
            ),
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

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// The "Intake" card's real entry point (§8) — hands off to [IntakeScreen].
/// Selects modes only; never sets a starting difficulty.
class _IntakeEntryPoint extends StatelessWidget {
  const _IntakeEntryPoint({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      title: 'Intake',
      subtitle: 'Satu pertanyaan per mode. Memilih mode yang tersedia — '
          'bukan memperkirakan level.',
      leading: const _CardIcon(icon: Icons.assignment_outlined),
      child: TkButton.secondary(
        label: 'Isi intake',
        icon: Icons.arrow_forward,
        onPressed: () => context.push(Routes.intakeFor(childId)),
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
    return TkCard(
      title: 'Pengaturan anak',
      subtitle: 'Bantuan mode bicara (contoh ucapan + saran pengucapan) dan '
          'pengaturan suara per anak.',
      leading: const _CardIcon(icon: Icons.tune_outlined),
      child: TkButton.secondary(
        label: 'Buka pengaturan',
        icon: Icons.arrow_forward,
        onPressed: () => context.push(Routes.childSettingsFor(childId)),
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
    final c = context.colors;
    return TkCard(
      title: 'Foto',
      subtitle: 'Quality gate dan ajakan variasi (lima foto berbeda — '
          'anjuran, bukan syarat).',
      leading: const _CardIcon(icon: Icons.add_a_photo_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah foto baru',
            style: context.type.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TkSpace.xs),
          TkButtonRow(
            children: [
              for (final module in ModuleId.values)
                TkButton.secondary(
                  label: _displayNameFor(module),
                  onPressed: () => context.push(Routes.photoUploadFor(childId, module)),
                ),
            ],
          ),
          const SizedBox(height: TkSpace.md),
          Text(
            'Lihat, ubah nama, atau hapus foto tersimpan',
            style: context.type.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TkSpace.xs),
          TkButtonRow(
            children: [
              for (final module in ModuleId.values)
                TkButton.quiet(
                  label: _displayNameFor(module),
                  icon: Icons.photo_library_outlined,
                  onPressed: () => context.push(Routes.photoLibraryFor(childId, module)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The tinted glyph plate every card on this screen leads with.
///
/// Scanning a column of same-shaped cards by their titles alone is slow; a
/// distinct silhouette per card gives the eye somewhere to land first.
class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.primaryAccentWash,
        borderRadius: TkRadius.sm,
      ),
      child: Icon(icon, size: 21, color: c.primaryAccent),
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
    final c = context.colors;
    final sessions = ref.watch(sessionRepositoryProvider);
    return TkCard(
      title: 'Ringkasan sesi',
      leading: const _CardIcon(icon: Icons.notes_outlined),
      child: FutureBuilder<List<SessionSummary>>(
        future: sessions.getSessionHistory(childId, limit: 1),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(compact: true);
          final latest = snapshot.data!;
          if (latest.isEmpty) {
            return const TkEmptyState(
              message: 'Belum ada sesi. Ringkasan muncul setelah sesi pertama.',
              compact: true,
            );
          }
          return Text(
            buildSessionRecap(latest.first),
            style: context.type.body.copyWith(color: c.text),
          );
        },
      ),
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
    return TkCard(
      title: 'Perjalanan',
      leading: const _CardIcon(icon: Icons.timeline_outlined),
      child: FutureBuilder<List<_MilestoneEntry>>(
        future: _loadMilestones(ref, childId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(compact: true);
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const TkEmptyState(
              message: 'Belum ada mode aktif untuk anak ini.',
              compact: true,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries)
                TkDetailRow(
                  label: '${entry.moduleLabel} · ${entry.modeLabel}',
                  value: entry.statusText,
                  // The badge states the same thing the sentence does — it is
                  // a scanning aid, never the only carrier of the meaning.
                  trailing: TkBadge(
                    label: entry.mastered ? 'menguasai' : 'berlatih',
                    tone: entry.mastered ? TkBadgeTone.success : TkBadgeTone.neutral,
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
        final mastered = dialEngine.isAtCeiling(position, mode);
        entries.add(
          _MilestoneEntry(
            moduleLabel: definition.displayName,
            modeLabel: modeLabel(mode),
            mastered: mastered,
            statusText: mastered
                ? 'Sudah menguasai — $tierCopy'
                : 'Sedang berlatih dengan $tierCopy',
          ),
        );
      }
    }
    return entries;
  }
}

/// Proves the session repository wiring end-to-end against the in-memory fake.
/// Renders duration + dials, deliberately no score of any kind.
class _SessionHistory extends ConsumerWidget {
  const _SessionHistory({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sessions = ref.watch(sessionRepositoryProvider);
    return TkCard(
      title: 'Riwayat',
      leading: const _CardIcon(icon: Icons.history_outlined),
      child: FutureBuilder<List<SessionSummary>>(
        future: sessions.getSessionHistory(childId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(compact: true);
          final history = snapshot.data!;
          if (history.isEmpty) {
            return const TkEmptyState(message: 'Belum ada sesi.', compact: true);
          }
          return Column(
            children: [
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0) Divider(color: c.border, height: TkSpace.lg),
                _SessionRow(summary: history[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TkBadge(label: summary.module.name),
                  const SizedBox(width: TkSpace.xxs),
                  TkBadge(label: summary.mode.name, tone: TkBadgeTone.info),
                ],
              ),
              const SizedBox(height: TkSpace.xs),
              Text(
                buildSessionRecap(summary),
                style: t.bodySm.copyWith(color: c.text),
              ),
            ],
          ),
        ),
        const SizedBox(width: TkSpace.sm),
        Text(
          // Timestamps are the mono role's only job (§12).
          '${summary.endedAt.day}/${summary.endedAt.month}',
          style: t.mono.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _MilestoneEntry {
  const _MilestoneEntry({
    required this.moduleLabel,
    required this.modeLabel,
    required this.statusText,
    required this.mastered,
  });

  final String moduleLabel;
  final String modeLabel;
  final String statusText;
  final bool mastered;
}
