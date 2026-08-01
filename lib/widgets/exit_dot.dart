import 'package:flutter/material.dart';

import 'package:temanku/core/theme/temanku_theme.dart';

/// The quiet exit affordance — **shared component, jointly owned.**
///
/// Source-of-truth §12: the child screen carries an **always-visible quiet exit**.
/// §6 describes the same visual grammar for the guardian's ✅/❌ cluster: "small,
/// muted, positioned to read as *not for you* to the child".
///
/// Two properties are requirements rather than styling:
///   1. It is always visible. It never fades, never hides behind a long-press,
///      never requires a confirmation dialog the child can't read.
///   2. Its touch target is at least 44×44pt at **phone** scale (§11), even
///      though the painted dot is smaller. The visual is muted; the tap area is not.
class ExitDot extends StatelessWidget {
  const ExitDot({
    super.key,
    required this.onExit,
    this.semanticLabel = 'Keluar',
  });

  final VoidCallback onExit;
  final String semanticLabel;

  /// Painted size. Intentionally much smaller than the touch target.
  static const double _dotSize = 14;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onExit,
        radius: TemanKuMetrics.minTouchTarget / 2,
        child: SizedBox(
          // The 44pt guarantee.
          width: TemanKuMetrics.minTouchTarget,
          height: TemanKuMetrics.minTouchTarget,
          child: Center(
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Muted on purpose — reads as "not for you" to the child.
                color: context.colors.neutralFeedback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
