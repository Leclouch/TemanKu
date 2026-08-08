import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/vision/vision_backend.dart';

/// Candidate vocabulary sent as `/classify`'s `labels` field, keyed by the
/// **English** word — not Indonesian — with the Indonesian domain word this
/// app shows the guardian as the value. This looks like it should be
/// backwards (every other classifier in this app reasons in Indonesian
/// throughout), but it is deliberate and load-bearing: live calibration
/// against real photos in `assets/test/` (§ below) showed SigLIP2's
/// zero-shot text tower performs dramatically worse against raw Indonesian
/// label strings than against English ones. Sending `"Apel"` as a candidate
/// for a bowl of apples scored `0.0006` and lost to `"Nanas"`; sending
/// `"apple"` for the identical photo scored `0.12` and won correctly. This
/// is the same shape of problem [MlKitClassifier] had (its base model only
/// speaks English too) — solved the same way, with an explicit translation
/// map — rather than a new one.
///
/// `'empty background'` is included as a 66th candidate deliberately: it
/// gives the model an explicit "nothing here" option to compete against,
/// rather than forcing every photo — including a blank wall or the
/// guardian's thumb — to win one of the 65 real object labels. It is never
/// looked up in this map on purpose; [SiglipClassifier.suggestLabel] treats
/// it as "no suggestion", same outcome as it not being in this map at all.
const Map<String, String> _labelVocabulary = {
  'banana': 'Pisang',
  'apple': 'Apel',
  'orange': 'Jeruk',
  'mango': 'Mangga',
  'watermelon': 'Semangka',
  'grape': 'Anggur',
  'strawberry': 'Stroberi',
  'pineapple': 'Nanas',
  'papaya': 'Pepaya',
  'avocado': 'Alpukat',
  'donut': 'Donat',
  'bread': 'Roti',
  'biscuit': 'Biskuit',
  'cake': 'Kue',
  'candy': 'Permen',
  'chocolate': 'Cokelat',
  'potato chips': 'Kripik',
  'boiled egg': 'Telur Rebus',
  'rice': 'Nasi',
  'fried noodles': 'Mi Goreng',
  'milk': 'Susu',
  'bottled water': 'Air Mineral',
  'fruit juice': 'Jus Buah',
  'ice cream': 'Es Krim',
  'cheese': 'Keju',
  'yogurt': 'Yogurt',
  'sausage': 'Sosis',
  'chicken nugget': 'Nugget',
  'french fries': 'Kentang Goreng',
  'carrot': 'Wortel',
  'tomato': 'Tomat',
  'cucumber': 'Timun',
  'broccoli': 'Brokoli',
  'spinach': 'Bayam',
  'ball': 'Bola',
  'shoe': 'Sepatu',
  'sandal': 'Sandal',
  'socks': 'Kaos Kaki',
  'hat': 'Topi',
  'shirt': 'Baju',
  'pants': 'Celana',
  'pencil': 'Pensil',
  'pen': 'Pulpen',
  'book': 'Buku',
  'bag': 'Tas',
  'toothbrush': 'Sikat Gigi',
  'soap': 'Sabun',
  'towel': 'Handuk',
  'cup': 'Gelas',
  'plate': 'Piring',
  'spoon': 'Sendok',
  'fork': 'Garpu',
  'toy car': 'Mobil Mainan',
  'doll': 'Boneka',
  'balloon': 'Balon',
  'puzzle': 'Puzzle',
  'crayon': 'Krayon',
  'scissors': 'Gunting',
  'wristwatch': 'Jam Tangan',
  'key': 'Kunci',
  'umbrella': 'Payung',
  'comb': 'Sisir',
  'glasses': 'Kacamata',
  'pillow': 'Bantal',
  'blanket': 'Selimut',
  'bolster pillow': 'Guling',
};

const String _emptyBackgroundLabel = 'empty background';

/// Comma-separated once at load time, not rebuilt per request.
final String _labelsField =
    ({..._labelVocabulary.keys, _emptyBackgroundLabel}).join(',');

