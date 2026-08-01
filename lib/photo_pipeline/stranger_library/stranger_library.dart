/// Bundled Keluarga distractor library — **IT-2.**
///
/// Source-of-truth §5.3. Licensed-stock or synthetic faces, **never real private
/// individuals photographed without consent.** Targets must be personal (that is
/// the far-transfer thesis); distractors only need to be plausible non-family, so
/// a shared bundled asset is *correct*, not a compromise — it removes the
/// third-party consent problem structurally.
///
/// MVP scope: 10–15 images, sufficient for Steps 1–4. Documented as
/// minimum-viable; production expansion is a tracked open item (§14).
///
/// Two requirements that shape the API below:
///   (a) demographic diversity matched to plausibly resemble Indonesian families,
///       preventing "family = people who look like this" shortcut-learning;
///   (b) candid, phone-photo-realistic style so children key off faces, not polish.
library;

/// Keluarga's similarity dial is **demographic closeness of the stranger**
/// (§4.4) — different age group at the easy end, same-age same-gender at the
/// hard end. That is why every asset must be tagged with these two attributes:
/// without them the dial cannot be moved.
enum AgeBand { child, adult, elder }

enum ApparentGender { female, male }

class StrangerImage {
  const StrangerImage({
    required this.assetPath,
    required this.ageBand,
    required this.gender,
  });

  final String assetPath;
  final AgeBand ageBand;
  final ApparentGender gender;
}

abstract class StrangerLibrary {
  /// Distractors for one trial, filtered to the requested demographic profile.
  ///
  /// [matchAge] / [matchGender] rise with the similarity tier: at the easy end
  /// neither matches the target family member, at the hard end both do.
  Future<List<StrangerImage>> pick({
    required int count,
    required AgeBand targetAge,
    required ApparentGender targetGender,
    required bool matchAge,
    required bool matchGender,
  });
}

/// TODO(IT-2): implement — Day 3, alongside Keluarga module wiring.
/// Reads from `assets/stranger_library/`; see that folder's .gitkeep for the
/// filename convention the loader is expected to parse.
class BundledStrangerLibrary implements StrangerLibrary {
  @override
  Future<List<StrangerImage>> pick({
    required int count,
    required AgeBand targetAge,
    required ApparentGender targetGender,
    required bool matchAge,
    required bool matchGender,
  }) async {
    throw UnimplementedError('BundledStrangerLibrary.pick');
  }
}
