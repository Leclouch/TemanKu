import 'dart:async';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/photo_repository.dart';

/// In-memory [PhotoRepository] (ADR-3 day-one target).
///
/// Seeded with fake local paths for one child across both MVP modules. The paths
/// point at nothing — IT-1's engine needs *photo records* to build array
/// composition against on day one; real bytes arrive from the content track
/// (timeline Day 2 dependency note).
///
/// Note there is no upload method to fake, because the interface has none — §10.
class InMemoryPhotoRepository implements PhotoRepository {
  InMemoryPhotoRepository({bool seed = true}) {
    if (seed) _seed();
  }

  final Map<String, Photo> _photos = {};
  final Map<String, StreamController<List<Photo>>> _controllers = {};
  int _idCounter = 0;

  void _seed() {
    // Makanan — the §4.4 worked table's cast: target pisang, plus same-category
    // distinct and visually-similar distractors so every similarity tier has
    // something to draw from.
    _add('child_arif', ModuleId.makanan, 'pisang', PhotoCategory.target);
    _add('child_arif', ModuleId.makanan, 'apel', PhotoCategory.target);
    _add('child_arif', ModuleId.makanan, 'roti', PhotoCategory.target);
    _add('child_arif', ModuleId.makanan, 'jeruk', PhotoCategory.target);
    _add('child_arif', ModuleId.makanan, 'nasi', PhotoCategory.target);
    _add('child_arif', ModuleId.makanan, 'mobil mainan', PhotoCategory.distractor);
    _add('child_arif', ModuleId.makanan, 'sikat gigi', PhotoCategory.distractor);
    _add('child_arif', ModuleId.makanan, 'buku', PhotoCategory.distractor);
    _add('child_arif', ModuleId.makanan, 'terong', PhotoCategory.distractor);
    _add('child_arif', ModuleId.makanan, 'wortel', PhotoCategory.distractor);

    // Keluarga — targets are the child's actual family (guardian-labelled, no
    // model, §5.3). Distractors here stand in for the bundled stranger library;
    // in the real implementation they are read from assets, not from the child's
    // own photo store.
    _add('child_arif', ModuleId.keluarga, 'Ibu', PhotoCategory.target);
    _add('child_arif', ModuleId.keluarga, 'Ayah', PhotoCategory.target);
    _add('child_arif', ModuleId.keluarga, 'Kakak Sari', PhotoCategory.target);
    _add('child_arif', ModuleId.keluarga, 'Nenek', PhotoCategory.target);
    _add('child_arif', ModuleId.keluarga, 'stranger_adult_f_01', PhotoCategory.distractor);
    _add('child_arif', ModuleId.keluarga, 'stranger_adult_m_02', PhotoCategory.distractor);
    _add('child_arif', ModuleId.keluarga, 'stranger_child_f_03', PhotoCategory.distractor);
  }

  void _add(String childId, ModuleId module, String label, PhotoCategory category) {
    final id = 'photo_${++_idCounter}';
    _photos[id] = Photo(
      id: id,
      childId: childId,
      module: module,
      localPath: '/fake/local/$childId/${module.name}/$id.jpg',
      category: category,
      label: label,
    );
  }

  String _key(String childId, ModuleId module) => '$childId::${module.name}';

  StreamController<List<Photo>> _controllerFor(String childId, ModuleId module) =>
      _controllers.putIfAbsent(
        _key(childId, module),
        () => StreamController<List<Photo>>.broadcast(),
      );

  List<Photo> _query(
    String childId,
    ModuleId module, [
    PhotoCategory? category,
  ]) =>
      _photos.values
          .where(
            (p) =>
                p.childId == childId &&
                p.module == module &&
                (category == null || p.category == category),
          )
          .toList();

  void _emit(String childId, ModuleId module) =>
      _controllerFor(childId, module).add(_query(childId, module));

  @override
  Future<Photo> addPhoto({
    required String childId,
    required ModuleId module,
    required String localPath,
    required PhotoCategory category,
    String? label,
    LabelSource labelSource = LabelSource.guardian,
  }) async {
    final id = 'photo_${++_idCounter}';
    final photo = Photo(
      id: id,
      childId: childId,
      module: module,
      localPath: localPath,
      category: category,
      label: label,
      labelSource: labelSource,
    );
    _photos[id] = photo;
    _emit(childId, module);
    return photo;
  }

  @override
  Future<List<Photo>> listPhotos({
    required String childId,
    required ModuleId module,
    PhotoCategory? category,
  }) async =>
      _query(childId, module, category);

  @override
  Future<void> updatePhoto(Photo photo) async {
    if (!_photos.containsKey(photo.id)) {
      throw StateError('No photo with id ${photo.id}');
    }
    _photos[photo.id] = photo;
    _emit(photo.childId, photo.module);
  }

  @override
  Future<void> removePhoto(String photoId) async {
    final photo = _photos.remove(photoId);
    // The real implementation must also delete the file at photo.localPath —
    // a removed photo must not survive on disk (§5.5, §10).
    if (photo != null) _emit(photo.childId, photo.module);
  }

  @override
  Stream<List<Photo>> watchPhotos({
    required String childId,
    required ModuleId module,
  }) async* {
    yield _query(childId, module);
    yield* _controllerFor(childId, module).stream;
  }

  @override
  Future<Map<PhotoCategory, int>> countByCategory({
    required String childId,
    required ModuleId module,
  }) async {
    final photos = _query(childId, module);
    return {
      for (final c in PhotoCategory.values)
        c: photos.where((p) => p.category == c).length,
    };
  }

  /// Not part of the interface — test/teardown convenience only.
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}
