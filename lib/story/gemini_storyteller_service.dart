import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:temanku/story/storyteller_service.dart';

/// Calls the Gemini API for a freshly-written story beat — **the one place
/// in this file group that leaves the device.**
///
/// Only ever constructed in `core/service_locator.dart`, and only when
/// *both* are true: the child's guardian opted in
/// (`Child.storytellerEnabled` — consent copy in
/// `features/guardian/child_settings_screen.dart`) and the running build was
/// given a key. The key is never hardcoded and never typed into a settings
/// screen — it's supplied at build/run time via
/// `--dart-define=GEMINI_API_KEY=...` (or
/// `--dart-define-from-file=secrets.json`, kept out of version control) and
/// read with [String.fromEnvironment], the standard Flutter pattern for a
/// compile-time secret that must never sit in source. `service_locator.dart`
/// falls back to [NoStorytellerService] whenever that value is empty, so an
/// unconfigured build is never one line away from an accidental network call.
///
/// Google has no official Dart SDK for the Gemini API, so this calls the
/// `generateContent` REST endpoint directly rather than pulling in a wrapper
/// package.
///
/// Model: `gemini-2.5-flash` — this is one short sentence of flavor text on
/// a cheap, latency-sensitive path, not a reasoning task, so a fast/cheap
/// tier model is the right fit. Google's model lineup moves independently of
/// this codebase; re-check `_model` against the current Gemini catalog
/// before relying on this in production.
///
/// The system prompt is the actual safety mechanism here, not a formality —
/// this app's own accessibility guidance (`core/design/tokens.dart`'s
/// "idiom and metaphor cost comprehension" note, repeated in
/// `features/onboarding/intake_screen.dart`) applies to LLM output exactly
/// as much as to hand-written copy, and an LLM will reach for exactly the
/// idiom/metaphor that guidance rules out unless explicitly told not to.
class GeminiStorytellerService implements StorytellerService {
  GeminiStorytellerService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

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
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _systemPrompt},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 120},
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        // TEMP DEBUG — remove once the silent-failure is diagnosed.
        developer.log(
          'Gemini story beat failed: HTTP ${response.statusCode} ${response.body}',
          name: 'GeminiStorytellerService',
        );
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Never index candidates[0]/parts[0] unconditionally — a safety block
      // (empty `candidates`) or a finish with no text both look like "no
      // beats" to this line's null-is-silent contract, not a crash.
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      final text = (parts.first as Map<String, dynamic>)['text'] as String?;
      return (text == null || text.trim().isEmpty) ? null : text.trim();
    } catch (e) {
      // TEMP DEBUG — remove once the silent-failure is diagnosed.
      developer.log('Gemini story beat threw: $e', name: 'GeminiStorytellerService');
      // Network error, timeout, malformed JSON — all collapse to "no beat
      // this time", the same null every other failure path returns. This
      // service must never throw into a child-facing screen.
      return null;
    }
  }
}
