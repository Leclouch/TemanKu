/// Per-child intake — **IT-2. Guardian-facing setup, not an assessment.**
///
/// Source-of-truth §8: intake asks one behavioural question per response
/// mode and selects which modes are *offered*. It never predicts a starting
/// difficulty — every mode a child ends up with here still starts at Step 1
/// of the dial engine (§4.5: "no placement quiz, no calibration screen"; see
/// `engine/ladder_persistence.dart`, which returns [LadderPosition.start] for
/// any (child, module, mode) with no stored position — true unconditionally
/// of how that mode was enabled). This screen must never set a ladder
/// position itself.
///
/// The diagnosis-status question is **context only**. It is written to
/// [Child.diagnosisStatus] and read by nothing else in this codebase — no
/// mode gating, no content gating. See the field's own doc comment in
/// `data/models/child.dart` for the constraint this is guarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';

/// The three mode questions share the same answer shape and mapping (§8):
/// "Ya, biasanya bisa" / "Kadang-kadang" both include the mode; "Belum"
/// excludes it. Kept distinct from [DiagnosisStatus], which has its own,
/// unrelated set of options.
enum _ModeAnswer { yes, sometimes, notYet }

const List<(_ModeAnswer, String)> _modeOptions = [
  (_ModeAnswer.yes, 'Ya, biasanya bisa'),
  (_ModeAnswer.sometimes, 'Kadang-kadang'),
  (_ModeAnswer.notYet, 'Belum'),
];

const List<(DiagnosisStatus, String)> _diagnosisOptions = [
  (DiagnosisStatus.diagnosed, 'Sudah'),
  (DiagnosisStatus.notDiagnosed, 'Belum'),
  (DiagnosisStatus.unsure, 'Saya tidak yakin'),
];

const _tapQuestion =
    'Kalau kamu sebutkan nama benda yang ia kenal, apakah ia bisa menunjuk atau mengetuk benda itu?';
const _matchQuestion = 'Bisakah ia mencocokkan dua gambar yang sama persis?';
const _speakQuestion = 'Apakah ia mengucapkan satu kata untuk benda yang ia kenal?';
const _diagnosisQuestion = 'Apakah anak sudah pernah didiagnosis oleh dokter atau terapis?';

/// Exact copy from the task brief — do not paraphrase; no score/result/level
/// language belongs anywhere near it.
const _confirmationCopy =
    'Kami akan mulai dari sini, dan menyesuaikan setelah beberapa sesi bersama.';

const _questionCount = 4;

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  /// 0=tap, 1=match, 2=speak, 3=diagnosis, 4=confirmation. Nothing here
  /// persists a "completed intake" flag — the screen is freely revisitable
  /// (guardians can come back and answer again later); it just always starts
  /// at the top of the four questions rather than trying to reconstruct a
  /// prior run.
  int _step = 0;

  _ModeAnswer? _tapAnswer;
  _ModeAnswer? _matchAnswer;
  _ModeAnswer? _speakAnswer;
  DiagnosisStatus? _diagnosisAnswer;

  bool get _canProceed => switch (_step) {
        0 => _tapAnswer != null,
        1 => _matchAnswer != null,
        2 => _speakAnswer != null,
        3 => _diagnosisAnswer != null,
        _ => true,
      };

  Future<void> _next() async {
    if (_step < _questionCount - 1) {
      setState(() => _step += 1);
      return;
    }
    await _saveIntake();
    if (!mounted) return;
    setState(() => _step = _questionCount);
  }

  Future<void> _saveIntake() async {
    // Included whenever the answer isn't "Belum" — the two-of-three mapping
    // from the task brief. Never a partial/fuzzy inclusion: a mode is either
    // offered or it isn't.
    final modes = <ResponseMode>{
      if (_tapAnswer != _ModeAnswer.notYet) ResponseMode.tap,
      if (_matchAnswer != _ModeAnswer.notYet) ResponseMode.match,
      if (_speakAnswer != _ModeAnswer.notYet) ResponseMode.speak,
    };

    final repository = ref.read(childRepositoryProvider);
    final child = await repository.getChild(widget.childId);
    if (child == null) return;

    // Existing interface only — ChildRepository.updateChild takes a full
    // Child, so no signature change was needed to add diagnosisStatus.
    await repository.updateChild(
      child.copyWith(availableModes: modes, diagnosisStatus: _diagnosisAnswer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intake')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == _questionCount
              ? _ConfirmationStep(
                  onDone: () => context.go(Routes.guardianFor(widget.childId)),
                )
              : _buildQuestionStep(context),
        ),
      ),
    );
  }

  Widget _buildQuestionStep(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pertanyaan ${_step + 1} dari $_questionCount',
          style: context.type.mono.copyWith(color: colors.neutralFeedback),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              Text(_questionFor(_step), style: context.type.display.copyWith(color: colors.text)),
              const SizedBox(height: 20),
              ..._optionsFor(_step),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_step > 0)
              TextButton(
                onPressed: () => setState(() => _step -= 1),
                child: const Text('Kembali'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _canProceed ? _next : null,
              child: Text(_step == _questionCount - 1 ? 'Selesai isi intake' : 'Lanjut'),
            ),
          ],
        ),
      ],
    );
  }

  String _questionFor(int step) => switch (step) {
        0 => _tapQuestion,
        1 => _matchQuestion,
        2 => _speakQuestion,
        _ => _diagnosisQuestion,
      };

  List<Widget> _optionsFor(int step) {
    if (step == 3) {
      return [
        for (final option in _diagnosisOptions)
          _OptionTile<DiagnosisStatus>(
            label: option.$2,
            value: option.$1,
            groupValue: _diagnosisAnswer,
            onSelected: (value) => setState(() => _diagnosisAnswer = value),
          ),
      ];
    }

    final current = switch (step) {
      0 => _tapAnswer,
      1 => _matchAnswer,
      _ => _speakAnswer,
    };
    void onSelected(_ModeAnswer value) => setState(() {
          switch (step) {
            case 0:
              _tapAnswer = value;
            case 1:
              _matchAnswer = value;
            default:
              _speakAnswer = value;
          }
        });

    return [
      for (final option in _modeOptions)
        _OptionTile<_ModeAnswer>(
          label: option.$2,
          value: option.$1,
          groupValue: current,
          onSelected: onSelected,
        ),
    ];
  }
}

/// A single-select option, styled as a big tappable card rather than a bare
/// radio row — 44pt minimum touch target (§11), guardian-surface styling.
class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final T value;
  final T? groupValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // secondaryAccent is the guardian-surface-only token (core/theme/).
            color: selected ? colors.secondaryAccent.withValues(alpha: 0.18) : colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.secondaryAccent : colors.neutralFeedback,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? colors.secondaryAccent : colors.neutralFeedback,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: context.type.body.copyWith(color: colors.text))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: colors.successFeedback),
            const SizedBox(height: 16),
            Text(
              _confirmationCopy,
              textAlign: TextAlign.center,
              style: context.type.body.copyWith(color: colors.text),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onDone, child: const Text('Selesai')),
          ],
        ),
      ),
    );
  }
}
