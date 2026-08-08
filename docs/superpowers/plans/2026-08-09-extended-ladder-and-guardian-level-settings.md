# Extended Ladder and Guardian Level Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow tap mode to continue through LRFFC arrays five and six with two targets, and let guardians set any reachable level per module and mode safely.

**Architecture:** The dial engine remains the sole owner of reachable progression. A new pure walker derives guardian-picker choices directly from that engine. Tap-specific trial metadata and UI state carry multi-target completion without changing the established one-target behavior. Guardian application persists a selected engine-reachable position then resets the corresponding in-memory advancement streak.

**Tech Stack:** Flutter/Dart, flutter_riverpod, go_router, flutter_test.

## Global Constraints

- `ArraySize.max == 4` remains the regular per-tier bound; `ArraySize.extendedMax == 6` is only reachable at LRFFC.
- `isAtCeiling` must remain LRFFC array four so the existing mastery closure occurs at the existing point.
- Multi-target tapping is only tap mode at LRFFC arrays five and six, has exactly two targets, accepts them in any order, and records every tap.
- The target/distractor composition and UI behavior for one-target trials must remain unchanged.
- Guardian positions must be derived by walking `DialEngine.advanceForMode`, never by a duplicate hand-maintained level table.
- Applying an override writes through `LadderPersistence.save` and clears the exact `(childId, module, mode)` streak afterward.

---

### Task 1: Extend the dial engine and preserve the celebrated milestone

**Files:**
- Modify: `lib/core/constants/domain_enums.dart`
- Modify: `lib/engine/dial_engine/dial_engine.dart`
- Modify: `test/engine/dial_engine_test.dart`
- Modify: `test/engine/advancement_tracker_test.dart`

**Interfaces:**
- Produces: `ArraySize.extendedMax`, `DialEngine.targetCountFor`, `TwoDialEngine.multiTargetCount`.
- Produces: tap progression `LRFFC/4 -> LRFFC/5 -> LRFFC/6 -> LRFFC/6`.

- [ ] **Step 1: Write failing dial-engine tests**

```dart
expect(engine.advance(const LadderPosition(arraySize: 4, similarityTier: SimilarityTier.lrffc)),
    const LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc));
expect(engine.advance(const LadderPosition(arraySize: 6, similarityTier: SimilarityTier.lrffc)),
    const LadderPosition(arraySize: 6, similarityTier: SimilarityTier.lrffc));
expect(engine.targetCountFor(const LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc), ResponseMode.tap), 2);
expect(engine.distractorCountFor(const LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc), ResponseMode.tap), 3);
```

- [ ] **Step 2: Run the focused tests and verify the missing API/old ceiling fails**

Run: `flutter test test/engine/dial_engine_test.dart`

- [ ] **Step 3: Implement the minimal engine extension**

```dart
static const int extendedMax = 6;
static const int multiTargetCount = 2;

int targetCountFor(LadderPosition position, ResponseMode mode) =>
    mode == ResponseMode.speak ? 0 :
    mode == ResponseMode.tap && position.similarityTier == SimilarityTier.lrffc && position.arraySize > ArraySize.max
        ? multiTargetCount : 1;
```

Order `advance` checks as extended fixed point, LRFFC array-four-or-greater growth, then existing array/tier behavior. Derive non-speak distractors with `position.arraySize - targetCountFor(position, mode)` and update ceiling comments without changing `isAtCeiling`.

- [ ] **Step 4: Update mastery-boundary regression coverage**

```dart
// A cleared streak at LRFFC array 4 sets masteredAtCeiling and advances to 5.
// Cleared streaks at arrays 5 and 6 leave masteredAtCeiling false.
```

- [ ] **Step 5: Run engine and tracker tests**

Run: `flutter test test/engine/dial_engine_test.dart test/engine/advancement_tracker_test.dart`

- [ ] **Step 6: Commit**

Run: `git add lib/core/constants/domain_enums.dart lib/engine/dial_engine/dial_engine.dart test/engine/dial_engine_test.dart test/engine/advancement_tracker_test.dart && git commit -m "feat: extend LRFFC tap ladder"`

