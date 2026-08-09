# TemanKu

**A guardian-mediated AI micro-game teaching Indonesian neurodivergent K-12
students real-world functional classification skills — using photos of the
child's own environment, in 3–5 minute sessions.**

---

## The problem

Most "serious games" built for neurodivergent learners (especially for ASD)
use English, Western stock imagery, and unfamiliar contexts — dollars,
foreign supermarkets, objects a child has never held. A World Bank paper (Hata, Wang, Yuwono & Nomura, 2023) surveying 2,000+
Indonesian special-education teachers found assistive-tech availability is
still low across the system, and the tools that do exist rarely reflect a
child's actual world.

We spent time observing at a neurodiversity clinic (Beyond Brighter Minds
Indonesia) and a special school (SLB Taruna Al-Quran), watching therapists
run physical drills — circling numbers, color matching, picture pointing,
family recognition — with children who have ADHD, ASD, or both. TemanKu asks
what happens if the digital version of those drills uses the child's *own*
snacks and the child's *own* family, instead of stock photography.

## What it does

**Two MVP modules**, each teaching a real-world classification skill:

| Module | Skill |
|---|---|
| **Makanan** (Food) | Edible vs. non-edible, using photos of the child's own snacks |
| **Keluarga** (Family) | "My family" vs. "not my family," using real family photos against a bundled, consent-safe library of distractor faces |

**Three response modes**, mirroring therapist practice, each with its own
independent progression per module (no cross-module gating):

| Mode | Maps to |
|---|---|
| **Tap** | Listener responding |
| **Match / Drag** | Visual perception, matching-to-sample |
| **Speak** | Tact (echoic) — child repeats a word, an adult judges |

**The guardian stays in the loop, always.** A guardian uploads the child's
photos and mediates every session. The app assists — checking photo quality,
suggesting a label, flagging when a child may be disengaging from a tap/match
trial — but never scores or advances a child on its own. Every ✅/↻ is a
guardian's tap, not a model's output. Guardians can also manually set a
child's starting difficulty per module/mode (e.g. from a therapist's
assessment) — nobody is placed by a quiz. Everyone starts at Step 1 by
default, because in real assessment, a wrong high placement is far more
damaging than a low one.

## How it's built

**Stack:** Flutter/Dart (single Android/iOS codebase), `flutter_riverpod`
for state, `go_router` for navigation, a custom token-based design system
(`lib/core/design/`) so no screen improvises its own visual language.

**Offline-first core loop.** Photo capture, classification, gameplay, and
tap/match disengagement detection all run entirely on-device, with zero
network calls — schools can't be assumed to have reliable internet. Data is
stored locally in encrypted Hive storage and optionally synced to
Firebase/Firestore.

**One deliberate network exception: Speak mode.** It's opt-in per child and
gated behind explicit guardian consent. When enabled: the target word is
synthesized via Microsoft Edge TTS directly from the device (text out, audio
back — no microphone data leaves the phone for that step), and the child's
echoed clip can optionally be scored by our own FastAPI + wav2vec2 backend
for a phonetic *hint*. That hint only ever highlights a suggested button; the
guardian's tap is still the only thing that reaches the advancement logic.

**A composition root for every hard call.** `lib/core/service_locator.dart`
is the one file where every swappable implementation is chosen — repository
backends and the two "risky" on-device services (photo classifier, VAD). The
image classifier has moved between a bundled TFLite model, Google ML Kit,
and a self-hosted zero-shot SigLIP2 model as tradeoffs became clearer; VAD
(Silero, via ONNX Runtime) currently runs on-device for Speak mode's
turn-taking. Tap/match disengagement detection is a separate, simpler
system — rule-based on response latency and pattern repetition, not audio —
and only ever *flags*, never pauses or ends a session.

**Consent-safe by construction.** The Keluarga module never uses real
strangers' photos. Distractor faces are a small bundled library, curated for
diversity so a child can't shortcut-learn "family = people who look like
this."

**Built for two people to work in parallel.** With a tight build clock and a
two-person IT team, repositories are defined as abstract interfaces backed
by an executable contract test (`test/data/child_repository_contract.dart`)
— one person could build the game engine against in-memory fakes while the
other built the real Firestore/Hive implementations, both required to pass
the same contract.

## Getting started

```bash
flutter pub get
flutter test         # engine + repository-contract suite
flutter analyze
flutter run           # → select-child screen
```

Verified on **Flutter 3.44.8 stable / Dart 3.12.2**. `android/`, `ios/`, and
`web/` are generated and committed.

Firebase is **not** initialized by default — `lib/firebase_options.dart` is
generated per-developer via `flutterfire configure` and gitignored, so the
app runs entirely on in-memory/local repositories out of the box. `flutter
run -d chrome` works for engine/repository work, but the app is phone-first
by design — validate any session-UI change on a real device.

To exercise Speak mode's optional backend end-to-end:

```bash
dart run tool/smoke_articulation_backend.dart   # 6 checks against a live host
```

## Project layout

```
lib/
  core/          design system, service locator, shared constants
  content/       module definitions (Makanan, Keluarga)
  data/          repositories (Firestore/Hive/in-memory) + models
  engine/        pure-Dart game logic — ladder, advancement, rotation
  features/      screens — child_session/, guardian/
  photo_pipeline/  classifiers, quality gate, stranger library
  speech/        VAD, TTS, articulation hint service
```

## Testing

Coverage is weighted deliberately: the engine (pure Dart, most likely to
hide a subtle bug) gets full unit tests, repositories get contract tests
that every implementation must pass unmodified, and widget tests are the
first thing cut under time pressure.

## What's next

- **Deferred modules already scaffolded in the UI** (shown but disabled):
  Sampah (organic/non-organic waste), Uang (Rupiah counting), plus two
  earlier-stage concepts, Pengenalan Keamanan and Pengenalan Orang
  Terpercaya.
- **A richer Keluarga hierarchy** — extended family relationships beyond the
  current immediate-family scope.
- **Co-design validation** with BBMI and SLB Taruna Al-Quran — recorded
  sessions and performance data feeding the next development loop.
- **A classroom surface** — teacher-led, multi-child, synchronous use
  (exploratory, not yet started).

## Team & credits

Built by a four-person team split across Information Technology and
Psychology — the psychology half grounding decisions in field observation
and theory (Stanford Neurodiversity Project's strengths-based model), the IT
half turning that into working software.

