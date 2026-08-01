# TemanKu — Source of Truth
**Version:** 1.0 · **Date:** 31 July 2026 · **Status:** Locked for hackathon build (IncludAI, in partnership with Stanford NNEA)

**How to read this document:** Everything here is a *decision*, not a proposal, unless explicitly marked **[OPEN]**. Each major decision carries its reasoning so it can be defended or deliberately revisited — never silently drifted from. If you're an AI assistant continuing this project: reason to one committed answer rather than presenting menus, ground choices in evidence, and push back on weak ideas instead of validating them.

---

## 1. Project identity

**TemanKu** ("My Friend") — a guardian-mediated AI micro-game teaching Indonesian neurodivergent K-12 students (SLB) real-world functional classification skills, using photos of the child's own environment, in 3–5 minute sessions built for how they actually learn.

**Framing (non-negotiable):** accommodation, not remediation. TemanKu works *with* the child's neurology; it never aims to normalize, extend attention span, or make a child appear less autistic. Aligned with the Stanford Neurodiversity Project's strengths-based model.

## 2. Foundation: field observations

All design traces to direct observation at an Indonesian clinic and an SLB:
1. The dominant gap is **functioning in the real world**, not academics.
2. **Attention is the binding constraint** — 15 minutes is exceptional. Treated as a design constraint, not a deficit to fix.
3. Clinics succeed with simple physical games: circling numbers, color matching, picture pointing/classification, family recognition.
4. Therapists differentiate by **response mode** (point / match / speak), not just difficulty.

## 3. Design pillars (each with its rejected alternative)

| Pillar | Grounding | Rejected |
|---|---|---|
| Content from the child's own photographed environment | Far-transfer failure is the documented weakness of serious games; real-object stimuli collapse the transfer distance | Generic/abstract training games; stock imagery; generic house/room themes |
| Three response modes (tap / match / speak) | UDL multiple means of expression; mirrors observed therapist practice; maps to VB-MAPP operants | Single forced input mode |
| 3–5 min micro-sessions ending before frustration | Strengths-based accommodation of the attention ceiling | Attention-extension training (weak transfer evidence); gamified escalation |
| One task per screen, instant feedback, errorless prompting | NDBI + errorless learning mechanics with functional, child-benefiting goals | Classic massed-trial DTT framing; normalization/compliance goals |
| Familiar stimuli (own family, own objects) | Intact familiar/self-face recognition in autism; video/photo modeling is an evidence-based practice | Cartoon mascots, clipart |
| Guardian mediation | Parent-mediated intervention meta-analyses show better real-life transfer than tech-only | Unsupervised child-only use |
| Anti-addiction design | Self-Determination Theory; dark-pattern vulnerability of children | Streaks, variable rewards, unlock mechanics, re-engagement notifications |

**On ABA:** mechanics kept (clear single task, immediate feedback, errorless prompting — grounded via NDBI/UDL/SDT); historical goals rejected (normalization, compliance, suppression of autistic traits). Goals are exclusively functional skills useful to the child's own life.

## 4. Curriculum

### 4.1 Framework
VB-MAPP (Sundberg) supplies the skill taxonomy. **Response mode and skill domain are separate axes** — the instruction, not the motor channel, determines the skill. Each mode delivers a ladder climbing from simple discrimination toward **LRFFC** (Listener Responding by Function, Feature, Class), the domain that maps onto real-world functioning.

- **Tap** → Listener Responding, climbing to LRFFC
- **Match/drag** → VP-MTS (visual perception/matching-to-sample), climbing to LRFFC-style categorical sorting
- **Speak** → Tact only (stimulus stays on screen; Intraverbal deliberately out of MVP)

