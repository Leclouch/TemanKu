/// Ladder-position persistence — thin wrapper over [ChildRepository] (ADR-3).
///
/// Consumes the shared repository contract only; it does not touch
/// `data/repositories/` implementations directly, so it works unmodified
/// against both [InMemoryChildRepository] and the future Firestore one.
///
/// Usage contract: load once per session at session start, then persist
/// immediately on every advancement — never batched, so a crash mid-session
/// never loses a step the child already earned.
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/repositories/child_repository.dart';

class LadderPersistence {
  const LadderPersistence(this._repository);

  final ChildRepository _repository;

  /// Call at session start. Never null — [ChildRepository.getLadderPosition]
  /// returns [LadderPosition.start] for a child/module/mode never played (§4.5).
  Future<LadderPosition> load({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
  }) =>
      _repository.getLadderPosition(
        childId: childId,
        module: module,
        mode: mode,
      );

  /// Call immediately on every advancement — do not batch or debounce.
  Future<void> save({
    required String childId,
    required ModuleId module,
    required ResponseMode mode,
    required LadderPosition position,
  }) =>
      _repository.setLadderPosition(
        childId: childId,
        module: module,
        mode: mode,
        position: position,
      );
}
