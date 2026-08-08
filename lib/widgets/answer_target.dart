import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/design/design.dart';

/// A category's answer zone (drag target / tap slot) — **shared component,
/// jointly owned.**
///
/// Every category is a [CategoryStyle]: a colour AND a shape, always painted
/// together. Colour alone must never carry meaning here — this is an
/// accessibility requirement (colour-vision deficiency), not a style choice —
/// so this widget always draws [CategoryStyle.shape] as an overlay on top of
/// the fill, never the fill alone.
///
/// Ink and overlay colours are **derived from the fill** via [tkInkOn] rather
/// than fixed. The brand palette spans [TkPalette.blue] to
/// [TkPalette.paleYellow], so no single hardcoded label colour is legible on
/// every category — the previous fixed cream label vanished entirely on the
/// light fills.
class AnswerTarget extends StatelessWidget {
  const AnswerTarget({
    super.key,
    required this.style,
    this.label,
    this.child,
    this.labelStyle,
  });

  final CategoryStyle style;
  final String? label;
  final Widget? child;

  /// Overrides the label's type role — null keeps [TemanKuTypography.title],
  /// the default every existing caller (match mode's zones among them) still
  /// gets. Tap and speak mode pass [TemanKuTypography.titleLg].
  ///
  /// Colour is always ignored if set: it is computed from the fill.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final ink = tkInkOn(style.color);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TemanKuMetrics.minTouchTarget,
        minHeight: TemanKuMetrics.minTouchTarget,
      ),
      child: Container(
        padding: const EdgeInsets.all(TkSpace.sm),
        decoration: BoxDecoration(
          color: style.color,
          borderRadius: TkRadius.md,
          // A thin ink outline at the same colour as the label. The pale
          // categories (paleYellow, pink) otherwise dissolve into the cream
          // ground and stop reading as a bounded target at all.
          border: Border.all(
            color: ink.withValues(alpha: 0.18),
            width: TkStroke.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryShapeOverlay(shape: style.shape, color: ink),
            if (child != null) ...[const SizedBox(height: TkSpace.xs), child!],
            if (label != null) ...[
              const SizedBox(height: TkSpace.xxs),
              Text(
                label!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (labelStyle ?? context.type.title).copyWith(color: ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The shape half of the colour+shape pairing, painted in a colour that
/// contrasts with the category fill so it reads as an overlay, not a shadow.
class _CategoryShapeOverlay extends StatelessWidget {
  const _CategoryShapeOverlay({required this.shape, required this.color});

  final CategoryShape shape;
  final Color color;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case CategoryShape.circle:
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      case CategoryShape.square:
        return Container(width: _size, height: _size, color: color);
      case CategoryShape.diamond:
        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: _size * 0.75,
            height: _size * 0.75,
            color: color,
          ),
        );
    }
  }
}