**Excluded domains (with reasons):** Motor Imitation (no camera — privacy commitment, not shortcut); Independent/Social Play (screen simulation risks parasocial substitution — permanent exclusion); Reading/Writing (academic-remediation drift); Mand (requires live listener; possible future guardian-mediated in-session requests — "lagi", "istirahat" — flagged, not designed). **Unlocked by the ASR pivot (roadmap, not MVP):** Intraverbal and Echoic — both were excluded for ASR reasons that no longer exist under guardian judgment; both are the existing speak mechanic with a different prompt.

### 4.2 Modules
Four designed; **MVP builds Makanan + Keluarga** to demo polish. Uang and Sampah are fully designed, intentionally deferred.

| Module | Content source | Classification |
|---|---|---|
| Makanan | Photos of the child's real snacks/foods | Edible / not edible |
| Keluarga | Photos of actual family members | My family / not my family |
| Uang *(deferred)* | Photos of the child's own coins/notes | Enough / not enough |
| Sampah *(deferred)* | Photos of household waste | Organic / non-organic |

**Why these two for MVP:** Makanan has zero unresolved design debt, instant judge legibility, and the worked difficulty table below. Keluarga is structurally impossible without personalization — the strongest single proof of the own-photo thesis — and requires no vision model at all (see §6), making it cheap. Uang carries denomination-recognition technical risk *and* is plausibly the hardest module cognitively (quantity comparison is a distinct, later-developing operation from category membership — flagged in clinical literature as its own difficulty domain). Keluarga's deferred consent problem is resolved (§5.3).

**No cross-module gating, ever.** Each child holds an independent ladder position per module per mode. No module's availability depends on another's progress — a mastery gate is the rejected unlock mechanic through a different door, punishing a weaker skill by withholding a stronger one. Narrative order is a presentation choice; guardians may open any module any day.

**[OPEN] Difficulty parity:** "Level 2" in Uang may not equal "Level 2" in Makanan for the same child. Do not assume cross-module comparability; calibrate against co-design feedback.

### 4.3 Narrative wrapper
Light audio narration sequences the day; no animated cutscenes (motion is a spent-deliberately cost). **MVP narrative: "Hari Ini Bersama [nama anak]"** — a complete morning-to-evening arc: wake/prepare (narration only) → kantin snack (Makanan) → home, family time (Keluarga). **No narration stubs for unbuilt modules** — narration only ever promises what is interactive. The full four-beat causal chain (uang → makanan → sampah → keluarga) is the documented product vision, framed as "MVP demonstrates two of four planned daily-life waypoints."

### 4.4 Difficulty: the two-dial system
Array size and distractor similarity are **independent dials, moved one at a time**. Array grows by one (2→3→4), never jumping; array resets to 2 whenever similarity steps up. Worked reference table (Makanan; target pisang):

| Step | Array | Similarity | Example distractors |
|---|---|---|---|
| 1 | 2 | Different category | toy car |
| 2 | 3 | Different category | toy car, toothbrush |
| 3 | 4 | Different category | + book |
| 4 | 2 | Same category, distinct | apel |
| 5 | 3 | Same category, distinct | apel, roti |
| 6 | 4 | Same category, distinct | + jeruk |
| 7 | 2 | Visually similar | terong |
| 8 | 3 | Visually similar | terong, ubi |
| 9 | 4 | Visually similar | + wortel |
| 10 | mixed | **LRFFC (semantic)** | "tunjuk yang boleh dimakan" over a mixed edible/non-edible array |

Keluarga's similarity axis is **demographic closeness of the stranger** (different age group → same-age same-gender), forcing genuine recognition over superficial cues. Guardian summaries describe dials, not levels: *"struggles when items look alike, handles larger groups fine."*

**Position rotation (tap + match):** every item's slot reassigns every trial — targets *and* distractors; match-mode target zones rotate too. Guard: no slot repeats more than twice consecutively. Speak mode has no array; nothing rotates.

### 4.5 Placement & advancement
**Everyone starts at Step 1 of every eligible mode+module. No placement quiz, no calibration screen** — the advancement criterion doubles as placement from trial one. Rationale: Level 1 is harmless for capable children (bounded cost ~1–2 minutes), while a wrong high placement produces exactly the frustration the design exists to avoid; and behavioral observation beats caregiver prediction, consistent with how VB-MAPP placement actually works.

