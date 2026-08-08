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
  /// Expected shape:
  ///   - arrays below 4 grow by one within their current similarity tier;
  ///   - arrays at 4 step similarity up and reset to 2, except LRFFC;
  ///   - LRFFC grows from 4 to 6, then remains at 6.
  LadderPosition advance(LadderPosition current);

  /// Speak mode has no array (§4.4), so [advance] on a speak-mode position must
  /// move similarity only. Implementations take [mode] into account rather than
  /// callers special-casing it.
  LadderPosition advanceForMode(LadderPosition current, ResponseMode mode);

  /// How many distractors to compose for [position]. Zero in speak mode.
  int distractorCountFor(LadderPosition position, ResponseMode mode);

  /// How many targets to compose for [position]. Zero in speak mode.
  int targetCountFor(LadderPosition position, ResponseMode mode);

  /// True at the mastery-celebration milestone for [mode]. It is deliberately
  /// distinct from the extended LRFFC advancement fixed point so callers can
  /// trigger the celebration at array 4 while allowing later practice.
  bool isAtCeiling(LadderPosition position, ResponseMode mode);
}

class TwoDialEngine implements DialEngine {
  const TwoDialEngine();

  static const int multiTargetCount = 2;

  @override
  LadderPosition advance(LadderPosition current) {
    // Extended LRFFC practice stops at array six.
    if (current.similarityTier == SimilarityTier.lrffc &&
        current.arraySize == ArraySize.extendedMax) {
      return current;
    }

    if (current.similarityTier == SimilarityTier.lrffc &&
        current.arraySize >= ArraySize.max) {
      return current.copyWith(arraySize: current.arraySize + 1);
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
    return position.arraySize - targetCountFor(position, mode);
  }

  @override
  int targetCountFor(LadderPosition position, ResponseMode mode) {
    if (mode == ResponseMode.speak) return 0;
    if (mode == ResponseMode.tap &&
        position.similarityTier == SimilarityTier.lrffc &&
        position.arraySize > ArraySize.max) {
      return multiTargetCount;
    }
    return 1;
  }

  @override
  bool isAtCeiling(LadderPosition position, ResponseMode mode) {
    if (mode == ResponseMode.speak) {
      // Speak mode has no array (§4.4) — [advanceForMode] only ever checks
      // similarity for it, so the ceiling condition mirrors that exactly.
      return position.similarityTier == SimilarityTier.lrffc;
    }
    // Array four remains the celebrated mastery milestone; five and six are
    // additional LRFFC practice positions rather than ceiling positions.
    return position.similarityTier == SimilarityTier.lrffc &&
        position.arraySize == ArraySize.max;
  }
}
