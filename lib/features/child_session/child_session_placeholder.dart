import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/widgets/exit_dot.dart';
import 'package:temanku/widgets/task_card.dart';

/// Child session screen — **IT-1. Placeholder: layout skeleton only.**
///
/// What this file is proving on day one, per source-of-truth §12 and §3:
///   - the **fixed task-card position** — the card sits in the same place every
///     trial, in every mode; nothing about the layout is content-dependent;
///   - the **always-visible quiet exit** dot, top-trailing, muted, 44pt target;
///   - the child **theme temperature**, applied locally over the app's guardian
///     theme, both from `core/theme/` — see the `Theme` wrapper below;
///   - phone-first responsive constraints (§11): the card is width-bounded, not
///     size-hardcoded, so tablet is free.
///
/// What it must never grow: a score, a level readout, a progress bar, or an
/// alarm colour. §10 — no scores visible to the child, ever; no alarm colours on
/// the child screen.
///
/// TODO(IT-1) Day 2: replace the placeholder card with real tap-mode trials from
/// `engine/modes/tap/`. The scaffolding around it should not need to change.
class ChildSessionPlaceholder extends ConsumerWidget {
  const ChildSessionPlaceholder({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The child surface runs a different temperature from the rest of the app —
    // one grammar, two temperatures (§12). Both come from core/theme/.
    return Theme(
      data: TemanKuTheme.child,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  // --- Fixed task-card position -------------------------------
                  Center(
                    child: ConstrainedBox(
                      // Bounded, not fixed — phone-first, tablet free (§11).
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Instruction line. One task per screen (§3).
                            Text(
                              'tunjuk pisang',
                              textAlign: TextAlign.center,
                              style: context.type.display
                                  .copyWith(color: colors.text),
                            ),
                            const SizedBox(height: 24),
                            const TaskCard(label: 'placeholder task card'),
                            const SizedBox(height: 24),
                            // Response area — array slots in tap/match, empty in
                            // speak. Sized here only to hold the position.
                            SizedBox(
                              height: 96,
                              child: Center(
                                child: Text(
                                  'response area (array slots go here)',
                                  style: context.type.body
                                      .copyWith(color: colors.neutralFeedback),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Always-visible quiet exit (§12) ------------------------
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ExitDot(
                      onExit: () {
                        // TODO(IT-1): exiting mid-session should pause and save
                        // (§7 — progress saves, timer freezes for resume), not
                        // discard. Placeholder just pops.
                        context.pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
