import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/features/guardian/pronunciation_hint_full_data.dart';
import 'package:temanku/features/guardian/session_full_data.dart';
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
    final colors = context.colors;
    return TkScreen(
      title: 'Catatan wali',
      // Reached both by a push (from `select_child_screen.dart`, where
      // `canPop` is already true and the default AppBar back arrow would
      // work) and by intake's `context.go(...)` (`intake_screen.dart`),
      // which replaces the whole stack and leaves nothing to pop — so the
      // default-only behaviour silently drops the arrow on that second path.
      // Falling back to the select-child screen keeps it working either way.
      onBack: () =>
          context.canPop() ? context.pop() : context.go(Routes.selectChild),
      decor: const TkScreenDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Each section sits on its own faint colour zone rather than the
          // bare cream ground — the same "each page/section owns a colour"
          // move the reference site makes at full-bleed scale
          // (`referenceimages/maxima9.png`, `maxima13.png`), scaled down to
          // section width here. Orange for "do this once", blue for "read
          // this" — the same split `_CardIcon`'s tone already draws below.
          _SectionZone(
            tint: colors.primaryAccentWash,
            child: TkSection(
              label: 'Persiapan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntakeEntryPoint(childId: childId),
                  _UploadEntryPoint(childId: childId),
                  _SettingsEntryPoint(childId: childId),
                  _LevelSettingsEntryPoint(childId: childId),
                  _ModuleListCard(childId: childId),
                ],
              ),
            ),
          ),
          const SizedBox(height: TkSpace.lg),
          _SectionZone(
            // 0.08 read as grey, not blue, against the cream ground — too
            // weak a tint to carry a hue at this fill area. 0.18 is the
            // point it visually balances the orange zone above, which reads
            // through a hand-picked opaque wash token rather than a derived
            // alpha.
            tint: colors.info.withValues(alpha: 0.18),
            child: TkSection(
              label: 'Catatan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionRecapCard(childId: childId),
                  _FullDataCard(childId: childId),
                  _MilestoneTimeline(childId: childId),
                  _SessionHistory(childId: childId),
                ],
              ),
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

/// Day/month/year — the "Data lengkap" section's own date format, distinct
/// from the day/month-only trailing timestamp the Riwayat list below uses.
/// This section is meant to stand alone as a reference table (a teacher
/// might read it long after the session, possibly a year on), so the year
/// stays explicit rather than assumed.
String _formatFullDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

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
      leading: const _CardIcon(icon: LucideIcons.clipboardPen),
      child: TkButton.secondary(
        label: 'Isi intake',
        icon: LucideIcons.arrowRight,
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
      leading: const _CardIcon(icon: LucideIcons.slidersHorizontal),
      child: TkButton.secondary(
        label: 'Buka pengaturan',
        icon: LucideIcons.arrowRight,
        onPressed: () => context.push(Routes.childSettingsFor(childId)),
      ),
    );
  }
}

/// The "Unggah foto" card's real entry point (§5.1/§5.2) — picks a module,
/// then hands off to [PhotoUploadScreen]. Quality gate, variety nudge, and the
/// no-network-call guarantee all live there; this card is just the doorway.
//
/// The guardian-only ladder override. The detailed screen derives its choices
/// from the engine so this card is only a doorway, not a second level model.
class _LevelSettingsEntryPoint extends StatelessWidget {
  const _LevelSettingsEntryPoint({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      title: 'Tahap latihan',
      subtitle:
          'Pilih tahap yang tersedia untuk setiap modul dan cara menjawab.',
      leading: const _CardIcon(icon: LucideIcons.slidersHorizontal),
      child: TkButton.secondary(
        label: 'Atur tahap',
        icon: LucideIcons.arrowRight,
        onPressed: () => context.push(Routes.levelSettingsFor(childId)),
      ),
    );
  }
}

