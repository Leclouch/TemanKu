import 'package:temanku/core/constants/domain_enums.dart';

/// A guardian-supplied photo of the child's own environment.
///
/// **Local-only by default** (source-of-truth §10 / §11). [localPath] is the
/// single source of truth for the image bytes; there is intentionally no
/// `remoteUrl` field on this class. Cloud backup is opt-in, consent-gated, and
/// out of MVP scope — adding an upload path is a consent-design task, not a
/// storage task.
class Photo {
  const Photo({
    required this.id,
    required this.childId,
    required this.module,
    required this.localPath,
    required this.category,
    this.label,
    this.labelSource = LabelSource.guardian,
  });

  final String id;
  final String childId;
  final ModuleId module;

  /// Path on device. Encrypted local storage (§11).
  final String localPath;

  /// The binary classification this photo belongs to within its module —
  /// e.g. Makanan: edible / not edible; Keluarga: my family / not my family.
  /// The **guardian's module choice is the categorization**; the AI never
  /// verifies or second-guesses it (§5).
  final PhotoCategory category;

  /// Object/person name used in game text and speech. Null until supplied.
  final String? label;

  final LabelSource labelSource;

  Photo copyWith({String? label, LabelSource? labelSource}) => Photo(
        id: id,
        childId: childId,
        module: module,
        localPath: localPath,
        category: category,
        label: label ?? this.label,
        labelSource: labelSource ?? this.labelSource,
      );
}

/// Which side of the module's binary classification a photo sits on.
/// `target` = belongs to the taught category (edible / my family);
/// `distractor` = does not.
enum PhotoCategory {
  target,
  distractor,
}

/// Where a label came from. Kept explicit because §5 makes the provenance
/// meaningful: Keluarga labels are **only ever** guardian-supplied (no model),
/// and a classifier label is always guardian-confirmable.
enum LabelSource {
  guardian,
  classifier,
}