/// A live-photo-calibrated **margin**, not an absolute floor — the two are
/// not interchangeable here. SigLIP2's zero-shot head scores each candidate
/// with an independent sigmoid, so absolute confidence for a genuine match
/// varies wildly with how visually clean the photo is: eleven real photos in
/// `assets/test/` (bananas, apples, a ball, a book, candy, a toothbrush,
/// etc. — filenames are the ground truth) scored anywhere from `0.9579`
/// (an unmistakable toy car) down to `0.0001` (a shoe photographed at an
/// odd angle) at the correct label. An absolute threshold that accepts the
/// weak case necessarily accepts noise; one that rejects noise necessarily
/// rejects the weak case.
///
/// The **ratio** between the top score and the runner-up score does not
/// have that problem. Across those same eleven real, correctly-identified
/// photos, the winning label beat its closest competitor by at least `31×`
/// (the weak shoe photo) and typically by `100×`–`9000×`. Across every
/// negative control tried (a photo containing none of these objects — an
/// app icon, a child's face), the top two candidates landed within
/// `1.05×`–`1.2×` of each other: noise looks like a coin flip between
/// whichever two labels happened to be nearest, a real match looks like one
/// label running away with it. `5.0` sits comfortably inside that gap —
/// above every noise sample seen, well below every genuine one.
///
/// Still best-effort: eleven real photos and three negative controls is not
/// a validation set. Retune if guardian-uploaded photos in production
/// disagree with it.
const double siglipMarginThreshold = 5.0;

/// Guards the margin check against float noise when *both* the top and
/// second scores are near zero (e.g. `9e-13` vs `9e-14` is a `10×` margin
/// that means nothing). Set an order of magnitude below the weakest genuine
/// top score observed (`0.0001`, the shoe photo) — low enough to never
/// reject a real weak match, high enough to filter out sub-noise-floor
/// arithmetic.
const double _minTopScore = 1e-5;

