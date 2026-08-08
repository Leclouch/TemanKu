import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';

/// The mascot's ongoing "chapter" line — **flavor text, not a report.**
///
/// Requested by the child's guardian ("I want the app to feel like there's a
/// story, for engagement") as a way to give session progression some lore
/// without touching anything §8/§12 protect. The line this service returns is
/// narrated *as* the mascot (`widgets/mascot.dart`), appears only in the
/// child-flow "between trials" moments the mascot already owns (currently
/// `day_arc_screen.dart` — never the trial screens, never a guardian surface),
/// and is never read by, or fed into, anything that judges the child:
///
///   - it never touches [LadderPosition]/the dial engine — the storyteller
///     reads the child's *current* tier for flavor, same as
///     `features/guardian/session_recap.dart` does for its own descriptive
///     sentence, but writes nothing back;
///   - it is not shown as a score, a level, or a comparison to anyone else;
///   - a null return means exactly "say nothing extra" — the day-arc screen
///     already reads fine without it (same null-is-silent contract
///     [PronunciationHintService] uses).
///
/// Two implementations, same shape as every other opt-in external service in
/// this codebase (`speech/pronunciation_hint_service.dart` is the direct
/// model):
///   - [NoStorytellerService] (`no_storyteller_service.dart`) — the default.
///     Local, canned, varied by module/tier. Zero network calls, so the
///     feature genuinely works before any API key exists.
///   - `GeminiStorytellerService` (`gemini_storyteller_service.dart`) — calls
///     the Gemini API for a freshly-written line each time. Only ever bound
///     in `core/service_locator.dart` for a child whose guardian has both
///     opted in (`Child.storytellerEnabled`) *and* whose build carries a key
///     (`--dart-define=GEMINI_API_KEY=...`) — see that file's own doc
///     comment for why the key check is separate from the consent check.
abstract class StorytellerService {
  /// Returns one short Bahasa Indonesia sentence (occasionally two) narrated
  /// as the mascot, or null to say nothing this time.
  ///
  /// Must never throw — any failure (no network, malformed reply, rate
  /// limit) is caught internally and reported as a null return, identically
  /// to "the feature is off". Callers are free to fire this without a
  /// try/catch for exactly that reason, same contract as
  /// [PronunciationHintService.scorePronunciation].
  Future<String?> nextBeat(StoryContext context);
}

/// Everything a beat is allowed to be written from — deliberately narrow.
/// No trial counts, no accuracy numbers, no comparison to another child:
/// the same "descriptive, not numeric" ceiling `session_recap.dart` already
/// enforces for the guardian's plain-sentence recap applies here too, even
/// though this line is child-facing rather than guardian-facing.
class StoryContext {
  const StoryContext({
    required this.childName,
    required this.module,
    required this.tierCopy,
    required this.mastered,
  });

  final String childName;
  final ModuleDefinition module;

  /// The child's current similarity tier, already in plain Bahasa —
  /// `ModuleDefinition.similarityTierCopy[position.similarityTier]`, the
  /// exact same lookup `session_recap.dart`'s fallback sentence uses. Never
  /// a raw [SimilarityTier] enum or a number.
  final String tierCopy;

  /// Whether the dial engine's ceiling is reached for this (module, mode) —
  /// same boolean `guardian_home_placeholder.dart`'s milestone timeline
  /// already computes via `DialEngine.isAtCeiling`. Lets the beat mark a
  /// real milestone as a "chapter" moment without carrying a score.
  final bool mastered;
}
