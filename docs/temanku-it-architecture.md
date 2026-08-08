# TemanKu — IT Architecture

**Deciders:** IT-1, IT-2 · **Status:** Accepted · **Date:** 31 July 2026
**Constraints this is designed under:** 5-day build, 2 developers split by layer (IT-1 = child-facing engine, IT-2 = guardian surface/data/pipeline), Flutter, phone-first, offline-first, two known technical risks with pre-approved fallbacks (classifier, VAD) per the build timeline.

---

## ADR-1: State management — Riverpod

**Context.** The hardest logic in the app — the two-dial engine, position rotation, advancement — is a real state machine, not incidental UI state, and it has to be correct, testable, and cleanly separable from IT-2's data layer given the two of you are working in parallel for five days with minimal time to untangle merge conflicts.

**Options considered**

| Option | Assessment |
|---|---|
| `setState`/plain `ChangeNotifier` | Fast to start, but couples business logic to widgets — the dial engine would be hard to unit-test in isolation, which is risky given it's the most correctness-critical piece |
| Bloc | Strong separation and testability, but its ceremony (events/states/boilerplate) costs build time neither of you can spare in 5 days |
| **Riverpod** | Testable providers without Bloc's boilerplate; business logic (engine, repositories) lives in plain Dart classes exposed via providers, consumed by widgets without either dev needing to touch the other's provider internals |

**Decision.** Riverpod. The dial engine, disengagement rules, and repositories are all plain Dart, provider-wrapped — unit-testable without spinning up widgets, which matters because the engine is exactly the piece you don't want to debug for the first time on Day 5.

**Consequences.** Small day-1 learning-curve cost if either of you hasn't used Riverpod; pays for itself by Day 3 when IT-1 and IT-2's code needs to compose without either fully understanding the other's implementation.

## ADR-2: Repo structure — layered by ownership, not by feature

**Context.** With only two developers working in parallel for five days, the biggest velocity risk isn't writing code, it's merge conflicts and blocking dependencies between you. The repo structure should make it physically obvious who owns which files.

**Decision.** Top-level folders split along the same IT-1/IT-2 boundary already established in the timeline — `engine/` and `speech/` are IT-1's; `data/` and `photo_pipeline/` are IT-2's; `features/` splits internally the same way. See the tree below.

**Consequences.** Reduces merge conflicts to near-zero on the files that matter most, at the cost of some duplication risk if a rule changes in two places — mitigated by ADR-3 below, which forces the shared contracts to be defined once, upfront.

## ADR-3: Repository interfaces defined Day 1, implemented in parallel

**Context.** IT-1's engine needs to read/write child ladder state; IT-2 is the one building the actual Firestore/Hive implementation. If IT-1 waits for IT-2's storage layer to exist before writing engine code, that's a hard dependency chain neither of you can afford in a 5-day build.

**Decision.** Define abstract repository interfaces (`ChildRepository`, `SessionRepository`, `PhotoRepository`) together on Day 1, as plain Dart abstract classes with no implementation. IT-1 codes the engine against these interfaces using an in-memory fake immediately. IT-2 builds the real Firestore/Hive-backed implementation in parallel. They're wired together via Riverpod provider overrides, not by IT-1 waiting.

**Consequences.** This is the single highest-leverage decision in this document for a 5-day timeline — it's what actually makes "layer split" mean *parallel*, not *sequential*. The cost is a short, deliberate Day-1 conversation to get the interfaces right before either of you starts building against them; changing an interface on Day 3 is more expensive than changing it on Day 1, so it's worth 30 real minutes together before splitting off.

## ADR-4: Risky components sit behind swappable service interfaces

**Context.** The build timeline already pre-approved fallbacks for two real technical risks: the Makanan classifier and VAD. Those fallbacks shouldn't be implemented as conditional branches scattered through the codebase — that's how a rushed fallback decision turns into a messy last-minute refactor.

