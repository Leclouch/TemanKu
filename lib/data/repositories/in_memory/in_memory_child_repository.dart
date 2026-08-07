import 'dart:async';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/child_repository.dart';

/// In-memory [ChildRepository] with realistic-but-fake seed data.
///
/// **This is the day-one development target for IT-1** (ADR-3). The engine is
/// built against this while IT-2 builds `FirestoreChildRepository` in parallel.
/// It is also the reference implementation for
/// `test/data/child_repository_contract_test.dart` — if a behaviour is asserted
/// there, this class must exhibit it and so must the Firestore one.
///
/// Seed data is deliberately *unfinished-looking*: one child, both MVP modules,
/// mid-ladder positions that exercise the interesting cases (a similarity step-up
/// that reset the array back to 2, and a fresh module still at start).
class InMemoryChildRepository implements ChildRepository {
  InMemoryChildRepository({bool seed = true}) {
    if (seed) _seed();
  }

  final Map<String, Child> _children = {};
  final Map<String, Map<(ModuleId, ResponseMode), LadderPosition>> _ladders = {};
  final StreamController<List<Child>> _childrenController =
      StreamController<List<Child>>.broadcast();

  int _idCounter = 0;

  void _seed() {
    const child = Child(
      id: 'child_arif',
      name: 'Arif',
      // Intake (§8) selected all three modes for this child. A child with no
      // speech would simply have a smaller set here — that is normal, not a gap.
      availableModes: {ResponseMode.tap, ResponseMode.match, ResponseMode.speak},
      // Opted in, so the guardian's "Data lengkap" pronunciation-hint
      // subsection (features/guardian/pronunciation_hint_full_data.dart) has
      // something to render on day one — same reasoning as every other
      // seeded field on this child.
      pronunciationHintEnabled: true,
    );
    _children[child.id] = child;

    _ladders[child.id] = {
      // Makanan / tap — Step 5 of the §4.4 worked table: array 3, same-category
      // distinct distractors (apel, roti alongside target pisang).
      (ModuleId.makanan, ResponseMode.tap): const LadderPosition(
        arraySize: 3,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      ),
      // Makanan / match — just stepped the similarity dial up, so the array dial
      // reset to 2. This is the invariant most likely to be got wrong; seeding it
      // means IT-1 sees the case on day one rather than on day five.
      (ModuleId.makanan, ResponseMode.match): const LadderPosition(
        arraySize: 2,
        similarityTier: SimilarityTier.similar,
      ),
      // Makanan / speak — no array in speak mode; the array value is inert here.
      (ModuleId.makanan, ResponseMode.speak): const LadderPosition(
        arraySize: 2,
        similarityTier: SimilarityTier.sameCategoryDistinct,
      ),
      // Keluarga / tap — early. Similarity here means demographic closeness of
      // the stranger, not visual similarity of objects.
      (ModuleId.keluarga, ResponseMode.tap): const LadderPosition(
        arraySize: 4,
        similarityTier: SimilarityTier.differentCategory,
      ),
      // Keluarga / match and speak are deliberately absent — never played, so
      // getLadderPosition must return LadderPosition.start() for them rather
      // than throwing. No cross-module gating (§4.2): being early in Keluarga
      // does not touch Makanan at all.
    };
  }

  void _emit() => _childrenController.add(_children.values.toList());

  @override
  Future<List<Child>> listChildren() async => _children.values.toList();

  @override
  Future<Child?> getChild(String childId) async => _children[childId];

  @override
  Future<Child> createChild({
    required String name,
    required Set<ResponseMode> availableModes,
  }) async {
    final child = Child(
      id: 'child_${++_idCounter}_${name.toLowerCase()}',
      name: name,
      availableModes: availableModes,
    );
    _children[child.id] = child;
    _ladders[child.id] = {};
    _emit();
    return child;
  }

  @override
  Future<void> updateChild(Child child) async {
    if (!_children.containsKey(child.id)) {
      throw StateError('No child with id ${child.id}');
    }
    _children[child.id] = child;
    _emit();
  }

  @override
  Future<void> deleteChild(String childId) async {
    _children.remove(childId);
    _ladders.remove(childId);
    _emit();
  }

  @override
  Stream<List<Child>> watchChildren() async* {
    yield _children.values.toList();
    yield* _childrenController.stream;
  }

  @override
  Future<LadderPosition> getLadderPosition({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  }) async {
    // Never null: "no stored position" and "at Step 1" are the same state (§4.5).
    return _ladders[childId]?[(module, mode)] ?? const LadderPosition.start();
  }

  @override
  Future<void> setLadderPosition({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
    required LadderPosition position,
  }) async {
    (_ladders[childId] ??= {})[(module, mode)] = position;
  }

  @override
  Future<Map<(ModuleId, ResponseMode), LadderPosition>> getAllLadderPositions(
    String childId,
  ) async =>
      Map.of(
        _ladders[childId] ?? const <(ModuleId, ResponseMode), LadderPosition>{},
      );

  /// Not part of the interface — test/teardown convenience only.
  void dispose() => _childrenController.close();
}
