/// The two-dial difficulty engine — **IT-1, Day 2.** Pure Dart, no widget imports.
///
/// Source-of-truth §4.4. Array size and distractor similarity are **independent
/// dials, moved one at a time**:
///   - array grows by one (2→3→4), never jumping;
///   - array **resets to 2 whenever similarity steps up**.
///
/// That reset is the single most bug-prone rule in the whole app, which is why
/// `engine/` gets real unit tests and UI does not (architecture doc, testing
/// priority).
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';

/// Advances or holds a [LadderPosition]. Stateless and synchronous by design —
/// it takes a position and returns a position, so it is trivially unit-testable
/// without a repository, a widget, or a clock.
abstract class DialEngine {
  /// The next position after the child met the advancement criterion at [current].
  ///
  /// Expected shape (TODO(IT-1) to implement and test):
  ///   - array < 4          → array + 1, similarity unchanged
  ///   - array == 4         → similarity steps up **and array resets to 2**
  ///   - similarity == lrffc and array == 4 → [current] (top of the ladder;
  ///     there is no step 11, and no artificial ceiling behaviour beyond staying put)
  LadderPosition advance(LadderPosition current);

  /// Speak mode has no array (§4.4), so [advance] on a speak-mode position must
  /// move similarity only. Implementations take [mode] into account rather than
  /// callers special-casing it.
  LadderPosition advanceForMode(LadderPosition current, ResponseMode mode);

  /// How many distractors to compose for [position]. Zero in speak mode.
  int distractorCountFor(LadderPosition position, ResponseMode mode);
}

/// TODO(IT-1): implement — Day 2, with unit tests in `test/engine/`.
///
/// Cases worth writing tests for before writing the code:
///   - 2→3→4 within a tier, no skipping
///   - 4 + advance → next tier at array 2 (the reset)
///   - lrffc + array 4 + advance → unchanged
///   - speak mode never touches the array dial
class TwoDialEngine implements DialEngine {
  const TwoDialEngine();

  @override
  LadderPosition advance(LadderPosition current) {
    throw UnimplementedError('TwoDialEngine.advance');
  }

  @override
  LadderPosition advanceForMode(LadderPosition current, ResponseMode mode) {
    throw UnimplementedError('TwoDialEngine.advanceForMode');
  }

  @override
  int distractorCountFor(LadderPosition position, ResponseMode mode) {
    throw UnimplementedError('TwoDialEngine.distractorCountFor');
  }
}