### Task 2: Add independent multi-target slot rotation

**Files:**
- Modify: `lib/engine/rotation/position_rotator.dart`
- Modify: `test/engine/position_rotator_test.dart`

**Interfaces:**
- Produces: `PositionRotator.nextTargetSlots({arraySize, count, recentPrimaryTargetSlots})`.
- Produces: `PositionRotator.shuffleSlotsMulti({arraySize, targetSlots})`.

- [ ] **Step 1: Write failing rotator tests**

```dart
final targets = rotator.nextTargetSlots(
  arraySize: 5, count: 2, recentPrimaryTargetSlots: const [1, 1],
);
expect(targets, hasLength(2));
expect(targets.toSet(), hasLength(2));
expect(targets.first, isNot(1));

final slots = rotator.shuffleSlotsMulti(arraySize: 5, targetSlots: const [1, 4]);
expect(slots[1], 0);
expect(slots[4], 1);
expect(slots.toSet(), {0, 1, 2, 3, 4});
```

- [ ] **Step 2: Run the focused test and verify the new methods are absent**

Run: `flutter test test/engine/position_rotator_test.dart`

- [ ] **Step 3: Implement new methods without modifying existing method bodies**

```dart
final first = nextTargetSlot(arraySize: arraySize, recentTargetSlots: recentPrimaryTargetSlots);
final remaining = [for (var slot = 0; slot < arraySize; slot++) if (slot != first) slot]..shuffle();
return [first, ...remaining.take(count - 1)];
```

In `shuffleSlotsMulti`, place target item indices `0..targetSlots.length - 1` at the supplied slots, shuffle all remaining item indices, and fill all other slots.

- [ ] **Step 4: Run the focused rotator tests**

Run: `flutter test test/engine/position_rotator_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/engine/rotation/position_rotator.dart test/engine/position_rotator_test.dart && git commit -m "feat: rotate multiple tap targets"`

### Task 3: Compose and judge two-target tap trials

**Files:**
- Modify: `lib/engine/modes/tap/tap_mode_controller.dart`
- Modify: `test/engine/tap_mode_controller_test.dart`

**Interfaces:**
- Produces: `class TapTrial extends Trial { final List<int> targetSlots; }`.
- Changes: `TapModeController.nextTrial` returns `Future<TapTrial>`.

- [ ] **Step 1: Write failing multi-target composition tests**

```dart
const position = LadderPosition(arraySize: 5, similarityTier: SimilarityTier.lrffc);
final trial = await controller.nextTrial(
  position: position, available: _photos(targets: 2, distractors: 3),
  recentTargetSlots: const [], recentTargetZones: const [],
);
expect(trial.targetSlots, hasLength(2));
expect(trial.targetSlots.toSet(), hasLength(2));
expect(trial.items.where((photo) => photo.category == PhotoCategory.target), hasLength(2));
```

Also assert the call throws a `StateError` with `need 2` when LRFFC array five has only one eligible target.

- [ ] **Step 2: Run the focused test and verify it fails under single-target composition**

Run: `flutter test test/engine/tap_mode_controller_test.dart`

- [ ] **Step 3: Implement `TapTrial` and preserve the one-target path**

```dart
if (targetCount == 1) {
  // existing target selection, nextTargetSlot, shuffleSlots and item mapping
  return TapTrial(/* existing Trial values */, targetSlots: [targetSlot]);
}
final targetPhotos = targets.take(targetCount).toList();
final targetSlots = _rotator.nextTargetSlots(/* ... */);
final itemOrder = _rotator.shuffleSlotsMulti(arraySize: position.arraySize, targetSlots: targetSlots);
```

Map target item indices to `targetPhotos`, other indices to selected distractors. Retain the category-based `judge` logic unchanged.

- [ ] **Step 4: Run the tap-controller tests**

Run: `flutter test test/engine/tap_mode_controller_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/engine/modes/tap/tap_mode_controller.dart test/engine/tap_mode_controller_test.dart && git commit -m "feat: compose multi-target tap trials"`

