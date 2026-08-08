/// Canonical reachable ladder positions derived from the difficulty engine.
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';

/// Enumerates the distinct positions reachable for one module and response
/// mode, starting from the initial ladder position and including its fixed
/// point.
///
/// [module] remains part of the contract so callers must enumerate a concrete
/// module-mode pair even though the current engine progression is shared.
List<LadderPosition> ladderStepsFor({
  required DialEngine dialEngine,
  required ModuleId module,
  required ResponseMode mode,
}) {
  final steps = <LadderPosition>[];
  var current = const LadderPosition.start();

  while (true) {
    steps.add(current);
    final next = dialEngine.advanceForMode(current, mode);
    if (next == current) return steps;
    current = next;
  }
}
