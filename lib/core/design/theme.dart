// ============================================================================
// TEMANKU THEME — token → Material binding.
//
// Everything in `tokens.dart` is inert data. This file is what makes a bare
// `AppBar(...)`, `FilledButton(...)` or `AlertDialog(...)` come out on-brand
// without the call site knowing anything about the design system.
//
// That is the whole consistency strategy, and it is why this app does not need
// a third-party component library: the drift being fixed here was never
// "Flutter's widgets look wrong", it was "half the app styled its widgets by
// hand and the other half accepted `ColorScheme.fromSeed` defaults". Both
// halves are addressed by theming the components once, here.
//
// Rule for feature code: reach for a `Tk*` component from `components/` first;
// if none fits, a plain Material widget is fine, because it is themed. What is
// never fine is a local `Container(decoration: BoxDecoration(...))` that
// reinvents card chrome — that is how the drift started.
// ============================================================================

import 'package:flutter/material.dart';

import 'package:temanku/core/design/tokens.dart';

/// Builds the two [ThemeData]s.
///
/// Both surfaces read tokens through `Theme.of(context).extension<...>()`, so
/// the child and guardian screens are genuinely one source. They differ in
/// density and register, never in palette — see [TemanKuColors.child].
abstract final class TemanKuTheme {
  static ThemeData _build(TemanKuColors c) {
    const type = TemanKuTypography.scale;

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: c.primaryAccent,
      // Each `on*` role is derived from its own fill rather than sharing one
      // token. The palette straddles the point where the better ink flips:
      // black wins on the orange primary (6.00:1 vs white's 3.50:1) and on
      // the success green (7.57:1 vs 2.78:1), while white wins on the blue
      // secondary (4.69:1 vs 4.48:1). One shared value would fail somewhere.
      onPrimary: tkInkOn(c.primaryAccent),
      primaryContainer: c.primaryAccentWash,
      onPrimaryContainer: c.text,
      secondary: c.secondaryAccent,
      onSecondary: tkInkOn(c.secondaryAccent),
      secondaryContainer: c.surfaceTinted,
      onSecondaryContainer: c.text,
      tertiary: c.successFeedback,
      onTertiary: tkInkOn(c.successFeedback),
      tertiaryContainer: c.successWash,
      onTertiaryContainer: c.text,
      // The child surface has no alarm slot at all (§12). Mapping Material's
      // mandatory error role onto the neutral "try again" token rather than a
      // red is what keeps a stray `Theme.of(context).colorScheme.error` from
      // smuggling an alarm colour onto a child screen.
      error: c.neutralFeedback,
      onError: tkInkOn(c.neutralFeedback),
      errorContainer: c.neutralWash,
      onErrorContainer: c.text,
      surface: c.background,
      onSurface: c.text,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceTinted,
      surfaceContainerHighest: c.surfaceTinted,
      onSurfaceVariant: c.textMuted,
      outline: c.border,
      outlineVariant: c.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.text,
      onInverseSurface: c.background,
      inversePrimary: c.primaryAccent,
    );

    final textTheme = TextTheme(
      displayLarge: type.displayXl,
      displayMedium: type.displayLg,
      displaySmall: type.display,
      headlineLarge: type.displayLg,
      headlineMedium: type.display,
      headlineSmall: type.titleLg,
      titleLarge: type.titleLg,
      titleMedium: type.title,
      titleSmall: type.title,
      bodyLarge: type.body,
      bodyMedium: type.body,
      bodySmall: type.bodySm,
      labelLarge: type.label,
      labelMedium: type.label,
      labelSmall: type.caption,
    ).apply(bodyColor: c.text, displayColor: c.text);