### Task 4: Render incremental two-target tap completion

**Files:**
- Modify: `lib/features/child_session/tap_mode_screen.dart`
- Modify: `test/features/child_session/tap_mode_screen_test.dart`

**Interfaces:**
- Changes: screen state stores `TapTrial? _trial` and `Set<int> _foundTargets`.
- Changes: `_AnswerRow` and `_AnswerItem` accept `found` and make found items inert.

- [ ] **Step 1: Write a failing widget test at LRFFC array five**

```dart
await tester.tap(_answerItemFor('target_item_0'));
await tester.pump();
expect(find.byType(PhotoImage), findsNWidgets(5));
expect(tester.widget<InkWell>(_answerItemFor('target_item_0')).onTap, isNull);

await tester.tap(_answerItemFor('distractor_item_0'));
await tester.pump();
expect(find.byType(PhotoImage), findsNWidgets(5));

await tester.tap(_answerItemFor('target_item_1'));
await tester.pump(const Duration(milliseconds: 600));
```

Seed LRFFC array five via `LadderPersistence`, provide two target and three distractor photos, and assert the trial only resolves after the second correct target.

- [ ] **Step 2: Run the widget test and verify it fails under the old unconditional-resolution flow**

Run: `flutter test test/features/child_session/tap_mode_screen_test.dart`

- [ ] **Step 3: Implement the multi-target branch**

```dart
if (trial.targetSlots.length <= 1) {
  // retain the current _handleTap logic byte-for-byte
  return;
}
// Flash and record this response. Add a correct slot to _foundTargets.
// Only run mastery/natural-pause/compose closure when all target slots are found.
```

Reset `_foundTargets` in `_composeTrial`; pass `found: _foundTargets.contains(slot)` while building answer items. A found item keeps a success ring and has `onTap: null`.

- [ ] **Step 4: Run the complete tap-screen test file**

Run: `flutter test test/features/child_session/tap_mode_screen_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/features/child_session/tap_mode_screen.dart test/features/child_session/tap_mode_screen_test.dart && git commit -m "feat: require both extended tap targets"`

### Task 5: Derive canonical picker steps and reset stale streaks

**Files:**
- Create: `lib/engine/dial_engine/ladder_steps.dart`
- Modify: `lib/engine/advancement/advancement_tracker.dart`
- Create: `test/engine/ladder_steps_test.dart`
- Modify: `test/engine/advancement_tracker_test.dart`

**Interfaces:**
- Produces: `List<LadderPosition> ladderStepsFor({required DialEngine dialEngine, required ModuleId module, required ResponseMode mode})`.
- Produces: `void AdvancementTracker.resetStreak({required String childId, required ModuleId module, required ResponseMode mode})`.

- [ ] **Step 1: Write failing walker and reset tests**

```dart
expect(ladderStepsFor(dialEngine: const TwoDialEngine(), module: ModuleId.makanan, mode: ResponseMode.tap).last,
    const LadderPosition(arraySize: 6, similarityTier: SimilarityTier.lrffc));
expect(ladderStepsFor(dialEngine: const TwoDialEngine(), module: ModuleId.makanan, mode: ResponseMode.speak).length,
    SimilarityTier.values.length);

tracker.resetStreak(childId: childId, module: module, mode: mode);
expect(tracker.streakFor(childId: childId, module: module, mode: mode), 0);
```

- [ ] **Step 2: Run focused tests and verify expected failures**

Run: `flutter test test/engine/ladder_steps_test.dart test/engine/advancement_tracker_test.dart`

- [ ] **Step 3: Implement the pure walker and reset**

```dart
final steps = <LadderPosition>[];
var current = const LadderPosition.start();
while (true) {
  steps.add(current);
  final next = dialEngine.advanceForMode(current, mode);
  if (next == current) return steps;
  current = next;
}
```

Keep the `module` argument in the public signature so callers always enumerate a concrete module × mode pair, even though current engine progression is module-independent. Implement reset with `_streaks.remove((childId, module, mode))`.

- [ ] **Step 4: Run the focused tests**

