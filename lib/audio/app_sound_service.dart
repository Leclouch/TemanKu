/// [SoundService] implementation on `package:audioplayers`.
///
/// ## Constraints the assets in `assets/sounds/` must satisfy —
/// SimpleTEA's "encouraging not repressive" principle, see
/// `sound_service.dart`'s own doc comment for the full frame:
///   - `correct.wav` and `try_again.wav` must be **tonally equivalent** —
///     same instrument family, same warmth, similar (short) duration.
///     Distinct enough to be informative, never a fanfare paired with a
///     buzzer.
///   - No looping background music or ambient audio anywhere in the app —
///     [ReleaseMode.stop] below is load-bearing, not a default left alone.
///   - Every sound is short (well under 1 second) with a soft attack/decay —
///     nothing that starts with a sudden loud onset.
///
/// `assets/sounds/*.wav` — plain PCM WAV, not MP3 — see
/// `assets/sounds/.gitkeep` for the file-by-file status. This class just
/// plays whatever asset is actually there; no code change is needed as the
/// audio content itself changes, only if the file *format* ever does.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'package:temanku/audio/sound_service.dart';

/// Moderate, not maxed — the guardian's explicit starting point (task brief
/// constraint), easy to raise or mute from `child_settings_screen.dart`.
const double _defaultVolume = 0.6;

class AppSoundService implements SoundService {
  AppSoundService()
      : _correctPlayer = _newPlayer(),
        _tryAgainPlayer = _newPlayer(),
        _sessionCompletePlayer = _newPlayer();

  /// One player per sound rather than one shared player — so a correct/
  /// try-again pair landing close together (fast consecutive trials) plays
  /// both instead of the second call cutting the first off.
  static AudioPlayer _newPlayer() {
    final player = AudioPlayer();
    // Never loop — each call plays once and stops, like a chime, never like
    // background music (constraint above). Swallowed the same as `_play`'s
    // own errors: construction must never crash the screen that triggers it
    // (e.g. no audio platform channel at all, as in a widget test host).
    unawaited(player.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
    return player;
  }

  final AudioPlayer _correctPlayer;
  final AudioPlayer _tryAgainPlayer;
  final AudioPlayer _sessionCompletePlayer;

  bool _muted = false;
  double _volume = _defaultVolume;

  @override
  bool get isMuted => _muted;

  @override
  double get volume => _volume;

  @override
  void setMuted(bool muted) => _muted = muted;

  @override
  void setVolume(double volume) => _volume = volume.clamp(0.0, 1.0);

  @override
  Future<void> playCorrect() => _play(_correctPlayer, 'sounds/correct.wav');

  @override
  Future<void> playTryAgain() => _play(_tryAgainPlayer, 'sounds/try_again.wav');

  @override
  Future<void> playSessionComplete() =>
      _play(_sessionCompletePlayer, 'sounds/session_complete.wav');

  /// Fails silently on any error — a missing/corrupt/unplayable asset or a
  /// platform audio failure must never crash or block the trial that
  /// triggered it (task constraint). [assetPath] is relative to `assets/`,
  /// per `AssetSource`'s own contract.
  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (_muted) return;
    try {
      await player.stop();
      await player.setVolume(_volume);
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Decoration, not a dependency — see class doc comment.
    }
  }

  /// Not part of the interface — composition-root teardown only, same
  /// convention as the other swappable services in `core/service_locator.dart`.
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _tryAgainPlayer.dispose();
    await _sessionCompletePlayer.dispose();
  }
}
