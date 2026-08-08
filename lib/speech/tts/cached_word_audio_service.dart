import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:temanku/audio/sound_service.dart';
import 'package:temanku/speech/tts/word_audio_service.dart';

/// [WordAudioService] on `package:audioplayers`, over a [WordAudioSource].
///
/// Three behaviours worth reading before changing anything here:
///
/// **1. It caches per word, in memory, for the process lifetime.** A speak
/// session repeats the same handful of labels many times, and a child waiting
/// on a round trip before every single trial is dead air in the middle of the
/// exercise. The cache also means the replay button is instant, which is what
/// makes it usable by the child rather than only by the guardian.
///
/// **2. [speak] completes when playback finishes, not when it starts.** The
/// caller (`speak_mode_screen.dart`) awaits this before opening the
/// microphone — see [WordAudioService]'s doc comment for why overlapping the
/// two corrupts the trial.
///
/// **3. The guardian's mute wins.** Muted means [speak] returns false having
/// produced nothing, immediately. Volume is read per call rather than cached,
/// so a change on the settings screen takes effect on the next word without
/// this service needing to observe anything.
class CachedWordAudioService implements WordAudioService {
  CachedWordAudioService({
    required WordAudioSource source,
    required SoundService soundService,
    AudioPlayer Function()? playerFactory,
  })  : _source = source,
        _sound = soundService,
        _playerFactory = playerFactory ?? AudioPlayer.new;

  final WordAudioSource _source;
  final SoundService _sound;
  final AudioPlayer Function() _playerFactory;

  /// Built on first actual playback, not in the constructor.
  ///
  /// Constructing an [AudioPlayer] touches the platform channel, so an eager
  /// one costs a child who never hears a word (guardian muted it, the network
  /// is down, consent is off) a real allocation for nothing — and makes this
  /// class unconstructible in a plain `test()` with no binding at all, which
  /// is exactly where its caching logic wants to be tested.
  AudioPlayer? _player;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final created = _playerFactory();
    // Never loop — one word, once. Same rule and same reasoning as
    // `audio/app_sound_service.dart`'s chimes.
    unawaited(created.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
    return _player = created;
  }

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Bounded so a long session with many distinct labels cannot grow without
  /// limit. Single-word MP3s are ~10KB, so this is well under a megabyte —
  /// the cap exists to be a cap, not because the pressure is real.
  static const int _maxCachedWords = 64;

  @override
  Future<void> prefetch(String word) async {
    final key = _key(word);
    if (key.isEmpty || _cache.containsKey(key)) return;
    await _load(key);
  }

  @override
  Future<bool> speak(String word) async {
    // Checked before the fetch, not after: a muted guardian should not cause
    // network traffic for audio that will never be played.
    if (_sound.isMuted) return false;

    final key = _key(word);
    if (key.isEmpty) return false;

    final bytes = await _load(key);
    if (bytes == null) return false;

    try {
      final player = _ensurePlayer();
      await player.stop();
      await player.setVolume(_sound.volume);

      // Not just `await player.onPlayerComplete.first` — on a reused player,
      // a "Dengar lagi" replay tapped soon after the previous word calls
      // `stop()` on a player the native side may still be tearing down from
      // the prior play, and some platforms have been observed to emit a
      // stray/near-immediate completion event for the *new* play() call
      // before it has actually produced audible sound (the exact bug this
      // was reported as: the replay's completion — and therefore the switch
      // to listening — arrives before the word is heard). Requiring an
      // observed [PlayerState.playing] transition *for this call* before a
      // [PlayerState.completed] is accepted closes that race: a stray event
      // arriving before real playback started is ignored rather than ending
      // the wait early.
      final stopwatch = Stopwatch()..start();
      final completer = Completer<void>();
      var sawPlaying = false;
      final subscription = player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.playing) {
          sawPlaying = true;
        } else if (state == PlayerState.completed && sawPlaying && !completer.isCompleted) {
          completer.complete();
        }
      });

      try {
        await player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));

        // The await that makes the ordering guarantee real. The timeout is a
        // backstop so a platform that never delivers the events above cannot
        // strand the trial waiting to start listening.
        await completer.future.timeout(_playbackCeiling, onTimeout: () {});
      } finally {
        await subscription.cancel();
      }

      // TEMP DEBUG — remove once the premature-completion report is
      // confirmed fixed. A genuine spoken word is not tens of milliseconds;
      // this line is the evidence to check if the bug resurfaces.
      developer.log(
        'speak("$word") settled after ${stopwatch.elapsedMilliseconds}ms '
        '(sawPlaying=$sawPlaying)',
        name: 'CachedWordAudioService',
      );
      return true;
    } catch (_) {
      // Decoration, not a dependency — identical stance to AppSoundService.
      // A trial with no model still runs; see WordAudioService.
      return false;
    }
  }

  /// A single Indonesian word is well under a second. This only ever fires if
  /// the completion event is lost entirely.
  static const Duration _playbackCeiling = Duration(seconds: 5);

  /// Deduplicated per word — a prefetch and a speak racing on the same label
  /// (which is exactly what happens when a trial composes and the child taps
  /// replay immediately) must share one request, not make two.
  Future<Uint8List?> _load(String key) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    return _inFlight[key] ??= _source.fetch(key).then((bytes) {
      if (bytes != null) {
        if (_cache.length >= _maxCachedWords) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = bytes;
      }
      return bytes;
      // Block body, NOT `=> _inFlight.remove(key)`. `Map.remove` returns the
      // value it removed — which here is this very future — and
      // `whenComplete` waits on any future its callback returns. The arrow
      // form therefore makes the future wait for itself, and every fetch
      // hangs forever. A block body discards the return and breaks the cycle.
    }).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Lower-cased and trimmed so "Apel", "apel " and "apel" are one cache
  /// entry and one request. Case does not change the synthesised audio.
  String _key(String word) => word.trim().toLowerCase();

  @override
  Future<void> dispose() async {
    _cache.clear();
    // Null whenever nothing was ever played — see [_ensurePlayer].
    await _player?.dispose();
    _player = null;
  }
}
