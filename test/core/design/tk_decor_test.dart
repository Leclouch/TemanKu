import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/core/design/design.dart';

Widget _wrap(Widget child) => MaterialApp(home: SizedBox(width: 200, height: 200, child: child));

void main() {
  testWidgets('with no asset, TkDecor always paints the procedural shape', (tester) async {
    await tester.pumpWidget(_wrap(const TkDecor(shape: TkDecorShape.blob, color: Colors.orange)));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(SvgPicture), findsNothing);
  });

  // Regression test for the bug this fix addresses: `tkAssetExists` read a
  // plain `AssetManifest.json` that this Flutter SDK no longer generates at
  // all (see `core/design/asset_probe.dart`'s doc comment) — the load threw,
  // `FutureBuilder` silently treated the rejected future as "not found", and
  // every real decor SVG fell back to the procedural shape with no error
  // anywhere. `decor_1.svg` genuinely exists on disk (`assets/decor/`).
  testWidgets('TkDecorAsset.decor1 renders the real SVG, not the procedural fallback', (tester) async {
    await tester.pumpWidget(
      _wrap(const TkDecor(shape: TkDecorShape.blob, asset: TkDecorAsset.decor1, color: Colors.orange)),
    );
    await tester.pumpAndSettle();

    // `SvgPicture` itself paints through an internal `CustomPaint`, so its
    // presence isn't proof either way — the positive assertion above is
    // what actually distinguishes "real asset" from "procedural fallback".
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
