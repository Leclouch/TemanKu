import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/session.dart';

/// Guardian home — **IT-2. Placeholder: shows where each surface will live.**
///
/// Reads tokens from the same `core/theme/` source as the child screen, at the
/// guardian temperature — that shared source is the thing this file is proving.
///
/// The four surfaces stubbed below, with their source-of-truth constraints:
///   - **Intake** (§8) — per-child, one behavioural question per mode, selecting
///     available *modes*, never predicting levels. Never a report, never a score.
///   - **Upload flow** (§5) — quality gate, variety coaching toward five varied
///     photos as a **soft nudge, never a hard gate**, label prompt on low
///     classifier confidence. Home of the "photo becomes the task" moment (§12).
///   - **Post-session summary** (§8) — descriptive sentences, **notebook not
///     dashboard**. Duration, mode, dial-specific observations. No percentages,
///     no accuracy stats.
///   - **Milestone timeline** (§8) — categorical mastered/emerging over time, not
///     a performance graph.
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
          const _Stub(
            title: 'Intake',
            body: 'Satu pertanyaan per mode. Memilih mode yang tersedia — '
                'bukan memperkirakan level. TODO(IT-2).',
          ),
          const _Stub(
            title: 'Unggah foto',
            body: 'Quality gate, ajakan variasi (lima foto berbeda — anjuran, '
                'bukan syarat), label bila AI ragu. TODO(IT-2) Day 2.',
          ),
          const _Stub(
            title: 'Ringkasan sesi',
            body: 'Kalimat deskriptif, bukan angka. TODO(IT-2) Day 4.',
          ),
          const _Stub(
            title: 'Perjalanan',
            body: 'Milestone timeline — kategori yang sudah dikuasai, '
                'bukan grafik nilai. TODO(IT-2) Day 4.',
          ),
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
                        '${s.duration.inMinutes} menit · ${s.ladderAtEnd}\n'
                        '${s.observations.join(" ")}',
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

class _Stub extends StatelessWidget {
  const _Stub({required this.title, required this.body});

  final String title;
  final String body;

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
            Text(body, style: context.type.body.copyWith(color: colors.text)),
          ],
        ),
      ),
    );
  }
}