/// The "Unggah foto" card's real entry point.
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
      leading: const _CardIcon(icon: LucideIcons.imagePlus),
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
                  onPressed: () =>
                      context.push(Routes.photoUploadFor(childId, module)),
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
                  icon: LucideIcons.images,
                  onPressed: () =>
                      context.push(Routes.photoLibraryFor(childId, module)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "Modul" card — the app's full intended module scope in one place,
/// inline in the normal guardian flow rather than on a separate roadmap
/// page. Makanan and Keluarga are wired end-to-end today (photo pipeline,
/// ladder, all three response modes); the four rows below them are
/// deliberate future scope with genuinely nothing behind them yet — never
/// used for work that's merely incomplete or partially wired (that's a bug
/// to fix, not a placeholder to label). Kept muted, badged, and inert rather
/// than hidden, so a reviewer sees the intended scope without hunting for it.
class _ModuleListCard extends StatelessWidget {
  const _ModuleListCard({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      title: 'Modul',
      subtitle: 'Modul yang sudah aktif, dan yang masih dalam pengembangan.',
      leading: const _CardIcon(icon: LucideIcons.layoutGrid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActiveModuleTile(
            childId: childId,
            module: ModuleId.makanan,
            icon: LucideIcons.utensils,
            description: 'Mengenali jenis makanan dan minuman sehari-hari',
          ),
          _ActiveModuleTile(
            childId: childId,
            module: ModuleId.keluarga,
            icon: LucideIcons.house,
            description: 'Mengenali anggota keluarga dan benda-benda di rumah',
          ),
          const _PlaceholderModuleTile(
            icon: LucideIcons.coins,
            name: 'Uang',
            description: 'Mengenali apakah uang cukup untuk membeli sesuatu',
          ),
          const _PlaceholderModuleTile(
            icon: LucideIcons.trash2,
            name: 'Sampah',
            description: 'Memilah sampah organik dan non-organik',
          ),
          const _PlaceholderModuleTile(
            icon: LucideIcons.shieldAlert,
            name: 'Pengenalan Keamanan',
            description: 'Membedakan benda atau situasi aman dan berbahaya',
          ),
          const _PlaceholderModuleTile(
            icon: LucideIcons.userCheck,
            name: 'Pengenalan Orang Terpercaya',
            description: 'Mengenali orang yang bisa dimintai tolong',
          ),
        ],
      ),
    );
  }
}

/// One working module's row inside [_ModuleListCard] — real navigation, to
/// the same photo-upload doorway [_UploadEntryPoint] above already offers
/// for this module, since "what does this module do" is best answered by
/// showing the guardian its actual content rather than adding a second,
/// competing destination.
class _ActiveModuleTile extends StatelessWidget {
  const _ActiveModuleTile({
    required this.childId,
    required this.module,
    required this.icon,
    required this.description,
  });

  final String childId;
  final ModuleId module;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _ModuleTileShell(
      icon: icon,
      name: _displayNameFor(module),
      description: description,
      trailing: Icon(LucideIcons.arrowRight,
          size: 16, color: context.colors.textMuted),
      onTap: () => context.push(Routes.photoUploadFor(childId, module)),
    );
  }
}

/// One not-yet-built module's row inside [_ModuleListCard]. Tapping never
/// navigates or throws — it only ever surfaces [_belumTersediaMessage] in a
/// snackbar, so an idle tap from a curious guardian reads as calm and
/// intentional rather than broken.
class _PlaceholderModuleTile extends StatelessWidget {
  const _PlaceholderModuleTile({
    required this.icon,
    required this.name,
    required this.description,
  });

  final IconData icon;
  final String name;
  final String description;

  static const _belumTersediaMessage = 'Modul ini sedang dikembangkan';

  @override
  Widget build(BuildContext context) {
    return _ModuleTileShell(
      icon: icon,
      name: name,
      description: description,
      trailing: const _BelumTersediaBadge(),
      muted: true,
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_belumTersediaMessage)),
      ),
    );
  }
}

/// The one shared "Belum tersedia" badge every placeholder module row uses —
/// defined once so the muted/planned visual language stays identical across
/// all four rows rather than drifting per call site.
class _BelumTersediaBadge extends StatelessWidget {
  const _BelumTersediaBadge();

  @override
  Widget build(BuildContext context) {
    return const TkBadge(label: 'Belum tersedia');
  }
}

/// Shared row layout for [_ActiveModuleTile] and [_PlaceholderModuleTile] —
/// same icon-plate/name/description/trailing shape either way, so "live" and
/// "planned" read as one consistent list and differ only in [muted] and
/// [trailing], never in structure.
class _ModuleTileShell extends StatelessWidget {
  const _ModuleTileShell({
    required this.icon,
    required this.name,
    required this.description,
    required this.trailing,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String name;
  final String description;
  final Widget trailing;
  final VoidCallback? onTap;

  /// True for a not-yet-built module — dims the whole row via one shared
  /// [Opacity] wrap rather than threading a separate muted colour through
  /// every child, so this stays the single place that visual rule lives.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: muted ? c.neutralWash : c.primaryAccentWash,
            borderRadius: TkRadius.sm,
          ),
          child: Icon(icon,
              size: 18, color: muted ? c.textMuted : c.primaryAccent),
        ),
        const SizedBox(width: TkSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: context.type.bodySm
                    .copyWith(color: c.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(description,
                  style: context.type.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: TkSpace.xs),
        trailing,
      ],
    );

    final content = ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TkSpace.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: muted ? Opacity(opacity: 0.55, child: row) : row,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: TkRadius.sm, onTap: onTap, child: content),
    );
  }
}

/// A section's faint colour ground — see the call sites above for why.
/// Padding is intentionally generous so the tint reads as a zone the cards
/// sit *in*, not a border hugging them.
class _SectionZone extends StatelessWidget {
  const _SectionZone({required this.tint, required this.child});

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TkSpace.sm),
      decoration: BoxDecoration(color: tint, borderRadius: TkRadius.lg),
      child: child,
    );
  }
}

