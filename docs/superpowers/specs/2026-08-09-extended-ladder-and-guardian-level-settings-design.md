# Extended Ladder and Guardian Level Settings Design

## Purpose

Extend tap-mode progression beyond the celebrated LRFFC array-four milestone
through arrays five and six, where each trial has two valid targets. Add a
guardian-only level settings screen that can set a child's reachable position
per module and response mode without allowing an in-progress streak to carry
across the override.

## Ladder and trial composition

`ArraySize.max` remains four: it is the normal per-tier array-growth bound.
`ArraySize.extendedMax` is six and is reachable only after a child advances
from LRFFC array four. `TwoDialEngine.advance` grows LRFFC arrays four to five
and five to six, then holds at LRFFC array six. `isAtCeiling` deliberately
continues to identify LRFFC array four, retaining today's mastery celebration
at precisely that point.

The dial engine exposes `targetCountFor(position, mode)`. It returns zero for
speak, one for normal visual trials, and two only for tap mode at LRFFC arrays
five and six. Distractor count is derived from the array size less that target
count.

Tap mode gains `TapTrial`, which stores all target slots while retaining the
base `Trial.target` and `Trial.targetSlot` fields for its primary target. The
single-target composition and UI paths remain unchanged. Multi-target trials
select two distinct target photos, rotate the primary target slot with the
existing anti-repeat guard, and shuffle the second target into a remaining
slot. The screen records every tap as a response; correct target slots stay
visibly locked, and the trial resolves only when both targets were found.

## Guardian level settings

`ladderStepsFor` is a pure engine-derived enumerator. For a module and mode it
starts at `LadderPosition.start()`, calls `advanceForMode` until its fixed
point, and returns each distinct reachable position in order. This ensures the
guardian UI cannot invent positions the engine would never produce.

`AdvancementTracker.resetStreak` clears the in-memory streak keyed by child,
module, and mode. The level settings screen writes the selected position via
`LadderPersistence.save`, then calls this reset operation immediately.

The route is a sibling of child settings. Its screen lists enabled module ×
mode combinations, displaying each current position and a `TkChoiceTile<int>`
for canonical steps. A per-block `Terapkan` action creates deliberate friction
before applying the selected position; no confirmation dialog is needed.
Guardian home links to this screen from the preparation area.

## Testing and verification

Engine tests cover extension progression, target and distractor counts, and
the unchanged celebration boundary. Rotator tests cover distinct multi-target
slots and complete mixed layouts. Tap controller and widget tests cover the
two-target trial and incremental response flow. New tests cover ladder-step
enumeration, streak reset, and a guardian override persisting the selected
position while clearing its existing streak.

Verification runs `flutter analyze` followed by the entire `flutter test`
suite.
