import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/data/repositories/photo_repository.dart';
import 'package:temanku/features/guardian/photo_upload_screen.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/quality_gate/quality_gate.dart';

/// Deterministic stand-in for the real [ClassifierService] binding — tests
/// that don't pass one still exercise the real `TfliteClassifier` default,
/// which degrades to a null suggestion in this environment (no native
/// library available), same outcome as `_FakeClassifier(null)` but by
/// accident rather than by design. Tests about the suggestion itself use
/// this instead so the behaviour under test doesn't depend on that.
class _FakeClassifier implements ClassifierService {
  _FakeClassifier(this._suggestion);

  final LabelSuggestion? _suggestion;

  @override
  bool get canSuggestLabels => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async =>
      _suggestion;

  @override
  Future<void> dispose() async {}
}

/// Fakes the plugin the way the image_picker team documents doing it: replace
/// [ImagePickerPlatform.instance] rather than reaching for a real camera or
/// gallery, which don't exist in the widget-test environment.
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  _FakeImagePickerPlatform(this._pathToReturn);

  /// Null simulates the guardian backing out of the system picker.
  final String? _pathToReturn;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return _pathToReturn == null ? null : XFile(_pathToReturn);
  }
}

class _StubQualityGate implements QualityGate {
  const _StubQualityGate(this._result);

  final QualityResult _result;

  @override
  Future<QualityResult> check(String imagePath) async => _result;
}

const _countLabel = '0 dari 5 disarankan untuk kategori ini.';
const _countLabelAfterOne = '1 dari 5 disarankan untuk kategori ini.';
const _confirmButton = 'Pakai foto ini';
const _retakeButton = 'Ambil ulang';

