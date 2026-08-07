/// Pronunciation-hint diagnostics for the "Data lengkap" experimental
/// subsection — the guardian-facing, post-session home of
/// [PronunciationHintLogEntry] data. Companion to `session_full_data.dart`,
/// same "raw counts and dates, never a verdict" register: every value here
/// is IPA text, an edit-distance count, a target word, or a date — never
/// the endpoint's own pass/fail label (see [PronunciationHintResult]'s doc
/// comment for why that field is never even parsed into this pipeline).
///
/// §5/§10 boundary this file must not cross: only ever reads
/// [PronunciationHintLogRepository], only for a child with
/// `Child.pronunciationHintEnabled` true — that flag is the guardian's own
/// consent gate (`features/guardian/child_settings_screen.dart`), and this
/// file is the one place besides the live speak-mode hint line that the
/// consent-gated data is allowed to reach.
library;

import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/repositories/child_repository.dart';
import 'package:temanku/data/repositories/pronunciation_hint_log_repository.dart';

/// Null when [childId] doesn't exist or hasn't opted in — the guardian's
/// "Data lengkap" card renders nothing for this subsection in that case
/// (constraint: absent, not an empty placeholder, for a child who never
/// enabled the feature). A non-null, possibly empty list means "opted in,
/// nothing recorded yet" — that case *does* get a placeholder line, since
/// the guardian did opt in.
Future<List<PronunciationHintLogEntry>?> loadPronunciationHintFullData(
  ChildRepository children,
  PronunciationHintLogRepository hintLog,
  String childId,
) async {
  final child = await children.getChild(childId);
  if (child == null || !child.pronunciationHintEnabled) return null;
  return hintLog.getEntries(childId);
}
