import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/photo.dart';

/// The child's photo library.
///
/// **ADR-3 contract — shared file.** See [ChildRepository] for the ownership rule.
///
/// **Hard privacy requirement, not a style choice.** Source-of-truth §10: photos
/// are on-device by default and "never uploaded without explicit guardian consent"
/// (UU PDP — children's data and biometric data are both sensitive classes,
/// Pasal 25 parental consent). This interface therefore exposes **no upload,
/// sync, or backup method at all**. Cloud backup is opt-in, consent-gated, and
/// out of MVP scope; when it is built it arrives as a separate consent-gated
/// interface, not as a quiet extra method here.
abstract class PhotoRepository {
  /// Store a photo locally and return the persisted record.
  ///
  /// Callers are expected to have passed the quality gate first
  /// (`photo_pipeline/quality_gate/`) — this method persists, it does not judge.
  Future<Photo> addPhoto({
    required String childId,
    required ModuleId module,
    required String localPath,
    required PhotoCategory category,
    String? label,
    LabelSource labelSource = LabelSource.guardian,
    AgeGroup? ageGroup,
  });

  /// All photos for one child in one module, optionally narrowed to one side of
  /// the classification.
  Future<List<Photo>> listPhotos({
    required String childId,
    required ModuleId module,
    PhotoCategory? category,
  });

  /// §5.5 standing correction path: guardians can re-tag or remove photos at any
  /// time. Re-tagging is [updatePhoto]; removal is [removePhoto].
  Future<void> updatePhoto(Photo photo);

  /// Removes the record **and** deletes the local file. A photo the guardian
  /// removed must not survive on disk.
  Future<void> removePhoto(String photoId);

  Stream<List<Photo>> watchPhotos({
    required String childId,
    required ModuleId module,
  });

  /// How many photos exist per category, for the §5.4 variety nudge
  /// ("five varied photos per category").
  ///
  /// This is a **soft nudge, never a hard gate** — the UI may coach toward five
  /// but must never block a session for having fewer.
  Future<Map<PhotoCategory, int>> countByCategory({
    required String childId,
    required ModuleId module,
  });
}
