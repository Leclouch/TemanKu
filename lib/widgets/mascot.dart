import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:temanku/core/design/asset_probe.dart';
import 'package:temanku/core/design/design.dart';

extension on MascotPose {
  /// `assets/mascot/mascot_<pose>.svg` — see `assets/mascot/README.md` for
  /// how those get sourced (composed and recolored in Blush, unlike
  /// `tk_decor.dart`'s assets this is never force-tinted, since a mascot
  /// pose is multi-part and tinting it flat would erase the character).
  String get _assetPath => switch (this) {
        MascotPose.greeting => 'assets/mascot/mascot_greeting.svg',
        MascotPose.pointing => 'assets/mascot/mascot_pointing.svg',
        MascotPose.celebrating => 'assets/mascot/mascot_celebrating.svg',
        MascotPose.standing => 'assets/mascot/mascot_standing.svg',
      };
}

/// menyapa (greeting), memberi instruksi (pointing), merayakan jawaban benar
/// (celebrating), and the character's resting pose (standing). Each is a
/// distinct silhouette (arm position), not just a swapped face — the same
/// "shape carries the meaning" rule `answer_target.dart` uses for category
/// styles applies here too, since some readers of this character will be
/// relying on shape over subtle expression.
///
/// [standing] does double duty: it's the idle pose between prompts, and it's
/// also what plays for a "try again" moment — there is no separate
/// discouraging/slumped pose. The reaction lives entirely in the jump
/// [Mascot] plays on every pose *change* (see that class's doc comment), not
/// in a different body: a wrong answer isn't a failure state here (§10/§12),
/// so the character doesn't get sadder for it, it just hops and keeps
/// standing.
enum MascotPose { greeting, pointing, celebrating, standing }

