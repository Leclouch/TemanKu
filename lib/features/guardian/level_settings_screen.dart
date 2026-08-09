/// Guardian controls for selecting an engine-reachable starting point, and
/// for choosing which response mode is active per module.
///
/// The screen deliberately derives every level option from [DialEngine]
/// rather than owning a second, hand-maintained level table. A manual level
/// override writes the selected position first, then clears only the
/// matching advancement streak so progress from the old position cannot
/// advance the new one.
///
/// Mode selection (`Child.activeModeByModule`) lives on this same screen
/// rather than a separate one — both controls are "guardian decides what a
/// child's session looks like" for the same (module, mode) axis, and mode
/// selection is what makes the level picker below meaningful for match/speak
/// at all: `features/child_session/day_arc_screen.dart`'s module cards
/// otherwise always default to tap (see `activeModeFor` in
/// `data/models/child.dart` for why and how). Unlike the level override,
/// picking a mode applies immediately — there's no streak to invalidate and
/// nothing leaves the device, so it doesn't need the "Terapkan" gate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/engine/dial_engine/ladder_steps.dart';

class LevelSettingsScreen extends ConsumerStatefulWidget {
  const LevelSettingsScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<LevelSettingsScreen> createState() =>
      _LevelSettingsScreenState();
}

class _LevelSettingsScreenState extends ConsumerState<LevelSettingsScreen> {
  Child? _child;
  List<_LevelBlock> _blocks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final child =
        await ref.read(childRepositoryProvider).getChild(widget.childId);
    if (child == null) return;

    final dialEngine = ref.read(dialEngineProvider);
    final persistence = ref.read(ladderPersistenceProvider);
    final blocks = <_LevelBlock>[];
    for (final module in ModuleId.values) {
      for (final mode in child.availableModes) {
        final steps = ladderStepsFor(
          dialEngine: dialEngine,
          module: module,
          mode: mode,
        );
        final current = await persistence.load(
          childId: child.id,
          module: module,
          mode: mode,
        );
        blocks.add(
          _LevelBlock(
            module: module,
            mode: mode,
            steps: steps,
            current: current,
            selectedIndex: steps.indexOf(current),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _child = child;
      _blocks = blocks;
    });
  }

  /// Applies immediately, unlike [_apply] — see the library doc comment for
  /// why this control doesn't need the same "Terapkan" friction.
  Future<void> _selectActiveMode(ModuleId module, ResponseMode mode) async {
    final child = _child;
    if (child == null) return;
    final updated = child.copyWith(
      activeModeByModule: {...child.activeModeByModule, module: mode},
    );
    await ref.read(childRepositoryProvider).updateChild(updated);
    if (!mounted) return;
    setState(() => _child = updated);
  }

  void _selectStep(int blockIndex, int selectedIndex) {
    setState(() {
      _blocks = [
        for (var index = 0; index < _blocks.length; index++)
          if (index == blockIndex)
            _blocks[index].copyWith(selectedIndex: selectedIndex)
          else
            _blocks[index],
      ];
    });
  }

  Future<void> _apply(int blockIndex) async {
    final block = _blocks[blockIndex];
    final selected = block.steps[block.selectedIndex];
    setState(
        () => _blocks = _replaceBlock(blockIndex, block.copyWith(busy: true)));

    await ref.read(ladderPersistenceProvider).save(
          childId: widget.childId,
          module: block.module,
          mode: block.mode,
          position: selected,
        );
    ref.read(advancementTrackerProvider).resetStreak(
          childId: widget.childId,
          module: block.module,
          mode: block.mode,
        );
    if (!mounted) return;
    setState(() {
      _blocks = _replaceBlock(
        blockIndex,
        block.copyWith(current: selected, busy: false),
      );
    });
  }

  List<_LevelBlock> _replaceBlock(int blockIndex, _LevelBlock block) => [
        for (var index = 0; index < _blocks.length; index++)
          if (index == blockIndex) block else _blocks[index],
      ];

  @override
  Widget build(BuildContext context) {
    final child = _child;
    return TkScreen(
      title: 'Atur tahap latihan',
      decor: const TkScreenDecor(),
      child: child == null
          ? const TkLoading(label: 'Memuat tahap latihan…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pilih tahap untuk setiap modul dan cara menjawab yang tersedia bagi ${child.name}.',
                  style: context.type.body.copyWith(color: context.colors.text),
                ),
                const SizedBox(height: TkSpace.md),
                for (final module in ModuleId.values)
                  _ModuleLevelDropdown(
                    module: module,
                    blocks: [
                      for (var index = 0; index < _blocks.length; index++)
                        if (_blocks[index].module == module)
                          (index: index, block: _blocks[index]),
                    ],
                    activeMode: activeModeFor(child, module),
                    onModeSelected: (mode) => _selectActiveMode(module, mode),
                    onSelected: _selectStep,
                    onApply: _apply,
                  ),
              ],
            ),
    );
  }
}

class _LevelBlockCard extends StatelessWidget {
  const _LevelBlockCard({
    required this.block,
    required this.onSelected,
    required this.onApply,
  });

