/// Decorative background shapes — the "Haikei-style" layer.
///
/// Five primitives ([TkDecorShape]), each a pure [CustomPainter] with no
/// asset file behind it — matching the visual family in
/// `referenceimages/maxima25.png` (arches, stacked-ellipse trees, star-bursts,
/// scalloped clouds, thin rings), which is flat shape composition, not
/// illustration craft. A screen composes 2-4 of these at different
/// size/rotation/opacity rather than each screen inventing its own decor —
/// same "recompose, don't multiply" rule `referenceimages/instruksi-decor-
/// icon-mascot.md` asks for with the Haikei exports this replaces.
///
/// Every instance takes its [color] from a caller-supplied token (a wash
/// slot off [TemanKuColors], almost always) — no literal ever lives here.
/// Purely decorative: [IgnorePointer] at the call site is the caller's job,
/// but every painter here is inert on its own (no gesture handling).
///
/// Static only, same as [Mascot] — nothing in this file loops or repeats,
/// consistent with `tokens.dart`'s [TkMotion] ceiling.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:temanku/core/design/asset_probe.dart';
import 'package:temanku/core/design/theme.dart';

enum TkDecorShape {
  /// An organic rounded blob — the background-fill primitive.
  blob,

  /// A rounded-top arch, half-height by default — echoes the "doorway" and
  /// "hill" shapes in the kids'-program reference.
  arch,

  /// A jagged N-point burst — the "pop"/celebratory accent.
  star,

  /// Three overlapping circles, scalloped like a cartoon cloud.
  cloud,

  /// A thin stroked circle — the quiet, low-key accent for dense corners.
  ring,
}

/// A real decor shape exported from Haikei, `assets/decor/decor_N.svg` — see
/// `assets/decor/README.md` for how those get sourced. Numbered rather than
/// named because Haikei exports are arbitrary organic shapes with no fixed
/// correspondence to [TkDecorShape]'s procedural vocabulary.
enum TkDecorAsset {
  decor1,
  decor2,
  decor3,
  decor4,
  decor5,
  decor6,
  decor7,
  decor8,
}

extension on TkDecorAsset {
  String get path => 'assets/decor/decor_${index + 1}.svg';
}

/// One decorative shape, painted flat in [color] at [opacity].
///
/// [rotation] is in radians. Sizing follows the widget's box — wrap in a
/// [SizedBox] or position with [Positioned] at the call site; this widget
/// never sizes itself.
///
/// [shape] is always required and is what renders while [asset] is null, its
/// file hasn't been dropped into `assets/decor/` yet, or is still loading —
/// see [tkAssetExists]. When present, the asset is force-tinted to [color]
/// via a `srcIn` [ColorFilter], the same "color always comes from a token"
/// rule the procedural painter follows, so a caller only ever names one
/// [color] regardless of which path renders.
class TkDecor extends StatelessWidget {
  const TkDecor({
    super.key,
    required this.shape,
    required this.color,
    this.asset,
    this.rotation = 0,
    this.opacity = 1,
  });

  final TkDecorShape shape;
  final Color color;
  final TkDecorAsset? asset;
  final double rotation;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: _TkDecorPainter(shape: shape, color: color),
      child: const SizedBox.expand(),
    );

    Widget painted = asset == null
        ? fallback
        : _TkDecorAssetOrFallback(path: asset!.path, color: color, fallback: fallback);

    if (rotation != 0) {
      painted = Transform.rotate(angle: rotation, child: painted);
    }
    if (opacity != 1) {
      painted = Opacity(opacity: opacity, child: painted);
    }
    return painted;
  }
}

class _TkDecorAssetOrFallback extends StatelessWidget {
  const _TkDecorAssetOrFallback({required this.path, required this.color, required this.fallback});

  final String path;
  final Color color;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: tkAssetExists(path),
      builder: (context, snapshot) {
        if (snapshot.data != true) return fallback;
        return SvgPicture.asset(
          path,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      },
    );
  }
}

class _TkDecorPainter extends CustomPainter {
  const _TkDecorPainter({required this.shape, required this.color});

  final TkDecorShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (shape) {
      case TkDecorShape.blob:
        canvas.drawPath(_blobPath(size), paint);
      case TkDecorShape.arch:
        canvas.drawPath(_archPath(size), paint);
      case TkDecorShape.star:
        canvas.drawPath(_starPath(size), paint);
      case TkDecorShape.cloud:
        _paintCloud(canvas, size, paint);
      case TkDecorShape.ring:
        canvas.drawCircle(
          size.center(Offset.zero),
          size.shortestSide / 2 - size.shortestSide * 0.06,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.shortestSide * 0.08,
        );
    }
  }

  /// A six-point organic outline — asymmetric radii around the centre keep
  /// it reading as "hand-drawn blob" rather than a perfect flower.
  Path _blobPath(Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const wobble = [1.0, 0.86, 1.08, 0.9, 1.04, 0.82];
    final points = <Offset>[
      for (var i = 0; i < wobble.length; i++)
        c +
            Offset.fromDirection(
              (i / wobble.length) * 2 * math.pi,
              r * wobble[i],
            ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % points.length];
      final mid = Offset.lerp(p0, p1, 0.5)!;
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  Path _archPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h)
      ..lineTo(0, w / 2)
      ..arcToPoint(Offset(w, w / 2), radius: Radius.circular(w / 2))
      ..lineTo(w, h)
      ..close();
  }

  Path _starPath(Size size) {
    const points = 7;
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.42;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
      final p = c + Offset.fromDirection(angle, radius);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _paintCloud(Canvas canvas, Size size, Paint paint) {
    final r = size.height / 2;
    canvas.drawCircle(Offset(r, size.height - r), r, paint);
    canvas.drawCircle(Offset(size.width / 2, r * 0.85), r * 1.05, paint);
    canvas.drawCircle(Offset(size.width - r, size.height - r), r, paint);
    canvas.drawRect(
      Rect.fromLTWH(r * 0.6, size.height - r * 1.4, size.width - r * 1.2, r * 1.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TkDecorPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

/// The **one** canonical background composition for guardian/onboarding
/// screens — [TkScreen]'s `decor` slot exists so every screen wires this in
/// the same way instead of each file hand-placing its own [Positioned]
/// shapes (which is how `select_child_screen.dart`'s first pass started, and
/// promptly diverged in size/opacity from `day_arc_screen.dart`'s).
///
/// Two shapes, both clearly visible (this is deliberately bolder than that
/// first pass — a shape at 0.6 opacity tucked behind a card reads as an
/// accident, not a design). Still "calm, editorial": no third shape, no
/// colour outside the existing wash tokens, nothing overlapping content.
/// Sits behind everything via [IgnorePointer] + [Positioned], scrolls with
/// the body it's placed in (matching `day_arc_screen.dart`'s own Stack
/// pattern) rather than staying pinned to the viewport.
class TkScreenDecor extends StatelessWidget {
  const TkScreenDecor({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -36,
            right: -44,
            child: SizedBox(
              width: 220,
              height: 220,
              child: TkDecor(
                shape: TkDecorShape.blob,
                color: colors.primaryAccentWash,
                rotation: 0.35,
              ),
            ),
          ),
          Positioned(
            top: 96,
            left: -30,
            child: SizedBox(
              width: 90,
              height: 90,
              child: TkDecor(shape: TkDecorShape.ring, color: colors.successWash),
            ),
          ),
        ],
      ),
    );
  }
}
