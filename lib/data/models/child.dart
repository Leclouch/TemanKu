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
    this.levelIndicatorEnabled = false,
    this.activeModeByModule = const {},
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

  /// Guardian-only debug/preview toggle (`features/guardian/child_settings_screen.dart`):
  /// when true, `TapModeScreen`/`MatchModeScreen` render a small, neutral
  /// [LevelIndicatorBadge] in the bottom-right corner showing the child's
  /// current ladder position. Default **off**.
  ///
  /// This is a deliberate, explicit exception to §4.5's "nothing about
  /// levels, scores, or thresholds is ever visible to the child" — there is
  /// no separate "guardian view" of an active session distinct from what the
  /// child sees on the same device, so turning this on does make the ladder
  /// position visible on-screen, full stop. It exists strictly as a
  /// guardian-controlled QA/debug aid (checking the engine is progressing as
  /// expected), not a feature aimed at the child, and it carries no privacy
  /// consequence the way [pronunciationHintEnabled]/[storytellerEnabled] do
  /// — nothing leaves the device — so it needs no consent dialog, just a
  /// plain switch.
  final bool levelIndicatorEnabled;

  /// Guardian-set override of which [ResponseMode] is "active" for a module —
  /// the mode `features/child_session/day_arc_screen.dart` actually routes
  /// into when its module card is tapped. Default **empty**: absence of a
  /// module's key means "no override", which [activeModeFor] treats
  /// identically to an override that names a mode no longer in
  /// [availableModes] — both fall back to [preferredModeFor]'s tap→match→speak
  /// priority.
  ///
  /// Exists because that priority order means match/speak are otherwise
  /// unreachable from the real product entry points whenever tap is also
  /// enabled (which is nearly always) — even though both are fully built and
  /// functional. Deliberately guardian-set, not child-facing and not
  /// automatic: mode choice stays "never re-litigated as a child-facing
  /// decision" (`day_arc_screen.dart`'s own doc comment), this just gives a
  /// guardian a way to point that fixed choice at match or speak instead of
  /// always tap. Set via `features/guardian/level_settings_screen.dart`,
  /// alongside that same screen's ladder-position override — both are
  /// "guardian controls what a child's session looks like" for the same
  /// (module, mode) axis.
  final Map<ModuleId, ResponseMode> activeModeByModule;

  Child copyWith({
    String? name,
    Set<ResponseMode>? availableModes,
    DiagnosisStatus? diagnosisStatus,
    bool? pronunciationHintEnabled,
    bool? storytellerEnabled,
    bool? levelIndicatorEnabled,
    Map<ModuleId, ResponseMode>? activeModeByModule,
  }) =>
      Child(
        id: id,
        name: name ?? this.name,
        availableModes: availableModes ?? this.availableModes,
        diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
        pronunciationHintEnabled: pronunciationHintEnabled ?? this.pronunciationHintEnabled,
        storytellerEnabled: storytellerEnabled ?? this.storytellerEnabled,
        levelIndicatorEnabled: levelIndicatorEnabled ?? this.levelIndicatorEnabled,
        activeModeByModule: activeModeByModule ?? this.activeModeByModule,
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

/// Priority when a child has more than one mode enabled and no guardian
/// override applies — never a choice the child makes. Tap first (simplest
/// motor channel), then match, then speak. Single source of truth for both
/// [preferredModeFor] and [activeModeFor]; also `day_arc_screen.dart`'s own
/// mode-priority doc comment describes the reasoning for this order.
const modePriority = [ResponseMode.tap, ResponseMode.match, ResponseMode.speak];

/// Null only when [availableModes] is entirely empty (a real, reachable
/// state per `test/features/onboarding/intake_screen_test.dart`), in which
/// case there is nothing valid to route into at all.
ResponseMode? preferredModeFor(Set<ResponseMode> availableModes) {
  for (final mode in modePriority) {
    if (availableModes.contains(mode)) return mode;
  }
  return null;
}

/// Which mode is active for [child]'s [module] — [Child.activeModeByModule]'s
/// override if one is set and still names a mode the child actually has,
/// [preferredModeFor]'s priority order otherwise (a stale override, e.g. one
/// intake later removed, is treated exactly like no override rather than
/// routing into a mode the child no longer has enabled).
///
/// Shared by `features/child_session/day_arc_screen.dart` (decides which
/// mode a module card actually routes into) and
/// `features/guardian/level_settings_screen.dart` (shows/sets that same
/// choice) — kept here, next to [Child.activeModeByModule] itself, so the
/// two screens can never drift apart on what "active mode" means.
ResponseMode? activeModeFor(Child child, ModuleId module) {
  final override = child.activeModeByModule[module];
  if (override != null && child.availableModes.contains(override)) return override;
  return preferredModeFor(child.availableModes);
}
