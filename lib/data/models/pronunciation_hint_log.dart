import 'package:temanku/core/constants/domain_enums.dart';

/// One [PronunciationHintResult] (`speech/pronunciation_hint_service.dart`)
/// persisted for a specific speak-mode trial — the durable form of what
/// otherwise only ever lived in `speak_mode_screen.dart`'s ephemeral
/// `_hintResult` widget state (discarded the moment the next trial composes).
///
/// **Advisory/experimental only, same boundary as the live hint line (§6):**
/// nothing here is a correctness verdict, nothing here is ever compared
/// against [TrialOutcome], and nothing here ever reaches
/// `AdvancementTracker`. Its only consumer is the guardian's post-session
/// "Data lengkap" view (`features/guardian/pronunciation_hint_full_data.dart`),
/// clearly labelled experimental there, never the live child-facing screen.
///
/// Local-only, same reasoning as [TrialLog] (§11) — this is per-trial raw
/// data, not an aggregate summary fit for remote sync.
class PronunciationHintLogEntry {
  const PronunciationHintLogEntry({
    required this.childId,
    required this.module,
    required this.targetWord,
    required this.ipaTranscription,
    required this.phonemeEditDistance,
    required this.recordedAt,
  });

  final String childId;
  final ModuleId module;

  /// The word the trial was targeting — known independently of the
  /// endpoint's own response, so this is populated even when the endpoint
  /// doesn't echo it back.
  final String targetWord;

  /// Raw technical values from [PronunciationHintResult] — see that class's
  /// own doc comments for why no pass/fail verdict field exists to log here
  /// in the first place.
  final String? ipaTranscription;
  final int? phonemeEditDistance;

  final DateTime recordedAt;
}
