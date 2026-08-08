/// Shared domain vocabulary.
///
/// These live in `core/constants/` rather than in `engine/` or `data/` because both
/// IT-1 and IT-2 need them and neither should own them. Per ADR-2's practical rule:
/// changes here are shared-folder changes — raise them at the evening checkpoint.
library;

/// Response mode. Source-of-truth §4.1: response mode and skill domain are
/// **separate axes** — the instruction, not the motor channel, determines the skill.
enum ResponseMode {
  tap,
  match,
  speak,
}

/// Modules built for MVP. Uang and Sampah are fully designed but intentionally
/// deferred (§4.2) — deliberately absent from this enum so an unbuilt module can
/// never be selected by accident.
enum ModuleId {
  makanan,
  keluarga,
}

/// Distractor-similarity tier — the second of the two independent dials (§4.4).
///
/// For Makanan these are visual/categorical. For Keluarga the same tiers mean
/// **demographic closeness of the stranger** (different age group → same age
/// group as the target — see [AgeGroup] and `photo_pipeline/stranger_library/`),
/// which is why the tier is named abstractly rather than, say, `visuallySimilar`.
enum SimilarityTier {
  /// Step 1–3: distractors from a different category entirely.
  differentCategory,

  /// Step 4–6: same category, clearly distinct.
  sameCategoryDistinct,

  /// Step 7–9: visually (or demographically) similar.
  similar,

  /// Step 10: semantic instruction over a mixed array — "tunjuk yang boleh dimakan".
  lrffc,
}

/// Array size — the first dial. Grows one at a time (2→3→4), never jumps, and
/// **resets to 2 whenever similarity steps up** (§4.4). Encoded as a plain int
/// elsewhere; these bounds are the guard rails.
abstract final class ArraySize {
  static const int min = 2;
  static const int max = 4;
  static const int extendedMax = 6;
}

/// Demographic age group — Keluarga's similarity axis (§4.4). Tags both the
/// guardian's own target photos (a person's apparent age group, supplied at
/// upload — `features/guardian/photo_upload_screen.dart`) and the bundled
/// stranger distractors (`photo_pipeline/stranger_library/`), so the two can
/// be compared for demographic closeness. Not used outside Keluarga.
enum AgeGroup {
  child,
  teen,
  adult,
  elderly,
}

/// Outcome of a single trial, from the engine's point of view.
///
/// Note `notAttempted` — speak mode auto-flags "tidak mencoba" from VAD silence
/// (§6), and it is explicitly *not* the same thing as an incorrect answer.
enum TrialOutcome {
  correct,
  incorrect,
  notAttempted,
}
