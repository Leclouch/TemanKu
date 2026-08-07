import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/theme/temanku_theme.dart';

/// A category's answer zone (drag target / tap slot) — **shared component,
/// jointly owned.**
///
/// Every category is a [CategoryStyle]: a colour AND a shape, always painted
/// together. Colour alone must never carry meaning here — this is an
/// accessibility requirement (colour-vision deficiency), not a style choice —
/// so this widget always draws [CategoryStyle.shape] as an overlay on top of
/// the fill, never the fill alone.
class AnswerTarget extends StatelessWidget {
  const AnswerTarget({
    super.key,
    required this.style,
    this.label,
    this.child,
  });

  final CategoryStyle style;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TemanKuMetrics.minTouchTarget,
        minHeight: TemanKuMetrics.minTouchTarget,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: style.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryShapeOverlay(shape: style.shape, color: colors.background),
            if (child != null) ...[const SizedBox(height: 8), child!],
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.body.copyWith(color: colors.background),
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
