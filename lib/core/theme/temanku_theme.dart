// TODO: replace with final design tokens (Claude Design)
//
// ============================================================================
// PLACEHOLDER THEME — NO REAL DESIGN TOKENS IN THIS FILE, ON PURPOSE.
//
// Visual design is being produced separately in Claude Design. This file exists
// to establish the *shape* the real theme slots into, not its values. Every
// colour below is a mid-grey so that nothing accidentally reads as "finished",
// and the type scale is wired to Flutter's default fonts — Fraunces / Plus
// Jakarta Sans / IBM Plex Mono are deliberately NOT installed or referenced yet,
// and there is no font package in pubspec.yaml.
//
// WHEN THE REAL TOKENS LAND: change the values in `TemanKuColors.child` and
// `TemanKuColors.guardian` below, and the three TextStyles in `TemanKuTypography`.
// That is the whole swap. Nothing outside this folder hardcodes a colour or a
// font size — if you find yourself reaching for `Color(0x...)` in a feature
// file, that is the bug, not a shortcut.
//
// Source-of-truth §12 records the intended structure this shape is built for:
// two temperatures, one grammar ("federated design") — the child screen calm and
// predictable, the guardian screen warm and notebook-like. Two things from §12
// are already load-bearing on structure rather than on values, so they are
// encoded here rather than left to the design pass:
//   - the child surface has NO error/alarm slot at all (§12: no red on the child
//     screen; "try again" is neutral, at equal visual weight to "correct");
//   - each category gets a consistent colour AND shape, always paired, never
//     colour alone (redundant coding, adopted from Japanese transit precedent).
//     `categoryShape` below is the hook for the shape half of that pair.
// ============================================================================

import 'package:flutter/material.dart';

/// The colour slots the app consumes. Named by role, never by hue — a slot
/// called `successFeedback` survives a palette change; one called `green` does not.
@immutable
class TemanKuColors extends ThemeExtension<TemanKuColors> {
  const TemanKuColors({
    required this.background,
    required this.text,
    required this.primaryAccent,
    required this.successFeedback,
    required this.neutralFeedback,
    required this.secondaryAccent,
  });

  /// Page background.
  final Color background;

  /// Primary text/ink.
  final Color text;

  /// Main interactive accent.
  final Color primaryAccent;

  /// "Correct" feedback. Child-facing.
  final Color successFeedback;

  /// "Try again" feedback. Child-facing, and deliberately at **equal visual
  /// weight** to [successFeedback] — this is not a de-emphasised error state,
  /// and it must never become one.
  final Color neutralFeedback;

  /// Guardian-surface-only accent. Not used on the child screen.
  final Color secondaryAccent;

  // --- PLACEHOLDER VALUES — swap these two blocks, nothing else --------------

  /// Child session surface: calm, predictable, no alarm colour.
  static const child = TemanKuColors(
    background: Color(0xFFE8E8E8),
    text: Color(0xFF3A3A3A),
    primaryAccent: Color(0xFF9A9A9A),
    successFeedback: Color(0xFF8C8C8C),
    neutralFeedback: Color(0xFFB0B0B0),
    secondaryAccent: Color(0xFFA6A6A6),
  );

  /// Guardian surface: warmer, notebook-like. Same slots, different temperature —
  /// one grammar, two temperatures.
  static const guardian = TemanKuColors(
    background: Color(0xFFDEDEDE),
    text: Color(0xFF2E2E2E),
    primaryAccent: Color(0xFF8F8F8F),
    successFeedback: Color(0xFF848484),
    neutralFeedback: Color(0xFFAAAAAA),
    secondaryAccent: Color(0xFF7C7C7C),
  );

  @override
  TemanKuColors copyWith({
    Color? background,
    Color? text,
    Color? primaryAccent,
    Color? successFeedback,
    Color? neutralFeedback,
    Color? secondaryAccent,
  }) =>
      TemanKuColors(
        background: background ?? this.background,
        text: text ?? this.text,
        primaryAccent: primaryAccent ?? this.primaryAccent,
        successFeedback: successFeedback ?? this.successFeedback,
        neutralFeedback: neutralFeedback ?? this.neutralFeedback,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      );

  @override
  TemanKuColors lerp(covariant TemanKuColors? other, double t) {
    if (other == null) return this;
    return TemanKuColors(
      background: Color.lerp(background, other.background, t)!,
      text: Color.lerp(text, other.text, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      successFeedback: Color.lerp(successFeedback, other.successFeedback, t)!,
      neutralFeedback: Color.lerp(neutralFeedback, other.neutralFeedback, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
    );
  }
}

/// Three named type roles. Wired to Flutter's default font for now — no font
/// package, no asset fonts, no `fontFamily` set anywhere.
@immutable
class TemanKuTypography extends ThemeExtension<TemanKuTypography> {
  const TemanKuTypography({
    required this.display,
    required this.body,
    required this.mono,
  });

  /// Headings and the child's instruction line.
  final TextStyle display;

  /// Everything else. All child-facing copy and UI.
  final TextStyle body;

  /// Timestamps only.
  final TextStyle mono;

  // --- PLACEHOLDER VALUES — swap this block when real type lands ------------
  static const placeholder = TemanKuTypography(
    display: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.2),
    body: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4),
    // `monospace` is a Flutter-resolved generic family, not a bundled font.
    mono: TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.3),
  );

  @override
  TemanKuTypography copyWith({
    TextStyle? display,
    TextStyle? body,
    TextStyle? mono,
  }) =>
      TemanKuTypography(
        display: display ?? this.display,
        body: body ?? this.body,
        mono: mono ?? this.mono,
      );

  @override
  TemanKuTypography lerp(covariant TemanKuTypography? other, double t) {
    if (other == null) return this;
    return TemanKuTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}

/// Layout constants that are accessibility requirements, not style preferences.
abstract final class TemanKuMetrics {
  /// §11: minimum touch target 44×44pt, **verified at phone scale for the
  /// guardian corner cluster** — a mis-tap there misjudges the child. This is
  /// not a value the design pass gets to lower.
  static const double minTouchTarget = 44;

  /// Phone is the primary design/test target (§11). Above this width, treat the
  /// layout as tablet and let constraints do the work — no separate tablet UI.
  static const double tabletBreakpoint = 600;
}

/// Builds the two [ThemeData]s. Both features read tokens through
/// `Theme.of(context).extension<...>()`, so the child and guardian surfaces are
/// genuinely one source.
abstract final class TemanKuTheme {
  static ThemeData _build(TemanKuColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primaryAccent,
      surface: colors.background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      extensions: [colors, TemanKuTypography.placeholder],
    );
  }

  static ThemeData get child => _build(TemanKuColors.child);
  static ThemeData get guardian => _build(TemanKuColors.guardian);
}

/// Read tokens without the ceremony: `context.colors.background`.
///
/// This extension is the *only* sanctioned way for feature code to reach a token.
extension TemanKuThemeAccess on BuildContext {
  TemanKuColors get colors =>
      Theme.of(this).extension<TemanKuColors>() ?? TemanKuColors.child;

  TemanKuTypography get type =>
      Theme.of(this).extension<TemanKuTypography>() ??
      TemanKuTypography.placeholder;
}
