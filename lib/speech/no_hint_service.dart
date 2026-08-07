import 'dart:typed_data';

import 'package:temanku/speech/pronunciation_hint_service.dart';

/// Default [PronunciationHintService] binding — **wired as the default in
/// `core/service_locator.dart`.**
///
/// Always null, instantly, no I/O, no mic-adjacent work at all. This is what
/// every child gets until their guardian explicitly opts in (§ toggle in
/// `features/guardian/child_settings_screen.dart`) — the "off" state must be
/// this cheap so leaving the feature off never costs a speak-mode trial
/// anything.
class NoHintService implements PronunciationHintService {
  const NoHintService();

  @override
  Future<PronunciationHintResult?> scorePronunciation({
    required Uint8List audioClip,
    required String targetWord,
    int difficulty = defaultPronunciationHintDifficulty,
  }) async =>
      null;
}
