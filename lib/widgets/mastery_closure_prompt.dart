/// Mastery-at-ceiling closure prompt — shared across tap/match/speak mode
/// screens (§4.5's top-of-ladder case).
///
/// Fires only when [AdvancementTracker.recordResponse]'s `masteredAtCeiling`
/// comes back true — the streak criterion cleared *while already* at the
/// dial engine's ceiling, never merely for reaching it (see that field's own
/// doc comment). Same calm, no-fanfare register as the rest of the child
/// surface: no level/tier number, no score, no "level complete" language —
/// this reads as a natural pause offered to the guardian, not an achievement
/// screen, and the guardian decides what happens next, not this dialog.
///
/// Not a new screen: a modal on top of whichever mode screen triggered it,
/// dismissed only by one of the two choices below — [barrierDismissible] is
/// false and both buttons carry identical [OutlinedButton] weight, so
/// neither "Lanjutkan" nor "Selesai" reads as the suggested default.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';

/// Shows the prompt and resolves to `true` for "Lanjutkan" (keep playing at
/// the ceiling tier) or `false` for "Selesai" (end the session now — the
/// caller pops the route exactly like a guardian-initiated exit). A dialog
/// dismissed some other way than the two buttons (e.g. the OS back gesture)
/// resolves to `true`: an ambiguous dismissal must never silently end the
/// session on the guardian's behalf.
///
/// Plays [SoundService.playSessionComplete] once, right as the prompt opens
/// — wired here rather than in each of the three mode screens so the sound
/// stays tied to the prompt itself, regardless of which button the guardian
/// ends up choosing.
Future<bool> showMasteryClosurePrompt(BuildContext context, WidgetRef ref) async {
  unawaited(ref.read(soundServiceProvider).playSessionComplete());
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        backgroundColor: colors.background,
        title: Text(
          'Titik berhenti alami',
          style: dialogContext.type.display.copyWith(color: colors.text, fontSize: 20),
        ),
        content: Text(
          'Anak sudah menjawab dengan lancar di titik ini. Lanjutkan '
          'berlatih, atau akhiri sesi sekarang — pilihan wali.',
          style: dialogContext.type.body.copyWith(color: colors.text),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjutkan'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Selesai'),
          ),
        ],
      );
    },
  );
  return result ?? true;
}
