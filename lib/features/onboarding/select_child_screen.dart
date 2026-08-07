import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';

/// Select-child screen — **guardian surface.**
///
/// Source-of-truth §9: "Select-child screen precedes session setup." One guardian
/// account → many child profiles. The demo shows one child end-to-end, but
/// multi-child is true underneath, and this screen is where that shows.
///
/// Placeholder: proves the repository wiring and navigation work. Real intake,
/// account setup, and the §12 visual treatment come later.
///
/// Note it reads through `childRepositoryProvider` — swapping in
/// `FirestoreChildRepository` at the composition root changes nothing in this file.
class SelectChildScreen extends ConsumerWidget {
  const SelectChildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(childRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih anak')),
      body: StreamBuilder<List<Child>>(
        stream: repo.watchChildren(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final children = snapshot.data!;
          if (children.isEmpty) {
            return Center(
              child: Text('Belum ada profil anak.', style: context.type.body),
            );
          }
          return ListView.builder(
            itemCount: children.length,
            itemBuilder: (context, i) {
              final child = children[i];
              return ListTile(
                // 44pt minimum (§11) — ListTile's default is taller, but stated
                // so a future redesign can't quietly shrink it.
                minVerticalPadding: TemanKuMetrics.minTouchTarget / 4,
                title: Text(child.name, style: context.type.display),
                subtitle: Text(
                  'Mode: ${child.availableModes.map((m) => m.name).join(", ")}',
                  style: context.type.body,
                ),
                onTap: () {
                  ref.read(selectedChildIdProvider.notifier).state = child.id;
                  context.push(Routes.sessionFor(child.id));
                },
                // A fixed-width box, not a bare Row — ListTile.trailing queries
                // its child's intrinsic width, and IconButton reports that
                // unreliably inside a Row, which throws a layout assertion at
                // phone width once three buttons are packed in here. Giving it
                // a hard bound sidesteps the intrinsic query entirely.
                trailing: SizedBox(
                  width: 4 * 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Direct dev/QA doorways into tap/match/speak mode on
                      // Makanan specifically, bypassing the real per-child mode
                      // selection `features/child_session/day_arc_screen.dart`
                      // does (that's what the row's own onTap below leads to —
                      // this row is the actual guardian path). Kept only for
                      // testing a fixed mode+module pair directly.
                      IconButton(
                        icon: const Icon(Icons.touch_app_outlined),
                        tooltip: 'Latihan menunjuk (Makanan)',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push(
                          Routes.tapSessionFor(child.id, ModuleId.makanan),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.extension_outlined),
                        tooltip: 'Latihan mencocokkan (Makanan)',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push(
                          Routes.matchSessionFor(child.id, ModuleId.makanan),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic_outlined),
                        tooltip: 'Latihan mengucap (Makanan)',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push(
                          Routes.speakSessionFor(child.id, ModuleId.makanan),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_book_outlined),
                        tooltip: 'Catatan wali',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push(Routes.guardianFor(child.id)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
