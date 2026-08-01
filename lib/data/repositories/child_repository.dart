import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';

/// Child profiles and their ladder state.
///
/// **ADR-3 contract — shared file.** IT-1 codes the engine against this interface
/// from day one using [InMemoryChildRepository]; IT-2 builds the Firestore/Hive
/// implementation in parallel. Neither waits for the other. Changing a signature
/// here is a shared-folder change — raise it at the evening checkpoint before
/// merging (ADR-2 practical rule).
///
/// Both implementations must pass `test/data/child_repository_contract_test.dart`.
/// That contract test is what makes "interchangeable implementations"
/// verifiable rather than aspirational.
abstract class ChildRepository {
  // --- Child profile CRUD, scoped to one guardian ------------------------------
  //
  // Every method is implicitly scoped to the signed-in guardian
  // (`guardians/{gid}/children/{cid}` — §11). The guardian id is not a parameter:
  // an implementation that could read another guardian's children would be a
  // privacy bug, and keeping gid out of the signature makes that unrepresentable
  // at this layer.

  /// All children under the current guardian. §9: multi-child is true underneath
  /// even though the demo shows one child end-to-end.
  Future<List<Child>> listChildren();

  Future<Child?> getChild(String childId);

  Future<Child> createChild({
    required String name,
    required Set<ResponseMode> availableModes,
  });

  Future<void> updateChild(Child child);

  Future<void> deleteChild(String childId);

  /// Emits whenever the child set changes, so the select-child screen stays live.
  Stream<List<Child>> watchChildren();

  // --- Ladder position: per child, per module, per mode -------------------------
  //
  // The three-way key is not incidental. §4.2: "Each child holds an independent
  // ladder position per module per mode. **No cross-module gating, ever.**" An
  // implementation that collapses any of these three axes breaks that rule.

  /// Returns [LadderPosition.start] for a child/module/mode never played before —
  /// never null. §4.5: everyone starts at Step 1 of every eligible mode+module,
  /// so "no stored position" and "at the start" are the same state.
  Future<LadderPosition> getLadderPosition({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  });

  Future<void> setLadderPosition({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
    required LadderPosition position,
  });

  /// Every stored position for one child, keyed for the guardian-facing milestone
  /// timeline (§8) which needs to read across modules at once.
  Future<Map<(ModuleId, ResponseMode), LadderPosition>> getAllLadderPositions(
    String childId,
  );
}
