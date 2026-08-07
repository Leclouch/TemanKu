/// Day-arc screen — **the real post-select-child entry point.**
///
/// Source-of-truth §9: select-child precedes session setup; this is that
/// setup, made concrete. It replaces `child_session_placeholder.dart` (now
/// deleted — its job was only ever to prove the fixed-layout/exit-dot/child-
/// theme scaffolding before tap/match/speak existed for real) as the
/// destination of [Routes.childSession].
///
/// Two module cards, kantin (Makanan) then rumah (Keluarga), in that fixed
/// order — no shuffling, no carousel, no swipe-to-reveal. Tapping a card
/// starts a session for that module in whichever [ResponseMode] the child
/// actually has: §8/§9 are explicit that intake selects *modes*, and mode
/// choice is never re-litigated as a child-facing decision downstream —
/// [_preferredModeFor] picks one deterministically (tap → match → speak
/// priority) rather than asking. A child excluded from a mode by intake can
/// never be routed into it; the module cards below only ever build a route
/// out of [Child.availableModes].
///
/// Text-only this pass, same as every other MVP surface (§4.3 narration is
/// designed but deferred) — see the TODO on [_ModuleCard] for the hook
/// point. No animation: static cards, no page transitions between them,
/// consistent with §12's no-ambient-motion rule on the child screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/widgets/exit_dot.dart';
import 'package:temanku/widgets/mascot.dart';

/// Priority when a child has more than one mode enabled — never a choice the
/// child makes. Tap first (simplest motor channel), then match, then speak;
/// see the doc comment above for why this exists at all instead of asking.
const _modePriority = [ResponseMode.tap, ResponseMode.match, ResponseMode.speak];

/// Null only when intake left every mode unchecked (`availableModes` empty —
/// a real, reachable state per `test/features/onboarding/intake_screen_test.dart`),
/// in which case there is nothing valid to route into at all.
ResponseMode? _preferredModeFor(Set<ResponseMode> availableModes) {
  for (final mode in _modePriority) {
    if (availableModes.contains(mode)) return mode;
  }
  return null;
}

class _DayArcModule {
  const _DayArcModule({required this.definition, required this.framingText, required this.icon});

  final ModuleDefinition definition;
  final String framingText;
  final IconData icon;
}

/// Fixed order: kantin (Makanan) then rumah (Keluarga) — the task brief's
/// explicit sequence, not alphabetical or config-driven.
const _dayArcModules = [
  _DayArcModule(
    definition: makananModule,
    framingText: 'Yuk lihat jajanan di kantin',
    icon: Icons.restaurant_outlined,
  ),
  _DayArcModule(
    definition: keluargaModule,
    framingText: 'Sekarang waktunya sama keluarga',
    icon: Icons.family_restroom_outlined,
  ),
];

String _routeFor(String childId, ModuleId module, ResponseMode mode) => switch (mode) {
      ResponseMode.tap => Routes.tapSessionFor(childId, module),
      ResponseMode.match => Routes.matchSessionFor(childId, module),
      ResponseMode.speak => Routes.speakSessionFor(childId, module),
    };

class DayArcScreen extends ConsumerStatefulWidget {
  const DayArcScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<DayArcScreen> createState() => _DayArcScreenState();
}

class _DayArcScreenState extends ConsumerState<DayArcScreen> {
  // Loaded once in initState rather than inline in a FutureBuilder — the
  // same shape tap/match/speak mode screens already use for their own
  // bootstrap. A Future built fresh on every build() re-arms a FutureBuilder
  // to "waiting" on every rebuild instead of ever settling.
  Child? _child;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final child = await ref.read(childRepositoryProvider).getChild(widget.childId);
    if (!mounted) return;
    setState(() {
      _child = child;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Child surface runs a different theme temperature, applied locally —
    // same rule as tap/match/speak mode screens, all sourced from core/theme/.
    return Theme(
      data: TemanKuTheme.child,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(child: _buildBody(context)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ExitDot(onExit: () => context.pop()),
                  ),
                  // Purely decorative corner element — day-arc only (see
                  // widgets/mascot.dart's own doc comment for why tap/match/
                  // speak never get this). Bottom-left, opposite the exit
                  // dot, small enough to never compete with the cards above it.
                  const Positioned(
                    left: 8,
                    bottom: 8,
                    child: Mascot(size: 88),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_loading) return const CircularProgressIndicator();

    final child = _child;
    if (child == null) {
      // Setup gap (bad/stale childId), not a child-facing failure state —
      // same neutral-copy treatment tap/match/speak give a missing-photos
      // setup gap.
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Profil anak tidak ditemukan.',
          textAlign: TextAlign.center,
          style: context.type.body.copyWith(color: colors.text),
        ),
      );
    }

    final preferredMode = _preferredModeFor(child.availableModes);

    return ConstrainedBox(
      // Bounded, not fixed — phone-first, tablet free (§11), same rule as
      // every other child session screen.
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hari Ini Bersama ${child.name}',
              textAlign: TextAlign.center,
              style: context.type.display.copyWith(color: colors.text),
            ),
            const SizedBox(height: 32),
            for (final module in _dayArcModules) ...[
              _ModuleCard(
                module: module,
                onTap: preferredMode == null
                    ? null
                    : () => context.push(
                          _routeFor(widget.childId, module.definition.id, preferredMode),
                        ),
              ),
              const SizedBox(height: 20),
            ],
            if (preferredMode == null)
              Text(
                'Belum ada mode yang aktif untuk anak ini. Minta wali mengisi intake dulu.',
                textAlign: TextAlign.center,
                style: context.type.body.copyWith(color: colors.neutralFeedback),
              ),
          ],
        ),
      ),
    );
  }
}

/// One module doorway. [onTap] is null exactly when [_preferredModeFor] found
/// no enabled mode at all — the card renders dimmed and inert rather than
/// disappearing, so "nothing is active yet" reads as a calm, visible state
/// rather than an unexplained missing card.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final _DayArcModule module;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimmed = onTap == null;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget * 1.5),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.neutralFeedback, width: 2),
            ),
            child: Row(
              children: [
                Icon(module.icon, size: 32, color: colors.primaryAccent),
                const SizedBox(width: 16),
                Expanded(
                  // TODO: add recorded Bahasa Indonesia narration per
                  // source-of-truth §4.3 — this is the hook point (play on
                  // card appearance/tap). Text-only for MVP.
                  child: Text(
                    module.framingText,
                    style: context.type.body.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
