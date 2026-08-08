import 'dart:typed_data';

import 'package:temanku/core/constants/domain_enums.dart';

/// Advisory articulation scoring for speak mode — **not part of §6's
/// correctness contract.**
///
/// §6 is unambiguous: correctness in speak mode is judged by the guardian's
/// ✅/❌, full stop. Nothing in this file is allowed to compete with that.
/// A [PronunciationHintResult] may *suggest* — `speak_mode_screen.dart`
/// highlights the button it points at — but the suggestion is never pressed,
/// never auto-committed, and never reaches [SessionRepository] or
/// `engine/advancement/advancement_tracker.dart`. Only a guardian tap does.
///
/// That boundary is the whole reason this is a separate service rather than
/// a branch inside the mode controller. A wav2vec2 phoneme model run on a
/// young child's speech, over a phone mic, in a room with other people in it,
/// has a real and asymmetric error rate — and the expensive direction is a
/// false "try again" on an answer the child actually got right. Keeping an
/// adult between the model and the ladder is what makes the model safe to
/// use at all.
///
/// The two implementations:
///   - [NoHintService] — the default. Always null, instantly, no I/O.
///   - `RemoteArticulationHintService` (`remote_articulation_hint_service.dart`)
///     — calls the external scoring endpoint. Only ever bound in
///     `core/service_locator.dart` for a child whose guardian explicitly
///     opted in (`Child.pronunciationHintEnabled` — see
///     `features/guardian/child_settings_screen.dart`'s consent copy).
///
/// Null is the only failure signal this interface has, and that is
/// deliberate: a timeout, a network error, a malformed response, a word the
/// backend has no target for, and "the feature is off" all look identical to
/// the caller. Speak mode must never distinguish "the hint failed" from
/// "there is no hint" — both mean exactly one thing to the UI: don't show a
/// hint line, don't highlight anything, let the guardian judge unaided.
abstract class PronunciationHintService {
  /// Scores [audioClip] (16kHz mono WAV bytes) against [targetWord].
  ///
  /// [tolerance] is the phoneme-distance ceiling for the child's current
  /// rung of the ladder — see [ArticulationTolerance.forPosition]. It is sent
  /// to the backend as its `difficulty` field *and* used to interpret the
  /// distance that comes back, so the two can never disagree.
  ///
  /// Must never throw. Any failure — timeout, network error, bad response,
  /// unknown word — is caught internally and reported as a null return, not
  /// an exception. Callers are free to fire this without a try/catch for
  /// exactly that reason.
  Future<PronunciationHintResult?> scorePronunciation({
    required Uint8List audioClip,
    required String targetWord,
    required int tolerance,
  });

  /// Whether this service can score [word] at all.
  ///
  /// The backend matches against a fixed target dictionary, so most of the
  /// words a guardian actually types ("pisang", "Ibu", "Kakak Sari") have no
  /// entry and can never be scored. Asking first lets speak mode skip the
  /// upload entirely rather than record a clip, send it, and discard the
  /// answer — which matters because that clip is audio of a child leaving
  /// the device (§10). Not sending it at all is the stronger guarantee.
  ///
  /// Must never throw; an unreachable backend answers `false`.
  Future<bool> canScore(String word);
}

/// One scored result. Advisory display data only.
class PronunciationHintResult {
  const PronunciationHintResult({
    required this.predictedIpa,
    required this.distance,
    required this.tolerance,
  });

  /// The phonemes the model heard, as IPA — e.g. `ˈapəl`. Rendered to the
  /// guardian verbatim; it is the most useful part of the response, because
  /// it says *what went wrong* rather than just how far off it was.
  ///
  /// May be empty: the model returns an empty string for audio it cannot
  /// resolve into phonemes at all (silence, pure noise). Callers should
  /// treat empty as "no phonemes detected", not as a zero-distance match.
  final String predictedIpa;

  /// Raw Levenshtein distance between the target IPA and [predictedIpa].
  /// Never rendered to the child; guardian-facing only.
  final int distance;

  /// The ceiling this result was measured against, carried alongside the
  /// distance so the UI can show both ("jarak 1 · toleransi ≤2"). A distance
  /// without its threshold is unreadable.
  final int tolerance;

  /// Whether [distance] falls inside [tolerance].
  bool get withinTolerance => distance <= tolerance;

  /// The outcome this result *points at* — *never* the outcome recorded.
  ///
  /// `speak_mode_screen.dart` uses this to highlight one of the guardian's
  /// three buttons. The highlight is a suggestion the guardian confirms with
  /// a tap; there is deliberately no code path anywhere that passes this
  /// value to `AdvancementTracker.recordResponse`. If you are about to add
  /// one, re-read §6 first — that is the rule this whole file is built to
  /// keep.
  ///
  /// An empty [predictedIpa] suggests [TrialOutcome.notAttempted] rather than
  /// [TrialOutcome.incorrect]: no phonemes at all means the model heard
  /// nothing it could parse, which is a different thing from a mispronounced
  /// word, and §6 already treats those two as distinct.
  TrialOutcome get suggestedOutcome {
    if (predictedIpa.isEmpty) return TrialOutcome.notAttempted;
    return withinTolerance ? TrialOutcome.correct : TrialOutcome.incorrect;
  }
}