/// A small, flat-geometric mascot — the child's companion on every level and
/// mode screen sees, day-arc included.
///
/// Built entirely from primitives ([RRect], circles, arcs, one blob body) as
/// its fallback — the same vocabulary `widgets/answer_target.dart`'s
/// category-shape overlay and `core/design/components/tk_decor.dart`'s
/// background shapes already use: a colour fill plus a contrasting overlay
/// shape, painted in the background colour. Real illustration (SVG, see
/// `assets/mascot/README.md`) is preferred when present; the procedural
/// painter only ever renders for a pose whose asset hasn't been dropped in
/// yet — see [_MascotAssetOrFallback].
///
/// Present on tap/match/speak as well as day-arc: the character reacts to
/// each trial ([MascotPose.celebrating] on a correct answer, a jump back
/// into [MascotPose.standing] on a try-again), so the child always has a
/// companion on screen, not just between trials.
///
/// Colour comes entirely from `core/design/` tokens, read once at build time
/// — never a literal `Color(0x...)`. Only neutral chrome tokens are used
/// ([TemanKuColors.primaryAccent], [TemanKuColors.background],
/// [TemanKuColors.textMuted]) for the procedural fallback.
///
/// No feedback token appears in the character's *colour*, deliberately: the
/// mascot sits alongside the task, and a body painted in the same green or
/// yellow the answer ring uses would read as commentary on the child's
/// answer. Reaction is carried by which [MascotPose] is showing and the jump
/// between poses, never by recolouring the character. [TemanKuColors.secondaryAccent]
/// is likewise never touched — its own doc comment marks it guardian-surface-only.
class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    this.size = 96,
    this.pose = MascotPose.standing,
    this.animate = true,
    this.reactionTick = 0,
  });

  /// Rendered small-to-medium — 96–150px is the intended range (bigger on
  /// day-arc, where it's the one focal decorative element; smaller on the
  /// trial screens, which still keep most of the screen for the task); 96 is
  /// the bare default for a caller that doesn't specify one. `TkChildScreen`
  /// nudges its main content up slightly (see that class's own doc comment)
  /// precisely so a mascot at this size has clear room in the corner without
  /// touching the task above it.
  final double size;

  /// See [MascotPose] for what each value means and when it's used.
  final MascotPose pose;

  /// A subtle fade + scale + jump, played once on mount and again every time
  /// [pose] or [reactionTick] *changes* — never a repeating/looping idle
  /// animation (blink, bob, wiggle): it only ever fires on an actual
  /// transition, then settles and stops. This character must never compete
  /// with or distract from the task content around it. Pass `false` for a
  /// fully static pose with no motion at all.
  final bool animate;

  /// Bump this to replay the jump even when the target [pose] is unchanged
  /// from the last build — the case a plain pose-change key can't cover.
  /// A wrong answer keeps the mascot in [MascotPose.standing] (§10/§12: no
  /// separate discouraged pose), so without this the second, third, ... "try
  /// again" in a row would land on an identical `(pose)` key and play no
  /// animation at all. Callers increment an int per trial judged; the exact
  /// value never matters, only that it differs from the previous build's.
  final int reactionTick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final procedural = CustomPaint(
      size: Size.square(size),
      painter: _MascotPainter(
        pose: pose,
        body: colors.primaryAccent,
        face: colors.background,
        feet: colors.textMuted,
        accent: colors.neutralFeedback,
      ),
    );
    final painted = SizedBox.square(
      dimension: size,
      child: _MascotAssetOrFallback(path: pose._assetPath, fallback: procedural),
    );

    // `animate: false` is the caller's opt-out; `context.reduceMotion` is the
    // platform's, and it wins unconditionally. Motion control is a stated
    // requirement for this audience, not a preference — and the one animation
    // on the child surface is exactly the one a motion-sensitive user would
    // have turned the setting off for.
    if (!animate || context.reduceMotion) return painted;

    // Keyed on `(pose, reactionTick)`: either changing tears down this
    // element and builds a fresh `TweenAnimationBuilder` in its place, which
    // restarts the tween from `begin` — the mechanism that makes the jump
    // replay on every transition (or every bumped [reactionTick], for a
    // same-pose repeat), not just the first mount. When neither changes
    // between builds, nothing here re-keys, so a same-pose, same-tick
    // rebuild plays no animation at all. One-shot per transition, not
    // looping: each build of this widget animates once from its start to its
    // target and then simply stops — there is no controller here to ever
    // repeat() or reverse().
    return TweenAnimationBuilder<double>(
      key: ValueKey((pose, reactionTick)),
      tween: Tween(begin: 0, end: 1),
      duration: TkMotion.slow,
      curve: TkMotion.enter,
      builder: (context, t, child) {
        // A small hop, not a bounce loop: sin(πt) rises from 0 to a single
        // peak at the animation's midpoint and back to 0 at its end, so the
        // character lands exactly on the ground both before and after —
        // never mid-air when the animation settles.
        final jump = size * 0.09 * math.sin(math.pi * t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -jump),
            child: Transform.scale(scale: 0.94 + (0.06 * t), child: child),
          ),
        );
      },
      child: painted,
    );
  }
}

class _MascotAssetOrFallback extends StatelessWidget {
  const _MascotAssetOrFallback({required this.path, required this.fallback});

  final String path;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: tkAssetExists(path),
      builder: (context, snapshot) {
        if (snapshot.data != true) return fallback;
        return SvgPicture.asset(path, fit: BoxFit.contain);
      },
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

    _paintArms(canvas, size, bodyPaint);

    // Body — one rounded rect, corners rounded past a "card" radius and
    // into blob territory. The whole character is this one primitive plus
    // the face on top of it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(s * 0.30)),
      bodyPaint,
    );

    _paintFace(canvas, size, facePaint, bodyRect);

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
      case MascotPose.standing:
        // No raised limb at all — arms stay at rest against the body. This
        // is the idle silhouette; the only "reaction" the pose ever gets is
        // the jump `Mascot` plays when it's switched into, not a gesture.
        break;
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