- **Advance** one step on a short consecutive run of correct responses *without the hint* (independent responding — qualitative, per-child, never a fixed percentage).
- Fast learners may clear multiple steps in one sitting; no artificial floor.
- **Repeat** with rotated photos across sessions (spaced, never crammed into one sitting) when the criterion isn't met.
- **The disengagement detector has absolute veto** — sessions end gracefully regardless of ladder position.
- Nothing about levels, scores, or thresholds is ever visible to the child.

## 5. Photo pipeline

**Governing principle: trust the guardian.** The guardian's module choice *is* the categorization; the AI never verifies or second-guesses it. AI works *for* the guardian (label extraction), never *over* them.

1. **Quality gate** (every photo, every module, on-device, instant): blur/lighting/single-subject via classical CV — friendly retake prompt, no jargon. This is about photo usability, not guardian judgment.
2. **Label extraction (Makanan only in MVP):** closed-set on-device classifier names the object for game text/speech. Silent when confident; when unconfident, asks *"apa nama benda ini?"* — framed as the AI needing help. (Uang, when built: denomination picker on low confidence, because value feeds game logic — the one place a wrong label teaches a wrong answer.)
3. **Keluarga: no model.** Guardian supplies name/relationship directly — the only valid source for that data.
4. **Variety target: five varied photos per category** (multiple-exemplar training; Stokes & Baer; Hupps 1986). Upload flow coaches *different instances*, not repeated angles ("tambahkan camilan lain juga ya"). **Soft nudge, never a hard gate.**
5. **Standing correction path:** guardians can re-tag/remove photos anytime. The summary may flag a specific photo the child repeatedly hesitates on (*"anak sering ragu pada foto ini — mungkin cek lagi?"*) — separating "bad exemplar" from "doesn't understand category," which telemetry alone cannot distinguish.