    // Shared across every button variant so a FilledButton and an
    // OutlinedButton sitting next to each other agree on height and shape.
    final buttonPadding = WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: TkSpace.lg, vertical: TkSpace.sm),
    );
    final buttonSize = WidgetStateProperty.all(
      const Size(0, TemanKuMetrics.minTouchTarget),
    );
    final buttonShape = WidgetStateProperty.all(
      const RoundedRectangleBorder(borderRadius: TkRadius.pill),
    );
    final buttonLabel = WidgetStateProperty.all(type.label);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      // ---- Chrome ---------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        // Flat on purpose. A tinted, elevating app bar changes colour as the
        // guardian scrolls; a surface that shifts under you is exactly the
        // unpredictability this audience's guidance warns about.
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: TkSpace.gutter,
        titleTextStyle: type.titleLg.copyWith(color: c.text),
        iconTheme: IconThemeData(color: c.text, size: 24),
      ),

      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: TkStroke.hairline,
        space: TkSpace.md,
      ),

      iconTheme: IconThemeData(color: c.text, size: 24),

      // ---- Containers -----------------------------------------------------
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        // Outlines, not shadows. Shadow-based depth reads as ambiguous at
        // this palette's low contrast range; a 2pt outline does not.
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TkRadius.md,
          side: BorderSide(color: c.border, width: TkStroke.regular),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TkRadius.xl,
          side: BorderSide(color: c.border, width: TkStroke.regular),
        ),
        titleTextStyle: type.titleLg.copyWith(color: c.text),
        contentTextStyle: type.body.copyWith(color: c.text),
        insetPadding: const EdgeInsets.all(TkSpace.xl),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: TkRadius.xlR),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: type.body.copyWith(color: c.background),
        actionTextColor: c.neutralFeedback,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(TkSpace.md),
        shape: const RoundedRectangleBorder(borderRadius: TkRadius.sm),
        elevation: 0,
      ),

      // ---- Buttons --------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.border : c.primaryAccent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : tkInkOn(c.primaryAccent),
          ),
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonLabel,
          elevation: WidgetStateProperty.all(0),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : c.text,
          ),
          backgroundColor: WidgetStateProperty.all(c.surface),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? c.border : c.borderStrong,
              width: TkStroke.regular,
            ),
          ),
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : c.primaryAccent,
          ),
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonLabel,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : c.text,
          ),
          minimumSize: WidgetStateProperty.all(
            const Size.square(TemanKuMetrics.minTouchTarget),
          ),
          shape: WidgetStateProperty.all(const CircleBorder()),
        ),
      ),

      // ---- Selection ------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primaryAccentWash,
        labelStyle: type.label.copyWith(color: c.text),
        side: BorderSide(color: c.border, width: TkStroke.regular),
        shape: const RoundedRectangleBorder(borderRadius: TkRadius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: TkSpace.sm,
          vertical: TkSpace.xs,
        ),
        showCheckmark: false,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tkInkOn(c.primaryAccent) : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primaryAccent : c.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.borderStrong),
        trackOutlineWidth: WidgetStateProperty.all(TkStroke.regular),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primaryAccent : c.borderStrong,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primaryAccent : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(tkInkOn(c.primaryAccent)),
        side: BorderSide(color: c.borderStrong, width: TkStroke.regular),
        shape: const RoundedRectangleBorder(borderRadius: TkRadius.xs),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TkSpace.md,
          vertical: TkSpace.xs,
        ),
        minVerticalPadding: TkSpace.sm,
        titleTextStyle: type.title.copyWith(color: c.text),
        subtitleTextStyle: type.bodySm.copyWith(color: c.textMuted),
        iconColor: c.text,
        shape: const RoundedRectangleBorder(borderRadius: TkRadius.sm),
      ),

      // ---- Input ----------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TkSpace.md,
          vertical: TkSpace.sm,
        ),
        hintStyle: type.body.copyWith(color: c.textMuted),
        labelStyle: type.bodySm.copyWith(color: c.textMuted),
        helperStyle: type.caption.copyWith(color: c.textMuted),
        // Material's default is red; §12 forbids alarm colour reaching the
        // child surface, and the two themes share this binding.
        errorStyle: type.caption.copyWith(color: c.text),
        border: OutlineInputBorder(
          borderRadius: TkRadius.md,
          borderSide: BorderSide(color: c.border, width: TkStroke.regular),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TkRadius.md,
          borderSide: BorderSide(color: c.border, width: TkStroke.regular),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TkRadius.md,
          borderSide: BorderSide(color: c.primaryAccent, width: TkStroke.thick),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: TkRadius.md,
          borderSide: BorderSide(color: c.neutralFeedback, width: TkStroke.thick),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: TkRadius.md,
          borderSide: BorderSide(color: c.neutralFeedback, width: TkStroke.thick),
        ),
      ),

      // ---- Progress -------------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primaryAccent,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
        linearMinHeight: 6,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.text, borderRadius: TkRadius.xs),
        textStyle: type.caption.copyWith(color: c.background),
      ),

      extensions: [c, type],
    );
  }

  static ThemeData get child => _build(TemanKuColors.child);
  static ThemeData get guardian => _build(TemanKuColors.guardian);
}

/// Read tokens without the ceremony: `context.colors.background`.
///
/// This extension is the *only* sanctioned way for feature code to reach a
/// token. The fallbacks keep a widget rendered outside a [TemanKuTheme] (a
/// bare `MaterialApp` in a test, say) on real values rather than crashing.
extension TemanKuThemeAccess on BuildContext {
  TemanKuColors get colors =>
      Theme.of(this).extension<TemanKuColors>() ?? TemanKuColors.child;

  TemanKuTypography get type =>
      Theme.of(this).extension<TemanKuTypography>() ?? TemanKuTypography.scale;

  /// True when the platform asks for reduced motion.
  ///
  /// Honoured by every animated component in `components/`. Neurodivergent
  /// design guidance treats motion control as a requirement, not a preference:
  /// animation here degrades to an instant cut, never to a slower animation.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// The motion duration to actually use — [TkMotion] value, or zero when the
  /// platform asked for stillness.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
