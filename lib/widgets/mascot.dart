import 'package:flutter/material.dart';

import 'package:temanku/core/theme/temanku_theme.dart';

/// A small, flat-geometric mascot — **`day_arc_screen.dart` only.**
///
/// Built entirely from primitives ([RRect], circles, one stroked arc) —
/// the same vocabulary `widgets/answer_target.dart`'s category-shape overlay
/// already uses on the child screen: a colour fill plus a contrasting
/// overlay shape, painted in the background colour. No gradient, no outline
/// stroke on the body, no image asset — everything here is drawn, not
/// imported.
///
/// Deliberately **not** reused on tap/match/speak: those are trial screens
/// and keep their zero-decoration rule untouched. Day-arc is the calm
/// "what's next" screen between trials, not a trial itself, which is the
/// only reason this exists at all.
///
/// Colour comes entirely from `core/theme/` tokens, read once at build time
/// — never a literal `Color(0x...)`. Only tokens already sanctioned for the
/// **child** surface are used ([TemanKuColors.primaryAccent],
/// [TemanKuColors.background], [TemanKuColors.neutralFeedback]).
/// [TemanKuColors.secondaryAccent] is deliberately never touched here even
/// though it exists on the same class: its own doc comment marks it
/// guardian-surface-only, and day-arc is a child screen.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 96, this.animate = true});

  /// Rendered small — 80–120px is the intended range; 96 is the default.
  final double size;

  /// A single, subtle fade + scale-in the first time this mounts. Never a
  /// repeating idle animation (blink, bob, wiggle) — this character must
  /// never compete with or distract from the task content around it. Pass
  /// `false` for a fully static pose with no motion at all.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final painted = CustomPaint(
      size: Size.square(size),
      painter: _MascotPainter(
        body: colors.primaryAccent,
        face: colors.background,
        feet: colors.neutralFeedback,
      ),
    );

    if (!animate) return painted;

    // One-shot, not looping: TweenAnimationBuilder animates once from its
    // initial build to the target and then simply stops — there is no
    // controller here to ever repeat() or reverse().
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + (0.06 * t), child: child),
      ),
      child: painted,
    );
  }
}

/// Pure vector paint. No [BuildContext], no theme lookups — colours are
/// handed in already resolved, which keeps this trivially testable and
/// independent of where/how [Mascot] reads its tokens.
class _MascotPainter extends CustomPainter {
  const _MascotPainter({required this.body, required this.face, required this.feet});

  final Color body;
  final Color face;
  final Color feet;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Feet — two small rounded rects peeking out under the body, just
    // enough to read as "standing" without adding limb detail.
    final feetPaint = Paint()..color = feet;
    for (final dx in [0.30, 0.62]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * dx, s * 0.88, s * 0.16, s * 0.10),
          Radius.circular(s * 0.05),
        ),
        feetPaint,
      );
    }

    // Body — one rounded rect, corners rounded past a "card" radius and
    // into blob territory. The whole character is this one primitive plus
    // the face on top of it.
    final bodyPaint = Paint()..color = body;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.08, s * 0.10, s * 0.84, s * 0.80),
        Radius.circular(s * 0.30),
      ),
      bodyPaint,
    );

    // Eyes — two small filled circles in the background colour, painted as
    // an overlay on the body fill (never colour-alone-as-meaning here, but
    // the same contrast-overlay technique answer_target.dart's category
    // shapes use).
    final facePaint = Paint()..color = face;
    canvas.drawCircle(Offset(s * 0.37, s * 0.42), s * 0.045, facePaint);
    canvas.drawCircle(Offset(s * 0.63, s * 0.42), s * 0.045, facePaint);

    // Smile — a single stroked arc along the bottom of a circle, not a
    // filled shape. drawArc's angles are clockwise from the positive
    // x-axis; 0.35..2.45 rad sweeps the lower ~140° of the circle, i.e.
    // just the "U" of a smile.
    final smilePaint = Paint()
      ..color = face
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;
    final smileRect = Rect.fromCircle(center: Offset(s * 0.5, s * 0.48), radius: s * 0.16);
    canvas.drawArc(smileRect, 0.35, 2.45, false, smilePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.face != face || oldDelegate.feet != feet;
}
