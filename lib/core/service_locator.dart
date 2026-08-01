/// Composition root — **the one place implementations are chosen.**
///
/// ADR-3 (repositories) and ADR-4 (risky services) both converge here on purpose.
/// The entire rationale for defining interfaces was to make a fallback decision a
/// **one-line swap under time pressure**, and that only holds if the choice lives
/// in exactly one file. If you ever find yourself writing
/// `if (useFallback)` inside a widget or a pipeline step, come back here instead.
///
/// ## The three swaps, pre-decided
///
/// | Provider                    | Now (scaffold)          | Swap to                    | When |
/// |-----------------------------|-------------------------|----------------------------|------|
/// | `childRepositoryProvider`   | `InMemoryChildRepository`  | `FirestoreChildRepository` | IT-2, Day 1–2 |
/// | `classifierServiceProvider` | `ManualLabelClassifier` | `TfliteClassifier`         | IT-2, Day 3 (tripwire: Day 3 evening reverts) |
/// | `vadServiceProvider`        | `ThreeButtonFallback`   | `SileroVadService`         | IT-1, Day 4 (tripwire: Day 4 midday reverts) |
///
/// Both risky services default to their **fallback**, not their primary. That is
/// deliberate: the scaffold runs today with zero native dependencies, and each
/// primary arrives as a promotion that can be reverted by editing one line —
/// which is exactly the shape the pre-approved fallback table assumes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/data/repositories/child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_photo_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_session_repository.dart';
import 'package:temanku/data/repositories/photo_repository.dart';
import 'package:temanku/data/repositories/session_repository.dart';
import 'package:temanku/engine/advancement/advancement_policy.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/manual_label_classifier.dart';
import 'package:temanku/photo_pipeline/quality_gate/quality_gate.dart';
import 'package:temanku/speech/three_button_fallback.dart';
import 'package:temanku/speech/vad_service.dart';

// ---------------------------------------------------------------------------
// Repositories (ADR-3)
// ---------------------------------------------------------------------------

/// TODO(IT-2): replace with FirestoreChildRepository
final childRepositoryProvider = Provider<ChildRepository>((ref) {
  final repo = InMemoryChildRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// TODO(IT-2): replace with FirestoreSessionRepository
/// (summaries → Firestore, trial logs → Hive; §11 keeps raw trials local-only)
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final repo = InMemorySessionRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// TODO(IT-2): replace with LocalPhotoRepository (Hive + encrypted file store).
/// There is no Firestore variant of this one, and that is the design: photos are
/// local-only by default and never auto-uploaded (§10).
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final repo = InMemoryPhotoRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

// ---------------------------------------------------------------------------
// Swappable services (ADR-4) — fallbacks are the default
// ---------------------------------------------------------------------------

/// Fallback by default. TODO(IT-1): swap to `SileroVadService()` on Day 4.
/// Tripwire: if VAD is still fighting back at Day 4 midday, revert this line. No debate.
final vadServiceProvider = Provider<VadService>((ref) {
  final service = ThreeButtonFallback();
  ref.onDispose(service.dispose);
  return service;
});

/// Fallback by default. TODO(IT-2): swap to `TfliteClassifier()` on Day 3.
/// Tripwire: not reliably usable by Day 3 evening → revert this line. Decide once, move on.
final classifierServiceProvider = Provider<ClassifierService>((ref) {
  final service = ManualLabelClassifier();
  ref.onDispose(service.dispose);
  return service;
});

/// TODO(IT-2): swap to `ClassicalCvQualityGate()` on Day 1.
final qualityGateProvider = Provider<QualityGate>((ref) => AlwaysPassQualityGate());

// ---------------------------------------------------------------------------
// Engine (ADR-1) — plain Dart, provider-wrapped, unit-testable without widgets
// ---------------------------------------------------------------------------

/// TODO(IT-1): implement TwoDialEngine — Day 2.
final dialEngineProvider = Provider<DialEngine>((ref) => const TwoDialEngine());

/// TODO(IT-1): implement GuardedPositionRotator — Day 2.
final positionRotatorProvider =
    Provider<PositionRotator>((ref) => GuardedPositionRotator());

/// TODO(IT-1): implement StreakAdvancementPolicy — Day 2.
final advancementPolicyProvider =
    Provider<AdvancementPolicy>((ref) => const StreakAdvancementPolicy());

// ---------------------------------------------------------------------------
// Session-scoped selection
// ---------------------------------------------------------------------------

/// The child currently selected on the select-child screen (§9 — select-child
/// precedes session setup). Null before selection.
final selectedChildIdProvider = StateProvider<String?>((ref) => null);
