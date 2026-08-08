/// A small, neutral badge showing the child's current ladder position —
/// **guardian debug/QA aid only.**
///
/// Gated behind `Child.levelIndicatorEnabled` (default off, no consent
/// dialog needed — see that field's own doc comment for why this is a
/// deliberate, explicit exception to §4.5's "nothing about levels, scores,
/// or thresholds is ever visible to the child"). Rendered via
/// `TkChildScreen.debugBadge`, bottom-right, by `TapModeScreen` and
/// `MatchModeScreen`.
library;

import 'package:flutter/material.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/components/tk_status.dart';
import 'package:temanku/data/models/child.dart';

/// Ordinal position of each tier, 1-indexed, for the badge's own compact
/// "n/4" reading — [SimilarityTier]'s declaration order already *is* this
/// ordering (see `dial_engine.dart`), this just names it for display.
const Map<SimilarityTier, int> _tierOrdinal = {
  SimilarityTier.differentCategory: 1,
  SimilarityTier.sameCategoryDistinct: 2,
  SimilarityTier.similar: 3,
  SimilarityTier.lrffc: 4,
};

class LevelIndicatorBadge extends StatelessWidget {
  const LevelIndicatorBadge({super.key, required this.position});

  final LadderPosition position;

  @override
  Widget build(BuildContext context) {
    final tier = _tierOrdinal[position.similarityTier]!;
    return TkBadge(
      label: 'Tingkat $tier/4 · ${position.arraySize} item',
      tone: TkBadgeTone.neutral,
    );
  }
}
