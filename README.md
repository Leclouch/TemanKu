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
flutter test         # → 263 passing
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

**3. `lib/core/design/` is the design system, and nothing outside it invents a
visual value.** Three layers, in reading order:

- `tokens.dart` — the brand palette, semantic colour slots, type scale, spacing,
  radii, stroke widths, motion. **The only file in the repo allowed a colour
  literal.** Slots are named by role (`successFeedback`), never by hue.
- `theme.dart` — binds those tokens onto Material's component themes, so a bare
  `AppBar`, `FilledButton` or `AlertDialog` comes out on-brand without the call
  site knowing anything. This is why the app needs no third-party UI library.
- `components/` — the `Tk*` vocabulary: `TkScreen` / `TkChildScreen` shells,
  `TkCard`, `TkSection`, `TkButton`, `TkChoiceTile`, `TkSwitchTile`,
  `TkStepIndicator`, `TkLoading`, `TkEmptyState`, `TkBadge`, `TkDetailRow`.

Import `core/design/design.dart` — one barrel for all three. Reach for a `Tk*`
component first; a plain Material widget is fine as a fallback, because it is
themed. What is never fine is a local `Container(decoration: BoxDecoration(...))`
that reinvents card chrome — that is how the last round of drift started.

`test/core/design/design_system_test.dart` guards the invariants: no type role
clips at 360×640, every interactive component clears the 44pt floor, derived ink
stays ≥4.5:1 across the palette, and no theme exposes a red error slot.

Two substitutions to know about. **Robuck Rounded** and **ABC Diatype Rounded
Plus** are commercial licences we do not hold; Nunito and Figtree stand in, and
each family name lives in a single `const` in `tokens.dart` so adopting the real
faces is a one-line change per family. Display leading is 0.95/1.00 rather than
the specimen's literal 0.80 — Nunito's extenders clip below ~0.90, which the
clipping guard catches.

---

## Speak mode and the external backend

Speak mode is an **echoic** exercise: the app speaks the word, the child
repeats it, an adult judges. Two of those three steps talk to a FastAPI
service (`main.py`, wav2vec2 + Edge TTS) declared in
`lib/speech/articulation_backend.dart` — **the only outbound network
destination in the app**, and gated entirely behind
`Child.pronunciationHintEnabled`.

| Direction | Endpoint | What crosses the wire |
|---|---|---|
| Model the word | `GET /tts` | the word as text → MP3 back. **No microphone data.** |
| Score the echo | `POST /score` | a clip of **the child's voice** → `{predicted_ipa, distance}` |

Four things to know before touching any of it:

**1. The guardian still judges.** §6 is unchanged. The score *highlights* one
of the ✅/↻/— buttons and prints the phonemes it heard; the guardian's tap is
the only thing that reaches `AdvancementTracker`. There is no code path from
`PronunciationHintResult` to `recordResponse`, and `speak_mode_screen.dart`'s
`_judge` takes its outcome as a parameter specifically so there cannot be.

**2. Playback must finish before the mic opens.** If they overlap, VAD hears
the app's own synthesised voice and scores the app against itself.
`WordAudioService.speak` completes on playback end, and `_runTrialTurn` awaits
it before listening. This is a correctness property, not presentation.

**3. Tolerance is calibrated client-side**, in
`speech/articulation_tolerance.dart`. The backend returns a **raw** Levenshtein
distance; that file maps `LadderPosition` → how much is tolerated, sends it as
the request's `difficulty` so both sides agree, and re-derives the judgement
locally so the UI can explain it. The bar **loosens** at a fresh similarity
tier — §4.5's one-dial-at-a-time rule says a child stepping up in visual
discrimination should not be charged again on articulation at the same moment.

**4. `TARGET_DICT` in `main.py` has three words.** Guardian labels are free
text, so most words cannot be scored. `PronunciationHintService.canScore`
probes `GET /` and, when the word is absent, **no clip is recorded at all** —
not captured, not uploaded (§10). TTS has no such limit, so the echoic
exercise still works; only the advisory hint drops out.
> `main.py` already sets the eSpeak env vars for `phonemizer` but never
> imports it. `phonemizer.phonemize(word, language='id')` would generate the
> target IPA for any Indonesian word and remove this limit entirely.

The ngrok URL is a **development address that changes when the tunnel
restarts** — one line in `articulation_backend.dart`. Verify a live backend
end-to-end with:

```bash
dart run tool/smoke_articulation_backend.dart   # 6 checks, real host
```

---

## Ownership (ADR-2)

| | Owns | Shared — agree before editing |
|---|---|---|
| **IT-1** | `engine/`, `speech/`, `features/child_session/` | `core/design/`, `data/repositories/` |
| **IT-2** | `data/`, `photo_pipeline/`, `features/guardian/` | `core/design/`, `data/repositories/` |

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

- **No font package.** Fonts are bundled as static OFL assets under `assets/fonts/`
  rather than fetched by `google_fonts` — §11 is offline-first, and type must not
  depend on a network call. See `core/design/tokens.dart`.

---

## Testing priority

Per the architecture doc, this is a deliberate call, not an oversight:
`engine/` gets real unit tests (pure Dart, fast, most likely to hide a subtle bug);
`data/repositories/` gets contract tests; UI/widget tests are the first thing to cut
if Day 5 is tight.
