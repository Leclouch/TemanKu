/// Closure prompts — shared across tap/match/speak mode screens. Two
/// distinct triggers, same dialog shape, same calm no-fanfare register as
/// the rest of the child surface: no level/tier number, no score, no "level
/// complete" language — either one reads as a natural pause offered to the
/// guardian, not an achievement screen, and the guardian decides what
/// happens next, not this dialog.
///
/// Not a new screen: a modal on top of whichever mode screen triggered it,
/// dismissed only by one of the two choices — [barrierDismissible] is false
/// and both buttons carry identical secondary weight, so neither "Lanjutkan"
/// nor "Selesai" reads as the suggested default.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';

/// How many trials pass between offers of [showNaturalPausePrompt] — a UI
/// checkpoint cadence, **not** a difficulty-calibration number. Unlike
/// `requiredStreakForAdvancement` (`engine/advancement/advancement_tracker.dart`),
/// which is explicitly flagged pending SLB teacher/therapist input, this
/// constant doesn't touch the dial engine or the advancement pace at all: it
/// only decides how often the guardian gets asked whether to stop. Free to
/// retune without that calibration concern.
const int naturalPauseTrialInterval = 8;

/// Shows the mastery-at-ceiling prompt and resolves to `true` for
/// "Lanjutkan" (keep playing at the ceiling tier) or `false` for "Selesai"
/// (end the session now — the caller pops the route exactly like a
/// guardian-initiated exit). A dialog dismissed some other way than the two
/// buttons (e.g. the OS back gesture) resolves to `true`: an ambiguous
/// dismissal must never silently end the session on the guardian's behalf.
///
/// Fires only when [AdvancementTracker.recordResponse]'s `masteredAtCeiling`
/// comes back true — the streak criterion cleared *while already* at the
/// dial engine's ceiling, never merely for reaching it (see that field's own
/// doc comment). See [showNaturalPausePrompt] for the periodic sibling that
/// doesn't require reaching the ceiling at all.
Future<bool> showMasteryClosurePrompt(BuildContext context, WidgetRef ref) => _showClosurePrompt(
      context,
      ref,
      body: 'Anak sudah menjawab dengan lancar di titik ini. Lanjutkan '
          'berlatih, atau akhiri sesi sekarang — pilihan wali.',
    );

/// The periodic sibling of [showMasteryClosurePrompt] — offered every
/// [naturalPauseTrialInterval] trials regardless of how the child is doing,
/// so a session that never reaches the dial engine's ceiling (a real
/// possibility if the ramp is steep for a given child) still gets a
/// guardian-facing "stop here?" checkpoint on its own, rather than the only
/// way out being the quiet exit dot — which records
/// [SessionOutcome.endedEarly] instead of [SessionOutcome.completed]. Same
/// resolve contract as [showMasteryClosurePrompt]: `true` keeps playing,
/// `false` (or the fallback on an ambiguous dismissal is still `true`, never
/// a silent end) stops.
Future<bool> showNaturalPausePrompt(BuildContext context, WidgetRef ref) => _showClosurePrompt(
      context,
      ref,
      body: 'Sudah beberapa babak dimainkan. Lanjutkan bermain, atau akhiri '
          'sesi sekarang — pilihan wali.',
    );

/// Plays [SoundService.playSessionComplete] once, right as the prompt opens
/// — wired here rather than in each of the three mode screens so the sound
/// stays tied to the prompt itself, regardless of which trigger fired it or
/// which button the guardian ends up choosing.
Future<bool> _showClosurePrompt(
  BuildContext context,
  WidgetRef ref, {
  required String body,
}) async {
  unawaited(ref.read(soundServiceProvider).playSessionComplete());
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      // Colours, radius, and both text styles come from `dialogTheme` in
      // core/design/theme.dart — nothing is set locally here, which is what
      // keeps this dialog looking like the rest of the app for free.
      return AlertDialog(
        title: const Text('Titik berhenti alami'),
        content: Text(body),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        // Both actions are TkButtonVariant.secondary, so neither reads as
        // the suggested default — see this function's own doc comment.
        actions: [
          TkButton.secondary(
            label: 'Lanjutkan',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          TkButton.secondary(
            label: 'Selesai',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      );
    },
  );
  return result ?? true;
}
