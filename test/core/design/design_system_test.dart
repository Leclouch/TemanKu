/// Guards on the design system itself.
///
/// The drift this whole layer exists to fix came back the same way every
/// time: a value looked fine on the developer's wide window and broke on a
/// phone, or a token was reused for a second meaning until the first one
/// stopped working. These tests catch both classes cheaply.
///
/// They are deliberately not golden tests. Goldens would pin the *rendering*,
/// which is exactly the thing a design pass is allowed to change; these pin
/// the *invariants*, which it is not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/core/design/design.dart';

/// The smallest phone the app claims to support.
const _smallPhone = Size(360, 640);

void main() {
  group('type scale', () {
    testWidgets('no role clips its own glyphs at 360x640', (tester) async {
      tester.view.physicalSize = _smallPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const t = TemanKuTypography.scale;
      await tester.pumpWidget(
        MaterialApp(
          theme: TemanKuTheme.guardian,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Hari Ini', style: t.displayXl),
                  Text('tunjuk yang boleh dimakan', style: t.displayLg),
                  Text('Catatan wali', style: t.display),
                  Text('Ringkasan sesi', style: t.titleLg),
                  Text('Perjalanan', style: t.title),
                  Text('Satu pertanyaan per mode.', style: t.body),
                  Text('anjuran, bukan syarat', style: t.bodySm),
                  Text('Isi intake', style: t.label),
                  Text('3 dari 5', style: t.caption),
                  Text('07/08', style: t.mono),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The supplied specimen sets display leading as low as 0.80. Robuck
      // Rounded tolerates that; Nunito (the OFL stand-in actually bundled)
      // has taller extenders and starts clipping its own descenders below
      // ~0.90. This is the check that caught it — if someone re-tightens
      // `height:` toward the literal specimen value, it fails here rather
      // than on a device.
      for (final element in find.byType(Text).evaluate()) {
        final text = element.widget as Text;
        final size = tester.getSize(find.byWidget(text));
        expect(
          size.height,
          greaterThanOrEqualTo(text.style!.fontSize!),
          reason: 'clipped: "${text.data}" at ${text.style!.fontSize}px '
              'rendered only ${size.height}px tall',
        );
      }
    });
  });

  group('components', () {
    testWidgets('the full vocabulary lays out at 360x640 without overflow',
        (tester) async {
      tester.view.physicalSize = _smallPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: TemanKuTheme.guardian,
          home: TkScreen(
            title: 'Catatan wali',
            child: TkSection(
              label: 'Persiapan',
              trailing: const TkBadge(label: '2 foto'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TkCard(
                    title: 'Intake',
                    subtitle: 'Satu pertanyaan per mode. Memilih mode yang '
                        'tersedia — bukan memperkirakan level.',
                    leading: const Icon(LucideIcons.clipboardPen),
                    child: TkButton.secondary(
                      label: 'Isi intake',
                      icon: LucideIcons.arrowRight,
                      onPressed: () {},
                    ),
                  ),
                  TkCard(
                    tone: TkCardTone.accent,
                    child: Column(
                      children: [
                        const TkStepIndicator(step: 1, total: 4),
                        const SizedBox(height: TkSpace.md),
                        TkChoiceTile<int>(
                          label: 'Ya, biasanya bisa',
                          value: 1,
                          groupValue: 1,
                          onSelected: (_) {},
                        ),
                        TkSwitchTile(
                          title: 'Saran pengucapan (eksperimental)',
                          value: true,
                          onChanged: (_) {},
                        ),
                        const TkDetailRow(
                          label: 'Makanan · Menunjuk',
                          value: 'Sedang berlatih dengan benda yang jelas berbeda',
                        ),
                        const TkEmptyState(
                          message: 'Belum ada sesi.',
                          compact: true,
                        ),
                        // The longest action label in the app, next to a
                        // second button. This is the pair that overflowed
                        // before TkButton learned to ellipsize.
                        Row(
                          children: [
                            TkButton.quiet(label: 'Kembali', onPressed: () {}),
                            const SizedBox(width: TkSpace.xs),
                            Expanded(
                              child: TkButton(
                                label: 'Selesai isi intake',
                                onPressed: () {},
                                expand: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: TkLoading's spinner never settles by design.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('layout survives a 2.0x system text scale', (tester) async {
      // Guardians using the app are often the ones who have already turned
      // system type up. Text scaling is the commonest way a card-and-button
      // layout breaks, and it breaks silently — nothing in a normal run
      // exercises it.
      tester.view.physicalSize = _smallPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: TemanKuTheme.guardian,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: TkScreen(
            title: 'Catatan wali',
            child: Column(
              children: [
                TkCard(
                  title: 'Intake',
                  subtitle: 'Satu pertanyaan per mode. Memilih mode yang tersedia.',
                  child: TkButton.secondary(label: 'Isi intake', onPressed: () {}),
                ),
                TkSwitchTile(
                  title: 'Saran pengucapan (eksperimental)',
                  value: true,
                  onChanged: (_) {},
                ),
                Row(
                  children: [
                    TkButton.quiet(label: 'Kembali', onPressed: () {}),
                    const SizedBox(width: TkSpace.xs),
                    Expanded(
                      child: TkButton(
                        label: 'Selesai isi intake',
                        onPressed: () {},
                        expand: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion collapses every animation to an instant cut',
        (tester) async {
      // Not "a shorter animation" — zero. The guidance treats motion control
      // as a requirement, and a fast animation is still animation.
      await tester.pumpWidget(
        MaterialApp(
          theme: TemanKuTheme.guardian,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                expect(context.reduceMotion, isTrue);
                expect(context.motion(TkMotion.base), Duration.zero);
                expect(context.motion(TkMotion.slow), Duration.zero);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('every interactive component clears the 44pt floor',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TemanKuTheme.guardian,
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TkButton(label: 'Lanjut', onPressed: () {}),
                TkChoiceTile<int>(
                  label: 'Ya',
                  value: 1,
                  groupValue: 0,
                  onSelected: (_) {},
                ),
                TkSwitchTile(title: 'Efek suara', value: true, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final type in [TkButton, TkChoiceTile<int>, TkSwitchTile]) {
        final size = tester.getSize(find.byType(type));
        expect(
          size.height,
          greaterThanOrEqualTo(TemanKuMetrics.minTouchTarget),
          reason: '$type is ${size.height}pt tall, below the 44pt floor (§11)',
        );
      }
    });
  });

  group('token discipline', () {
    test('category fills stay off the feedback tokens', () {
      // The feedback ring is drawn *around* a category fill. If a category
      // ever adopts a feedback colour, "correct" becomes invisible on it.
      const feedback = [
        TkPalette.green, // successFeedback
        TkPalette.yellow, // neutralFeedback
      ];
      final categoryFills = [
        makananModule.distractorStyle.color,
        keluargaModule.distractorStyle.color,
      ];
      for (final fill in categoryFills) {
        expect(
          feedback.contains(fill),
          isFalse,
          reason: 'distractor fill $fill collides with a feedback token',
        );
      }
    });

    test('every category pairs a distinct shape with its colour', () {
      // Redundant coding (§12): colour never carries meaning alone, so the
      // two categories within a module must differ in shape as well as hue.
      for (final module in [makananModule, keluargaModule]) {
        expect(
          module.targetStyle.shape,
          isNot(module.distractorStyle.shape),
          reason: '${module.displayName} uses one shape for both categories',
        );
        expect(module.targetStyle.color, isNot(module.distractorStyle.color));
      }
    });

    test('tkInkOn picks readable ink across the whole palette', () {
      // Category fills span TkPalette.blue to TkPalette.paleYellow, so the
      // label colour has to be derived. Anything under 4.5:1 here means a
      // label that vanishes on some module.
      const fills = [
        TkPalette.blue,
        TkPalette.green,
        TkPalette.yellow,
        TkPalette.pink,
        TkPalette.paleYellow,
        TkPalette.softGreen,
        TkPalette.orange,
      ];
      for (final fill in fills) {
        final ratio = tkContrast(tkInkOn(fill), fill);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'ink on $fill is only ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('muted ink clears AA on both card grounds', () {
      // textMuted carries captions, helper copy and metadata on `surface`
      // (white) and `background` (cream) alike. It is the token most likely
      // to be nudged lighter for "subtlety" — this is the floor.
      for (final colors in [TemanKuColors.child, TemanKuColors.guardian]) {
        for (final ground in [colors.surface, colors.background]) {
          expect(
            tkContrast(colors.textMuted, ground),
            greaterThanOrEqualTo(4.5),
            reason: 'textMuted on $ground is below AA',
          );
        }
      }
    });

    test('the two feedback tokens stay separable by luminance', () {
      // Green/yellow is a poor hue pair under deuteranopia, so the flash
      // states must also differ in lightness. Shape pairing covers the rest
      // (see the category test above), but the ring itself has no shape.
      final delta = (TemanKuColors.child.successFeedback.computeLuminance() -
              TemanKuColors.child.neutralFeedback.computeLuminance())
          .abs();
      expect(
        delta,
        greaterThan(0.2),
        reason: 'correct and try-again differ by only $delta in luminance',
      );
    });

    test('body copy keeps generous leading', () {
      // The supplied specimen measures 1.20, which is display leading on a
      // marketing page. Cognitive-accessibility guidance for this audience
      // calls for open line spacing in running copy; this pins that decision
      // so a later "match the spec exactly" pass has to argue with it first.
      const t = TemanKuTypography.scale;
      expect(t.body.height, greaterThanOrEqualTo(1.4));
      expect(t.bodySm.height, greaterThanOrEqualTo(1.4));
    });

    test('no theme exposes a red error slot to the child surface', () {
      // §12: no alarm colour where a child can see it. Material demands an
      // `error` role exist, so it is mapped onto the neutral "try again"
      // token — this is the check that it stayed mapped.
      for (final theme in [TemanKuTheme.child, TemanKuTheme.guardian]) {
        final colors = theme.extension<TemanKuColors>()!;
        expect(theme.colorScheme.error, colors.neutralFeedback);
        expect(theme.colorScheme.error, isNot(Colors.red));
      }
    });
  });
}
