// ============================================================================
// TEMANKU DESIGN TOKENS — the single source of truth for every visual value.
//
// This is the layer that makes the app look like one product. It plays the
// role shadcn/ui's `globals.css` plays in a React app: nothing below it
// invents a value. If a feature file contains a raw `Color(0x...)`, a bare
// `fontSize:`, or a naked `EdgeInsets.all(17)`, that is the bug — the token
// is missing here, not the screen.
//
// Reading order:
//   1. [TkPalette]  — the raw brand hexes. The ONLY place a hex literal lives.
//   2. [TemanKuColors] — semantic slots (`background`, `successFeedback`).
//      Named by ROLE, never by hue: a slot called `successFeedback` survives a
//      palette change; one called `green` does not.
//   3. [TemanKuTypography] — the type scale.
//   4. [TkSpace] / [TkRadius] / [TkStroke] / [TkMotion] — geometry and time.
//
// Two structural rules from source-of-truth §12 are load-bearing here, not
// style preferences:
//   - the child surface has NO error/alarm slot at all (no red on the child
//     screen; "try again" is neutral, at EQUAL visual weight to "correct");
//   - each category gets a consistent colour AND shape, always paired, never
//     colour alone (redundant coding). See `content/module_definition.dart`.
// ============================================================================

import 'package:flutter/material.dart';

/// The brand palette, exactly as supplied (`colors.zip → figma-colors.json`).
///
/// **The only place in the codebase where a colour literal is allowed.**
/// Everything else reads a semantic slot off [TemanKuColors]. Named by hue
/// here on purpose — this class is the paint box, not the design.
abstract final class TkPalette {
  /// #FD4401 — the brand orange. Display headings and the primary action.
  static const orange = Color(0xFFFD4401);

  /// #FDCB40 — warm yellow. Highlight fills and the "try again" beat.
  static const yellow = Color(0xFFFDCB40);

  /// #FFF2B7 — pale yellow. Tinted surfaces, selected-row wash.
  static const paleYellow = Color(0xFFFFF2B7);

  /// #00B351 — signal green. "Correct", and Makanan's target category.
  static const green = Color(0xFF00B351);

  /// #A7EB98 — soft green. Success washes, never signal weight.
  static const softGreen = Color(0xFFA7EB98);

  /// #2668FD — signal blue. Keluarga's target category, informational chips.
  static const blue = Color(0xFF2668FD);

  /// #FFCCCD — soft pink. Distractor-category fill on the child surface.
  ///
  /// Deliberately a *pink*, not a red: §12 forbids an alarm colour anywhere a
  /// child can see it, and this fills the "not the answer" category card.
  static const pink = Color(0xFFFFCCCD);

  /// #F3EFE0 — cream. The page ground on both surfaces.
  ///
  /// Not white, and that is the point: autism design guidance is consistent
  /// that a pure-white ground under high-contrast ink produces glare. Cream
  /// keeps the 4.5:1 floor intact while dropping the luminance ceiling.
  static const cream = Color(0xFFF3EFE0);

  /// #FFFFFF — card/sheet surfaces that need to lift off [cream].
  static const white = Color(0xFFFFFFFF);

  /// #000000 — primary ink. 21:1 on both [cream] and [white].
  static const black = Color(0xFF000000);
}

/// The semantic colour slots the app consumes.
///
/// Feature code never touches [TkPalette] — it reads these. Every slot below
/// carries the constraint that governs it in its own doc comment; those are
/// requirements, not descriptions.
@immutable
class TemanKuColors extends ThemeExtension<TemanKuColors> {
  const TemanKuColors({
    required this.background,
    required this.surface,
    required this.surfaceTinted,
    required this.text,
    required this.textMuted,
    required this.onAccent,
    required this.border,
    required this.borderStrong,
    required this.primaryAccent,
    required this.primaryAccentWash,
    required this.successFeedback,
    required this.successWash,
    required this.neutralFeedback,
    required this.neutralWash,
    required this.secondaryAccent,
    required this.info,
  });

  /// Page ground. Warm cream, never white — see [TkPalette.cream].
  final Color background;

  /// Card and sheet fill, lifted off [background].
  final Color surface;

  /// A quieter card fill for grouped/secondary content.
  final Color surfaceTinted;

  /// Primary ink. 21:1 against [background] and [surface].
  final Color text;

  /// Secondary ink — metadata, captions, helper copy. Still ≥4.5:1.
  ///
  /// Never used for anything a guardian must act on, and never on the child
  /// surface for task content.
  final Color textMuted;