/// Primary label extraction (§11, ADR-4) — a self-hosted SigLIP2 zero-shot
/// classifier, reached over HTTPS via a static ngrok domain
/// (`vision/vision_backend.dart`). See hosting notes for the full
/// architecture: FastAPI + uvicorn on port 8000 behind
/// `ngrok-tunnel.service`, `POST /classify` taking `file` + a comma-separated
/// `labels` field.
///
/// Replaces both prior attempts documented in
/// `core/service_locator.dart`'s swap table:
///   - [TfliteClassifier] — bundled Teachable Machine export, locked to the
///     ~14 classes it was manually trained on.
///   - [MlKitClassifier] — on-device and free, but its base model returns
///     generic parent categories ("Food", "Cuisine") for food photos rather
///     than the specific item.
///
/// SigLIP2 is zero-shot: no training step, and the label vocabulary is
/// supplied at request time rather than baked into a model file. Unlike
/// either prior classifier, that vocabulary is free to grow arbitrarily
/// large with no retraining cost — see [_labelVocabulary]'s doc comment for
/// why it is nonetheless keyed in English, with translation back to
/// Indonesian handled explicitly rather than assumed away.
///
/// Confidence handling is the load-bearing part, same principle as the
/// classifiers it replaces (§5.2): below [siglipMarginThreshold], this
/// returns **null** and lets the guardian answer *"apa nama benda ini?"*
/// rather than surfacing a low-confidence guess as certain. Network failure,
/// timeout, a non-200 response, or a malformed body all degrade to that same
/// null — nothing from this class is ever allowed to surface as an app
/// error to the upload flow.
class SiglipClassifier implements ClassifierService {
  SiglipClassifier({
    http.Client? client,
    Uri? baseUrl,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? VisionBackend.baseUrl,
        _timeout = timeout ?? _defaultTimeout;

  /// Same shape as `speech/remote_articulation_hint_service.dart`'s timeout:
  /// a hard ceiling on a call to an external service behind an ngrok tunnel,
  /// never a target. The upload flow does not block its own UI on this
  /// either way.
  ///
  /// `30` seconds, not `15` — raised after live testing
  /// (`tool/smoke_siglip_classifier.dart`) showed individual requests can
  /// legitimately take several seconds once the backend has a few requests
  /// queued up. Note this is a mitigation, not a fix: the same run also saw
  /// requests fail even at a 30s ceiling once the backend fell far enough
  /// behind, because a single blocking-inference request there can stall
  /// every other request — including `/health` — behind it (see
  /// `_logFailure`'s doc comment for how to see this happening from this
  /// side). No client-side timeout reliably papers over that; the real fix
  /// is server-side.
  static const Duration _defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  @override
  bool get canSuggestLabels => true;

  @override
  Future<void> initialize() async {
    // Nothing to load — the vocabulary is a compile-time constant, unlike
    // TfliteClassifier's bundled model or the asset this class used to read
    // before calibration showed a hardcoded translation map was the right
    // shape (see _labelVocabulary's doc comment).
  }

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async {
    // No face model, by design and permanently (§5.3) — and more generally,
    // this classifier only ever knows the Makanan label set.
    if (module != ModuleId.makanan) return null;

    try {
      final request = http.MultipartRequest(
        'POST',
        _baseUrl.resolve('classify'),
      )
        ..headers.addAll(VisionBackend.headers)
        ..fields['labels'] = _labelsField
        ..files.add(await http.MultipartFile.fromPath('file', imagePath));

      final streamed = await _client.send(request).timeout(_timeout);
      if (streamed.statusCode != 200) {
        _logFailure('non-200 status ${streamed.statusCode}');
        return null;
      }

      final body = await streamed.stream.bytesToString().timeout(_timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        _logFailure('response body was not a JSON object');
        return null;
      }

      final scores = _parseScores(decoded['all_scores']);
      if (scores == null || scores.isEmpty) {
        _logFailure('response missing a usable all_scores list');
        return null;
      }
      scores.sort((a, b) => b.value.compareTo(a.value));

      final top = scores.first;
      final second = scores.length > 1 ? scores[1].value : 0.0;

      if (top.value < _minTopScore) return null;
      // second == 0 (a single-candidate response) is an infinite margin —
      // never the blocking condition here, so short-circuit rather than
      // divide by zero.
      if (second > 0 && top.value / second < siglipMarginThreshold) return null;

      final englishLabel = top.key.trim().toLowerCase();
      if (englishLabel == _emptyBackgroundLabel) return null;

      final indonesianLabel = _labelVocabulary[englishLabel];
      if (indonesianLabel == null) {
        // The backend echoed something outside this app's vocabulary —
        // shouldn't happen given what was sent, but "ask the guardian" is
        // the correct degrade either way.
        _logFailure('top label "$englishLabel" has no Indonesian translation');
        return null;
      }

      return LabelSuggestion(label: indonesianLabel, confidence: top.value);
    } on TimeoutException {
      _logFailure('timed out after $_timeout');
      return null;
    } catch (error) {
      // Deliberately broad — network errors, decode errors, anything else
      // the http client or dart:convert can throw. All of it degrades to
      // "no hint this trial", never an error the guardian sees.
      _logFailure('$error');
      return null;
    }
  }

  /// `[{"label": "banana", "score": 0.94}, ...]` — tolerant of entries with
  /// the wrong shape (drops them) rather than failing the whole response
  /// over one malformed element.
  List<MapEntry<String, double>>? _parseScores(dynamic rawScores) {
    if (rawScores is! List) return null;
    return [
      for (final entry in rawScores)
        if (entry is Map && entry['label'] is String && entry['score'] is num)
          MapEntry(entry['label'] as String, (entry['score'] as num).toDouble()),
    ];
  }

  @override
  Future<void> dispose() async {}

  // Writes to both dart:developer (DevTools/`flutter run`'s own console) and
  // plain `print` (which the Flutter engine forwards to raw `adb logcat`
  // under the `flutter` tag — `dart:developer.log` alone does not reach it)
  // — same reasoning as MlKitClassifier's identical note there, which uses
  // `debugPrint` instead. `print` here, not `debugPrint`, is deliberate:
  // `debugPrint` lives in `package:flutter/foundation.dart`, and pulling
  // that in would stop this file compiling under plain `dart run` — which
  // `tool/smoke_siglip_classifier.dart` depends on to test this class
  // outside `flutter_test`'s HTTP-blocking sandbox (see that file's doc
  // comment). A single failure-reason line per classification attempt is
  // far below the burst volume `debugPrint`'s throttling exists for, so
  // `print` loses nothing here that this class actually needs.
  void _logFailure(String reason) {
    final message = 'classification request failed: $reason';
    developer.log(message, name: 'SiglipClassifier');
    // ignore: avoid_print
    print('[SiglipClassifier] $message');
  }
}
