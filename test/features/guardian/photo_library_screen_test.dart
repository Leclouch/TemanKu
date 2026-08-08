import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/features/guardian/photo_library_screen.dart';

const _childId = 'child_1';
const _module = ModuleId.makanan;

Widget _buildApp(InMemoryPhotoRepository repo) => ProviderScope(
      overrides: [photoRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: TemanKuTheme.guardian,
        home: const PhotoLibraryScreen(childId: _childId, module: _module),
      ),
    );

void main() {
  testWidgets('shows an empty state when there are no photos yet', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada foto tersimpan.'), findsOneWidget);
  });

  testWidgets('lists photos grouped by category, with counts', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    await repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/pisang.jpg',
      category: PhotoCategory.target,
      label: 'pisang',
    );
    await repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/sikat.jpg',
      category: PhotoCategory.distractor,
      label: 'sikat gigi',
    );

    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();

    // One count badge per category section. The count moved out of the
    // heading string and into a TkBadge — see _CategorySection.
    expect(find.text('1 foto'), findsNWidgets(2));
    expect(find.text('pisang'), findsOneWidget);
    expect(find.text('sikat gigi'), findsOneWidget);
  });

  testWidgets('deleting a photo removes both the tile and the repository record',
      (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    final saved = await repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/pisang.jpg',
      category: PhotoCategory.target,
      label: 'pisang',
    );

    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('pisang'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    // The confirm dialog's own button is also labelled "Hapus" — the second
    // tap lands on that, not the (now-closed) menu item.
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('pisang'), findsNothing);
    expect(find.text('Belum ada foto tersimpan.'), findsOneWidget);
    final remaining = await repo.listPhotos(childId: _childId, module: _module);
    expect(remaining, isEmpty);
    expect(
      (await repo.listPhotos(childId: _childId, module: _module))
          .where((p) => p.id == saved.id),
      isEmpty,
    );
  });

  testWidgets('cancelling delete leaves the photo untouched', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    await repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/pisang.jpg',
      category: PhotoCategory.target,
      label: 'pisang',
    );

    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('pisang'), findsOneWidget);
    final remaining = await repo.listPhotos(childId: _childId, module: _module);
    expect(remaining, hasLength(1));
  });

  testWidgets('renaming a photo updates both the tile and the repository record',
      (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    await repo.addPhoto(
      childId: _childId,
      module: _module,
      localPath: '/fake/unknown.jpg',
      category: PhotoCategory.target,
    );

    await tester.pumpWidget(_buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Belum diberi nama'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pisang');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('pisang'), findsOneWidget);
    final saved = await repo.listPhotos(childId: _childId, module: _module);
    expect(saved.single.label, 'pisang');
  });
}