  /// Ink that sits on top of [primaryAccent] and [successFeedback] fills.
  ///
  /// **Black, not white** — measured, not chosen. White on the brand orange
  /// is 3.50:1, which fails WCAG AA for button text; the supplied specimen
  /// records that same 3.50 and marks it "Poor". Black on the same orange is
  /// 6.00:1, and on the success green 7.57:1.
  ///
  /// Roles whose fill is *darker* than orange (the blue [secondaryAccent] and
  /// [info]) do better with white, so `theme.dart` derives those per role via
  /// [tkInkOn] rather than reusing this slot.
  final Color onAccent;

  /// Hairline separators and resting card outlines.
  final Color border;

  /// The outline on interactive, focused, or selected chrome.
  final Color borderStrong;

  /// The main interactive accent — primary buttons, links, active states.
  ///
  /// Brand orange. Never used as feedback: on the child surface an accent and
  /// an answer-outcome must stay visually separable.
  final Color primaryAccent;

  /// A low-chroma [primaryAccent] for selected backgrounds.
  final Color primaryAccentWash;

  /// "Correct" feedback. Child-facing.
  final Color successFeedback;

  /// The wash form of [successFeedback], for a whole-card correct state.
  final Color successWash;

  /// "Try again" feedback. Child-facing, and deliberately at **equal visual
  /// weight** to [successFeedback] — this is not a de-emphasised error state,
  /// and it must never become one.
  ///
  /// Yellow, not red. Paired with [successFeedback]'s green it also clears the
  /// commonest CVD confusion (both stay separable in deuteranopia by
  /// luminance, and the mode screens pair every flash with a shape besides).
  final Color neutralFeedback;

  /// The wash form of [neutralFeedback].
  final Color neutralWash;

  /// Guardian-surface-only accent. Never used on the child screen.
  final Color secondaryAccent;

  /// Informational chips and non-actionable status on the guardian surface.
  final Color info;

  /// Child session surface: calm, predictable, **no alarm colour anywhere**.
  static const child = TemanKuColors(
    background: TkPalette.cream,
    surface: TkPalette.white,
    surfaceTinted: TkPalette.paleYellow,
    text: TkPalette.black,
    textMuted: Color(0xFF6B6659),
    onAccent: TkPalette.black,
    border: Color(0xFFDDD6C2),
    borderStrong: TkPalette.black,
    primaryAccent: TkPalette.orange,
    primaryAccentWash: Color(0xFFFFE2D6),
    successFeedback: TkPalette.green,
    successWash: TkPalette.softGreen,
    neutralFeedback: TkPalette.yellow,
    neutralWash: TkPalette.paleYellow,
    // Present so the two surfaces share one shape, unused here by rule.
    secondaryAccent: TkPalette.blue,
    info: TkPalette.blue,
  );

  /// Guardian surface: same grammar, same tokens, warmer chrome.
  ///
  /// One token set across both temperatures is deliberate — the "federated
  /// design" rule in §12 means the two surfaces differ in *density and
  /// register*, not in palette.
  static const guardian = TemanKuColors(
    background: TkPalette.cream,
    surface: TkPalette.white,
    surfaceTinted: TkPalette.paleYellow,
    text: TkPalette.black,
    textMuted: Color(0xFF6B6659),
    onAccent: TkPalette.black,
    border: Color(0xFFDDD6C2),
    borderStrong: TkPalette.black,
    primaryAccent: TkPalette.orange,
    primaryAccentWash: Color(0xFFFFE2D6),
    successFeedback: TkPalette.green,
    successWash: TkPalette.softGreen,
    neutralFeedback: TkPalette.yellow,
    neutralWash: TkPalette.paleYellow,
    secondaryAccent: TkPalette.blue,
    info: TkPalette.blue,
  );

