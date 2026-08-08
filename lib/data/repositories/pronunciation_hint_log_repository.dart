import 'package:temanku/data/models/pronunciation_hint_log.dart';

/// Per-trial pronunciation-hint diagnostics — **local-only, guardian-facing,
/// experimental**, the same three-part boundary [PronunciationHintLogEntry]'s
/// own doc comment states.
///
/// **ADR-3 contract — shared file.** See `ChildRepository` for the ownership
/// rule.
///
/// Deliberately its own small interface rather than a field bolted onto
/// [SessionRepository]'s `TrialLog`: pronunciation-hint diagnostics only
/// ever exist for speak-mode trials on children with
/// `Child.pronunciationHintEnabled` true, so tying them to every mode's
/// trial log would mean every tap/match trial carries an always-null field.
abstract class PronunciationHintLogRepository {
  /// Appends one entry. Callers (`speak_mode_screen.dart`) fire this without
  /// awaiting or wrapping in a try/catch — same "never block or fail the
  /// live trial" rule [PronunciationHintService] itself follows.
  Future<void> append(PronunciationHintLogEntry entry);

  /// Every entry recorded for [childId], newest first — the raw material
  /// for the guardian's "Data lengkap" experimental subsection.
  Future<List<PronunciationHintLogEntry>> getEntries(String childId);
}
