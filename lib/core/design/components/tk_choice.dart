/// Single-select choice tiles, and the stepper chrome around them.
///
/// The intake screen's `_OptionTile` was already the right idea — a big
/// tappable card rather than a bare radio row — but it lived inside one
/// feature file, so the photo-upload and settings screens each grew their own
/// unrelated selection affordance. This is that idea, promoted.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/core/design/theme.dart';
import 'package:temanku/core/design/tokens.dart';

/// One option in a single-select group.
///
/// Selection is signalled three ways at once — fill, border weight, and the
/// radio glyph. That redundancy is deliberate and matches the colour+shape
/// rule the child surface uses for categories: no state in this app is ever
/// carried by colour alone.
class TkChoiceTile<T> extends StatelessWidget {
  const TkChoiceTile({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
    this.description,
  });

  final String label;

  /// Optional second line — use it to say what the option *means* in plain
  /// terms. Literal, concrete phrasing only; the guidance for this audience is
  /// explicit that idiom and metaphor cost comprehension.
  final String? description;

  final T value;
  final T? groupValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final selected = value == groupValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: TkSpace.xs),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: TkRadius.md,
            child: AnimatedContainer(
              duration: context.motion(TkMotion.fast),
              constraints: const BoxConstraints(
                minHeight: TemanKuMetrics.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: TkSpace.md,
                vertical: TkSpace.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? c.primaryAccentWash : c.surface,
                borderRadius: TkRadius.md,
                border: Border.all(
                  color: selected ? c.primaryAccent : c.border,
                  width: selected ? TkStroke.thick : TkStroke.regular,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? LucideIcons.circleDot : LucideIcons.circle,
                    color: selected ? c.primaryAccent : c.textMuted,
                  ),
                  const SizedBox(width: TkSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: t.body.copyWith(
                            color: c.text,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: TkSpace.xxs),
                          Text(
                            description!,
                            style: t.bodySm.copyWith(color: c.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled on/off row.
///
/// The **whole row** is the tap target, not just the switch — a 44pt-tall
/// full-width band rather than a 40pt glyph at the far edge. That is the
/// property worth having a component for: it is easy to lose by writing
/// `Row(children: [Text(...), Switch(...)])`, and losing it costs exactly the
/// users this app is for.
///
/// [onChanged] null disables the row; [enabled] false does the same while
/// keeping a handler around for when it becomes available again.
class TkSwitchTile extends StatelessWidget {
  const TkSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: TkRadius.sm,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TemanKuMetrics.minTouchTarget,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: t.title.copyWith(
                          color: enabled ? c.text : c.textMuted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: TkSpace.xxs),
                        Text(
                          subtitle!,
                          style: t.bodySm.copyWith(color: c.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: TkSpace.sm),
                // Excluded from semantics so the row above is the single
                // announced control — otherwise a screen reader offers two
                // targets for one setting.
                ExcludeSemantics(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Step 2 of 4", rendered as a labelled segment bar.
///
/// Replaces the intake screen's bare `Pertanyaan 2 dari 4` line. Knowing how
/// much is left is the single most effective mitigation for the form-freeze
/// response the ADHD guidance describes — a stepped flow with no visible end
/// reads as unbounded.
class TkStepIndicator extends StatelessWidget {
  const TkStepIndicator({
    super.key,
    required this.step,
    required this.total,
    this.label,
  });

  /// Zero-based.
  final int step;
  final int total;

  /// Overrides the default "N dari M" caption.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: TkSpace.xxs),
              Expanded(
                child: AnimatedContainer(
                  duration: context.motion(TkMotion.base),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? c.primaryAccent : c.border,
                    borderRadius: TkRadius.pill,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: TkSpace.xs),
        Text(
          label ?? 'Pertanyaan ${step + 1} dari $total',
          style: context.type.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}
