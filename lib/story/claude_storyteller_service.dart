import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:temanku/story/storyteller_service.dart';

/// Calls the Claude API for a freshly-written story beat — **the one place
/// in this file group that leaves the device.**
///
/// Only ever constructed in `core/service_locator.dart`, and only when
/// *both* are true: the child's guardian opted in
/// (`Child.storytellerEnabled` — consent copy in
/// `features/guardian/child_settings_screen.dart`) and the running build was
/// given a key. The key is never hardcoded and never typed into a settings
/// screen — it's supplied at build/run time via
/// `--dart-define=ANTHROPIC_API_KEY=...` (or
/// `--dart-define-from-file=secrets.json`, kept out of version control) and
/// read with [String.fromEnvironment], the standard Flutter pattern for a
/// compile-time secret that must never sit in source. `service_locator.dart`
/// falls back to [NoStorytellerService] whenever that value is empty, so an
/// unconfigured build is never one line away from an accidental network call.
///
/// Model: `claude-haiku-4-5` — this is one short sentence of flavor text on
/// a cheap, latency-sensitive path, not a reasoning task; Haiku is the
/// documented fit for that shape of call. See the [SKILL.md claude-api
/// reference] this was written against for the model table.
///
/// The system prompt is the actual safety mechanism here, not a formality —
/// this app's own accessibility guidance (`core/design/tokens.dart`'s
/// "idiom and metaphor cost comprehension" note, repeated in
/// `features/onboarding/intake_screen.dart`) applies to LLM output exactly
/// as much as to hand-written copy, and an LLM will reach for exactly the
/// idiom/metaphor that guidance rules out unless explicitly told not to.
class ClaudeStorytellerService implements StorytellerService {
  ClaudeStorytellerService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5';
  static const _anthropicVersion = '2023-06-01';

  static const _systemPrompt = '''
Kamu adalah maskot pendamping di aplikasi terapi wicara untuk anak SLB
(non-verbal/neurodivergent). Tugasmu: tulis SATU kalimat pendek (maksimal
dua kalimat) berbahasa Indonesia yang merayakan langkah kecil anak dalam
"petualangan" bermain di aplikasi.

Aturan wajib:
- Bahasa Indonesia yang sangat sederhana dan harfiah — TANPA idiom, TANPA
  metafora, TANPA peribahasa. Guidance aksesibilitas untuk audiens ini
  eksplisit: idiom dan metafora menyulitkan pemahaman.
- Nada tenang dan hangat, tidak berlebihan, tidak seperti sorak-sorai game.
- JANGAN pernah menyebut angka, skor, persentase, peringkat, atau
  perbandingan dengan anak lain.
- JANGAN pernah menyebut kata "salah", "gagal", atau kata yang terdengar
  seperti alarm/negatif.
- Balas HANYA dengan kalimat ceritanya, tanpa tanda kutip, tanpa penjelasan.
''';

  @override
  Future<String?> nextBeat(StoryContext context) async {
    final prompt = context.mastered
        ? 'Anak bernama ${context.childName} baru saja menguasai babak '
            '"${context.module.displayName}". Tulis satu kalimat perayaan.'
        : 'Anak bernama ${context.childName} sedang berlatih babak '
            '"${context.module.displayName}", tahap saat ini: '
            '${context.tierCopy}. Tulis satu kalimat lanjutan cerita.';

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': _anthropicVersion,
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 120,
              'system': _systemPrompt,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Never index content[0] unconditionally (SKILL.md's own warning) —
      // a refusal or an empty-content edge case both look like "no beats"
      // to this line's null-is-silent contract, not a crash.
      final content = decoded['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) return null;
      final first = content.first as Map<String, dynamic>;
      final text = first['text'] as String?;
      return (text == null || text.trim().isEmpty) ? null : text.trim();
    } catch (_) {
      // Network error, timeout, malformed JSON — all collapse to "no beat
      // this time", the same null every other failure path returns. This
      // service must never throw into a child-facing screen.
      return null;
    }
  }
}
