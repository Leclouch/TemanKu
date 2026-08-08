/// Runtime "does this asset exist" check, for components that have a real
/// illustration asset to prefer but must keep working before that asset is
/// dropped into the repo — see `tk_decor.dart` and `widgets/mascot.dart`.
///
/// Uses the framework's [AssetManifest] API rather than hand-parsing a
/// manifest file: this SDK no longer ships a plain `AssetManifest.json` at
/// all (verified against the installed Flutter SDK's
/// `packages/flutter/lib/src/services/asset_manifest.dart` — the manifest is
/// `AssetManifest.bin`, a binary `StandardMessageCodec` payload, re-encoded
/// as base64-in-JSON only on web). A prior version of this file called
/// `rootBundle.loadString('AssetManifest.json')` directly, which throws on
/// this SDK — silently, because [FutureBuilder] treats a rejected future the
/// same as "not found yet" and just keeps showing whichever component's
/// procedural fallback, with no error visible anywhere. `AssetManifest.
/// loadFromAssetBundle` is the documented, version-stable way to ask "what's
/// actually bundled" and should be preferred over reading either manifest
/// file by hand.
library;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

Future<Set<String>>? _manifest;

Future<Set<String>> _loadManifest() => _manifest ??=
    AssetManifest.loadFromAssetBundle(rootBundle).then((manifest) => manifest.listAssets().toSet());

/// Resolves to `true` once [assetPath] is confirmed present in the bundled
/// asset manifest, `false` otherwise. Safe to call every build — the
/// manifest itself is fetched once and cached for the process lifetime.
Future<bool> tkAssetExists(String assetPath) async => (await _loadManifest()).contains(assetPath);
