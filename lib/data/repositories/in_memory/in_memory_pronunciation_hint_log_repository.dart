import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/repositories/pronunciation_hint_log_repository.dart';

/// In-memory [PronunciationHintLogRepository] (ADR-3 day-one target).
class InMemoryPronunciationHintLogRepository implements PronunciationHintLogRepository {
  InMemoryPronunciationHintLogRepository({bool seed = true}) {
    if (seed) _seed();
  }

  final Map<String, List<PronunciationHintLogEntry>> _entries = {};

  void _seed() {
    // A couple of entries for the seeded demo child, opted in
    // (`InMemoryChildRepository`'s own seed), so the guardian's "Data
    // lengkap" experimental subsection has something to render on day one —
    // same reasoning as `InMemorySessionRepository`'s seeded trial logs.
    _entries['child_arif'] = [
      PronunciationHintLogEntry(
        childId: 'child_arif',
        module: ModuleId.makanan,
        targetWord: 'pisang',
        predictedIpa: 'pisaŋ',
        distance: 0,
        recordedAt: DateTime(2026, 7, 30, 16, 15),
      ),
      PronunciationHintLogEntry(
        childId: 'child_arif',
        module: ModuleId.makanan,
        targetWord: 'apel',
        predictedIpa: 'apəl',
        distance: 1,
        recordedAt: DateTime(2026, 7, 30, 16, 18),
      ),
    ];
  }

  @override
  Future<void> append(PronunciationHintLogEntry entry) async {
    (_entries[entry.childId] ??= []).insert(0, entry); // newest first
  }

  @override
  Future<List<PronunciationHintLogEntry>> getEntries(String childId) async =>
      List.unmodifiable(_entries[childId] ?? const []);
}
