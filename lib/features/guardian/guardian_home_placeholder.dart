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
import 'package:temanku/data/models/session.dart';
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
