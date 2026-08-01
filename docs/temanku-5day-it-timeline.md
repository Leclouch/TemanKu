# TemanKu — 5-Day IT Build Timeline (IT-1 · IT-2)

**Scope target:** MVP per Source of Truth v1.0 — Makanan + Keluarga, three modes, two-dial engine, photo pipeline, VAD + guardian judgment, disengagement rules, guardian surface, multi-child data model.

**Roles (unchanged):**
- **IT-1** — child-facing game loop: modes, dial engine, rotation, advancement, VAD
- **IT-2** — guardian surface, photo pipeline, backend/data

**Dependency note:** IT-1's Day 2 work needs placeholder photos and Bahasa copy to build against; IT-2's classifier needs real sample photos by Day 2–3. These come from the content/psychology track running in parallel — flag immediately if they're not ready, since it blocks both of you, not just one.

**Standing rule:** short evening checkpoint every day. Fallback triggers below are pre-decided — hit the trigger, take the fallback, don't debate it in the moment.

---

## Day 1 — Foundation

| IT-1 | IT-2 |
|---|---|
| Flutter scaffold with design tokens (§12); responsive constraint-based layout, phone-first; child screen skeleton (fixed task-card position, exit dot); select-child screen | Firebase Auth + Firestore (`guardians/{gid}/children/{cid}`); local encrypted photo storage; photo quality gate (classical CV: blur + luminance) with friendly retake prompt |

**Checkpoint:** scaffold runs on a phone; data model in place.

## Day 2 — Core loop begins

| IT-1 | IT-2 |
|---|---|
| Tap mode end-to-end on Makanan (placeholder photos): two-dial engine (array/similarity steps moved independently), position rotation with ≤2-repeat guard, advancement logic (independent-correct streak), per-child ladder persistence | Guardian upload flow with variety coaching; begin Makanan label-extraction classifier (TFLite); wire quality gate into the flow |

**Checkpoint:** one full tap-mode session playable on placeholder content.

## Day 3 — Match mode, Keluarga, disengagement

| IT-1 | IT-2 |
|---|---|
| Match/drag mode with zone rotation; Keluarga module wiring (guardian-labeled targets + bundled stranger library, no model needed) | Disengagement rules engine (latency baseline, randomness, same-position taps) + discreet guardian notification; classifier continued |

**Evening tripwire — classifier go/fallback:** if the Makanan classifier isn't reliably usable by tonight, switch to guardian-types-the-label (already-designed fallback, not a new build). Decide once, move on.

## Day 4 — Speak mode + guardian surface

| IT-1 | IT-2 |
|---|---|
| Speak mode: Silero VAD integration, guardian ✅/❌ corner cluster + "tidak mencoba" auto-flag with override | Guardian post-session summary (descriptive, dial-specific), milestone timeline, session-end screen, pause/resume with frozen timer |

**Midday tripwire — VAD go/fallback:** if VAD/Flutter integration is still fighting back by lunch, switch to the 3-button guardian judgment fallback (✅/❌/tidak mencoba) — no debate.

**Evening: FEATURE FREEZE.** Everything from here is integration, bugs, and polish — nothing new enters scope.

## Day 5 — Integration, polish, submission-ready

| IT-1 | IT-2 |
|---|---|
| Morning: full integration + bug triage across all three modes; offline test (airplane mode, full session start-to-finish); 44pt touch-target check at phone scale, especially the guardian corner cluster | Morning: same integration pass from the data/backend side; verify multi-child switching, pause/resume, and summary generation under real conditions |
| Afternoon: run the demo flow (child session → guardian summary → Keluarga "impossible without personalization" beat) until it's boringly reliable | Afternoon: record the demo video; repo cleanup + README |
| Late day: final bug fixes only | Late day: package build for submission |

**This day is tight by design** — integration, demo recording, and repo cleanup all landing on one day is the real cost of compressing from 6 to 5. If Day 4's feature freeze slips, Day 5 has no slack left; treat the Day 4 evening freeze as non-negotiable specifically because of this.

---

## Pre-approved fallback table

| Risk | Trigger | Fallback | Cost |
|---|---|---|---|
| Makanan label classifier underperforms | Day 3 evening | Guardian types the label at upload | Loses one "silent AI" moment, pipeline stays honest |
| VAD/Flutter integration stalls | Day 4 midday | 3-button guardian judgment | Loses clean latency timestamps for speak mode only |
| Behind at Day 4 evening freeze | Day 4 evening | Cut speak mode from the *demo script* (keep it in the build if it's close to working) | Speak stays truthfully claimable as built, just not demoed live |
| Day 5 running out of time | Midday Day 5 | Prioritize: working demo flow > repo polish > README completeness, in that order | Submission is judged on the demo first |

## What compressing to 5 days actually costs

Being direct about this rather than pretending it's free: the original 6-day plan had a full day (Day 5) for integration *before* a separate day for demo recording and submission packaging. Here they're the same day. The practical implication is that **Day 4's feature freeze has to actually hold** — in the 6-day version a small scope slip on Day 4 was recoverable; in this version it directly eats into demo-recording time. If either of you senses Day 4 running long by the afternoon, that's the moment to invoke a fallback, not the evening.