/// The tinted glyph plate every card on this screen leads with.
///
/// Scanning a column of same-shaped cards by their titles alone is slow; a
/// distinct silhouette per card gives the eye somewhere to land first — which
/// only works if the plates don't all share one colour. [accent] defaults to
/// the orange "do this" tone for the "Persiapan" section; the "Catatan"
/// section (read-only, past tense) passes [_CardIconAccent.info] instead, so
/// the two card groups the screen's own doc comment describes ("things I do
/// once" vs "things I come back to read") are visually, not just spatially,
/// distinct.
enum _CardIconAccent { primary, info }

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon, this.accent = _CardIconAccent.primary});

  final IconData icon;
  final _CardIconAccent accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, ink) = switch (accent) {
      _CardIconAccent.primary => (c.primaryAccentWash, c.primaryAccent),
      _CardIconAccent.info => (c.info.withValues(alpha: 0.14), c.info),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: fill, borderRadius: TkRadius.sm),
      child: Icon(icon, size: 21, color: ink),
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
      leading: const _CardIcon(
          icon: LucideIcons.notebookPen, accent: _CardIconAccent.info),
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
            style:
                context.type.display.copyWith(color: colors.text, fontSize: 18),
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
                    child: Text('Belum ada data.',
                        style: context.type.body.copyWith(color: colors.text)),
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
                        style: context.type.display
                            .copyWith(color: colors.text, fontSize: 16),
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
                            style:
                                context.type.mono.copyWith(color: colors.text),
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

Future<_FullDataCardData> _loadFullDataCard(
    WidgetRef ref, String childId) async {
  final stats =
      await loadFullData(ref.read(sessionRepositoryProvider), childId);
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
          style:
              context.type.display.copyWith(color: colors.text, fontSize: 16),
        ),
        const SizedBox(height: 4),
        // Constraint 4: labelled experimental/advisory every time it's
        // shown, consistent with the opt-in consent copy in
        // `child_settings_screen.dart` — never presented as an official
        // assessment.
        Text(
          'Data eksperimental dari fitur saran pengucapan — bukan penilaian resmi.',
          style: context.type.body.copyWith(
              color: colors.neutralFeedback, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          Text('Belum ada data pengucapan.',
              style: context.type.body.copyWith(color: colors.text))
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
                'target "${entry.targetWord}" · IPA: ${entry.predictedIpa ?? '—'} · '
                'jarak fonem: ${entry.distance ?? '—'}',
                style: context.type.mono
                    .copyWith(color: colors.text, fontSize: 12),
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
          style: context.type.body
              .copyWith(color: colors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Total percobaan: ${stats.totalTrials}',
            style: context.type.body.copyWith(color: colors.text)),
        Text(
          '${stats.independentCorrect} dari ${stats.independentAttempts} percobaan tanpa bantuan berhasil',
          style: context.type.body.copyWith(color: colors.text),
        ),
        Text(positionText,
            style: context.type.body.copyWith(color: colors.text)),
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
                style: context.type.mono
                    .copyWith(color: colors.neutralFeedback, fontSize: 12),
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
    return TkCard(
      title: 'Perjalanan',
      leading: const _CardIcon(
          icon: LucideIcons.route, accent: _CardIconAccent.info),
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
                    tone: entry.mastered
                        ? TkBadgeTone.success
                        : TkBadgeTone.neutral,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<List<_MilestoneEntry>> _loadMilestones(
      WidgetRef ref, String childId) async {
    final child = await ref.read(childRepositoryProvider).getChild(childId);
    if (child == null) return const [];

    final persistence = ref.read(ladderPersistenceProvider);
    final dialEngine = ref.read(dialEngineProvider);

    final entries = <_MilestoneEntry>[];
    for (final module in ModuleId.values) {
      final definition = _definitionFor(module);
      for (final mode in child.availableModes) {
        final position = await persistence.load(
            childId: childId, module: module, mode: mode);
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
      leading: const _CardIcon(
          icon: LucideIcons.history, accent: _CardIconAccent.info),
      child: FutureBuilder<List<SessionSummary>>(
        future: sessions.getSessionHistory(childId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(compact: true);
          final history = snapshot.data!;
          if (history.isEmpty) {
            return const TkEmptyState(
                message: 'Belum ada sesi.', compact: true);
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
                  const SizedBox(width: TkSpace.xxs),
                  // The one badge that isn't just naming a fixed axis
                  // (module/mode) — it's the fact this whole feature was
                  // missing before: whether a mastery moment happened this
                  // session, distinguishable at a glance from an early exit.
                  TkBadge(
                    label: sessionOutcomeLabel(summary.outcome),
                    tone: summary.outcome == SessionOutcome.completed
                        ? TkBadgeTone.success
                        : TkBadgeTone.neutral,
                  ),
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
