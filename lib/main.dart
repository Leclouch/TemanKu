import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/app.dart';

/// Entry point.
///
/// Firebase is intentionally **not** initialised here yet. `firebase_options.dart`
/// is generated per-developer by `flutterfire configure` and is gitignored, so
/// calling `Firebase.initializeApp()` now would make the scaffold fail to run for
/// anyone who hasn't provisioned a project — the opposite of what a day-one
/// scaffold is for. The whole app currently runs on the in-memory repositories
/// wired in `core/service_locator.dart`.
///
/// TODO(IT-2) Day 1: after `flutterfire configure`, uncomment the block below and
/// swap the repository providers in `core/service_locator.dart`. Those are the
/// only two changes needed — nothing in `features/` or `engine/` should move.
///
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// await Hive.initFlutter();
/// ```
void main() {
  runApp(
    // ProviderScope is the composition root's host (ADR-1). Tests and future
    // Firestore wiring both work by passing `overrides:` here rather than by
    // editing feature code.
    const ProviderScope(
      child: TemanKuApp(),
    ),
  );
}
