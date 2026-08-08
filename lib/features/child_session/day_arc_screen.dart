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
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/story/storyteller_service.dart';
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

  /// Lucide — the one icon family the redesign settled on
  /// (`referenceimages/instruksi-decor-icon-mascot.md`; Phosphor was tried
  /// first but doesn't compile on this SDK, see the `pubspec.yaml` note on
  /// the `lucide_icons_flutter` entry). Consistent stroke weight, replacing
  /// Material's `_outlined` default that was never chosen on purpose.
  final IconData icon;
}

/// Fixed order: kantin (Makanan) then rumah (Keluarga) — the task brief's
/// explicit sequence, not alphabetical or config-driven.
const _dayArcModules = [
  _DayArcModule(
    definition: makananModule,
    framingText: 'Yuk lihat jajanan di kantin',
    icon: LucideIcons.utensils,
  ),
  _DayArcModule(
    definition: keluargaModule,
    framingText: 'Sekarang waktunya sama keluarga',
    icon: LucideIcons.house,
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

  /// The mascot's story-beat line (`lib/story/`) — null until (if ever) it
  /// resolves. Fetched *after* the screen is already usable and never
  /// awaited before that, same "advisory, never blocks the real UI" shape
  /// `speech/pronunciation_hint_service.dart` uses for speak mode's hint:
  /// this is flavor text, and flavor text arriving 400ms late is fine,
  /// flavor text delaying the child's actual doorway is not.
  String? _storyBeat;

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
    if (child != null) unawaited(_loadStoryBeat(child));
  }

  /// Always keyed to Makanan/kantin — the module `_dayArcModules` always
  /// leads with (§ that list's own doc comment on the fixed order) — and to
  /// whichever mode `_preferredModeFor` would actually route into. Not a
  /// per-module story yet; one flavor line per visit is enough for a first
  /// pass, and this picks the same module the child sees first regardless.
  Future<void> _loadStoryBeat(Child child) async {
    // Checked here, not just inside which [StorytellerService] gets bound —
    // `NoStorytellerService` itself always returns a beat (that's the whole
    // point of it being a real fallback, not a stub), so if this screen
    // called `nextBeat` unconditionally, turning the guardian's "Cerita
    // maskot" toggle *off* would do nothing until an API key also existed.
    // Same "not sending it at all is the stronger guarantee" reasoning
    // `pronunciation_hint_service.dart` states for its own off switch: the
    // predictable off state is "this screen never asks", not "it asks and
    // happens to get free flavor text back".
    if (!child.storytellerEnabled) return;

    final mode = _preferredModeFor(child.availableModes);
    if (mode == null) return;

    final position = await ref.read(ladderPersistenceProvider).load(
          childId: child.id,
          module: makananModule.id,
          mode: mode,
        );
    final mastered = ref.read(dialEngineProvider).isAtCeiling(position, mode);
    final tierCopy = makananModule.similarityTierCopy[position.similarityTier] ?? '';

    final storyContext = StoryContext(
      childName: child.name,
      module: makananModule,
      tierCopy: tierCopy,
      mastered: mastered,
    );
    final beat = await ref
        .read(storytellerServiceProvider(child.storytellerEnabled))
        .nextBeat(storyContext);
    if (!mounted || beat == null) return;
    setState(() => _storyBeat = beat);
  }

  @override
  Widget build(BuildContext context) {
    return TkChildScreen(
      onExit: () => context.pop(),
      // Purely decorative corner element — day-arc only (see
      // widgets/mascot.dart's own doc comment for why tap/match/speak never
      // get this). Bottom-left, opposite the exit dot, small enough to never
      // compete with the cards above it. Greeting pose: this is the one
      // moment day-arc plays "welcome back", before either module opens.
      corner: const Mascot(size: 104, pose: MascotPose.greeting),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.colors;

    if (_loading) return const TkLoading();

    final child = _child;
    if (child == null) {
      // Setup gap (bad/stale childId), not a child-facing failure state —
      // same neutral-copy treatment tap/match/speak give a missing-photos
      // setup gap.
      return const TkChildNotice(message: 'Profil anak tidak ditemukan.');
    }

    final preferredMode = _preferredModeFor(child.availableModes);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Quiet background texture, not foreground content — a `Stack` with
        // no explicit size takes its size from the tallest non-positioned
        // child (the `Column` below), so these `Positioned` shapes never
        // grow the layout or push anything. Two shapes only, both washed to
        // low opacity: `instruksi-decor-icon-mascot.md`'s "calm, editorial"
        // brief applies to every surface except the mascot itself, so decor
        // stays texture, never the thing competing for attention.
        Positioned(
          top: -28,
          right: -36,
          child: IgnorePointer(
            child: SizedBox(
              width: 168,
              height: 168,
              child: TkDecor(
                shape: TkDecorShape.blob,
                color: colors.primaryAccentWash,
                rotation: 0.4,
                opacity: 0.7,
              ),
            ),
          ),
        ),
        Positioned(
          top: 64,
          left: -18,
          child: IgnorePointer(
            child: SizedBox(
              width: 56,
              height: 56,
              child: TkDecor(shape: TkDecorShape.ring, color: colors.successWash, opacity: 0.8),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hari Ini Bersama',
              textAlign: TextAlign.center,
              style: context.type.displayLg.copyWith(color: colors.text),
            ),
            // A plain `Text`, not a second `TextSpan` on the line above — kept
            // as its own widget so the child's name stays a literal, findable
            // string (existing behaviour contract: `find.textContaining` in
            // `day_arc_screen_test.dart`), and so it can carry the accent
            // colour independently of the neutral-ink line above it.
            Text(
              child.name,
              textAlign: TextAlign.center,
              style: context.type.displayLg.copyWith(color: colors.primaryAccent),
            ),
            const SizedBox(height: TkSpace.xxl),
            for (final module in _dayArcModules) ...[
              _ModuleCard(
                module: module,
                onTap: preferredMode == null
                    ? null
                    : () => context.push(
                          _routeFor(widget.childId, module.definition.id, preferredMode),
                        ),
              ),
              const SizedBox(height: TkSpace.sm),
            ],
            if (preferredMode == null)
              Padding(
                padding: const EdgeInsets.only(top: TkSpace.xs),
                child: Text(
                  'Belum ada mode yang aktif untuk anak ini. Minta wali mengisi intake dulu.',
                  textAlign: TextAlign.center,
                  style: context.type.body.copyWith(color: colors.textMuted),
                ),
              ),
            if (_storyBeat != null) ...[
              const SizedBox(height: TkSpace.lg),
              // The mascot's line — a speech-bubble plate rather than bare
              // text, so it reads as the character talking, not as another
              // status line. Never blocks layout while it loads: this whole
              // block simply doesn't exist until `_storyBeat` resolves (see
              // `_loadStoryBeat`'s own doc comment on why it's fetched after,
              // not before, the screen is already usable).
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TkSpace.md,
                  vertical: TkSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceTinted,
                  borderRadius: TkRadius.lg,
                ),
                child: Text(
                  _storyBeat!,
                  textAlign: TextAlign.center,
                  style: context.type.bodySm.copyWith(
                    color: colors.text,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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

    // The module's own colour+shape identity (`content/module_definition.dart`
    // → `targetStyle`) — Makanan's green, Keluarga's blue — carried onto its
    // doorway card instead of both cards sharing one generic accent wash.
    // Same "each category gets a consistent colour" rule `answer_target.dart`
    // already enforces for the in-session answer zones; this just extends it
    // one screen earlier, so a child who has done a session before already
    // half-recognises which door is which before reading the label. Alpha is
    // derived from the token, not a new literal — same pattern
    // `answer_target.dart` uses for its own outline.
    final moduleColor = module.definition.targetStyle.color;
    final onModuleColor = tkInkOn(moduleColor);

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: TkRadius.lg,
        child: InkWell(
          onTap: onTap,
          child: Container(
            // The child-scale target, not the 44pt guardian floor — this is
            // the doorway a child taps, under less motor control than the
            // guardian's corner cluster assumes.
            constraints: const BoxConstraints(
              minHeight: TemanKuMetrics.childTouchTarget * 1.4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: TkRadius.lg,
              border: Border.all(color: colors.borderStrong, width: TkStroke.regular),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A full-bleed colour panel rather than a small icon square
                  // — this is the one deliberate departure from the rest of
                  // the app's card vocabulary, borrowed straight from the
                  // Maxima reference's colour-blocked panels
                  // (`referenceimages/maxima34.png` and neighbours).
                  Container(
                    width: 84,
                    color: moduleColor,
                    alignment: Alignment.center,
                    child: Icon(module.icon, size: 34, color: onModuleColor),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(TkSpace.lg),
                      child: Row(
                        children: [
                          // TODO: add recorded Bahasa Indonesia narration per
                          // source-of-truth §4.3 — this is the hook point (play on
                          // card appearance/tap). Text-only for MVP.
                          Expanded(
                            child: Text(
                              module.framingText,
                              style: context.type.titleLg.copyWith(color: colors.text),
                            ),
                          ),
                          const SizedBox(width: TkSpace.sm),
                          // A round "open" affordance, module-tinted — the
                          // same circular-arrow chip Maxima's own carousel
                          // controls use, repurposed here as a static "this
                          // is a door" cue rather than a real control (the
                          // whole card is already the tap target).
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: moduleColor.withValues(alpha: 0.14),
                            ),
                            child: Icon(LucideIcons.arrowRight, size: 18, color: moduleColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
