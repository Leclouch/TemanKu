# Task 3 — Compose and judge two-target tap trials

## Delivered

- Added `TapTrial extends Trial` with `targetSlots`.
- Made `TapModeController.nextTrial` return `Future<TapTrial>`.
- Used `DialEngine.targetCountFor` to preserve the existing one-target path and
  compose two-target trials only when requested.
- Two-target trials select two eligible target photos, use
  `nextTargetSlots`/`shuffleSlotsMulti`, and keep item indices 0 and 1 mapped
  to those target photos.
- Insufficient eligible targets now throw `StateError` with the clear message
  `Two target photos are needed to compose a tap trial.`
- `judge` remains category-based, so either target-category item is correct.

## TDD evidence

1. Added focused extended-LRFFC composition and insufficient-target tests.
2. Red run: `flutter test test/engine/tap_mode_controller_test.dart` failed as
   expected: the prior single-target layout indexed beyond the three
   distractors and did not reject one eligible target.
3. Implemented the minimal two-target branch and reran the focused suite green.

## Final verification

- `flutter analyze lib/engine/modes/tap/tap_mode_controller.dart test/engine/tap_mode_controller_test.dart`
  — no issues found.
- `flutter test test/engine/tap_mode_controller_test.dart`
  — 16 tests passed.

## Scope and concerns

Only the tap controller, its focused tests, and this report changed. Flutter
reported 22 outdated transitive packages during verification; this task made no
dependency changes.
