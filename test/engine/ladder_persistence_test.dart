import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/engine/ladder_persistence.dart';

void main() {
  group('LadderPersistence', () {
    test('load returns start position when nothing was ever saved', () async {
      final persistence =
          LadderPersistence(InMemoryChildRepository(seed: false));

      final position = await persistence.load(
        childId: 'never_seen',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );

      expect(position, const LadderPosition.start());
    });

    test('save then load round-trips through the ChildRepository interface',
        () async {
      final persistence =
          LadderPersistence(InMemoryChildRepository(seed: false));
      const target = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.similar,
      );

      await persistence.save(
        childId: 'child_1',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: target,
      );

      final loaded = await persistence.load(
        childId: 'child_1',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );
      expect(loaded, target);
    });

    test('save does not leak across module/mode axes', () async {
      final persistence =
          LadderPersistence(InMemoryChildRepository(seed: false));

      await persistence.save(
        childId: 'child_1',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: const LadderPosition(
          arraySize: 4,
          similarityTier: SimilarityTier.lrffc,
        ),
      );

      final keluarga = await persistence.load(
        childId: 'child_1',
        module: ModuleId.keluarga,
        mode: ResponseMode.tap,
      );
      expect(keluarga, const LadderPosition.start());
    });
  });
}
