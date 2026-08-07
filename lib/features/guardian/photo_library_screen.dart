/// Photo library — view and manage a child's uploaded photos, per module.
///
/// Source-of-truth §5.5: "guardians can re-tag or remove photos at any
/// time" — this screen is that standing-correction surface, not a new idea.
/// Rename reuses [EditLabelDialog], the same dialog the upload flow's saved
/// nudge already opens; delete goes through [PhotoRepository.removePhoto],
/// which removes the on-device file as well as the record (§10/§11 — a
/// removed photo must not survive on disk).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/widgets/edit_label_dialog.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

class PhotoLibraryScreen extends ConsumerWidget {
  const PhotoLibraryScreen({super.key, required this.childId, required this.module});

  final String childId;
  final ModuleId module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = _definitionFor(module);
    final repo = ref.watch(photoRepositoryProvider);

    return TkScreen(
      title: 'Foto · ${definition.displayName}',
      child: StreamBuilder<List<Photo>>(
        stream: repo.watchPhotos(childId: childId, module: module),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const TkLoading(label: 'Memuat foto…');

          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const TkEmptyState(
              message: 'Belum ada foto tersimpan.',
              icon: Icons.photo_library_outlined,
            );
          }

          final targets = photos.where((p) => p.category == PhotoCategory.target).toList();
          final distractors = photos.where((p) => p.category == PhotoCategory.distractor).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategorySection(title: definition.targetCategoryLabel, photos: targets),
              // Keluarga has no distractor photos of its own — its
              // distractors are bundled stranger-library assets
              // (module_definition.dart usesBundledDistractors), never
              // per-child uploads — so this section simply never renders
              // there rather than showing an always-empty "0 foto" block.
              if (distractors.isNotEmpty) ...[
                const SizedBox(height: TkSpace.xl),
                _CategorySection(title: definition.distractorCategoryLabel, photos: distractors),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.photos});

  final String title;
  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    return TkSection(
      label: title,
      // The count moves into a badge rather than being spliced into the
      // heading string — the heading is then the category's own words, and
      // "how many" stays scannable without re-reading the label.
      trailing: TkBadge(label: '${photos.length} foto'),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: TkSpace.sm,
          crossAxisSpacing: TkSpace.sm,
          childAspectRatio: 0.85,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) => _PhotoTile(photo: photos[i]),
      ),
    );
  }
}

enum _PhotoAction { rename, delete }

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});

  final Photo photo;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => EditLabelDialog(initialLabel: photo.label ?? ''),
    );
    if (newLabel == null || newLabel.isEmpty || newLabel == photo.label) return;
    await ref.read(photoRepositoryProvider).updatePhoto(photo.copyWith(label: newLabel));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto ini?'),
        content: Text(
          photo.label != null
              ? 'Foto "${photo.label}" akan dihapus dari perangkat. Tindakan ini tidak bisa dibatalkan.'
              : 'Foto ini akan dihapus dari perangkat. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(photoRepositoryProvider).removePhoto(photo.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unnamed = photo.label == null || photo.label!.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: TkStroke.regular),
        borderRadius: TkRadius.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoImage(localPath: photo.localPath),
                Positioned(
                  top: TkSpace.xxs,
                  right: TkSpace.xxs,
                  child: PopupMenuButton<_PhotoAction>(
                    tooltip: 'Pilihan foto',
                    // Opaque plate, not a translucent overlay: this control
                    // sits on top of arbitrary guardian photography, and a
                    // see-through affordance disappears against a busy one.
                    icon: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.border,
                          width: TkStroke.hairline,
                        ),
                      ),
                      child: Icon(Icons.more_vert, size: 16, color: colors.text),
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case _PhotoAction.rename:
                          unawaited(_rename(context, ref));
                        case _PhotoAction.delete:
                          unawaited(_delete(context, ref));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _PhotoAction.rename, child: Text('Ubah nama')),
                      PopupMenuItem(value: _PhotoAction.delete, child: Text('Hapus')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TkSpace.xs,
              vertical: TkSpace.xs,
            ),
            child: Text(
              unnamed ? 'Belum diberi nama' : photo.label!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // An unnamed photo is a soft nudge, not a fault — muted, and
              // deliberately not the neutralFeedback token, which would read
              // as a verdict on the guardian's upload.
              style: context.type.bodySm.copyWith(
                color: unnamed ? colors.textMuted : colors.text,
                fontStyle: unnamed ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
