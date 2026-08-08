import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  testWidgets('renders at the requested size — real SVG or procedural fallback alike', (tester) async {
    await tester.pumpWidget(_wrap(const Mascot(size: 120, animate: false)));
    // Every pose currently has a real asset on disk (see the SVG-vs-fallback
    // group below), so this measures the rendered box directly rather than
    // assuming a `CustomPaint` descendant — that assumption broke the moment
    // the default pose's SVG existed and `SvgPicture` took over instead.
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Mascot)), const Size.square(120));
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

  // "renders without error" above passes whether the real asset loaded or
  // the procedural painter took over — both are valid, silent outcomes of
  // the same widget. This is the one test that actually distinguishes them:
  // a real `assets/mascot/mascot_<pose>.svg` on disk (see that folder) must
  // resolve to an `SvgPicture`, never silently fall back.
  for (final pose in MascotPose.values) {
    testWidgets('$pose renders the real SVG, not the procedural fallback — the asset exists '
        'on disk for every pose', (tester) async {
      await tester.pumpWidget(_wrap(Mascot(pose: pose, animate: false)));
      // The asset-existence check is itself async (`tkAssetExists`) — a
      // single `pump()` only gets past the FutureBuilder's initial
      // "waiting" frame, not its resolved one.
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Mascot), matching: find.byType(CustomPaint)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
