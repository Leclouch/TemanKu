import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';

/// Below this, [MlKitClassifier.suggestLabel] never even sees the label —
/// ML Kit itself drops it (`ImageLabelerOptions.confidenceThreshold`), same
/// "silence over a guess" rule [TfliteClassifier] uses (§5.2).
const double mlKitConfidenceThreshold = 0.7;

/// Ceiling on [ImageLabeler.processImage], same reasoning as the timeouts
/// on `RemoteArticulationHintService`/`EdgeTtsSource`: a plugin call must
/// never be allowed to stall the upload flow. On-device inference is
/// normally well under a second; this is generous enough to cover a cold
/// unbundled-model download via Play Services, and short enough that a
/// stuck channel (no plugin registered at all — e.g. mid-test, or a device
/// with no Play Services) degrades to "ask the guardian" instead of hanging
/// forever. [ImageLabeler] talks over a platform `MethodChannel`, and a
/// channel with no handler ever registered **buffers the message and never
/// resolves** rather than failing fast — unlike [TfliteClassifier]'s native
/// library load, which fails synchronously. Without this timeout, that
/// showed up as widget tests that don't stub the classifier hanging
/// indefinitely.
const Duration _mlKitTimeout = Duration(seconds: 5);

/// Primary label extraction (§11, ADR-4) — Google ML Kit's on-device,
/// pretrained Image Labeling API. Source-of-truth §11 records that a
/// pretrained general-purpose classifier is an acceptable fallback: guardian
/// confirmation catches misses, so a model that names "pisang" correctly
/// most of the time is good enough.
///
/// Replaces the Teachable Machine/TFLite model
/// (`photo_pipeline/tflite_classifier.dart`, kept as the documented ADR-4
/// revert) for one reason: that model only ever recognised the ~14 classes
/// it was manually trained on. ML Kit's base model ships 400+ generic labels
/// with no training step at all — on-device, offline, free.
///
/// ## The label-language problem, and how this handles it
///
/// ML Kit's base model returns **English** category words ("Banana",
/// "Bread"), but every target word in this app — the child-facing label, the
/// TTS model (`speech/tts/edge_tts_source.dart`), the backend's
/// `TARGET_DICT` — is Indonesian. Showing "Banana" to a guardian labelling a
/// photo of pisang would be actively wrong, not just unhelpful, so this
/// class never hands back a raw ML Kit label. [_labelTranslations] maps a
/// fixed set of expected English labels to their Indonesian domain word
/// (drawn from `assets/models/makanan_labels.txt`, the old model's class
/// list); a label with no entry there is treated exactly like a
/// below-threshold one — null, guardian types it.
///
/// That map is **best-effort, not verified against a live device** — ML
/// Kit's exact label strings and casing weren't something this change could
/// confirm without running it. Tune [_labelTranslations] against real
/// `suggestLabel` output on device before relying on it; the label map at
/// https://developers.google.com/ml-kit/vision/image-labeling/label-map is
/// the reference for what the base model can return.
///
/// **Tripwire, same as the model it replaces:** not reliably useful →
/// revert `classifierServiceProvider` in `core/service_locator.dart` back to
/// `TfliteClassifier` (still bundled) or `ManualLabelClassifier`. Decide
/// once, move on.
class MlKitClassifier implements ClassifierService {
  ImageLabeler? _labeler;

  @override
  bool get canSuggestLabels => true;

  @override
  Future<void> initialize() async {
    try {
      _labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: mlKitConfidenceThreshold),
      );
    } catch (error) {
      // Same degrade-not-throw contract as TfliteClassifier: a construction
      // failure here (missing Play Services on an unbundled install, etc.)
      // leaves _labeler null, and suggestLabel below reads that as "ask the
      // guardian" — never surfaced as an error to the upload flow.
      _log('MlKitClassifier failed to initialize; falling back to manual entry: $error');
      _labeler = null;
    }
  }

  @override
  Future<LabelSuggestion?> suggestLabel({
    required String imagePath,
    required ModuleId module,
  }) async {
    // No face model, by design and permanently (§5.3) — and more generally,
    // this classifier only ever knows the Makanan label set below.
    if (module != ModuleId.makanan) return null;

    final labeler = _labeler;
    if (labeler == null) return null;

    try {
      final labels = await labeler
          .processImage(InputImage.fromFilePath(imagePath))
          .timeout(_mlKitTimeout);
      // TEMP DEBUG — remove once _labelTranslations is verified against real
      // device output (see this file's own doc comment: that map was never
      // confirmed against actual ML Kit label strings/casing). This is the
      // evidence to check when a photo that obviously shows e.g. an apple
      // still leaves the name field empty: either ML Kit returned nothing
      // usable, or it returned something not present in the map below.
      _log(
        'ML Kit raw labels for $imagePath: '
        '${labels.map((l) => '${l.label} (${l.confidence.toStringAsFixed(2)})').join(', ')}',
      );
      for (final label in labels) {
        final translated = _labelTranslations[label.label.trim().toLowerCase()];
        if (translated != null) {
          return LabelSuggestion(label: translated, confidence: label.confidence);
        }
      }
      // ML Kit was confident about *something*, just nothing in this app's
      // domain (e.g. a hand, a table edge) — same outcome as no labels at
      // all: ask the guardian, don't guess a translation.
      return null;
    } on TimeoutException {
      _log('MlKitClassifier timed out after $_mlKitTimeout; treating as no suggestion.');
      return null;
    } catch (error, stackTrace) {
      _log('MlKitClassifier inference failed; treating as no suggestion: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _labeler?.close();
    _labeler = null;
  }

  // TEMP DEBUG — remove alongside the call sites above once the label map is
  // verified on device. Writes to both `dart:developer` (DevTools/`flutter
  // run`'s own console) and `debugPrint` (which does reach raw `adb logcat`,
  // under the `flutter` tag — `dart:developer.log` alone does not), since
  // it's not obvious in advance which one whoever's testing will be watching.
  void _log(String message) {
    developer.log(message, name: 'MlKitClassifier');
    debugPrint('[MlKitClassifier] $message');
  }
}

/// English ML Kit label (lowercased) → Indonesian domain word, scoped to
/// the Makanan class list `tflite_classifier.dart` used to train against.
/// Several plausible ML Kit synonyms are mapped to the same Indonesian word
/// where the base model's exact category name is genuinely uncertain — see
/// the class doc comment. `Background_Empty` has no entry: there is no
/// English label for "nothing", so an empty/off-target photo simply matches
/// nothing here and falls through to null, correctly.
const Map<String, String> _labelTranslations = {
  'doughnut': 'Donat',
  'donut': 'Donat',
  'egg': 'Telur Rebus',
  'boiled egg': 'Telur Rebus',
  'candy': 'Permen',
  'confectionery': 'Permen',
  'junk food': 'Kripik',
  'potato chip': 'Kripik',
  'chips': 'Kripik',
  'snack': 'Kripik',
  'cookie': 'Biskuit',
  'biscuit': 'Biskuit',
  'baked goods': 'Biskuit',
  'bread': 'Roti',
  'bun': 'Roti',
  'apple': 'Apel',
  'banana': 'Pisang',
  'ball': 'Bola',
  'shoe': 'Sepatu',
  'footwear': 'Sepatu',
  'pencil': 'Pensil',
  'office supplies': 'Pensil',
  'book': 'Buku',
  'publication': 'Buku',
  'toothbrush': 'Sikat Gigi',
  'toy': 'Mobil Mainan',
  'vehicle': 'Mobil Mainan',
  'car': 'Mobil Mainan',
};
