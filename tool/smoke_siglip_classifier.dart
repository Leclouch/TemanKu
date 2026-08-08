/// Live smoke test for the SigLIP2 vision backend — **run by hand, never in
/// CI, and never from `flutter test`.**
///
/// ```
/// dart run tool/smoke_siglip_classifier.dart
/// ```
///
/// Same reasoning as `tool/smoke_articulation_backend.dart`: the mocked unit
/// tests (`test/photo_pipeline/siglip_classifier_test.dart`) prove the
/// parsing and the margin logic, but cannot prove the real backend still
/// returns what this app assumes. This one is stronger than "never in CI" —
/// it is **never runnable** from anywhere `TestWidgetsFlutterBinding` gets
/// initialized at all. `flutter_test` intercepts every real `HttpClient` a
/// test creates and hands back a synthetic `400` with no body
/// (`flutter_test`'s own documented behaviour, not a bug in this app or the
/// backend) — a `test/` file that talks to a real host will always get that
/// `400`, silently, and look like a passing "returns null on failure"
/// result. A previous version of this check lived in `test/` for exactly
/// that reason and never actually exercised the network path even once;
/// this script is what replaced it, following `smoke_articulation_backend`'s
/// established shape for live-only checks.
///
/// Talks to an ngrok tunnel that is up only while the backend is running, so
/// this is deliberately not a `test/` file for the ordinary reason too: a
/// normal `flutter test` run must never depend on that tunnel being up.
library;

import 'dart:io';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/photo_pipeline/siglip_classifier.dart';

/// Filename (under `assets/test/`) -> expected Indonesian label. Spelled out
/// rather than derived from the filename on purpose: "Mainan Mobil.jpeg" and
/// "Telur.jpeg" don't match this app's "Mobil Mainan"/"Telur Rebus" label
/// strings exactly, and that mismatch should be visible here, not silently
/// normalised away.
const _cases = {
  'Pisang.jpeg': 'Pisang',
  'Apel.jpeg': 'Apel',
  'Donat.jpeg': 'Donat',
  'Bola.jpeg': 'Bola',
  'Sepatu.jpeg': 'Sepatu',
  'Buku.jpeg': 'Buku',
  'Telur.jpeg': 'Telur Rebus',
  'Sikat Gigi.jpeg': 'Sikat Gigi',
  'Sikat Gigi_2.jpeg': 'Sikat Gigi',
  'Kripik.jpeg': 'Kripik',
  'Permen.jpeg': 'Permen',
  'Mainan Mobil.jpeg': 'Mobil Mainan',
};

Future<void> main() async {
  var failures = 0;
  void check(String label, bool ok, [String detail = '']) {
    stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $label${detail.isEmpty ? '' : '  — $detail'}');
    if (!ok) failures++;
  }

  final classifier = SiglipClassifier(timeout: const Duration(seconds: 30));

  stdout.writeln('--- suggestLabel (POST /classify) against assets/test/ ---');
  for (final entry in _cases.entries) {
    final imagePath = 'assets/test/${entry.key}';
    if (!File(imagePath).existsSync()) {
      check(entry.key, false, 'file not found at $imagePath');
      continue;
    }

    final suggestion = await classifier.suggestLabel(
      imagePath: imagePath,
      module: ModuleId.makanan,
    );

    check(
      '${entry.key} -> "${entry.value}"',
      suggestion?.label == entry.value,
      suggestion == null
          ? 'null — either the backend is unreachable, or nothing cleared '
              'siglipMarginThreshold; check the backend directly with curl '
              'before assuming this app is at fault'
          : 'got "${suggestion.label}" (confidence=${suggestion.confidence})',
    );
  }

  await classifier.dispose();

  stdout.writeln('\n${failures == 0 ? 'All checks passed.' : '$failures check(s) failed.'}');
  exit(failures == 0 ? 0 : 1);
}
