/// Composition root — **the one place implementations are chosen.**
///
/// ADR-3 (repositories) and ADR-4 (risky services) both converge here on purpose.
/// The entire rationale for defining interfaces was to make a fallback decision a
/// **one-line swap under time pressure**, and that only holds if the choice lives
/// in exactly one file. If you ever find yourself writing
/// `if (useFallback)` inside a widget or a pipeline step, come back here instead.
///
/// ## The swaps, pre-decided
///
/// | Provider                    | Now                        | Swap to                    | When |
/// |-----------------------------|-----------------------------|----------------------------|------|
/// | `childRepositoryProvider`   | `InMemoryChildRepository`  | `FirestoreChildRepository` | IT-2, Day 1–2 |
/// | `classifierServiceProvider` | `TfliteClassifier` (promoted) | `ManualLabelClassifier` | revert here if it stops being reliable — no debate |
/// | `vadServiceProvider`        | `SileroVadService` (promoted) | `ThreeButtonFallback` | revert here if the `vad` package ever stops being reliable — no debate |
///
/// `pronunciationHintServiceProvider` isn't in that table — it isn't a global
/// swap. It's a `Provider.family<PronunciationHintService, bool>` keyed on
/// `Child.pronunciationHintEnabled`, so the choice is made **per child, per
/// read**, not once at startup. `NoHintService` is the only thing bound for
/// `enabled: false`; `RemoteArticulationHintService` is only ever
/// constructed for `enabled: true`, which only happens after a guardian's
/// explicit consent (`features/guardian/child_settings_screen.dart`). Same
/// ADR-4 principle as the table above — the choice lives in exactly one
/// file — just parameterised instead of static.
///
/// `classifierServiceProvider` and `vadServiceProvider` have both been
/// promoted to their primaries — a real trained model exists
/// (`assets/models/`) for the former, and `speech/silero_vad_service.dart`
/// is a real implementation (on-device Silero via `package:vad`, model
/// bundled as an asset — see that file and `pubspec.yaml`'s asset entry) for
/// the latter. Both fallback columns are now the *revert* direction, not the
/// pending direction — `ThreeButtonFallback` is untouched and still exactly
/// one line away if `SileroVadService` ever needs reverting.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/data/local/local_photo_repository.dart';
import 'package:temanku/data/repositories/child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_child_repository.dart';
import 'package:temanku/data/repositories/in_memory/in_memory_session_repository.dart';
import 'package:temanku/data/repositories/photo_repository.dart';
import 'package:temanku/data/repositories/session_repository.dart';
import 'package:temanku/engine/advancement/advancement_policy.dart';
import 'package:temanku/engine/advancement/advancement_tracker.dart';
import 'package:temanku/engine/dial_engine/dial_engine.dart';
import 'package:temanku/engine/ladder_persistence.dart';
import 'package:temanku/engine/rotation/position_rotator.dart';
import 'package:temanku/photo_pipeline/classifier_service.dart';
import 'package:temanku/photo_pipeline/quality_gate/quality_gate.dart';
import 'package:temanku/photo_pipeline/tflite_classifier.dart';
import 'package:temanku/photo_pipeline/stranger_library/stranger_library.dart';
import 'package:temanku/speech/no_hint_service.dart';
import 'package:temanku/speech/pronunciation_hint_service.dart';
import 'package:temanku/speech/remote_articulation_hint_service.dart';
import 'package:temanku/speech/silero_vad_service.dart';
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

/// Hive + local file store (`data/local/local_photo_repository.dart`). There is
/// no Firestore variant of this one, and that is the design: photos are
/// local-only by default and never auto-uploaded (§10).
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final repo = LocalPhotoRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

// ---------------------------------------------------------------------------
// Swappable services (ADR-4) — fallbacks are the default
// ---------------------------------------------------------------------------

/// Promoted to its primary — `speech/silero_vad_service.dart`, on-device
/// Silero VAD via `package:vad`. `initialize()` is not called here: nothing
/// downstream calls it either (`SpeakModeController`/`speak_mode_screen.dart`
/// only ever call `listenForUtterance`/`cancel`), and `SileroVadService`
/// starts itself lazily on the first `listenForUtterance` for exactly that
/// reason — see that file's doc comment.
///
/// Tripwire unchanged from the original plan: not reliably usable → revert
/// this line to `ThreeButtonFallback()` (`import 'package:temanku/speech/three_button_fallback.dart';`).
/// Decide once, move on.
final vadServiceProvider = Provider<VadService>((ref) {
  final service = SileroVadService();
  ref.onDispose(service.dispose);
  return service;
});

/// Promoted to its primary (Day 3) — `assets/models/makanan_classifier.tflite`
/// exists now. `initialize()` is fire-and-forget here rather than awaited:
/// `TfliteClassifier.suggestLabel` already treats "not loaded yet" exactly
/// like "failed to load" (both return null, the same outcome
/// `ManualLabelClassifier` always produces), so nothing needs to block on
/// this resolving before the provider can be read.
///
/// Tripwire unchanged from the original plan: not reliably usable → revert
/// this line to `ManualLabelClassifier()`. Decide once, move on.
final classifierServiceProvider = Provider<ClassifierService>((ref) {
  final service = TfliteClassifier();
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});

final qualityGateProvider = Provider<QualityGate>((ref) => const ClassicalCvQualityGate());

/// Keyed on `Child.pronunciationHintEnabled` — the one place that decision
/// turns into an actual service instance. `false` (the default for every
/// child until a guardian opts in) always resolves to the free, instant
/// [NoHintService]; `true` is the only path that ever constructs
/// [RemoteArticulationHintService], which is the only thing in this file
/// that talks to a server outside this device.
final pronunciationHintServiceProvider =
    Provider.family<PronunciationHintService, bool>((ref, enabled) {
  return enabled ? RemoteArticulationHintService() : const NoHintService();
});

/// Keluarga's bundled distractor faces (§5.3) — never network-fetched, never
/// mixed into `photoRepositoryProvider`. Only Keluarga consumes this today
/// (`ModuleDefinition.usesBundledDistractors`), but the provider itself is
/// module-agnostic, same as every other entry here.
final strangerLibraryProvider = Provider<StrangerLibrary>((ref) => BundledStrangerLibrary());

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

/// Thin repository wrapper (ADR-3-consuming, not itself a repository) — see
/// `engine/ladder_persistence.dart`.
final ladderPersistenceProvider = Provider<LadderPersistence>(
  (ref) => LadderPersistence(ref.watch(childRepositoryProvider)),
);

/// One tracker for the whole app: it is keyed internally by
/// (childId, module, mode), so a single instance safely serves every session
/// rather than needing to be recreated per screen.
final advancementTrackerProvider = Provider<AdvancementTracker>(
  (ref) => AdvancementTracker(
    dialEngine: ref.watch(dialEngineProvider),
    persistence: ref.watch(ladderPersistenceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Session-scoped selection
// ---------------------------------------------------------------------------

/// The child currently selected on the select-child screen (§9 — select-child
/// precedes session setup). Null before selection.
final selectedChildIdProvider = StateProvider<String?>((ref) => null);
