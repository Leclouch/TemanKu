import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                trailing: IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: 'Catatan wali',
                  onPressed: () => context.push(Routes.guardianFor(child.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
