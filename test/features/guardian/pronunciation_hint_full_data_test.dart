import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/pronunciation_hint_log.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_pronunciation_hint_log_repository.dart';
import 'package:temanku/features/guardian/pronunciation_hint_full_data.dart';

void main() {
  test('returns null for a child that never enabled pronunciation-hint — '
      'absent, not an empty list', () async {
    final children = InMemoryChildRepository(seed: false);
    final child = await children.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    final hintLog = InMemoryPronunciationHintLogRepository(seed: false);

    final result = await loadPronunciationHintFullData(children, hintLog, child.id);
    expect(result, isNull);
  });

  test('returns an empty list for an opted-in child with nothing recorded yet', () async {
    final children = InMemoryChildRepository(seed: false);
    final child = await children.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    await children.updateChild(child.copyWith(pronunciationHintEnabled: true));
    final hintLog = InMemoryPronunciationHintLogRepository(seed: false);

    final result = await loadPronunciationHintFullData(children, hintLog, child.id);
    expect(result, isNotNull);
    expect(result, isEmpty);
  });

  test('returns the recorded entries for an opted-in child', () async {
    final children = InMemoryChildRepository(seed: false);
    final child = await children.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
    await children.updateChild(child.copyWith(pronunciationHintEnabled: true));
    final hintLog = InMemoryPronunciationHintLogRepository(seed: false);
    await hintLog.append(
      PronunciationHintLogEntry(
        childId: child.id,
        module: ModuleId.makanan,
        targetWord: 'pisang',
        ipaTranscription: 'pisaŋ',
        phonemeEditDistance: 0,
        recordedAt: DateTime(2026, 1, 1),
      ),
    );

    final result = await loadPronunciationHintFullData(children, hintLog, child.id);
    expect(result, hasLength(1));
    expect(result!.single.targetWord, 'pisang');
  });

  test('returns null for a childId with no matching child at all', () async {
    final children = InMemoryChildRepository(seed: false);
    final hintLog = InMemoryPronunciationHintLogRepository(seed: false);

    expect(await loadPronunciationHintFullData(children, hintLog, 'no_such_child'), isNull);
  });
}
