import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temanku/audio/sound_service.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/features/guardian/child_settings_screen.dart';

/// Records what the screen tells the sound service, without touching any
/// real audio platform channel — same fake-not-mock shape the rest of this
/// codebase's tests use for its other swappable services.
class _FakeSoundService implements SoundService {
  bool _muted = false;
  double _volume = 0.6;

  @override
  bool get isMuted => _muted;

  @override
  double get volume => _volume;

  @override
  void setMuted(bool muted) => _muted = muted;

  @override
  void setVolume(double volume) => _volume = volume;

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playTryAgain() async {}

  @override
  Future<void> playSessionComplete() async {}
}

final _hintToggleFinder = find.widgetWithText(SwitchListTile, 'Saran pengucapan (eksperimental)');
final _soundToggleFinder = find.widgetWithText(SwitchListTile, 'Efek suara');

Widget _buildApp(String childId, InMemoryChildRepository repo, {SoundService? sound}) {
  return ProviderScope(
    overrides: [
      childRepositoryProvider.overrideWithValue(repo),
      soundServiceProvider.overrideWithValue(sound ?? _FakeSoundService()),
    ],
    child: MaterialApp(
      theme: TemanKuTheme.guardian,
      home: ChildSettingsScreen(childId: childId),
    ),
  );
}

void main() {
  testWidgets('the toggle starts off, matching Child.pronunciationHintEnabled default', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(_hintToggleFinder);
    expect(tile.value, isFalse);
  });

  testWidgets('turning it on shows a consent dialog first; cancelling leaves it off and unsaved',
      (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(_hintToggleFinder);
    await tester.pumpAndSettle();

    // The consent copy — explicit about audio leaving the device for this
    // feature only, distinct from the app's normal on-device-only handling.
    expect(find.textContaining('server luar'), findsOneWidget);
    expect(find.textContaining('foto dan data lain'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(_hintToggleFinder);
    expect(tile.value, isFalse);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isFalse);
  });

  testWidgets('confirming the consent dialog turns it on and persists via ChildRepository',
      (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(_hintToggleFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(_hintToggleFinder);
    expect(tile.value, isTrue);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isTrue);
  });

  testWidgets('turning it back off needs no confirmation dialog', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});
    await repo.updateChild(child.copyWith(pronunciationHintEnabled: true));

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    await tester.tap(_hintToggleFinder);
    await tester.pumpAndSettle();

    // No dialog appeared, so the tap took effect immediately.
    expect(find.text('Batal'), findsNothing);
    final tile = tester.widget<SwitchListTile>(_hintToggleFinder);
    expect(tile.value, isFalse);
    expect((await repo.getChild(child.id))!.pronunciationHintEnabled, isFalse);
  });

  testWidgets('the sound toggle starts on, matching SoundService.isMuted default', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});

    await tester.pumpWidget(_buildApp(child.id, repo));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(_soundToggleFinder);
    expect(tile.value, isTrue);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('muting the sound toggle calls setMuted and hides the volume slider — '
      'no confirmation needed, unlike the hint toggle', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});
    final sound = _FakeSoundService();

    await tester.pumpWidget(_buildApp(child.id, repo, sound: sound));
    await tester.pumpAndSettle();

    await tester.tap(_soundToggleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Batal'), findsNothing);
    expect(sound.isMuted, isTrue);
    final tile = tester.widget<SwitchListTile>(_soundToggleFinder);
    expect(tile.value, isFalse);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('dragging the volume slider calls setVolume', (tester) async {
    final repo = InMemoryChildRepository(seed: false);
    final child = await repo.createChild(name: 'Arif', availableModes: {});
    final sound = _FakeSoundService();

    await tester.pumpWidget(_buildApp(child.id, repo, sound: sound));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(-100, 0));
    await tester.pumpAndSettle();

    expect(sound.volume, lessThan(0.6));
  });
}
