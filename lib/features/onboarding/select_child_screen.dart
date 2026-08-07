import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/features/guardian/session_recap.dart' show modeLabel;

/// Select-child screen — **guardian surface.**
///
/// Source-of-truth §9: "Select-child screen precedes session setup." One guardian
/// account → many child profiles. The demo shows one child end-to-end, but
/// multi-child is true underneath, and this screen is where that shows.
///
/// Note it reads through `childRepositoryProvider` — swapping in
/// `FirestoreChildRepository` at the composition root changes nothing in this file.
///
/// **Layout note.** This was a `ListTile` per child with four bare
/// [IconButton]s crammed into a fixed-width trailing box — a workaround for
/// `ListTile.trailing` querying intrinsic widths, and visually the densest
/// thing in the app. It is now a card per child: the child's own name leads,
/// the one real guardian path (start a session) is the card itself, and the
/// dev/QA mode doorways are demoted to a labelled secondary row where they
/// can no longer be mistaken for the primary action.
class SelectChildScreen extends ConsumerWidget {
  const SelectChildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(childRepositoryProvider);

    return TkScreen(
      title: 'Pilih anak',
      child: StreamBuilder<List<Child>>(
        stream: repo.watchChildren(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(label: 'Memuat profil…');

          final children = snapshot.data!;
          if (children.isEmpty) {
            return const TkEmptyState(
              message: 'Belum ada profil anak.',
              icon: Icons.person_outline,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                _ChildCard(
                  child: child,
                  onOpen: () {
                    ref.read(selectedChildIdProvider.notifier).state = child.id;
                    context.push(Routes.sessionFor(child.id));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.onOpen});

  final Child child;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TkCard(
      title: child.name,
      leading: _Avatar(name: child.name),
      onTap: onOpen,
      trailing: Icon(Icons.chevron_right, color: c.textMuted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (child.availableModes.isEmpty)
            const TkEmptyState(
              message: 'Belum ada mode aktif. Isi intake dulu.',
              compact: true,
            )
          else
            Wrap(
              spacing: TkSpace.xxs,
              runSpacing: TkSpace.xxs,
              children: [
                for (final mode in child.availableModes)
                  TkBadge(label: modeLabel(mode), icon: _iconFor(mode)),
              ],
            ),
          const SizedBox(height: TkSpace.sm),
          Divider(color: c.border, height: TkSpace.md),
          Text(
            // Named for what it is. These bypass the real per-child mode
            // selection `day_arc_screen.dart` does — keeping them unlabelled
            // next to the primary path is how a guardian ends up in a mode
            // intake never enabled.
            'Pintasan uji (Makanan)',
            style: context.type.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TkSpace.xs),
          TkButtonRow(
            children: [
              TkButton.quiet(
                label: 'Menunjuk',
                icon: Icons.touch_app_outlined,
                onPressed: () => context.push(
                  Routes.tapSessionFor(child.id, ModuleId.makanan),
                ),
              ),
              TkButton.quiet(
                label: 'Mencocokkan',
                icon: Icons.extension_outlined,
                onPressed: () => context.push(
                  Routes.matchSessionFor(child.id, ModuleId.makanan),
                ),
              ),
              TkButton.quiet(
                label: 'Mengucap',
                icon: Icons.mic_outlined,
                onPressed: () => context.push(
                  Routes.speakSessionFor(child.id, ModuleId.makanan),
                ),
              ),
              TkButton.quiet(
                label: 'Catatan wali',
                icon: Icons.menu_book_outlined,
                onPressed: () => context.push(Routes.guardianFor(child.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ResponseMode mode) => switch (mode) {
        ResponseMode.tap => Icons.touch_app_outlined,
        ResponseMode.match => Icons.extension_outlined,
        ResponseMode.speak => Icons.mic_outlined,
      };
}

/// The child's initial on a tinted plate.
///
/// No photo: the guardian's uploads belong to the modules, and a face here
/// would imply a profile picture the app never asks for.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primaryAccentWash,
        borderRadius: TkRadius.sm,
      ),
      child: Text(
        initial,
        style: context.type.title.copyWith(color: c.primaryAccent),
      ),
    );
  }
}
