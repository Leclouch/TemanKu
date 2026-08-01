import 'package:temanku/core/constants/domain_enums.dart';

/// A child profile. Source-of-truth §9: one guardian account → many child profiles;
/// each child owns their photo library, ladder positions, session history, intake.
class Child {
  const Child({
    required this.id,
    required this.name,
    required this.availableModes,
  });

  final String id;
  final String name;

  /// Modes unlocked by intake (§8) — intake selects available *modes*, never
  /// predicts levels. A child with no speech may simply have no `speak` here.
  final Set<ResponseMode> availableModes;

  Child copyWith({String? name, Set<ResponseMode>? availableModes}) => Child(
        id: id,
        name: name ?? this.name,
        availableModes: availableModes ?? this.availableModes,
      );
}

/// A position on the two-dial ladder, for one child × one module × one mode.
///
/// The two dials are **independent and moved one at a time** (§4.4). This type
/// carries both; the invariant "array resets to 2 when similarity steps up" is the
/// engine's job to enforce, not this value object's.
class LadderPosition {
  const LadderPosition({
    required this.arraySize,
    required this.similarityTier,
  });

  /// Everyone starts here. §4.5: no placement quiz, no calibration screen —
  /// the advancement criterion doubles as placement from trial one.
  const LadderPosition.start()
      : arraySize = ArraySize.min,
        similarityTier = SimilarityTier.differentCategory;

  final int arraySize;
  final SimilarityTier similarityTier;

  LadderPosition copyWith({int? arraySize, SimilarityTier? similarityTier}) =>
      LadderPosition(
        arraySize: arraySize ?? this.arraySize,
        similarityTier: similarityTier ?? this.similarityTier,
      );

  @override
  bool operator ==(Object other) =>
      other is LadderPosition &&
      other.arraySize == arraySize &&
      other.similarityTier == similarityTier;

  @override
  int get hashCode => Object.hash(arraySize, similarityTier);

  @override
  String toString() => 'LadderPosition(array: $arraySize, sim: ${similarityTier.name})';
}
