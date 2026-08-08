/// Speaks the target word aloud — **the model half of an echoic trial.**
///
/// Speak mode is an echoic exercise: an adult (or the app) produces the word,
/// and the child repeats it. Without the model there is no echoic structure
/// at all — the child is being asked to name a picture from memory, which is
/// a tact, a different skill on a different track (§4.1 is explicit that
/// these are separate axes). This service is what supplies the model.
///
/// ## Ordering is a correctness property, not a nicety
///
/// Playback must **finish** before `VadService.listenForUtterance` starts.
/// If listening overlaps playback, the microphone captures the app's own
/// synthesised voice, VAD flags it as the child speaking, and the clip sent
/// for scoring is the app scoring itself — which would return an excellent
/// distance for a child who said nothing. `speak_mode_screen.dart` awaits
/// [speak] before it begins listening for exactly this reason.
///
/// ## Constraints inherited from the sound layer
///
/// The guardian's mute and volume (`audio/sound_service.dart`,
/// `features/guardian/child_settings_screen.dart`) govern this too. Muted
/// means silent — and a muted trial is still a valid trial, just without the
/// model, because the guardian can always say the word themselves. Nothing
/// here ever blocks a trial from proceeding.
library;

import 'dart:typed_data';

/// One spoken word.
abstract class WordAudioService {
  /// Speaks [word], completing when playback has finished.
  ///
  /// **Never throws, and always completes** — a network failure, an
  /// unplayable response, or no audio platform at all (a widget-test host)
  /// all resolve normally, having produced no sound. A trial that cannot play
  /// its model still runs; see the class doc comment.
  ///
  /// Returns true if audio actually played, so callers can distinguish "the
  /// child heard the model" from "we moved on without it" — used only for
  /// the replay affordance's enabled state, never to gate the trial.
  Future<bool> speak(String word);

  /// Warms [word] into the cache without playing it.
  ///
  /// Called as a trial is composed so the fetch overlaps the UI settling,
  /// rather than the child sitting in silence waiting for a round trip.
  /// Fire-and-forget; failures are swallowed exactly like [speak]'s.
  Future<void> prefetch(String word);

  /// Frees any players/buffers. Composition-root teardown only.
  Future<void> dispose();
}

/// Fetches the audio bytes for a word. Split out from playback so the network
/// half can be tested without an audio platform, and faked without faking
/// `package:audioplayers`.
abstract class WordAudioSource {
  /// MP3 bytes for [word], or null on any failure. Must never throw.
  Future<Uint8List?> fetch(String word);
}

/// The no-op binding — used whenever the guardian has not consented to the
/// remote services, and as the safe default everywhere else.
///
/// Silent and instant, the same relationship [NoHintService] has to
/// `RemoteArticulationHintService`: the feature's absence must be
/// indistinguishable from its failure, so speak mode has exactly one code
/// path either way.
class NoWordAudioService implements WordAudioService {
  const NoWordAudioService();

  @override
  Future<bool> speak(String word) async => false;

  @override
  Future<void> prefetch(String word) async {}

  @override
  Future<void> dispose() async {}
}
