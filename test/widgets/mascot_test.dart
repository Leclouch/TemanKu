import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/widgets/mascot.dart';

Widget _wrap(Widget child) => MaterialApp(theme: TemanKuTheme.child, home: Center(child: child));

void main() {
  testWidgets('renders without error at the default size', (tester) async {
    await tester.pumpWidget(_wrap(const Mascot()));
    await tester.pumpAndSettle();

    expect(find.byType(Mascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints at the requested size', (tester) async {
    await tester.pumpWidget(_wrap(const Mascot(size: 120, animate: false)));
    await tester.pump();

    final painter = tester.widget<CustomPaint>(
      find.descendant(of: find.byType(Mascot), matching: find.byType(CustomPaint)),
    );
    expect(painter.size, const Size.square(120));
  });

  testWidgets('animate: false skips the entrance animation entirely — fully static', (tester) async {
    await tester.pumpWidget(_wrap(const Mascot(animate: false)));
    await tester.pump();

    // No animation-driving widget at all.
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('the default entrance animation is one-shot — pumpAndSettle completes '
      'well within its own duration (no repeating/looping ticker)', (tester) async {
    await tester.pumpWidget(_wrap(const Mascot()));

    // A looping idle animation would never let this settle — pumpAndSettle
    // would exhaust its own retry budget and throw. A single fade+scale-in
    // settles cleanly instead. This is the regression guard against the
    // "never a continuous idle animation" constraint.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.byType(Mascot), findsOneWidget);
  });

  testWidgets('renders even with no TemanKuColors extension present at all — '
      'context.colors\' own fallback (core/theme/temanku_theme.dart) covers it',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(), home: const Center(child: Mascot(animate: false))),
    );
    await tester.pump();

    expect(find.byType(Mascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final pose in MascotPose.values) {
    testWidgets('paints the $pose pose without error', (tester) async {
      await tester.pumpWidget(_wrap(Mascot(pose: pose, animate: false)));
      await tester.pump();

      expect(find.byType(Mascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
