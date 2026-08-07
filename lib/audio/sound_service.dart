/// Sound-effect service — **guardian-controlled, no-punishment audio**, the
/// same pattern as everything else on the child screen (§10/§12: equal
/// visual weight for "correct" and "try again", no alarm colour, guardian
/// holds every real control). Grounded in SimpleTEA's "encouraging not
/// repressive" audio principle: a sound effect layer is decoration on top of
/// the existing feedback, never a competing signal and never a punishment.
///
/// [playCorrect] and [playTryAgain] are deliberately **tonally
/// equivalent** — two friendly chimes from the same instrument family, same
/// warmth, similar (short) duration; distinct enough to be informative
/// (different pitch/pattern), never a success fanfare paired with an error
/// buzzer. See `audio/app_sound_service.dart` for the concrete asset
/// constraints (short, soft attack, no loop) that make that true in practice.
library;

abstract class SoundService {
  /// Plays on a correct, independent response — the same trigger point as
  /// the existing visual feedback in tap/match mode's flash and speak mode's
  /// guardian ✅, never a replacement for it.
  Future<void> playCorrect();

  /// Plays on "coba lagi" — an incorrect response, or (speak mode) no
  /// attempt detected. Never louder or harsher than [playCorrect]; both must
  /// read as equally friendly, the same equal-weight rule the app's
  /// success/neutral colour tokens already follow.
  Future<void> playTryAgain();

  /// Plays once, when a mode screen detects mastery-at-ceiling and is about
  /// to offer the guardian the Lanjutkan/Selesai closure prompt
  /// (`widgets/mastery_closure_prompt.dart`) — marks that natural stopping
  /// point itself, regardless of which button the guardian ends up choosing.
  Future<void> playSessionComplete();

  /// Guardian-facing mute (`features/guardian/child_settings_screen.dart`'s
  /// sound card). Muting silences every `play*` method above immediately; it
  /// never affects whether a trial can proceed — sound is the one thing
  /// being turned off, nothing else.
  void setMuted(bool muted);

  /// Guardian-facing volume. Implementations must clamp to 0.0–1.0. Default
  /// is moderate, never maxed — see `audio/app_sound_service.dart`.
  void setVolume(double volume);

  /// Current mute state — read by the guardian settings toggle so it starts
  /// in sync with whatever this service already holds.
  bool get isMuted;

  /// Current volume — same reasoning as [isMuted].
  double get volume;
}
