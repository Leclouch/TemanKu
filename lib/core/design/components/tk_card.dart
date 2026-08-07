/// Cards and section grouping.
///
/// [TkCard] replaces five near-identical hand-rolled `Card`s on the guardian
/// home plus the ad-hoc `Container(decoration: BoxDecoration(...))` blocks on
/// day-arc and the intake screen. They agreed on intent and disagreed on
/// radius (12 vs 20), border width (1 vs 2) and padding (16 vs 20) — which is
/// precisely the kind of difference nobody notices in a diff and everybody
/// notices on a device.
library;

import 'package:flutter/material.dart';

import 'package:temanku/core/design/theme.dart';
import 'package:temanku/core/design/tokens.dart';

/// How prominent a card is.
enum TkCardTone {
  /// White fill, hairline border. The default for informational content.
  plain,

  /// Tinted fill — for grouped or secondary content that should recede.
  tinted,

  /// Brand-accented outline. For the one card on a screen that is the point
  /// of the screen. At most one per screen; two accented cards is none.
  accent,
}

/// The single card primitive.
///
/// Tappable when [onTap] is non-null, in which case it also guarantees the
/// 44pt minimum target and paints a press state — a card that looks tappable
/// and is not is a predictability failure this audience pays for.
class TkCard extends StatelessWidget {
  const TkCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone = TkCardTone.plain,
    this.padding = const EdgeInsets.all(TkSpace.md),
    this.margin = const EdgeInsets.only(bottom: TkSpace.sm),
  });

  final Widget child;

  /// Rendered in the title role, above [subtitle] and [child].
  ///
  /// Note this is `type.title` (17/w700), *not* `type.display` (28/w800).
  /// Every guardian card used to set its heading in the display role, which
  /// put a 28pt hero on five stacked cards and flattened the hierarchy —
  /// when everything shouts, nothing is heard.
  final String? title;

  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TkCardTone tone;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;

    final (fill, borderColor, borderWidth) = switch (tone) {
      TkCardTone.plain => (c.surface, c.border, TkStroke.regular),
      TkCardTone.tinted => (c.surfaceTinted, c.border, TkStroke.regular),
      TkCardTone.accent => (c.surface, c.primaryAccent, TkStroke.thick),
    };

    final hasHeader = title != null || subtitle != null || leading != null || trailing != null;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasHeader) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: TkSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(title!, style: t.title.copyWith(color: c.text)),
                    if (subtitle != null) ...[
                      if (title != null) const SizedBox(height: TkSpace.xxs),
                      Text(subtitle!, style: t.bodySm.copyWith(color: c.textMuted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: TkSpace.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: TkSpace.sm),
        ],
        child,
      ],
    );

    content = Padding(padding: padding, child: content);

    final decorated = AnimatedContainer(
      duration: context.motion(TkMotion.fast),
      constraints: onTap == null
          ? null
          : const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: TkRadius.md,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: content,
    );

    return Padding(
      padding: margin,
      child: onTap == null
          ? decorated
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: TkRadius.md,
                child: decorated,
              ),
            ),
    );
  }
}

/// A labelled group of content, with the label in the small-caps metadata role.
///
/// Use to break a long guardian screen into scannable regions without stacking
/// more cards — nested cards read as depth the content does not have.
class TkSection extends StatelessWidget {
  const TkSection({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: TkSpace.xs,
            left: TkSpace.xxs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: context.type.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}