Run: `flutter test test/engine/ladder_steps_test.dart test/engine/advancement_tracker_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/engine/dial_engine/ladder_steps.dart lib/engine/advancement/advancement_tracker.dart test/engine/ladder_steps_test.dart test/engine/advancement_tracker_test.dart && git commit -m "feat: derive ladder steps and reset streaks"`

### Task 6: Add guardian level settings route, screen, and entry point

**Files:**
- Modify: `lib/core/routing/app_router.dart`
- Create: `lib/features/guardian/level_settings_screen.dart`
- Modify: `lib/features/guardian/guardian_home_placeholder.dart`
- Create: `test/features/guardian/level_settings_screen_test.dart`

**Interfaces:**
- Produces: `Routes.levelSettings` and `Routes.levelSettingsFor(String childId)`.
- Produces: `LevelSettingsScreen(childId: childId)`.

- [ ] **Step 1: Write a failing level-settings widget test**

```dart
await tester.tap(find.text('Tahap 2'));
await tester.tap(find.text('Terapkan'));
await tester.pumpAndSettle();

expect(await repo.getLadderPosition(childId: child.id, module: ModuleId.makanan, mode: ResponseMode.tap),
    const LadderPosition(arraySize: 3, similarityTier: SimilarityTier.differentCategory));
expect(tracker.streakFor(childId: child.id, module: ModuleId.makanan, mode: ResponseMode.tap), 0);
```

Create a child with tap enabled, pre-seed a nonzero tracker streak, and override the persistence and tracker providers in `ProviderScope` as in the child-settings tests.

- [ ] **Step 2: Run the focused widget test and verify the route/screen is absent**

Run: `flutter test test/features/guardian/level_settings_screen_test.dart`

- [ ] **Step 3: Implement routing and the screen**

```dart
static const levelSettings = '/guardian/:childId/level';
static String levelSettingsFor(String childId) => '/guardian/$childId/level';
```

Load the child, iterate every `ModuleId` and each mode in `child.availableModes`, load the current persisted position, and initialize each block's selected index from `ladderStepsFor`. Render `TkChoiceTile<int>` items labeled `Tahap ${index + 1}` with array/tier descriptions. On `Terapkan`, call `LadderPersistence.save` and then `AdvancementTracker.resetStreak`; refresh that block's current selection. Add a matching `TkCard` entry in the Persiapan zone that navigates to the route.

- [ ] **Step 4: Run guardian screen and relevant route/widget tests**

Run: `flutter test test/features/guardian/level_settings_screen_test.dart test/features/guardian/child_settings_screen_test.dart`

- [ ] **Step 5: Commit**

Run: `git add lib/core/routing/app_router.dart lib/features/guardian/level_settings_screen.dart lib/features/guardian/guardian_home_placeholder.dart test/features/guardian/level_settings_screen_test.dart && git commit -m "feat: add guardian level settings"`

### Task 7: Full integration verification

**Files:**
- Verify: all modified and new files from Tasks 1–6.

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib/core/constants/domain_enums.dart lib/engine/dial_engine/dial_engine.dart lib/engine/dial_engine/ladder_steps.dart lib/engine/rotation/position_rotator.dart lib/engine/modes/tap/tap_mode_controller.dart lib/engine/advancement/advancement_tracker.dart lib/features/child_session/tap_mode_screen.dart lib/features/guardian/level_settings_screen.dart lib/features/guardian/guardian_home_placeholder.dart lib/core/routing/app_router.dart test/engine/dial_engine_test.dart test/engine/advancement_tracker_test.dart test/engine/ladder_steps_test.dart test/engine/position_rotator_test.dart test/engine/tap_mode_controller_test.dart test/features/child_session/tap_mode_screen_test.dart test/features/guardian/level_settings_screen_test.dart`

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

- [ ] **Step 3: Run the full automated suite**

Run: `flutter test`

- [ ] **Step 4: Inspect the final diff and status**

Run: `git diff --check && git status --short`

- [ ] **Step 5: Commit any formatting-only changes, if present**

Run: `git add -u && git commit -m "style: format ladder and level settings changes"`