void main() {
  late Directory tempDir;
  late String validImagePath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('photo_upload_screen_test');
    final image = img.Image(width: 8, height: 8);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        image.setPixelRgb(x, y, 128, 128, 128);
      }
    }
    validImagePath = '${tempDir.path}/photo.png';
    await File(validImagePath).writeAsBytes(img.encodePng(image));
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  Widget buildApp({
    required QualityGate gate,
    required PhotoRepository repo,
    String? pickedPath,
    ModuleId module = ModuleId.makanan,
    ClassifierService? classifier,
  }) {
    ImagePickerPlatform.instance = _FakeImagePickerPlatform(pickedPath);
    return ProviderScope(
      overrides: [
        qualityGateProvider.overrideWithValue(gate),
        photoRepositoryProvider.overrideWithValue(repo),
        if (classifier != null) classifierServiceProvider.overrideWithValue(classifier),
      ],
      child: MaterialApp(
        theme: TemanKuTheme.guardian,
        home: PhotoUploadScreen(childId: 'child_1', module: module),
      ),
    );
  }

  testWidgets(
      'a quality-gate pass shows a confirmation preview first — nothing is '
      'saved until the guardian confirms', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    final app = buildApp(
      gate: const AlwaysPassQualityGate(),
      repo: repo,
      pickedPath: validImagePath,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text(_countLabel), findsOneWidget);

    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();

    // Preview stage: confirm/retake bar visible, nothing persisted yet, and
    // the ordinary capture UI (which would read "0 dari 5" here) is gone.
    expect(find.text(_confirmButton), findsOneWidget);
    expect(find.text(_retakeButton), findsOneWidget);
    expect(await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan), isEmpty);

    await tester.tap(find.text(_confirmButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bagus!'), findsOneWidget);
    expect(find.text(_countLabelAfterOne), findsOneWidget);

    final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
    expect(saved, hasLength(1));
    expect(saved.single.category, PhotoCategory.target);
    expect(saved.single.localPath, validImagePath);
  });

  testWidgets('retaking from the preview discards the photo and saves nothing', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    final app = buildApp(
      gate: const AlwaysPassQualityGate(),
      repo: repo,
      pickedPath: validImagePath,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();
    expect(find.text(_confirmButton), findsOneWidget);

    await tester.tap(find.text(_retakeButton));
    await tester.pumpAndSettle();

    // Back to the ordinary capture UI, nothing saved.
    expect(find.text('Ambil foto'), findsOneWidget);
    expect(find.text(_confirmButton), findsNothing);
    expect(await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan), isEmpty);
  });

  testWidgets('a photo that fails the gate shows the retake prompt and saves nothing',
      (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    const failResult = QualityResult.fail(QualityIssue.blurry);
    final app = buildApp(
      gate: const _StubQualityGate(failResult),
      repo: repo,
      pickedPath: validImagePath,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();

    final expectedPrompt = qualityIssueRetakePrompt[QualityIssue.blurry]!;
    expect(find.text(expectedPrompt), findsOneWidget);
    expect(find.text('Coba lagi dengan kamera'), findsOneWidget);
    // A quality-gate fail never reaches the confirmation preview at all.
    expect(find.text(_confirmButton), findsNothing);

    final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
    expect(saved, isEmpty);
  });

  testWidgets('cancelling the system picker saves nothing and stays idle', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    final app = buildApp(
      gate: const AlwaysPassQualityGate(),
      repo: repo,
      pickedPath: null,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();

    final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
    expect(saved, isEmpty);
    expect(find.text('Ambil foto'), findsOneWidget);
  });

  testWidgets('the count shown tracks whichever category is selected', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    await repo.addPhoto(
      childId: 'child_1',
      module: ModuleId.makanan,
      localPath: '/fake/existing.jpg',
      category: PhotoCategory.distractor,
    );
    final app = buildApp(
      gate: const AlwaysPassQualityGate(),
      repo: repo,
      pickedPath: null,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text(_countLabel), findsOneWidget);

    await tester.tap(find.text(makananModule.distractorCategoryLabel));
    await tester.pumpAndSettle();

    expect(find.text(_countLabelAfterOne), findsOneWidget);
  });

  testWidgets('the saved nudge dismisses without touching saved data', (tester) async {
    final repo = InMemoryPhotoRepository(seed: false);
    final app = buildApp(
      gate: const AlwaysPassQualityGate(),
      repo: repo,
      pickedPath: validImagePath,
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_confirmButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bagus!'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bagus!'), findsNothing);
    final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
    expect(saved, hasLength(1));
  });

  group('Makanan — classifier-suggested label (§5.2)', () {
    testWidgets(
        'a confident suggestion pre-fills the preview\'s name field and is saved as-is',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        classifier: _FakeClassifier(const LabelSuggestion(label: 'Pisang', confidence: 0.9)),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();

      // Pre-filled before any confirmation — the guardian sees the guess,
      // doesn't have to trust it blindly.
      expect(find.text('Pisang'), findsOneWidget);

      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
      expect(saved.single.label, 'Pisang');
      expect(find.textContaining('Tersimpan sebagai "Pisang"'), findsOneWidget);
    });

    testWidgets('no suggestion leaves the preview field empty for the guardian to fill in',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        classifier: _FakeClassifier(null),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();

      expect(find.text('apa nama benda ini?'), findsOneWidget); // hint text

      await tester.enterText(find.byType(TextField), 'Pisang');
      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
      expect(saved.single.label, 'Pisang');
    });

    testWidgets(
        'confirming with no suggestion and no typed name saves unlabeled; the '
        'post-save nudge still offers the §5.5 fallback to name it', (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        classifier: _FakeClassifier(null),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
      expect(saved.single.label, isNull);
      const askPrompt = 'Wali tahu nama benda ini? Ketuk untuk kasih nama.';
      expect(find.text(askPrompt), findsOneWidget);

      await tester.tap(find.text(askPrompt));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pisang');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final relabeled = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
      expect(relabeled.single.label, 'Pisang');
      expect(find.textContaining('Tersimpan sebagai "Pisang"'), findsOneWidget);
    });

    testWidgets('cancelling the post-save edit dialog leaves the saved label untouched',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        classifier: _FakeClassifier(const LabelSuggestion(label: 'Pisang', confidence: 0.9)),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Tersimpan sebagai "Pisang"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.makanan);
      expect(saved.single.label, 'Pisang');
    });
  });

  group('Keluarga — name + age group instead of a category picker', () {
    testWidgets('the category picker is replaced by name/age-group fields', (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        module: ModuleId.keluarga,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Foto ini termasuk:'), findsNothing);
      expect(find.text('Nama / hubungan keluarga:'), findsOneWidget);
      expect(find.text('Kelompok usia:'), findsOneWidget);
    });

    testWidgets('capture stays disabled until both a name and an age group are set',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        module: ModuleId.keluarga,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      FilledButton captureButton() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Ambil foto'));

      expect(captureButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Kakak Sari');
      await tester.pumpAndSettle();
      expect(captureButton().onPressed, isNull, reason: 'age group still unset');

      await tester.tap(find.text('Remaja')); // AgeGroup.teen
      await tester.pumpAndSettle();
      expect(captureButton().onPressed, isNotNull);
    });

    testWidgets('the preview recaps the typed name and age group before saving', (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        module: ModuleId.keluarga,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kakak Sari');
      await tester.tap(find.text('Remaja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();

      expect(find.text('Kakak Sari · Remaja'), findsOneWidget);
      expect(await repo.listPhotos(childId: 'child_1', module: ModuleId.keluarga), isEmpty);
    });

    testWidgets('a saved photo carries the typed name as its label and the chosen age group',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        module: ModuleId.keluarga,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kakak Sari');
      await tester.tap(find.text('Remaja'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      final saved = await repo.listPhotos(childId: 'child_1', module: ModuleId.keluarga);
      expect(saved, hasLength(1));
      expect(saved.single.category, PhotoCategory.target);
      expect(saved.single.label, 'Kakak Sari');
      expect(saved.single.ageGroup, AgeGroup.teen);

      // Keluarga collects the name up front and is permanently
      // usesClassifier: false — the nudge's edit-label affordance is
      // Makanan-only and must not appear here.
      expect(find.textContaining('Ketuk untuk'), findsNothing);
    });

    testWidgets('the name field clears after a save so the next person starts fresh',
        (tester) async {
      final repo = InMemoryPhotoRepository(seed: false);
      final app = buildApp(
        gate: const AlwaysPassQualityGate(),
        repo: repo,
        pickedPath: validImagePath,
        module: ModuleId.keluarga,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nenek');
      await tester.tap(find.text('Lansia')); // AgeGroup.elderly
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_confirmButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });
}
