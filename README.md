# TemanKu

Guardian-mediated AI micro-game teaching Indonesian neurodivergent K-12 students
real-world functional classification skills, using photos of the child's own
environment, in 3–5 minute sessions.

This repo is currently a **scaffold**: structure and wiring only, no feature logic.
It exists so IT-1 and IT-2 can build in parallel from day one without blocking on
each other. See `docs/` for the governing documents — the source of truth is the
authority on product decisions, the architecture doc (ADR-1…4) on structural ones.

---

## First run

```bash
flutter pub get
flutter test         # → 29 passing
flutter analyze      # → clean
flutter run          # → select-child screen
```

Verified on **Flutter 3.44.8 stable / Dart 3.12.2**. `android/`, `ios/`, and
`web/` are generated and committed.

**Android needs two one-time setup steps** on a fresh machine — the SDK is
detected but incomplete:

```bash
# install "Android SDK Command-line Tools" via Android Studio → SDK Manager
flutter doctor --android-licenses
```

Until then, `flutter run -d chrome` works and is enough for engine and
repository work. Do not merge child-session UI on the strength of a web run
alone — §11 is phone-first, and touch targets and layout need a real device.

Firebase is **not** initialised yet, on purpose — `lib/firebase_options.dart` is
generated per-developer by `flutterfire configure` and is gitignored, so
initialising it here would make the scaffold fail to run for anyone who hasn't
provisioned a project. The app runs entirely on in-memory repositories today.
See the commented block in `lib/main.dart`.

---

## The three things to understand before you touch anything

**1. `lib/core/service_locator.dart` is the only place implementations are chosen.**
Repositories (ADR-3) and the two risky services (ADR-4) are all bound there. Both
risky services default to their **fallback**, so the scaffold runs with zero native
dependencies and each primary arrives as a one-line promotion:

| Provider | Now | Swap to | When |
|---|---|---|---|
| `childRepositoryProvider` | `InMemoryChildRepository` | `FirestoreChildRepository` | IT-2, Day 1–2 |
| `classifierServiceProvider` | `ManualLabelClassifier` | `TfliteClassifier` | IT-2, Day 3 · tripwire Day 3 evening |
| `vadServiceProvider` | `ThreeButtonFallback` | `SileroVadService` | IT-1, Day 4 · tripwire Day 4 midday |

If you catch yourself writing `if (useFallback)` in a widget, come back here instead.

**2. `lib/data/repositories/` is a shared contract.** Three abstract classes, three
in-memory fakes with seeded sample data (one child, Makanan + Keluarga). IT-1 builds
the engine against the fakes today; IT-2 builds Firestore/Hive in parallel. Changing
a signature there is a shared-folder change — raise it at the evening checkpoint.

`test/data/child_repository_contract.dart` is the executable definition of that
contract. Every implementation must pass it unmodified. Don't weaken an assertion
to make a new implementation pass — each case encodes a source-of-truth rule.

**3. `lib/core/theme/` is a placeholder and looks like one.** Every colour is a
mid-grey; type is wired to Flutter defaults with no font package installed. Real
tokens come from Claude Design. Both `features/child_session/` and
`features/guardian/` read through the same `ThemeExtension`, so the swap is one
file — no feature file hardcodes a colour or a font size.

---

## Ownership (ADR-2)

| | Owns | Shared — agree before editing |
|---|---|---|
| **IT-1** | `engine/`, `speech/`, `features/child_session/` | `core/theme/`, `data/repositories/` |
| **IT-2** | `data/`, `photo_pipeline/`, `features/guardian/` | `core/theme/`, `data/repositories/` |

`content/` and `widgets/` are jointly touched.

---

## Package choices

Pinned by the source of truth: `flutter_riverpod` (ADR-1), `firebase_core` /
`firebase_auth` / `cloud_firestore` (§11). Chosen here:

- **`hive` + `hive_flutter`** for local persistence. Everything the MVP stores
  locally is key-value shaped — ladder positions keyed `childId::module::mode`,
  photo metadata by id, trial logs appended per session — and Hive needs no schema
  migration step, which matters on a 5-day clock. It also ships `HiveAesCipher`,
  which §11's "local **encrypted** storage" requires and sqflite does not provide
  out of the box.
  **Flagged for IT-2:** if the disengagement detector's latency baseline ends up
  wanting real queries over trial logs (percentiles across sessions, filtered by
  module), sqflite would serve that better than iterating boxes. Adding sqflite
  *alongside* Hive for trial logs only is a reasonable Day 2 call — the
  `SessionRepository` interface already separates trial logs from summaries, so
  that swap does not touch the engine.

- **`go_router`** for navigation, over hand-rolled Navigator 2.0. The flows are
  shallow and named; a declarative route table is one file both developers can read
  without owning each other's screens. Routes carry `childId` in the path rather
  than in ambient state, so a screen can't render the wrong child (§9).

- **No font package.** Deliberate for this pass — see `core/theme/`.

---

## Testing priority

Per the architecture doc, this is a deliberate call, not an oversight:
`engine/` gets real unit tests (pure Dart, fast, most likely to hide a subtle bug);
`data/repositories/` gets contract tests; UI/widget tests are the first thing to cut
if Day 5 is tight.