  @override
  TemanKuColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceTinted,
    Color? text,
    Color? textMuted,
    Color? onAccent,
    Color? border,
    Color? borderStrong,
    Color? primaryAccent,
    Color? primaryAccentWash,
    Color? successFeedback,
    Color? successWash,
    Color? neutralFeedback,
    Color? neutralWash,
    Color? secondaryAccent,
    Color? info,
  }) =>
      TemanKuColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceTinted: surfaceTinted ?? this.surfaceTinted,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        onAccent: onAccent ?? this.onAccent,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        primaryAccent: primaryAccent ?? this.primaryAccent,
        primaryAccentWash: primaryAccentWash ?? this.primaryAccentWash,
        successFeedback: successFeedback ?? this.successFeedback,
        successWash: successWash ?? this.successWash,
        neutralFeedback: neutralFeedback ?? this.neutralFeedback,
        neutralWash: neutralWash ?? this.neutralWash,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
        info: info ?? this.info,
      );

  @override
  TemanKuColors lerp(covariant TemanKuColors? other, double t) {
    if (other == null) return this;
    return TemanKuColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceTinted: Color.lerp(surfaceTinted, other.surfaceTinted, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      primaryAccentWash: Color.lerp(primaryAccentWash, other.primaryAccentWash, t)!,
      successFeedback: Color.lerp(successFeedback, other.successFeedback, t)!,
      successWash: Color.lerp(successWash, other.successWash, t)!,
      neutralFeedback: Color.lerp(neutralFeedback, other.neutralFeedback, t)!,
      neutralWash: Color.lerp(neutralWash, other.neutralWash, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// The WCAG contrast ratio between two colours, 1.0 (identical) to 21.0.
double tkContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Picks readable ink for an arbitrary fill.
///
/// The category fills in `content/` span [TkPalette.blue] to
/// [TkPalette.paleYellow], so no single hardcoded label colour works across
/// all of them — the previous fixed cream label vanished entirely on the
/// light fills.
///
/// Compares the two candidates' **actual contrast ratios** rather than
/// thresholding on luminance. Those are not the same test, and the difference
/// is not academic: a luminance cut at the naive midpoint sends
/// [TkPalette.green] to white ink at 2.78:1, when black on the same green is
/// 7.2:1. Saturated mid-tones are exactly where the shortcut fails, and this
/// palette is mostly saturated mid-tones.
Color tkInkOn(Color fill) =>
    tkContrast(TkPalette.black, fill) >= tkContrast(TkPalette.white, fill)
        ? TkPalette.black
        : TkPalette.white;

/// The type scale.
///
/// Derived from the supplied specimen, with two deliberate departures, both
/// documented at the styles concerned: display sizes are re-based for phone,
/// and body leading is opened up from the specimen's 1.20 to [_bodyLeading].
///
/// Fonts are bundled as static assets (§11 offline-first — no `google_fonts`,
/// no network fetch for type). See [_displayFamily] / [_bodyFamily] for the
/// substitution note.
@immutable
class TemanKuTypography extends ThemeExtension<TemanKuTypography> {
  const TemanKuTypography({
    required this.displayXl,
    required this.displayLg,
    required this.display,
    required this.titleLg,
    required this.title,
    required this.body,
    required this.bodySm,
    required this.label,
    required this.caption,
    required this.mono,
  });

  /// Stands in for **Robuck Rounded**, which is a commercial licence we do not
  /// hold. Nunito is the closest OFL-licensed match — geometric, rounded, and
  /// heavy enough at w800/w900 to carry the same display weight.
  ///
  /// To adopt the real face: drop the files into `assets/fonts/robuck/`,
  /// register the family in `pubspec.yaml`, and change this one constant.
  static const _displayFamily = 'Nunito';

  /// Stands in for **ABC Diatype Rounded Plus** (also commercial). Same
  /// swap-in-one-place rule as [_displayFamily].
  static const _bodyFamily = 'Figtree';

  static const _monoFamily = 'IBM Plex Mono';

  /// The specimen's tracking, in ems: -0.466019/23.3009 = -0.02.
  static const _tightTracking = -0.02;

  /// The specimen measures 1.20 (15.9778/13.3148). That is display leading on
  /// a marketing page, and too tight for sustained reading — cognitive
  /// accessibility guidance for this audience calls for generous line spacing
  /// in running copy. Display styles keep the specimen's tight ratio; body
  /// copy gets this instead.
  static const _bodyLeading = 1.45;

  /// Hero display. The specimen's 149.79/119.83 is a desktop web hero
  /// (1.00 ratio at 180px on a 0.832 inspection zoom); this is that scale
  /// re-based for a phone viewport. Ratio preserved at 0.85 rather than the
  /// literal 0.80 — Nunito carries taller extenders than Robuck Rounded and
  /// clips its own descenders below that.
  final TextStyle displayXl;

  /// Section hero — the specimen's 43.27/34.62 tier.
  final TextStyle displayLg;

  /// Screen title. The default display role.
  final TextStyle display;

  /// The specimen's H2/H4 tier: 23.3px, w700, -0.02em.
  final TextStyle titleLg;

  /// The specimen's H3 tier: 16.6px, w700, -0.02em.
  final TextStyle title;

  /// Running copy. The specimen's 13.31px paragraph, re-based to 16 for a
  /// phone and opened to [_bodyLeading].
  final TextStyle body;

  /// Secondary copy — helper text under a control, card subtitles.
  final TextStyle bodySm;

  /// Button and chip text. Same size as [bodySm], heavier.
  final TextStyle label;

  /// The specimen's 10.65px/9.59px span tier — metadata only.
  final TextStyle caption;

  /// Timestamps only.
  final TextStyle mono;

  static const scale = TemanKuTypography(
    displayXl: TextStyle(
      fontFamily: _displayFamily,
      fontSize: 52,
      fontWeight: FontWeight.w800,
      height: 0.95,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displayLg: TextStyle(
      fontFamily: _displayFamily,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    display: TextStyle(
      fontFamily: _displayFamily,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleLg: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 22 * _tightTracking,
    ),
    title: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 17 * _tightTracking,
    ),
    body: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: _bodyLeading,
      letterSpacing: 16 * _tightTracking,
    ),
    bodySm: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: _bodyLeading,
      letterSpacing: 14 * _tightTracking,
    ),
    label: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 15 * _tightTracking,
    ),
    caption: TextStyle(
      fontFamily: _bodyFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
    mono: TextStyle(
      fontFamily: _monoFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
  );

  /// Retained so existing call sites keep compiling. Prefer [scale].
  static const placeholder = scale;

  @override
  TemanKuTypography copyWith({
    TextStyle? displayXl,
    TextStyle? displayLg,
    TextStyle? display,
    TextStyle? titleLg,
    TextStyle? title,
    TextStyle? body,
    TextStyle? bodySm,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? mono,
  }) =>
      TemanKuTypography(
        displayXl: displayXl ?? this.displayXl,
        displayLg: displayLg ?? this.displayLg,
        display: display ?? this.display,
        titleLg: titleLg ?? this.titleLg,
        title: title ?? this.title,
        body: body ?? this.body,
        bodySm: bodySm ?? this.bodySm,
        label: label ?? this.label,
        caption: caption ?? this.caption,
        mono: mono ?? this.mono,
      );

  @override
  TemanKuTypography lerp(covariant TemanKuTypography? other, double t) {
    if (other == null) return this;
    return TemanKuTypography(
      displayXl: TextStyle.lerp(displayXl, other.displayXl, t)!,
      displayLg: TextStyle.lerp(displayLg, other.displayLg, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      titleLg: TextStyle.lerp(titleLg, other.titleLg, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySm: TextStyle.lerp(bodySm, other.bodySm, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}

/// The spacing scale. Every gap in the app is one of these.
///
/// A 4pt base with a doubling-ish ramp — the point is not the specific numbers
/// but that there are only nine of them, so two screens built a week apart
/// still rhyme.
abstract final class TkSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// The standard screen gutter. Phone-first.
  static const double gutter = xl;
}

/// The corner radii. Generous by design — the brand's display face is a
/// *Rounded* cut, and the softness has to carry through to the chrome or the
/// two read as different products.
abstract final class TkRadius {
  static const Radius xsR = Radius.circular(8);
  static const Radius smR = Radius.circular(12);
  static const Radius mdR = Radius.circular(16);
  static const Radius lgR = Radius.circular(20);
  static const Radius xlR = Radius.circular(24);

  static const BorderRadius xs = BorderRadius.all(xsR);
  static const BorderRadius sm = BorderRadius.all(smR);

  /// The default for cards, sheets, and inputs.
  static const BorderRadius md = BorderRadius.all(mdR);

  /// Large tappable cards and answer targets.
  static const BorderRadius lg = BorderRadius.all(lgR);

  /// Modals and the biggest surfaces.
  static const BorderRadius xl = BorderRadius.all(xlR);

  /// Pills — chips, badges, and the primary button.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Border widths. Thick, on purpose: outline weight is what lets this palette
/// stay soft without the layout going mushy.
abstract final class TkStroke {
  static const double hairline = 1;
  static const double regular = 2;
  static const double thick = 3;

  /// The answer-feedback ring on the child surface.
  static const double feedback = 4;
}

/// Durations and curves.
///
/// Ceiling of [slow] is not arbitrary: neurodivergent design guidance is
/// consistent that motion must be brief, non-looping, and never decorative.
/// Nothing in this app animates for longer than [slow], and nothing repeats.
abstract final class TkMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 350);

  /// How long a correct/try-again flash stays up before the next trial.
  static const Duration feedbackHold = Duration(milliseconds: 500);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;
}

/// Layout constants that are accessibility requirements, not style preferences.
abstract final class TemanKuMetrics {
  /// §11: minimum touch target 44×44pt, **verified at phone scale for the
  /// guardian corner cluster** — a mis-tap there misjudges the child. This is
  /// not a value the design pass gets to lower.
  static const double minTouchTarget = 44;

  /// The comfortable target for child-facing controls, which are hit by
  /// smaller hands under less motor control than the guardian's.
  static const double childTouchTarget = 64;

  /// Phone is the primary design/test target (§11). Above this width, treat the
  /// layout as tablet and let constraints do the work — no separate tablet UI.
  static const double tabletBreakpoint = 600;

  /// Content column cap. Bounded, not fixed: phone-first, tablet free.
  static const double contentMaxWidth = 480;

  /// A wider cap for guardian list/grid surfaces, which tolerate more columns.
  static const double guardianMaxWidth = 640;
}
