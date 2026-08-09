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
/// [preferredModeFor] picks one deterministically (tap → match → speak
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
import 'dart:developer' as developer;

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

/// A module with nothing behind it yet — no [ModuleDefinition], no photo
/// pipeline, no ladder. Deliberately a separate, lighter type from
/// [_DayArcModule] rather than a fake/stub [ModuleDefinition]: constructing
/// one of those would imply this module has a real `targetStyle`, similarity
/// tiers, and so on, none of which exist. Same four modules and copy as
/// `guardian_home_placeholder.dart`'s `_ModuleListCard` — see that file for
/// why these four specifically are the declared future scope.
class _PlannedModule {
  const _PlannedModule({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const _plannedDayArcModules = [
  _PlannedModule(icon: LucideIcons.coins, label: 'Uang'),
  _PlannedModule(icon: LucideIcons.trash2, label: 'Sampah'),
  _PlannedModule(icon: LucideIcons.shieldAlert, label: 'Pengenalan Keamanan'),
  _PlannedModule(icon: LucideIcons.userCheck, label: 'Pengenalan Orang Terpercaya'),
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
  /// whichever mode `activeModeFor` would actually route into (the
  /// guardian's override if one is set and still valid, `preferredModeFor`'s
  /// priority order otherwise). Not a per-module story yet; one flavor line
  /// per visit is enough for a first pass, and this picks the same module the
  /// child sees first regardless.
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
    if (!child.storytellerEnabled) {
      developer.log('story beat skipped: storytellerEnabled is false', name: 'DayArcScreen');
      return;
    }

    final mode = activeModeFor(child, makananModule.id);
    if (mode == null) {
      developer.log('story beat skipped: no available mode', name: 'DayArcScreen');
      return;
    }

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
    developer.log('story beat resolved: ${beat ?? "null"}', name: 'DayArcScreen');
    if (!mounted || beat == null) return;
    setState(() => _storyBeat = beat);
  }

  @override
  Widget build(BuildContext context) {
    return TkChildScreen(
      onExit: () => context.pop(),
      // Bottom-left, opposite the exit dot, small enough to never compete
      // with the cards above it. Greeting pose: this is the one moment the
      // child sees "welcome back", before either module opens — tap/match/
      // speak (`widgets/mascot.dart`) start their own mascot in the resting
      // `standing` pose instead, since there's no arrival beat mid-trial.
      corner: const Mascot(size: 148, pose: MascotPose.greeting),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Quiet background texture, not foreground content — a `Stack` with
        // no explicit size takes its size from the tallest non-positioned
        // child (the `Column` below), so these `Positioned` shapes never
        // grow the layout or push anything. Six shapes, one per corner plus
        // two edge accents, all washed to low opacity:
        // `instruksi-decor-icon-mascot.md`'s "calm, editorial" brief applies
        // to every surface except the mascot itself, so decor stays
        // texture, never the thing competing for attention — but texture
        // reads as texture only when it's spread around the frame, not
        // huddled in one corner. Every shape bleeds off its edge via a
        // negative offset (the same technique the original two used) so
        // nothing sits squarely inside the card's own reading area.
        Positioned(
          top: -28,
          right: -36,
          child: IgnorePointer(
            child: SizedBox(
              width: 168,
              height: 168,
              child: TkDecor(
                shape: TkDecorShape.blob,
                asset: TkDecorAsset.decor1,
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
              child: TkDecor(
                shape: TkDecorShape.ring,
                asset: TkDecorAsset.decor2,
                color: colors.successWash,
                opacity: 0.8,
              ),
            ),
          ),
        ),
        Positioned(
          top: -22,
          left: -26,
          child: IgnorePointer(
            child: SizedBox(
              width: 88,
              height: 88,
              child: TkDecor(
                shape: TkDecorShape.star,
                asset: TkDecorAsset.decor4,
                color: colors.info.withValues(alpha: 0.16),
                rotation: -0.2,
                opacity: 0.6,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -20,
          right: -18,
          child: IgnorePointer(
            child: SizedBox(
              width: 110,
              height: 110,
              child: TkDecor(
                shape: TkDecorShape.cloud,
                asset: TkDecorAsset.decor3,
                color: colors.neutralWash,
                opacity: 0.6,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -14,
          left: -22,
          child: IgnorePointer(
            child: SizedBox(
              width: 64,
              height: 64,
              child: TkDecor(
                shape: TkDecorShape.arch,
                asset: TkDecorAsset.decor5,
                color: colors.primaryAccentWash,
                rotation: 0.15,
                opacity: 0.45,
              ),
            ),
          ),
        ),
        Positioned(
          top: 220,
          right: -14,
          child: IgnorePointer(
            child: SizedBox(
              width: 48,
              height: 48,
              child: TkDecor(
                shape: TkDecorShape.ring,
                asset: TkDecorAsset.decor6,
                color: colors.successWash,
                opacity: 0.5,
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed — never inside the scrollable region below, so "Hari Ini
            // Bersama <name>" stays put at this screen's usual middle-upper
            // spot (`TkChildScreen`'s own `Align(0, -0.12)`) regardless of
            // how many module cards are beneath it.
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
            // Only this part scrolls. Capped at a fraction of the screen
            // rather than left to grow with the child count — six cards no
            // longer fit the fixed frame two used to (see this file's git
            // history), but the fix is scoped to the list itself, not the
            // whole screen: the heading above stays exactly where it always
            // was, never sliding toward the top edge as more cards are added.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Computed per module, not once for the whole screen —
                    // a guardian override (`Child.activeModeByModule`) is
                    // per-module, so kantin and rumah can now resolve to
                    // different modes. See `activeModeFor`'s own doc
                    // comment. `activeModeFor` is a cheap pair of map/set
                    // lookups, so calling it twice below (the null check,
                    // then the route) is simpler than threading a local
                    // through an extra widget just for variable scope.
                    for (final module in _dayArcModules) ...[
                      _ModuleCard(
                        module: module,
                        onTap: activeModeFor(child, module.definition.id) == null
                            ? null
                            : () => context.push(
                                  _routeFor(
                                    widget.childId,
                                    module.definition.id,
                                    activeModeFor(child, module.definition.id)!,
                                  ),
                                ),
                      ),
                      const SizedBox(height: TkSpace.sm),
                    ],
                    // Unchanged in meaning from before this was computed
                    // per-module: this was only ever true when
                    // `availableModes` was entirely empty in the first
                    // place, since any non-empty set gives every module's
                    // `activeModeFor` something to fall back to.
                    if (child.availableModes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: TkSpace.xs),
                        child: Text(
                          'Belum ada mode yang aktif untuk anak ini. Minta wali mengisi intake dulu.',
                          textAlign: TextAlign.center,
                          style: context.type.body.copyWith(color: colors.textMuted),
                        ),
                      ),
                    // Four future-scope modules, shown here (not just on the
                    // guardian side) so the full intended scope is visible in
                    // the actual product screen — deliberately requested
                    // despite this being the one child-facing surface the
                    // design otherwise keeps at zero clutter.
                    // `_PlaceholderModuleCard` never takes [onTap] at all
                    // (not even a snackbar, unlike its guardian-home
                    // counterpart in `guardian_home_placeholder.dart`'s
                    // `_PlaceholderModuleTile`) — on a screen a nonverbal
                    // child uses unsupervised, a tap that produces a message
                    // is still a tap that produced *something*, which is its
                    // own small promise this card must not make. Same 0.5
                    // dimmed-and-inert opacity `_ModuleCard` already uses for
                    // "no mode enabled" above, so a child who has learned
                    // "faded = not a real door" from that case reads these
                    // the same way.
                    const SizedBox(height: TkSpace.sm),
                    for (final module in _plannedDayArcModules) ...[
                      _PlaceholderModuleCard(module: module),
                      const SizedBox(height: TkSpace.sm),
                    ],
                  ],
                ),
              ),
            ),
            if (_storyBeat != null) ...[
              const SizedBox(height: TkSpace.lg),
              // The mascot's line — a speech-bubble plate rather than bare
              // text, so it reads as the character talking, not as another
              // status line. Never blocks layout while it loads: this whole
              // block simply doesn't exist until `_storyBeat` resolves (see
              // `_loadStoryBeat`'s own doc comment on why it's fetched after,
              // not before, the screen is already usable). Kept fixed, below
              // the scroll box rather than inside it — the mascot's line is
              // its own thing, not one more item in the module list.
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

/// One module doorway. [onTap] is null exactly when [preferredModeFor] found
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

/// A future-scope module's card — same size/shape as [_ModuleCard] so it
/// reads as one consistent row of doorways, but neutral-grey rather than
/// module-tinted (it isn't a module yet, so it gets no module colour) and
/// with no [InkWell]/`onTap` at all, unlike [_ModuleCard]'s `dimmed` state,
/// which is still tappable in principle (`onTap` is only null while intake
/// is incomplete). This card is never tappable, on purpose — see the call
/// site's own comment for why even a snackbar-on-tap is more promise than
/// this surface should make.
class _PlaceholderModuleCard extends StatelessWidget {
  const _PlaceholderModuleCard({required this.module});

  final _PlannedModule module;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: 0.5,
      child: Container(
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
              Container(
                width: 84,
                color: colors.neutralWash,
                alignment: Alignment.center,
                child: Icon(module.icon, size: 34, color: colors.textMuted),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(TkSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        module.label,
                        style: context.type.titleLg.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: TkSpace.xxs),
                      Text(
                        'Belum tersedia',
                        style: context.type.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
