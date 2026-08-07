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

  /// True when [position] is the fixed point [advance]/[advanceForMode] would
  /// return unchanged for [mode] — "top of the ladder" (§4.5), the same
  /// condition each of those already checks, surfaced here so a caller can
  /// ask *before* advancing whether a streak clearing at [position] would be
  /// mastery-at-ceiling rather than an ordinary step up.
  bool isAtCeiling(LadderPosition position, ResponseMode mode);
}

class TwoDialEngine implements DialEngine {
  const TwoDialEngine();

  @override
  LadderPosition advance(LadderPosition current) {
    // Top of the ladder: lrffc at array 4 is a fixed point, no step 11.
    if (current.similarityTier == SimilarityTier.lrffc &&
        current.arraySize == ArraySize.max) {
      return current;
    }

    // Array dial moves first, one step at a time, regardless of tier.
    if (current.arraySize < ArraySize.max) {
      return current.copyWith(arraySize: current.arraySize + 1);
    }

    // Array is maxed out: similarity steps up and array resets to 2.
    const tiers = SimilarityTier.values;
    final nextTier = tiers[tiers.indexOf(current.similarityTier) + 1];
    return LadderPosition(arraySize: ArraySize.min, similarityTier: nextTier);
  }

  @override
  LadderPosition advanceForMode(LadderPosition current, ResponseMode mode) {
    if (mode != ResponseMode.speak) {
      return advance(current);
    }

    // Speak mode has no array (§4.4) — advance moves similarity only, and the
    // array value is left untouched rather than reset, since it never applied.
    if (current.similarityTier == SimilarityTier.lrffc) {
      return current;
    }
    const tiers = SimilarityTier.values;
    final nextTier = tiers[tiers.indexOf(current.similarityTier) + 1];
    return current.copyWith(similarityTier: nextTier);
  }

  @override
  int distractorCountFor(LadderPosition position, ResponseMode mode) {
    if (mode == ResponseMode.speak) return 0;
    return position.arraySize - 1;
  }

  @override
  bool isAtCeiling(LadderPosition position, ResponseMode mode) {
    if (mode == ResponseMode.speak) {
      // Speak mode has no array (§4.4) — [advanceForMode] only ever checks
      // similarity for it, so the ceiling condition mirrors that exactly.
      return position.similarityTier == SimilarityTier.lrffc;
    }
    return position.similarityTier == SimilarityTier.lrffc &&
        position.arraySize == ArraySize.max;
  }
}
