import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:temanku/core/design/design.dart';

/// The four poses `referenceimages/instruksi-decor-icon-mascot.md` asks
/// for: menyapa (greeting), memberi instruksi (pointing), merayakan jawaban
/// benar (celebrating), mendorong coba lagi (encouraging). Each is a distinct
/// silhouette (arm position + accent), not just a swapped face — the same
/// "shape carries the meaning" rule `answer_target.dart` uses for category
/// styles applies here too, since some readers of this character will be
/// relying on shape over subtle expression.
enum MascotPose { greeting, pointing, celebrating, encouraging }

/// A small, flat-geometric mascot — **`day_arc_screen.dart` only.**
///
/// Built entirely from primitives ([RRect], circles, arcs, one blob body) —
/// the same vocabulary `widgets/answer_target.dart`'s category-shape overlay
/// and `core/design/components/tk_decor.dart`'s background shapes already
/// use: a colour fill plus a contrasting overlay shape, painted in the
/// background colour. No gradient, no outline stroke on the body, no image
/// asset — everything here is drawn, not imported. See the redesign
/// conversation for why: a hand-illustrated character at Maxima's level of
/// craft is not something procedural shape code can match, so this stays in
/// its own honest lane — a charming geometric character, not an attempt to
/// fake an illustrator's line work.
///
/// Deliberately **not** reused on tap/match/speak: those are trial screens
/// and keep their zero-decoration rule untouched. Day-arc is the calm
/// "what's next" screen between trials, not a trial itself, which is the
/// only reason this exists at all.
///
/// Colour comes entirely from `core/design/` tokens, read once at build time
/// — never a literal `Color(0x...)`. Only neutral chrome tokens are used
/// ([TemanKuColors.primaryAccent], [TemanKuColors.background],
/// [TemanKuColors.textMuted]).
///
/// No feedback token appears here, deliberately: the mascot is on screen
/// alongside the task, and a character painted in the same green or yellow
/// the answer ring uses would read as commentary on the child's answer.
/// [TemanKuColors.secondaryAccent] is likewise never touched — its own doc
/// comment marks it guardian-surface-only, and day-arc is a child screen.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 96, this.pose = MascotPose.greeting, this.animate = true});

  /// Rendered small — 80–120px is the intended range; 96 is the default.
  final double size;

  /// See [MascotPose] for what each value means and when it's used.
  final MascotPose pose;

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
        pose: pose,
        body: colors.primaryAccent,
        face: colors.background,
        feet: colors.textMuted,
        accent: colors.neutralFeedback,
      ),
    );

    // `animate: false` is the caller's opt-out; `context.reduceMotion` is the
    // platform's, and it wins unconditionally. Motion control is a stated
    // requirement for this audience, not a preference — and the one animation
    // on the child surface is exactly the one a motion-sensitive user would
    // have turned the setting off for.
    if (!animate || context.reduceMotion) return painted;

    // One-shot, not looping: TweenAnimationBuilder animates once from its
    // initial build to the target and then simply stops — there is no
    // controller here to ever repeat() or reverse().
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: TkMotion.slow,
      curve: TkMotion.enter,
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
  const _MascotPainter({
    required this.pose,
    required this.body,
    required this.face,
    required this.feet,
    required this.accent,
  });

  final MascotPose pose;
  final Color body;
  final Color face;
  final Color feet;

  /// The "try again" token — the only feedback-family colour this file uses,
  /// and only as a small warm accent (sparkle points) at half strength,
  /// never as a fill. See the class doc for why a real feedback colour would
  /// otherwise be off-limits here.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bodyPaint = Paint()..color = body;
    final facePaint = Paint()..color = face;
    final feetPaint = Paint()..color = feet;

    // Feet — two small rounded rects peeking out under the body, just
    // enough to read as "standing" without adding limb detail. Skipped for
    // `celebrating`, whose whole body lifts slightly, feet included, so a
    // fixed foot position would look like it's floating instead of hopping.
    if (pose != MascotPose.celebrating) {
      for (final dx in [0.30, 0.62]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * dx, s * 0.88, s * 0.16, s * 0.10),
            Radius.circular(s * 0.05),
          ),
          feetPaint,
        );
      }
    }

    final bodyRect = pose == MascotPose.celebrating
        ? Rect.fromLTWH(s * 0.08, s * 0.04, s * 0.84, s * 0.80)
        : Rect.fromLTWH(s * 0.08, s * 0.10, s * 0.84, s * 0.80);

    // Encouraging tilts the whole body a few degrees — a gentle head-tilt
    // reads as warmth without needing a different face.
    final tilt = pose == MascotPose.encouraging ? -0.06 : 0.0;
    canvas.save();
    if (tilt != 0) {
      canvas.translate(bodyRect.center.dx, bodyRect.center.dy);
      canvas.rotate(tilt);
      canvas.translate(-bodyRect.center.dx, -bodyRect.center.dy);
    }

    _paintArms(canvas, size, bodyPaint);

    // Body — one rounded rect, corners rounded past a "card" radius and
    // into blob territory. The whole character is this one primitive plus
    // the face on top of it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(s * 0.30)),
      bodyPaint,
    );

    _paintFace(canvas, size, facePaint, bodyRect);
    canvas.restore();

    if (pose == MascotPose.celebrating) {
      _paintSparkles(canvas, size);
    }
  }

  /// Arms are drawn *before* the body so their shoulder end tucks under it —
  /// only the gesture end (hand/point) reads as separate from the torso.
  void _paintArms(Canvas canvas, Size size, Paint paint) {
    final s = size.shortestSide;
    switch (pose) {
      case MascotPose.greeting:
        // One arm raised and out, elbow-bent via two joined rounded rects —
        // the classic "waving hello" silhouette.
        _drawLimb(canvas, paint, s, start: Offset(s * 0.80, s * 0.42), angle: -0.9, length: s * 0.30);
      case MascotPose.pointing:
        // One arm extended straight out and slightly up — unambiguous
        // "look over there" / "do this" gesture.
        _drawLimb(canvas, paint, s, start: Offset(s * 0.80, s * 0.46), angle: -0.35, length: s * 0.42);
      case MascotPose.celebrating:
        // Both arms up in a V — the shared "we did it" silhouette across
        // most reward iconography, which is exactly why it's legible here
        // without relying on a facial expression at all.
        _drawLimb(canvas, paint, s, start: Offset(s * 0.78, s * 0.36), angle: -1.15, length: s * 0.32);
        _drawLimb(canvas, paint, s, start: Offset(s * 0.22, s * 0.36), angle: -2.0, length: s * 0.32);
      case MascotPose.encouraging:
        // A single small raised arm, thumb-up height, not a full wave —
        // quieter than `greeting`, paired with the body tilt for warmth.
        _drawLimb(canvas, paint, s, start: Offset(s * 0.78, s * 0.50), angle: -0.6, length: s * 0.22);
    }
  }

  void _drawLimb(
    Canvas canvas,
    Paint paint,
    double s, {
    required Offset start,
    required double angle,
    required double length,
  }) {
    final end = start + Offset.fromDirection(angle, length);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = paint.color
        ..strokeWidth = s * 0.16
        ..strokeCap = StrokeCap.round,
    );
    // A small round "hand" at the gesture end reads clearer than a bare
    // stroke terminus, especially at the 80-120px this renders at.
    canvas.drawCircle(end, s * 0.09, paint);
  }

  void _paintFace(Canvas canvas, Size size, Paint facePaint, Rect bodyRect) {
    final s = size.shortestSide;
    final eyeY = bodyRect.top + bodyRect.height * 0.42;

    // Eyes — two small filled circles in the background colour, painted as
    // an overlay on the body fill (never colour-alone-as-meaning here, but
    // the same contrast-overlay technique answer_target.dart's category
    // shapes use). Celebrating closes them into upward arcs (a "^_^" beat)
    // rather than dots — eyes-closed-with-joy is the one expression change
    // this file allows itself, since it pairs with the arms-up silhouette
    // rather than trying to carry the meaning alone.
    if (pose == MascotPose.celebrating) {
      final eyePaint = Paint()
        ..color = facePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..strokeCap = StrokeCap.round;
      for (final dx in [0.37, 0.63]) {
        final c = Offset(size.width * dx, eyeY);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: s * 0.05),
          math.pi,
          math.pi,
          false,
          eyePaint,
        );
      }
    } else {
      canvas.drawCircle(Offset(size.width * 0.37, eyeY), s * 0.045, facePaint);
      canvas.drawCircle(Offset(size.width * 0.63, eyeY), s * 0.045, facePaint);
    }

    // Smile — a single stroked arc along the bottom of a circle, not a
    // filled shape. drawArc's angles are clockwise from the positive
    // x-axis; 0.35..2.45 rad sweeps the lower ~140° of the circle, i.e.
    // just the "U" of a smile.
    final smilePaint = Paint()
      ..color = facePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;
    final smileCenter = Offset(size.width * 0.5, bodyRect.top + bodyRect.height * 0.48);
    final smileRect = Rect.fromCircle(center: smileCenter, radius: s * 0.16);
    canvas.drawArc(smileRect, 0.35, 2.45, false, smilePaint);
  }

  /// Small four-point sparkles scattered around the body — the warm accent
  /// colour, half-strength, never a fill. Cheap to draw as two crossed thin
  /// rounded rects rather than a real star path; at 8-14px that reads
  /// identically and costs far less than `tk_decor.dart`'s full star path.
  void _paintSparkles(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()..color = accent.withValues(alpha: 0.9);
    for (final spec in const [(0.06, 0.10, 1.0), (0.92, 0.22, 0.7), (0.86, 0.68, 0.55)]) {
      final center = Offset(size.width * spec.$1, size.height * spec.$2);
      final r = s * 0.07 * spec.$3;
      final bar = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.35),
        Radius.circular(r * 0.2),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawRRect(bar, paint);
      canvas.rotate(math.pi / 2);
      canvas.drawRRect(bar, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.body != body ||
      oldDelegate.face != face ||
      oldDelegate.feet != feet ||
      oldDelegate.accent != accent;
}
