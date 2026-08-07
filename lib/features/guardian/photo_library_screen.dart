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
import 'package:temanku/core/theme/temanku_theme.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text('Foto · ${definition.displayName}')),
      body: StreamBuilder<List<Photo>>(
        stream: repo.watchPhotos(childId: childId, module: module),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Belum ada foto tersimpan.', style: context.type.body),
              ),
            );
          }

          final targets = photos.where((p) => p.category == PhotoCategory.target).toList();
          final distractors = photos.where((p) => p.category == PhotoCategory.distractor).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CategorySection(title: definition.targetCategoryLabel, photos: targets),
              // Keluarga has no distractor photos of its own — its
              // distractors are bundled stranger-library assets
              // (module_definition.dart usesBundledDistractors), never
              // per-child uploads — so this section simply never renders
              // there rather than showing an always-empty "0 foto" block.
              if (distractors.isNotEmpty) ...[
                const SizedBox(height: 24),
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
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${photos.length})',
          style: context.type.display.copyWith(color: colors.text, fontSize: 20),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) => _PhotoTile(photo: photos[i]),
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.neutralFeedback),
        borderRadius: BorderRadius.circular(12),
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
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<_PhotoAction>(
                    tooltip: 'Pilihan foto',
                    icon: CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.background,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              photo.label ?? '(belum diberi nama)',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.body.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
