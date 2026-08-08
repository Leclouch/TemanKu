/// Screen shells — the outermost layer every screen in the app starts from.
///
/// Before these existed, each screen re-declared its own `Scaffold` +
/// `SafeArea` + `ConstrainedBox` + gutter padding, and the four child-session
/// screens each re-declared the local `Theme(data: TemanKuTheme.child)` wrap
/// and the exit-dot `Positioned` on top of that. Same intent four times, four
/// slightly different results. That is the drift these two widgets close.
library;

import 'package:flutter/material.dart';

import 'package:temanku/core/design/theme.dart';
import 'package:temanku/core/design/tokens.dart';
import 'package:temanku/widgets/exit_dot.dart';

/// The guardian-surface shell: app bar, cream ground, bounded content column.
///
/// Use for every guardian and onboarding screen. The content column is
/// *bounded, not fixed* — phone-first, tablet free (§11).
class TkScreen extends StatelessWidget {
  const TkScreen({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onBack,
    this.scrollable = true,
    this.maxWidth = TemanKuMetrics.guardianMaxWidth,
    this.padding = const EdgeInsets.all(TkSpace.gutter),
    this.floatingActionButton,
    this.bottomBar,
    this.decor,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  /// When provided, replaces the [AppBar]'s default back behaviour with an
  /// explicit callback — needed for a screen that can be reached both by a
  /// push (where `Navigator.canPop` is true and Flutter would already draw a
  /// back arrow on its own) and by a `context.go()` that replaced the whole
  /// stack (where it can't pop, so no arrow appears at all without this).
  /// Leave null on any screen only ever reached by push, where the default
  /// behaviour is already correct.
  final VoidCallback? onBack;

  /// When true (the default) the body scrolls as one column. Pass false for a
  /// screen that manages its own scrolling — a `ListView.builder` over a long
  /// list, or a fixed header/footer layout.
  final bool scrollable;

  final double maxWidth;
  final EdgeInsets padding;
  final Widget? floatingActionButton;

  /// Pinned to the bottom, inside the safe area and the content column — for
  /// the "Back / Next" pair on a stepped flow.
  final Widget? bottomBar;

  /// Background texture behind [child] — pass `const TkScreenDecor()` for the
  /// app's one standard composition (`core/design/components/tk_decor.dart`).
  /// Null on screens that need the full surface for focused content (a photo
  /// preview, a stepped question) — the same "no decoration competing with
  /// the task" instinct `TkChildScreen` enforces unconditionally, applied
  /// here as an opt-out rather than a rule, since the guardian surface has
  /// genuine full-attention moments too.
  final Widget? decor;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (decor != null) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [Positioned.fill(child: decor!), body],
      );
    }
    if (scrollable) {
      body = SingleChildScrollView(padding: padding, child: body);
    } else if (padding != EdgeInsets.zero) {
      body = Padding(padding: padding, child: body);
    }

    if (bottomBar != null) {
      body = Column(
        children: [
          Expanded(child: body),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              TkSpace.sm,
              padding.right,
              padding.bottom,
            ),
            child: bottomBar,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: onBack == null ? null : BackButton(onPressed: onBack),
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// The child-session shell.
///
/// Three things it guarantees that a hand-rolled `Scaffold` did not reliably
/// guarantee before:
///
///  1. **The child theme is applied.** Wrapping happens here, once, instead of
///     in each mode screen — a screen that forgets the wrap silently renders
///     at guardian density, and that failure is invisible in review.
///  2. **The quiet exit is always present** (§12). Not optional, not
///     conditional, not behind a long-press. Passing [onExit] is the only
///     control the caller has, and it is required.
///  3. **One task, centred, in a fixed position** (§3/§12) — the child never
///     has to re-find the game between modes.
class TkChildScreen extends StatelessWidget {
  const TkChildScreen({
    super.key,
    required this.onExit,
    required this.child,
    this.corner,
    this.bottomOverlay,
    this.debugBadge,
    this.maxWidth = TemanKuMetrics.contentMaxWidth,
  });

  /// Invoked by the always-visible exit dot. Required — see (2) above.
  final VoidCallback onExit;

  final Widget child;

  /// An optional decorative element in the bottom-left, opposite the exit dot.
  /// Every child screen — day-arc and the three trial modes — passes the
  /// mascot here (`widgets/mascot.dart`).
  final Widget? corner;

  /// Centred along the bottom edge, above [child]. Speak mode's guardian ✅/❌
  /// cluster (§6) is the only current user — it belongs to the guardian, not
  /// the child, so it sits outside the content column on purpose.
  ///
  /// Callers reserve their own height for it in [child] so the task above
  /// never shifts when it appears; see `speak_mode_screen.dart`.
  final Widget? bottomOverlay;

  /// Bottom-right, mirroring [corner] on the opposite side — the one current
  /// user is `LevelIndicatorBadge` (`widgets/level_indicator_badge.dart`),
  /// gated behind `Child.levelIndicatorEnabled`. Like [bottomOverlay], this
  /// belongs to the guardian, not the child — see that field's own doc
  /// comment.
  final Widget? debugBadge;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TemanKuTheme.child,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: Stack(
              children: [
                // Nudged up from dead centre — a fixed offset, not a
                // percentage of screen height, so it reads the same on every
                // device rather than growing with taller screens. Leaves
                // room at the bottom edge for [corner] (the mascot) without
                // the two ever touching; still "one task, fixed position"
                // per the class doc comment, just not mathematically centred.
                Align(
                  alignment: const Alignment(0, -0.12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TkSpace.gutter,
                      ),
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  top: TkSpace.xs,
                  right: TkSpace.xs,
                  child: ExitDot(onExit: onExit),
                ),
                if (corner != null)
                  Positioned(
                    left: TkSpace.xs,
                    bottom: TkSpace.xs,
                    child: corner!,
                  ),
                if (bottomOverlay != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: TkSpace.md,
                    child: Center(child: bottomOverlay!),
                  ),
                if (debugBadge != null)
                  Positioned(
                    right: TkSpace.xs,
                    bottom: TkSpace.xs,
                    child: debugBadge!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
