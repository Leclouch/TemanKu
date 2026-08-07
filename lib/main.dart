import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:temanku/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


/// Entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // §11: local encrypted storage — LocalPhotoRepository (and the ladder/session
  // Hive boxes as they land) all assume this has run before any box opens.
  await Hive.initFlutter();

  runApp(
    // ProviderScope is the composition root's host (ADR-1). Tests and future
    // Firestore wiring both work by passing `overrides:` here rather than by
    // editing feature code.
    const ProviderScope(
      child: TemanKuApp(),
    ),
  );
}
