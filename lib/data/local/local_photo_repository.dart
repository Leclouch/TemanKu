import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/local/local_store.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/photo_repository.dart';

/// Hive + filesystem [PhotoRepository] (IT-2 promotion target — ADR-3).
///
/// The Hive box ([Boxes.photos]) holds metadata only — module, category,
/// label, and a file path. Image bytes never go into Hive: [addPhoto] copies
/// them into a `photos/` subdirectory of the app's documents directory and
/// stores that path. §10/§11: this repository never touches the network —
/// there is no upload method to accidentally wire one into.
///
/// The box is opened lazily on first use rather than eagerly in the
/// constructor, so constructing this class has no I/O side effect.
class LocalPhotoRepository implements PhotoRepository {
  LocalPhotoRepository({
    String boxName = Boxes.photos,
    Future<Directory> Function()? documentsDirectory,
  })  : _boxName = boxName,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final String _boxName;
  final Future<Directory> Function() _documentsDirectory;

  Future<Box<Map>>? _boxFuture;
  final Map<String, StreamController<List<Photo>>> _controllers = {};
  int _idCounter = 0;

  Future<Box<Map>> _box() => _boxFuture ??= Hive.openBox<Map>(_boxName);

  Future<Directory> _photosDir() async {
    final docs = await _documentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<Photo> addPhoto({
    required String childId,
    required ModuleId module,
    required String localPath,
    required PhotoCategory category,
    String? label,
    LabelSource labelSource = LabelSource.guardian,
    AgeGroup? ageGroup,
  }) async {
    final id = 'photo_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
    final dir = await _photosDir();
    final storedFile = await File(localPath).copy(
      '${dir.path}${Platform.pathSeparator}$id${_extensionOf(localPath)}',
    );

    final photo = Photo(
      id: id,
      childId: childId,
      module: module,
      localPath: storedFile.path,
      category: category,
      label: label,
      labelSource: labelSource,
      ageGroup: ageGroup,
    );

    final box = await _box();
    await box.put(id, _toRecord(photo));
    _emit(box, childId, module);
    return photo;
  }

  @override
  Future<List<Photo>> listPhotos({
    required String childId,
    required ModuleId module,
    PhotoCategory? category,
  }) async {
    final box = await _box();
    return _query(box, childId, module, category);
  }

  @override
  Future<void> updatePhoto(Photo photo) async {
    final box = await _box();
    if (!box.containsKey(photo.id)) {
      throw StateError('No photo with id ${photo.id}');
    }
    await box.put(photo.id, _toRecord(photo));
    _emit(box, photo.childId, photo.module);
  }

  @override
  Future<void> removePhoto(String photoId) async {
    final box = await _box();
    final record = box.get(photoId);
    if (record == null) return;
    final photo = _fromRecord(record);

    final file = File(photo.localPath);
    if (await file.exists()) {
      await file.delete();
    }
    await box.delete(photoId);
    _emit(box, photo.childId, photo.module);
  }

  @override
  Stream<List<Photo>> watchPhotos({
    required String childId,
    required ModuleId module,
  }) async* {
    final box = await _box();
    yield _query(box, childId, module);
    yield* _controllerFor(childId, module).stream;
  }

  @override
  Future<Map<PhotoCategory, int>> countByCategory({
    required String childId,
    required ModuleId module,
  }) async {
    final box = await _box();
    final photos = _query(box, childId, module);
    return {
      for (final c in PhotoCategory.values)
        c: photos.where((p) => p.category == c).length,
    };
  }

  List<Photo> _query(
    Box<Map> box,
    String childId,
    ModuleId module, [
    PhotoCategory? category,
  ]) =>
      box.values
          .map(_fromRecord)
          .where(
            (p) =>
                p.childId == childId &&
                p.module == module &&
                (category == null || p.category == category),
          )
          .toList();

  String _key(String childId, ModuleId module) => '$childId::${module.name}';

  StreamController<List<Photo>> _controllerFor(String childId, ModuleId module) =>
      _controllers.putIfAbsent(
        _key(childId, module),
        () => StreamController<List<Photo>>.broadcast(),
      );

  void _emit(Box<Map> box, String childId, ModuleId module) =>
      _controllerFor(childId, module).add(_query(box, childId, module));

  Map<String, dynamic> _toRecord(Photo photo) => {
        'id': photo.id,
        'childId': photo.childId,
        'module': photo.module.name,
        'localPath': photo.localPath,
        'category': photo.category.name,
        'label': photo.label,
        'labelSource': photo.labelSource.name,
        'ageGroup': photo.ageGroup?.name,
      };

  Photo _fromRecord(Map record) => Photo(
        id: record['id'] as String,
        childId: record['childId'] as String,
        module: ModuleId.values.byName(record['module'] as String),
        localPath: record['localPath'] as String,
        category: PhotoCategory.values.byName(record['category'] as String),
        label: record['label'] as String?,
        labelSource: LabelSource.values.byName(record['labelSource'] as String),
        ageGroup: record['ageGroup'] == null
            ? null
            : AgeGroup.values.byName(record['ageGroup'] as String),
      );

  String _extensionOf(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '.jpg';
    return path.substring(dotIndex);
  }

  /// Not part of the interface — test/teardown convenience only.
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }
}