  final _LevelBlock block;
  final ValueChanged<int> onSelected;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final definition = _definitionFor(block.module);
    return TkCard(
      title: '${definition.displayName} · ${_modeLabel(block.mode)}',
      subtitle:
          'Saat ini: ${_stepLabel(block.current, block.steps, block.mode)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < block.steps.length; index++)
            TkChoiceTile<int>(
              label: 'Tahap ${index + 1}',
              description: _positionDescription(
                  definition, block.steps[index], block.mode),
              value: index,
              groupValue: block.selectedIndex,
              onSelected: block.busy ? (_) {} : onSelected,
            ),
          const SizedBox(height: TkSpace.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TkButton.secondary(
              label: 'Terapkan',
              onPressed: block.busy ? null : onApply,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleLevelDropdown extends StatelessWidget {
  const _ModuleLevelDropdown({
    required this.module,
    required this.blocks,
    required this.activeMode,
    required this.onModeSelected,
    required this.onSelected,
    required this.onApply,
  });

  final ModuleId module;
  final List<({int index, _LevelBlock block})> blocks;

  /// [activeModeFor]'s current resolution for this module — the guardian's
  /// override if one is set and still valid, the tap→match→speak priority
  /// fallback otherwise. Only null when [Child.availableModes] is entirely
  /// empty, which also means [blocks] is empty and `build` returns before
  /// this is ever read — nullable purely so the caller (which computes this
  /// once per module, before knowing whether that module's [blocks] will be
  /// empty) doesn't need its own separate empty-check first.
  final ResponseMode? activeMode;
  final ValueChanged<ResponseMode> onModeSelected;

  final void Function(int blockIndex, int selectedIndex) onSelected;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    final resolvedActiveMode = activeMode;
    if (blocks.isEmpty || resolvedActiveMode == null) return const SizedBox.shrink();
    final definition = _definitionFor(module);
    final availableModes = [for (final entry in blocks) entry.block.mode];

    return Padding(
      padding: const EdgeInsets.only(bottom: TkSpace.sm),
      child: TkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Only shown when there's an actual choice to make — a single
            // available mode has nothing to pick between, so a selector
            // would just be a one-option control with no real function
            // (matches the existing "match/speak both work fine, tap is
            // just what always won by default" gap this screen exists to
            // close — see the library doc comment).
            if (availableModes.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(TkSpace.md, TkSpace.sm, TkSpace.md, TkSpace.xxs),
                child: Text(
                  'Mode aktif untuk modul ini:',
                  style: context.type.bodySm.copyWith(color: context.colors.textMuted),
                ),
              ),
              for (final mode in availableModes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TkSpace.sm),
                  child: TkChoiceTile<ResponseMode>(
                    label: _modeLabel(mode),
                    value: mode,
                    groupValue: resolvedActiveMode,
                    onSelected: onModeSelected,
                  ),
                ),
              const SizedBox(height: TkSpace.xs),
            ],
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                title: Text(definition.displayName),
                subtitle: const Text('Buka untuk memilih tahap.'),
                children: [
                  for (final entry in blocks)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TkSpace.sm,
                        0,
                        TkSpace.sm,
                        TkSpace.sm,
                      ),
                      child: _LevelBlockCard(
                        block: entry.block,
                        onSelected: (step) => onSelected(entry.index, step),
                        onApply: () => onApply(entry.index),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBlock {
  const _LevelBlock({
    required this.module,
    required this.mode,
    required this.steps,
    required this.current,
    required this.selectedIndex,
    this.busy = false,
  });

  final ModuleId module;
  final ResponseMode mode;
  final List<LadderPosition> steps;
  final LadderPosition current;
  final int selectedIndex;
  final bool busy;

  _LevelBlock copyWith({
    LadderPosition? current,
    int? selectedIndex,
    bool? busy,
  }) =>
      _LevelBlock(
        module: module,
        mode: mode,
        steps: steps,
        current: current ?? this.current,
        selectedIndex: selectedIndex ?? this.selectedIndex,
        busy: busy ?? this.busy,
      );
}

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

String _modeLabel(ResponseMode mode) => switch (mode) {
      ResponseMode.tap => 'Ketuk',
      ResponseMode.match => 'Seret',
      ResponseMode.speak => 'Bicara',
    };

String _stepLabel(
  LadderPosition position,
  List<LadderPosition> steps,
  ResponseMode mode,
) =>
    'Tahap ${steps.indexOf(position) + 1} (${_arraySizeLabel(position, mode)})';

String _positionDescription(
  ModuleDefinition definition,
  LadderPosition position,
  ResponseMode mode,
) =>
    '${_arraySizeLabel(position, mode)} · ${definition.similarityTierCopy[position.similarityTier]!}';

String _arraySizeLabel(LadderPosition position, [ResponseMode? mode]) =>
    mode == ResponseMode.speak
        ? 'ukuran susunan tidak berlaku'
        : 'ukuran susunan ${position.arraySize}';
