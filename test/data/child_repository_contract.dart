import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/child_repository.dart';

/// **The ADR-3 contract suite for [ChildRepository].**
///
/// ADR-3 claims the in-memory fake and the real Firestore implementation are
/// "interchangeable". This file is what makes that claim *verifiable* rather than
/// aspirational — it is the executable definition of the contract, and every
/// implementation must pass it unmodified.
///
/// Usage: call [runChildRepositoryContractTests] from a `_test.dart` file with a
/// factory that returns a **fresh, empty** repository.
///
/// ```dart
/// void main() {
///   runChildRepositoryContractTests(
///     'InMemoryChildRepository',
///     () => InMemoryChildRepository(seed: false),
///   );
/// }
/// ```
///
/// TODO(IT-2): when `FirestoreChildRepository` exists, add
/// `test/data/firestore_child_repository_contract_test.dart` calling this same
/// function against the emulator. If it passes there and here, the swap at the
/// composition root is safe. **Do not weaken an assertion to make a new
/// implementation pass** — every case below encodes a source-of-truth rule, not
/// an implementation detail.
void runChildRepositoryContractTests(
  String implementationName,
  ChildRepository Function() createRepository,
) {
  group('ChildRepository contract — $implementationName', () {
    late ChildRepository repo;

    setUp(() => repo = createRepository());

    // --- Profile CRUD --------------------------------------------------------

    test('starts empty', () async {
      expect(await repo.listChildren(), isEmpty);
    });

    test('createChild returns a child with a non-empty id and is then listed',
        () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );

      expect(child.id, isNotEmpty);
      expect(child.name, 'Arif');

      final all = await repo.listChildren();
      expect(all.map((c) => c.id), contains(child.id));
    });

    test('getChild returns null for an unknown id, not a throw', () async {
      expect(await repo.getChild('does_not_exist'), isNull);
    });

    test('updateChild persists changes', () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );

      await repo.updateChild(
        child.copyWith(
          name: 'Arif R.',
          availableModes: {ResponseMode.tap, ResponseMode.speak},
        ),
      );

      final reloaded = await repo.getChild(child.id);
      expect(reloaded!.name, 'Arif R.');
      expect(reloaded.availableModes, contains(ResponseMode.speak));
    });

    test('pronunciationHintEnabled defaults false and persists an explicit opt-in', () async {
      // The pronunciation-hint consent gate (features/guardian/child_settings_screen.dart)
      // — off for every child until a guardian explicitly flips it, and that
      // flip must survive exactly like every other field on Child.
      final child = await repo.createChild(name: 'Arif', availableModes: {ResponseMode.speak});
      expect(child.pronunciationHintEnabled, isFalse);

      await repo.updateChild(child.copyWith(pronunciationHintEnabled: true));

      final reloaded = await repo.getChild(child.id);
      expect(reloaded!.pronunciationHintEnabled, isTrue);
    });

    test('activeModeByModule defaults empty and persists a guardian override', () async {
      // The guardian mode-selection override (features/guardian/level_settings_screen.dart)
      // — empty (no override) for every child until a guardian explicitly
      // picks a mode for a module, and that pick must survive exactly like
      // every other field on Child.
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap, ResponseMode.match},
      );
      expect(child.activeModeByModule, isEmpty);

      await repo.updateChild(
        child.copyWith(activeModeByModule: {ModuleId.keluarga: ResponseMode.match}),
      );

      final reloaded = await repo.getChild(child.id);
      expect(reloaded!.activeModeByModule, {ModuleId.keluarga: ResponseMode.match});
      // Makanan was never set — absence means "no override", not "tap".
      expect(reloaded.activeModeByModule.containsKey(ModuleId.makanan), isFalse);
    });

    test('deleteChild removes the profile', () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );

      await repo.deleteChild(child.id);

      expect(await repo.getChild(child.id), isNull);
      expect(await repo.listChildren(), isEmpty);
    });

    test('multiple children coexist under one guardian', () async {
      // §9: one guardian account → many child profiles. The SLB teacher who is
      // half the field research has many students; this is not a demo nicety.
      await repo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});
      await repo.createChild(name: 'Sari', availableModes: {ResponseMode.match});

      expect((await repo.listChildren()).length, 2);
    });

    test('watchChildren emits the current set immediately', () async {
      await repo.createChild(name: 'Arif', availableModes: {ResponseMode.tap});

      final first = await repo.watchChildren().first;
      expect(first.map((c) => c.name), contains('Arif'));
    });

    // --- Ladder position -----------------------------------------------------

    test('getLadderPosition returns the start position when nothing is stored',
        () async {
      // §4.5: "no stored position" and "at Step 1" are the same state. An
      // implementation that returns null here, or throws, breaks the engine's
      // ability to place a child from trial one.
      final position = await repo.getLadderPosition(
        childId: 'never_seen',
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );

      expect(position, const LadderPosition.start());
    });

    test('setLadderPosition round-trips', () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );
      const target = LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.similar,
      );

      await repo.setLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: target,
      );

      final loaded = await repo.getLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );
      expect(loaded, target);
    });

    test('ladder position is independent per module — no cross-module gating',
        () async {
      // §4.2: "No cross-module gating, ever." Advancing in Makanan must leave
      // Keluarga untouched. This is the assertion that catches a storage layer
      // which collapsed the module axis.
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );

      await repo.setLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: const LadderPosition(
          arraySize: 4,
          similarityTier: SimilarityTier.lrffc,
        ),
      );

      final keluarga = await repo.getLadderPosition(
        childId: child.id,
        module: ModuleId.keluarga,
        mode: ResponseMode.tap,
      );
      expect(keluarga, const LadderPosition.start());
    });

    test('ladder position is independent per mode', () async {
      // §4.1: response mode and skill domain are separate axes. A child strong
      // at tapping is not thereby placed high in speak.
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap, ResponseMode.speak},
      );

      await repo.setLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: const LadderPosition(
          arraySize: 4,
          similarityTier: SimilarityTier.similar,
        ),
      );

      final speak = await repo.getLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.speak,
      );
      expect(speak, const LadderPosition.start());
    });

    test('ladder position is independent per child', () async {
      final arif = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );
      final sari = await repo.createChild(
        name: 'Sari',
        availableModes: {ResponseMode.tap},
      );

      await repo.setLadderPosition(
        childId: arif.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: const LadderPosition(
          arraySize: 4,
          similarityTier: SimilarityTier.similar,
        ),
      );

      final sariPosition = await repo.getLadderPosition(
        childId: sari.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
      );
      expect(sariPosition, const LadderPosition.start());
    });

    test('setLadderPosition overwrites rather than appending', () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );

      for (final size in [2, 3, 4]) {
        await repo.setLadderPosition(
          childId: child.id,
          module: ModuleId.makanan,
          mode: ResponseMode.tap,
          position: LadderPosition(
            arraySize: size,
            similarityTier: SimilarityTier.differentCategory,
          ),
        );
      }

      final all = await repo.getAllLadderPositions(child.id);
      expect(all.length, 1);
      expect(all[(ModuleId.makanan, ResponseMode.tap)]!.arraySize, 4);
    });

    test('getAllLadderPositions returns every stored pair, keyed by module+mode',
        () async {
      // The guardian milestone timeline (§8) reads across modules at once.
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap, ResponseMode.match},
      );

      await repo.setLadderPosition(
        childId: child.id,
        module: ModuleId.makanan,
        mode: ResponseMode.tap,
        position: const LadderPosition(
          arraySize: 3,
          similarityTier: SimilarityTier.sameCategoryDistinct,
        ),
      );
      await repo.setLadderPosition(
        childId: child.id,
        module: ModuleId.keluarga,
        mode: ResponseMode.match,
        position: const LadderPosition(
          arraySize: 2,
          similarityTier: SimilarityTier.similar,
        ),
      );

      final all = await repo.getAllLadderPositions(child.id);
      expect(all.length, 2);
      expect(all.containsKey((ModuleId.makanan, ResponseMode.tap)), isTrue);
      expect(all.containsKey((ModuleId.keluarga, ResponseMode.match)), isTrue);
    });

    test('getAllLadderPositions is empty for a child who has never played',
        () async {
      final child = await repo.createChild(
        name: 'Arif',
        availableModes: {ResponseMode.tap},
      );
      expect(await repo.getAllLadderPositions(child.id), isEmpty);
    });
  });
}
