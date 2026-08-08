/// The button vocabulary.
///
/// Flutter ships five button widgets and the app was using four of them
/// interchangeably — `OutlinedButton` for a primary action on one screen and
/// `FilledButton` for the same action on the next, `TextButton.icon` for a
/// navigation affordance that was a `TextButton` elsewhere. Since none of them
/// carried a theme, each also picked up a different `ColorScheme.fromSeed`
/// default.
///
/// [TkButton] collapses that to three named intents. The Material widgets are
/// still themed (see `theme.dart`) so an incidental `TextButton` inside a
/// dialog looks right — but new code should say what it *means* with a
/// [TkButtonVariant] rather than picking a widget by how it looks.
library;

import 'package:flutter/material.dart';

import 'package:temanku/core/design/tokens.dart';

enum TkButtonVariant {
  /// The one action that moves the screen forward. At most one per screen.
  primary,

  /// A real action that is not *the* action — outlined, equal height.
  secondary,

  /// Navigation and dismissal. No fill, no outline.
  quiet,
}

class TkButton extends StatelessWidget {
  const TkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TkButtonVariant.primary,
    this.icon,
    this.expand = false,
  });

  const TkButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : variant = TkButtonVariant.secondary;

  const TkButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : variant = TkButtonVariant.quiet;

  final String label;

  /// Null disables the button. Disabled is a *visible, explained* state here —
  /// see the callers, which always pair a disabled primary with helper text
  /// saying what is missing. A dead control with no explanation is the
  /// "freeze" trigger the ADHD guidance specifically calls out.
  final VoidCallback? onPressed;

  final TkButtonVariant variant;
  final IconData? icon;

  /// Fill the available width. Use for the single action at the bottom of a
  /// stepped flow.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    // Every label can ellipsize, icon or not. A button is laid out from the
    // label outward, so a long one silently overflows its Row instead of
    // shrinking — and Indonesian action phrases ("Selesai isi intake") run
    // considerably longer than the English they were designed against.
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      textAlign: TextAlign.center,
    );

    final child = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: TkSpace.xs),
              Flexible(child: text),
            ],
          );

    final button = switch (variant) {
      TkButtonVariant.primary => FilledButton(onPressed: onPressed, child: child),
      TkButtonVariant.secondary => OutlinedButton(onPressed: onPressed, child: child),
      TkButtonVariant.quiet => TextButton(onPressed: onPressed, child: child),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A row of buttons that wraps instead of overflowing.
///
/// The guardian home packed module buttons into a bare `Wrap` with a bespoke
/// spacing value each time; this fixes the spacing to the scale and keeps the
/// wrap behaviour.
class TkButtonRow extends StatelessWidget {
  const TkButtonRow({super.key, required this.children, this.alignment = WrapAlignment.start});

  final List<Widget> children;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: TkSpace.xs,
        runSpacing: TkSpace.xs,
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
}
