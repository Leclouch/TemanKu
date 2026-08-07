import 'dart:typed_data';

/// Optional advisory layer for speak mode — **not part of §6's correctness
/// contract.**
///
/// §6 is unambiguous: correctness in speak mode is judged by the guardian's
/// ✅/❌, full stop. Nothing in this file is allowed to compete with that.
/// [PronunciationHintResult] is a *suggestion* the guardian may glance at
/// before or after they judge — never a verdict, never a pre-selection,
/// never something that writes to [SessionRepository] or feeds
/// `engine/advancement/advancement_tracker.dart`. See
/// `features/child_session/speak_mode_screen.dart` for how the boundary is
/// kept: the hint result only ever renders as a small secondary line next
/// to the guardian's own buttons, and no code path lets it set them.
///
/// The two implementations:
///   - [NoHintService] — the default. Always null, instantly, no I/O.
///   - `RemoteArticulationHintService` (`remote_articulation_hint_service.dart`)
///     — calls an external scoring endpoint. Only ever bound in
///     `core/service_locator.dart` for a child whose guardian explicitly
///     opted in (`Child.pronunciationHintEnabled` — see
///     `features/guardian/child_settings_screen.dart`'s consent copy).
///
/// Null is the only failure signal this interface has, and that is
/// deliberate: a timeout, a network error, a malformed response, and "the
/// feature is off" all look identical to the caller. Speak mode must never
/// distinguish "the hint failed" from "there is no hint" — both mean
/// exactly one thing to the child-facing UI: don't show a hint line.
abstract class PronunciationHintService {
  /// Scores [audioClip] (16kHz mono WAV bytes) against [targetWord].
  ///
  /// Must never throw. Any failure — timeout, network error, bad response —
  /// is caught internally and reported as a null return, not an exception.
  /// Callers are free to fire this without a try/catch for exactly that
  /// reason.
  Future<PronunciationHintResult?> scorePronunciation({
    required Uint8List audioClip,
    required String targetWord,
    int difficulty = defaultPronunciationHintDifficulty,
  });
}

/// Fixed for now (task scope: "pass a fixed default (2) for now — do not
/// wire this to the dial engine's similarity/array tiers yet"). Deferred
/// past the hackathon deliberately — see the doc comment on [difficulty]'s
/// call sites in `speak_mode_screen.dart`.
const int defaultPronunciationHintDifficulty = 2;

/// One scored result. Advisory display data only — no field here is a
/// correctness verdict, and nothing in this type should ever be compared
/// against [TrialOutcome].
class PronunciationHintResult {
  const PronunciationHintResult({
    required this.closestWord,
    this.confidence,
    this.ipaTranscription,
    this.phonemeEditDistance,
  });

  /// The word the scoring service judged the utterance closest to, for
  /// copy like "Sistem: mirip 'apel'". Guardian-facing, never child-facing —
  /// see `speak_mode_screen.dart`'s secondary-line placement.
  final String closestWord;

  /// Optional 0–1 confidence, if the endpoint supplies one. Never rendered
  /// as a percentage to the child; guardian-facing display only, and only
  /// if a designer later wants it — nothing currently reads this field.
  final double? confidence;

  /// The endpoint's predicted IPA transcription of the utterance, if it
  /// supplied one. Raw technical value — only ever surfaced in the
  /// guardian's post-session "Data lengkap" experimental subsection
  /// (`features/guardian/pronunciation_hint_full_data.dart`), never in the
  /// live child-facing hint line.
  final String? ipaTranscription;

  /// The endpoint's phoneme edit-distance between the utterance and
  /// [closestWord]/the target word, if it supplied one. Same
  /// guardian-only, post-session surfacing as [ipaTranscription] — and
  /// deliberately framed as a distance ("jarak fonem: 0"), never as a
  /// pass/fail label. This class never carries the endpoint's own raw
  /// pass/fail verdict string at all — [RemoteArticulationHintService]
  /// does not parse it into any field here, so there is nothing to
  /// accidentally render.
  final int? phonemeEditDistance;
}