**Decision.** `ClassifierService` and `VadService` are defined as interfaces with two implementations each, decided up front:
- `ClassifierService`: `MlKitClassifier` (primary, on-device ML Kit Image Labeling) vs. `TfliteClassifier` (revert — the original Teachable Machine model, still bundled) vs. `ManualLabelClassifier` (fallback — just prompts the guardian, no model at all)
- `VadService`: `SileroVadService` (primary) vs. `ThreeButtonFallback` (fallback — guardian's third button does the job VAD would have done, no audio detection)

**Consequences.** Triggering a fallback from the timeline's tripwire table becomes a one-line dependency swap at the app's composition root, not a scramble through UI code. This is worth building this way even though it's slightly more setup than hardcoding the primary path directly — the whole point of pre-approving fallbacks was to make the Day-3/Day-4 decision cheap, and that only holds if the code is actually structured to make swapping cheap too.

---

## Repo structure

```
lib/
  core/
    theme/              # design tokens: Kertas, Aksara, Tenang, Daun, Kabut, Kunyit; type scale
    constants/
    routing/

  data/                                    # IT-2
    local/                                 # Hive/sqflite — photos, raw trial logs, ladder cache
    remote/                                # Firestore — guardians/{gid}/children/{cid}/...
    repositories/                          # ChildRepository, SessionRepository, PhotoRepository
                                            #   ↳ interfaces defined Day 1 (ADR-3); impls by IT-2

  engine/                                  # IT-1 — pure Dart, no widget imports, unit-tested
    dial_engine/                           # array-size + similarity-tier state machine (independent dials)
    rotation/                              # position rotation, ≤2-repeat guard
    advancement/                           # independent-correct-streak → level-up logic
    disengagement/                         # latency/randomness/repeat-tap signal collection
    modes/
      tap/
      match/
      speak/                               # wires to speech/ below

  speech/                                  # IT-1
    vad_service.dart                       # interface (ADR-4)
    silero_vad_service.dart
    three_button_fallback.dart

  photo_pipeline/                          # IT-2
    quality_gate/                          # classical CV: blur, luminance
    classifier_service.dart                # interface (ADR-4)
    tflite_classifier.dart
    manual_label_classifier.dart
    stranger_library/                      # bundled Keluarga distractor assets

  content/                                 # module definitions — data, not logic
    makanan/
    keluarga/

  features/
    child_session/                         # IT-1 — tap/match/speak screens, task card, exit dot
    guardian/                              # IT-2 — intake, upload flow, ✅/❌ cluster host,
                                            #   post-session summary, milestone timeline
    onboarding/                            # select-child, guardian account setup

  widgets/                                 # shared design-system components, jointly owned

test/
  engine/                                  # IT-1's priority — the correctness-critical layer
  data/                                    # IT-2's priority — repository contract tests
```

## Ownership map (who touches what, day to day)

| Owns primarily | Touches occasionally | Shared, agree before editing |
|---|---|---|
| **IT-1:** `engine/`, `speech/`, `features/child_session/` | `content/` (module data) | `core/design/`, `data/repositories/` (interfaces only) |
| **IT-2:** `data/`, `photo_pipeline/`, `features/guardian/` | `content/` (module data) | `core/design/`, `data/repositories/` (interfaces only) |

**Practical rule:** if a change touches a shared folder, say so in the evening checkpoint before merging — those are the only files where an uncoordinated change from either of you can break the other's work.

## Testing priority, given 5 days

Not everything gets equal test coverage — this is a deliberate call, not an oversight. `engine/` gets real unit tests, because it's pure Dart (fast to test, no widget harness needed) and it's the piece most likely to have a subtle logic bug (dial-reset-on-similarity-step-up, streak-counting edge cases). `data/repositories/` gets contract tests against the interface, so IT-1's in-memory fake and IT-2's real implementation are verifiably interchangeable. UI/widget tests are the first thing to cut if Day 5 is tight — a visual bug is easy to catch by hand in a 5-minute run-through; a wrong dial-engine transition is not.
