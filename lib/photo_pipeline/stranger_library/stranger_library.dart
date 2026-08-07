/// Bundled Keluarga distractor library — **IT-2.**
///
/// Source-of-truth §5.3. Licensed-stock or synthetic faces, **never real private
/// individuals photographed without consent.** Targets must be personal (that is
/// the far-transfer thesis); distractors only need to be plausible non-family, so
/// a shared bundled asset is *correct*, not a compromise — it removes the
/// third-party consent problem structurally.
///
/// Assets are declared as static Flutter assets in `pubspec.yaml`
/// (`assets/stranger_library/`) — bundled at build time, **never fetched over
/// the network, never mixed into [PhotoRepository]** (that repository is the
/// guardian's own local photos; strangers are shipped with the app, not
/// stored per-child).
///
/// MVP scope: 10–15 images, sufficient for Steps 1–4. Documented as
/// minimum-viable; production expansion is a tracked open item (§14).
///
/// **The images bundled today are placeholders** (`tool/generate_stranger_placeholders.dart`),
/// not the curated set — see `assets/stranger_library/.gitkeep` for the
/// naming convention and the TODO to replace them before demo.
library;

import 'package:flutter/services.dart' show AssetManifest, AssetBundle, rootBundle;

import 'package:temanku/core/constants/domain_enums.dart';

/// Keluarga's similarity dial is **demographic closeness of the stranger**
/// (§4.4) — [AgeGroup] is the one attribute every asset must carry, or the
/// dial has nothing to move against.
class StrangerImage {
  const StrangerImage({required this.assetPath, required this.ageGroup});

  final String assetPath;
  final AgeGroup ageGroup;
}

/// child ⟷ teen ⟷ adult ⟷ elderly — the linear order [StrangerLibrary]
/// implementations measure demographic distance along.
const List<AgeGroup> _ageOrder = [
  AgeGroup.child,
  AgeGroup.teen,
  AgeGroup.adult,
  AgeGroup.elderly,
];

/// Which age group(s) count as an acceptable distractor for [targetAgeGroup]
/// at [tier] — the mode-aware/tier-aware interpretation the task brief asks
/// for, kept in one place so no caller re-derives it.
///
///   - [SimilarityTier.differentCategory] → the group **farthest** from the
///     target on the linear order (easy: obviously not the same generation).
///   - [SimilarityTier.sameCategoryDistinct] → a **neighbouring** group, one
///     step away — nearer, but still not equal.
///   - [SimilarityTier.similar] and [SimilarityTier.lrffc] → the **same**
///     group as the target — hardest, forcing genuine recognition over
///     age as a shortcut. (The task brief specifies tiers 1–3 explicitly;
///     lrffc is not called out separately, so it inherits tier 3's hardest
///     case rather than introducing a fifth behaviour.)
List<AgeGroup> acceptableDistractorAgeGroups({
  required AgeGroup targetAgeGroup,
  required SimilarityTier tier,
}) {
  final targetIndex = _ageOrder.indexOf(targetAgeGroup);
  final distances = {
    for (final group in _ageOrder) group: (_ageOrder.indexOf(group) - targetIndex).abs(),
  };

  switch (tier) {
    case SimilarityTier.differentCategory:
      final maxDistance = distances.values.reduce((a, b) => a > b ? a : b);
      return [for (final e in distances.entries) if (e.value == maxDistance) e.key];
    case SimilarityTier.sameCategoryDistinct:
      return [for (final e in distances.entries) if (e.value == 1) e.key];
    case SimilarityTier.similar:
    case SimilarityTier.lrffc:
      return [targetAgeGroup];
  }
}

abstract class StrangerLibrary {
  /// [count] distractors for one trial, chosen by demographic closeness to
  /// [targetAgeGroup] at [tier] — never by visual feature similarity, which
  /// is Makanan's axis, not Keluarga's.
  Future<List<StrangerImage>> pickDistractors({
    required int count,
    required AgeGroup targetAgeGroup,
    required SimilarityTier tier,
  });
}

/// Reads whatever is bundled under `assets/stranger_library/` — real curated
/// photos or the placeholder set, without caring which, so swapping one for
/// the other before demo is a file-drop, not a code change. Filenames must
/// follow `stranger_<agegroup>_<nn>.<ext>` (see the folder's `.gitkeep`);
/// anything else in that folder (like `.gitkeep` itself) is silently skipped
/// rather than treated as a malformed asset.
class BundledStrangerLibrary implements StrangerLibrary {
  BundledStrangerLibrary({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static final RegExp _filenamePattern = RegExp(r'stranger_([a-z]+)_\d+\.\w+$');

  List<StrangerImage>? _cache;

  Future<List<StrangerImage>> _library() async {
    final cached = _cache;
    if (cached != null) return cached;

    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final images = <StrangerImage>[];
    for (final path in manifest.listAssets()) {
      if (!path.startsWith('assets/stranger_library/')) continue;
      final match = _filenamePattern.firstMatch(path);
      if (match == null) continue; // e.g. .gitkeep — not a stranger image.

      AgeGroup? ageGroup;
      for (final candidate in AgeGroup.values) {
        if (candidate.name == match.group(1)) {
          ageGroup = candidate;
          break;
        }
      }
      if (ageGroup == null) continue; // unrecognised age-group segment.

      images.add(StrangerImage(assetPath: path, ageGroup: ageGroup));
    }

    _cache = images;
    return images;
  }

  @override
  Future<List<StrangerImage>> pickDistractors({
    required int count,
    required AgeGroup targetAgeGroup,
    required SimilarityTier tier,
  }) async {
    final library = await _library();
    final acceptable = acceptableDistractorAgeGroups(targetAgeGroup: targetAgeGroup, tier: tier);
    final candidates = library.where((s) => acceptable.contains(s.ageGroup)).toList()..shuffle();

    if (candidates.isEmpty) {
      throw StateError(
        'No bundled stranger images tagged ${acceptable.map((g) => g.name).join("/")} — '
        'is assets/stranger_library/ populated and declared in pubspec.yaml?',
      );
    }

    // The MVP pool is small (§5.3: 10–15 images) — repeat with replacement
    // rather than fail a trial for lacking enough distinct faces in one
    // age-group bucket.
    return [for (var i = 0; i < count; i++) candidates[i % candidates.length]];
  }
}
