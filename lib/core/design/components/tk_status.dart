/// Status, empty, and loading states.
///
/// These were the least consistent surfaces in the app and the most important
/// to get right: every one of them is a moment where something the guardian
/// expected is not there. They appeared variously as a bare centred
/// `CircularProgressIndicator`, a `LinearProgressIndicator` in 8pt padding, a
/// naked `Text('Belum ada sesi.')`, and a paragraph of neutral copy in a
/// `Padding` — four registers for one situation.
///
/// The rule they now share: say what is happening, say what to do about it,
/// and never use an alarm colour to say it.
library;

import 'package:flutter/material.dart';

import 'package:temanku/core/design/theme.dart';
import 'package:temanku/core/design/tokens.dart';

/// The app's only loading affordance.
///
/// Deliberately understated. A spinner is motion, and motion on this app's
/// surfaces has to earn its place — so it is small, it is centred, and it
/// carries optional text rather than leaving the guardian to guess.
class TkLoading extends StatelessWidget {
  const TkLoading({super.key, this.label, this.compact = false});

  final String? label;

  /// Inline form for use inside a card, rather than filling a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final indicator = SizedBox(
      width: compact ? 18 : 28,
      height: compact ? 18 : 28,
      child: CircularProgressIndicator(
        strokeWidth: compact ? 2.5 : 3.5,
        color: c.primaryAccent,
      ),
    );

    if (label == null) {
      return Padding(
        padding: EdgeInsets.all(compact ? TkSpace.xs : TkSpace.xl),
        child: Center(child: indicator),
      );
    }

    return Padding(
      padding: EdgeInsets.all(compact ? TkSpace.xs : TkSpace.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: TkSpace.sm),
          Flexible(
            child: Text(
              label!,
              style: context.type.bodySm.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing here yet — and what to do about it.
///
/// [action] is not decoration. An empty state without a way out is a dead end,
/// and dead ends are where a guardian abandons setup.
class TkEmptyState extends StatelessWidget {
  const TkEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.compact = false,
  });

  final String message;
  final IconData? icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? TkSpace.sm : TkSpace.xxl,
        horizontal: TkSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null && !compact) ...[
            Icon(icon, size: 40, color: c.textMuted),
            const SizedBox(height: TkSpace.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: (compact ? context.type.bodySm : context.type.body)
                .copyWith(color: c.textMuted),
          ),
          if (action != null) ...[
            const SizedBox(height: TkSpace.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A setup gap on the child surface — "not enough photos to play yet".
///
/// Distinct from [TkEmptyState] because the audience is different: this is
/// text a child may be looking at while a guardian reads it, so it stays
/// large, centred, and completely free of chrome. Never an alarm colour,
/// never an error icon, never the word "error" (§10/§12).
class TkChildNotice extends StatelessWidget {
  const TkChildNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(TkSpace.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.type.body.copyWith(color: c.text),
      ),
    );
  }
}

/// How a [TkBadge] reads.
enum TkBadgeTone { neutral, success, info, accent }

/// A small categorical label — mode names, module names, mastery status.
///
/// Guardian surface only. Every badge pairs its colour with a word: the tone
/// tints it, the text carries the meaning.
class TkBadge extends StatelessWidget {
  const TkBadge({
    super.key,
    required this.label,
    this.tone = TkBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final TkBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, ink) = switch (tone) {
      TkBadgeTone.neutral => (c.surfaceTinted, c.text),
      TkBadgeTone.success => (c.successWash, c.text),
      TkBadgeTone.info => (c.info.withValues(alpha: 0.14), c.text),
      TkBadgeTone.accent => (c.primaryAccentWash, c.text),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TkSpace.sm,
        vertical: TkSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: TkRadius.pill,
        border: Border.all(color: c.border, width: TkStroke.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: TkSpace.xxs),
          ],
          Text(
            label,
            style: context.type.caption.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A key–value line, for the guardian's descriptive readouts.
///
/// §8 is emphatic that the guardian surface is a notebook, not a dashboard —
/// so this renders a label and a sentence, and there is deliberately no
/// variant of it that renders a number, a percentage, or a bar.
class TkDetailRow extends StatelessWidget {
  const TkDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TkSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: t.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: t.body.copyWith(color: c.text)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: TkSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
