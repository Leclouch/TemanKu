import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';

import 'child_repository_contract.dart';

/// Runs the ADR-3 contract suite against the in-memory implementation.
///
/// `seed: false` because the contract asserts behaviour from an empty store —
/// the seeded sample data exists for IT-1's day-one development, not for tests.
///
/// TODO(IT-2): add the sibling file for `FirestoreChildRepository` against the
/// emulator. Same function, different factory. Passing both is what licenses the
/// one-line swap in `core/service_locator.dart`.
void main() {
  runChildRepositoryContractTests(
    'InMemoryChildRepository',
    () => InMemoryChildRepository(seed: false),
  );
}
