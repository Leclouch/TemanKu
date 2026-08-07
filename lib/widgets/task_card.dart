import 'package:flutter/material.dart';

import 'package:temanku/core/design/design.dart';

/// The task card — **shared component, jointly owned.**
///
/// Source-of-truth §12: the child screen has a **fixed task-card position**. That
/// fixity is the point — one task per screen (§3), in the same place every time,
/// so the child never has to re-find the game. Layout code should not move this
/// card between modes; tap, match and speak all render into the same slot.
///
/// Placeholder rendering only. The real card shows the photo; the signature
/// "photo becomes the task" moment belongs to the **guardian upload flow only**
/// and is **never animated on the child screen** (§12).
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    this.child,
    this.label,
  });

  final Widget? child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TkRadius.md,
          border: Border.all(color: colors.border, width: TkStroke.regular),
        ),
        alignment: Alignment.center,
        child: child ??
            Text(
              label ?? 'task',
              textAlign: TextAlign.center,
              style: context.type.body.copyWith(color: colors.textMuted),
            ),
      ),
    );
  }
}
