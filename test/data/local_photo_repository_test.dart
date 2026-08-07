import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/local/local_photo_repository.dart';
import 'package:temanku/data/local/local_store.dart';
import 'package:temanku/data/models/photo.dart';

/// Contract test for [LocalPhotoRepository] — the two behaviours that are
/// easy to get wrong and expensive to discover late: that a saved photo
/// genuinely survives process restart (not just a live object still holding
/// the open box), and that deletion removes the file, not only the record.
///
/// Hive is pointed at a temp directory via [Hive.init] (not
/// `Hive.initFlutter()`) so this runs as a plain Dart/VM test with no
/// platform channels. The documents directory is likewise injected, so no
/// path_provider platform channel is needed either.
void main() {
  late Directory hiveDir;
  late Directory docsDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('temanku_hive_test_');
    docsDir = await Directory.systemTemp.createTemp('temanku_docs_test_');
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  LocalPhotoRepository makeRepo() => LocalPhotoRepository(
        documentsDirectory: () async => docsDir,
      );

  Future<File> makeSourceImage(String name) async {
    final file = File('${docsDir.path}${Platform.pathSeparator}source_$name');
    await file.writeAsBytes([1, 2, 3, 4]);
    return file;
  }

  group('LocalPhotoRepository contract', () {
    test(
        'a saved photo survives a fresh instantiation of the repository '
        '(simulated restart)', () async {
      final source = await makeSourceImage('pisang.jpg');
      final repo1 = makeRepo();
      final saved = await repo1.addPhoto(
        childId: 'child_arif',
        module: ModuleId.makanan,
        localPath: source.path,
        category: PhotoCategory.target,
        label: 'pisang',
      );
      repo1.dispose();

      // Close the box so the next repository instance must re-read from
      // disk, not just reuse a box already held open in memory — that is
      // what actually simulates an app restart.
      await Hive.box<Map>(Boxes.photos).close();

      final repo2 = makeRepo();
      final photos = await repo2.listPhotos(
        childId: 'child_arif',
        module: ModuleId.makanan,
      );
      repo2.dispose();

      expect(photos, hasLength(1));
      expect(photos.single.id, saved.id);
      expect(photos.single.label, 'pisang');
      expect(await File(photos.single.localPath).exists(), isTrue);
    });

    test('delete removes both the Hive record and the file on disk',
        () async {
      final source = await makeSourceImage('apel.jpg');
      final repo = makeRepo();
      final saved = await repo.addPhoto(
        childId: 'child_arif',
        module: ModuleId.makanan,
        localPath: source.path,
        category: PhotoCategory.target,
        label: 'apel',
      );

      final storedFile = File(saved.localPath);
      expect(await storedFile.exists(), isTrue);

      await repo.removePhoto(saved.id);
      repo.dispose();

      expect(await storedFile.exists(), isFalse);

      final repo2 = makeRepo();
      final photos = await repo2.listPhotos(
        childId: 'child_arif',
        module: ModuleId.makanan,
      );
      repo2.dispose();
      expect(photos, isEmpty);
    });
  });
}