### 5.3 Keluarga stranger library
Distractors come from a **bundled, curated library of licensed-stock or synthetic faces — never real private individuals photographed without consent.** Targets must be personal (that's the far-transfer thesis); distractors only need to be plausible non-family, so a shared asset is *correct*, not a compromise — and it removes the third-party consent problem structurally. Requirements: (a) demographic diversity matched to plausibly resemble Indonesian families, preventing "family = people who look like this" shortcut-learning; (b) candid, phone-photo-realistic style so children key off faces, not photo polish. **MVP scope: 10–15 images**, sufficient for Steps 1–4; documented as minimum-viable, production expansion required.

## 6. Speak mode & speech technology

**Correctness is judged by the guardian, not a model.** A live guardian who knows their child's articulation outperforms any ASR on neurodivergent Indonesian child speech — and base ASR's documented ~20+ point WER degradation on child speech makes machine judgment a false-negative machine: the child says it right, the machine says wrong. That is the punishing-feedback failure mode this design forbids.

- Guardian control: **✅ / ❌** in a corner cluster on the **same device** (no companion device) — small, muted, positioned to read as "not for you" to the child, exactly like the exit affordance.
- **VAD (voice activity detection), not ASR:** on-device (Silero-class), detecting *that and when* the child spoke — never *what* was said. This provides (a) an honest response-latency timestamp uncontaminated by guardian reaction time, and (b) automatic silence-vs-attempt distinction for the disengagement detector. These are one detection, not two features.
- Auto-flag "tidak mencoba" from VAD silence; guardian gets a lightweight override for VAD misses. Common path stays two buttons.
- Fine-tuned Indonesian child ASR: **explicit roadmap item**, feasible only once consented session data exists. Not MVP. Pitch this honestly: "we chose human judgment because automated judgment of atypical speech is unreliable, and we won't pretend otherwise."

## 7. Disengagement detection

On-device, rules-first, no camera, no eye-tracking. Signals: response-latency drift (per-child baseline), answer randomness, repeated same-position tapping (now a *clean* signal because position rotation removes the innocent explanation), VAD silence duration in speak mode. **Sole action: discreetly notify the guardian** (*"sepertinya mulai lelah"*) — never auto-escalate stimulation. Guardian decides: pause, switch mode, or stop; progress saves, timer freezes for resume. Upgrade path to a learned model only after labeled co-design session data exists.

## 8. Guardian experience

- **Intake is per-child** (multi-child model, §9): one behavioral question per mode — "does your child point to something familiar when asked?" / "match two identical pictures?" / "say single words for things they recognize?" — selecting available *modes*, not predicting levels. Diagnosis-status question is context only, never gating. Output framing: *"we'll start here and adjust as we learn from real sessions"* — never a report, never a score. No cognitive/socioemotional assessment claims.
- **Post-session summary: descriptive sentences, notebook not dashboard.** Duration, mode, dial-specific observations. No percentages, no accuracy stats.
- **Longitudinal view: milestone timeline**, not a performance graph — categories reached independent mastery, shown categorically (mastered/emerging) over time. Consistent with therapist-facing VB-MAPP convention without importing scoring culture.
- Guardian voice recording for instructions (adopted from external critique): familiar voice as instruction audio; also the model stimulus if Echoic ships later.
- Prompt fading: hint frequency decreases with demonstrated independence, always subordinate to the disengagement detector — if fading produces frustration signals, back off, never push through.

## 9. Account & data model

**One guardian account → many child profiles.** Each child: own photo library, own per-module/per-mode ladder position, own session history, own intake. Select-child screen precedes session setup. Rationale: the SLB teacher (half the field research) has many students; keying data to the guardian account would require a painful migration later and would structurally exclude the project's own co-designers. **Demo shows one child end-to-end; multi-child is true underneath.** Classroom-level aggregation (cross-child dashboards) is explicitly deferred — bigger build, and aggregate ranking sits in tension with the no-comparison ethic; it is its own future initiative, not a module.

## 10. Ethics (non-negotiable)

- No streaks, variable/random rewards, unlock mechanics, or re-engagement notifications. Rewards predictable and competence-affirming.
- No diagnostic claims anywhere; no scores visible to the child, ever; no alarm colors on the child screen.
- Photos: on-device by default, never uploaded without explicit guardian consent (UU PDP: children's data + biometric data are both sensitive classes; Pasal 25 parental consent).
- AI informs; the human decides — disengagement, correctness (speak), photo labels (low confidence), session continuation.
- Strengths-based language throughout; no deficit framing, no normalization goals.

## 11. Tech stack (corrected — supersedes all earlier stack sketches)

| Layer | Decision | Notes |
|---|---|---|
| Frontend | **Flutter**, responsive from day one | **Phone is the primary design/test target** (smartphones ~98% of Indonesian internet users; tablets ~17% and declining — a tablet-first assumption would reintroduce the access barrier the project exists to remove). Tablet supported free via constraint-based layout; genuine secondary benefit for table-flat classroom joint viewing. Min touch target 44×44pt, **verified at phone scale for the guardian corner cluster** — a mis-tap there misjudges the child. |
| Vision: quality gate | Classical CV (Laplacian blur, luminance) | No ML model needed; every module |
| Vision: label extraction | Small closed-set on-device classifier (MobileNetV3-class, TFLite), Makanan only | Pretrained food/object classifier is an acceptable fallback — guardian confirmation catches misses |
| Vision: Keluarga | **None** | Guardian-supplied labels only |
| Speech | **Silero-class VAD on-device; no ASR** | Verify Flutter/ONNX integration at build time |
| Backend | Firebase Auth + Firestore | **No Cloud Functions in MVP** — no server-side AI calls remain in the core loop; add only if the consented cloud-enhancement path is built |
| Region | asia-southeast1 (Singapore) assumed | **[OPEN]** confirm whether Firestore offers asia-southeast2 (Jakarta) at provisioning |
| Data | `guardians/{gid}/children/{cid}/...`; aggregated telemetry in Firestore; raw trial logs local-only | Summary never needed trial granularity |
| Photos | Local encrypted storage (Hive/sqflite) default; cloud backup = opt-in, consent-gated, out of MVP scope | |
| Stranger library | Bundled app asset | Offline-safe, zero backend, zero consent surface |

**Dead ends, recorded so they aren't re-litigated:** fine-tuned Whisper ASR (superseded by guardian judgment + VAD); AI category-verification of guardian uploads (violated guardian-trust principle); server-side vision as default (privacy + connectivity + latency); eye-tracking/camera-based engagement detection (privacy, philosophy).

## 12. Design system (visual)

Two temperatures, one grammar ("federated design"): child screen calm/predictable (fixed task-card position, always-visible quiet exit, no score, no red — "try again" is neutral Kabut mist at equal visual weight to "correct"); guardian screen warm/notebook-like. Tokens: Kertas `#F7F4EE`, Aksara `#2B2A28`, Tenang `#4F7C77`, Daun `#8FA888` (correct-only), Kabut `#A8B3B8`, Kunyit `#C99A3E` (guardian-only). Type: Fraunces (display), Plus Jakarta Sans (all child-facing + UI), IBM Plex Mono (timestamps only). Signature moment: "the photo becomes the task" in the guardian upload flow only — never animated on the child screen. Japanese transit precedents adopted: redundant coding (each category gets a consistent color **and** shape, always paired, never color alone), Fukuoka local-object-as-identity (direct precedent for photo personalization), non-judgmental progress display (grey-out/highlight journey pattern, candidate for guardian summary). **[OPEN]** Palette validation against CUDO/Okabe-Ito colorblind-safe methodology. **[OPEN]** Screens not yet designed: match mode, speak mode (incl. guardian ✅/❌ cluster), session-end, select-child, guided upload flow.

## 13. Roadmap beyond MVP (direction-setting, not commitments)

Build-out order candidates: Sampah and Uang (already designed; Uang last — hardest cognitively + denomination risk). New module candidates consistent with the project's spine: **safety recognition** (dangerous/safe objects, known adult/stranger — strongest fifth-module candidate, squarely in the DLS-predicts-outcomes domain), **community helper recognition** (bridges into guardian-mediated Mand), **Uang depth extension** (counting). Domains unlocked cheaply: Intraverbal, Echoic (speak mechanic + guardian judgment). **Permanent exclusions:** Motor Imitation (absent a full separate consent/design pass), Independent/Social Play, Reading/Writing/academics. Classroom surface (teacher-led, multi-child, synchronous) = separate future initiative.

## 14. Open items (consolidated)

- [ ] CUD/Okabe-Ito palette validation
- [ ] Remaining screen states (match, speak + guardian cluster, session-end, select-child, upload flow)
- [ ] Co-design sessions with the observed SLB teachers and clinic therapists — validate module set, ladder steps, dial calibration, summary tone; **this outranks further desk refinement**
- [ ] IncludAI official rubric weights + submission requirements (video/repo/deadline) — verify from event page
- [ ] Uang difficulty-parity calibration (cross-module levels not comparable by default)
- [ ] Firestore Jakarta region availability at provisioning
- [ ] Keluarga library production expansion (beyond the 10–15 image MVP set)
- [ ] Team roles / build ownership

## 15. Companion documents

- *TemanKu: A Guardian-Guided AI Micro-Game…* (project description) — theory, references, competitive landscape, evaluation plan. **Its tech-stack and ASR sections are superseded by §11 of this document.**
- *TemanKu — Visual Design Handoff* — full design-direction detail; §12 here is the summary of record.
- Static HTML design mockup (child tap screen, guardian summary, token sheet).
