import 'package:temanku/core/constants/domain_enums.dart';

/// Whether a child has a formal diagnosis — **context only** (§8 intake).
///
/// Collected by `features/onboarding/intake_screen.dart` and stored here, but
/// deliberately inert: nothing in the engine, content, or mode selection may
/// ever branch on this field. It exists so a guardian's answer isn't lost, not
/// so the app can gate on it. If a future PR adds an `if (diagnosisStatus...)`
/// anywhere outside a guardian-facing display, that is the constraint this
/// comment exists to catch.
enum DiagnosisStatus { diagnosed, notDiagnosed, unsure }

/// A child profile. Source-of-truth §9: one guardian account → many child profiles;
/// each child owns their photo library, ladder positions, session history, intake.
class Child {
  const Child({
    required this.id,
    required this.name,
    required this.availableModes,
    this.diagnosisStatus,
    this.pronunciationHintEnabled = false,
    this.storytellerEnabled = false,
  });

  final String id;
  final String name;

  /// Modes unlocked by intake (§8) — intake selects available *modes*, never
  /// predicts levels. A child with no speech may simply have no `speak` here.
  final Set<ResponseMode> availableModes;

  /// Null until intake has been answered — distinct from [DiagnosisStatus.unsure],
  /// which is the guardian's explicit "I'm not sure" answer.
  final DiagnosisStatus? diagnosisStatus;

  /// Per-child consent for the optional pronunciation-hint layer in speak
  /// mode (`speech/pronunciation_hint_service.dart`). Default **off**. Only
  /// when this is true does `core/service_locator.dart` ever bind
  /// `RemoteArticulationHintService` — and only then does
  /// `features/child_session/speak_mode_screen.dart` ever record a clip of
  /// the child's voice to send off-device. Flipping this on is the explicit
  /// consent gate; see `features/guardian/child_settings_screen.dart` for
  /// the copy shown before it can be set true.
  ///
  /// Strictly advisory either way (§6): this field never touches which
  /// response mode is offered, the ladder, or correctness — it only decides
  /// whether a hint line may appear next to the guardian's own ✅/❌.
  final bool pronunciationHintEnabled;

  /// Per-child consent for the storyteller feature (`lib/story/`) — an
  /// optional narrative line, in the mascot's voice, that turns session
  /// progression into a small ongoing "chapter" for the child. Default
  /// **off**, same consent shape as [pronunciationHintEnabled]: only when
  /// true does `core/service_locator.dart` ever bind a network-backed
  /// [StorytellerService] instead of the local, offline [NoStorytellerService]
  /// — see `features/guardian/child_settings_screen.dart` for the copy shown
  /// before it can be set true.
  ///
  /// Strictly flavor text (§12-equivalent for this feature): the storyteller
  /// never reads or writes the ladder, never scores the child, and its output
  /// is never shown anywhere the guardian's own judgment belongs.
  final bool storytellerEnabled;

  Child copyWith({
    String? name,
    Set<ResponseMode>? availableModes,
    DiagnosisStatus? diagnosisStatus,
    bool? pronunciationHintEnabled,
    bool? storytellerEnabled,
  }) =>
      Child(
        id: id,
        name: name ?? this.name,
        availableModes: availableModes ?? this.availableModes,
        diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
        pronunciationHintEnabled: pronunciationHintEnabled ?? this.pronunciationHintEnabled,
        storytellerEnabled: storytellerEnabled ?? this.storytellerEnabled,
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
