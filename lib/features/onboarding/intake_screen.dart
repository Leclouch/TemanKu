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
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
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
    if (_step == _questionCount) {
      return TkScreen(
        title: 'Intake',
        maxWidth: TemanKuMetrics.contentMaxWidth,
        decor: const TkScreenDecor(),
        child: _ConfirmationStep(
          onDone: () => context.go(Routes.guardianFor(widget.childId)),
        ),
      );
    }

    return TkScreen(
      title: 'Intake',
      maxWidth: TemanKuMetrics.contentMaxWidth,
      decor: const TkScreenDecor(),
      // The question list owns its own scrolling so the step indicator stays
      // pinned at the top and the Back/Next pair stays pinned at the bottom —
      // a stepped flow whose controls scroll away is a flow you can get lost in.
      scrollable: false,
      // Back is content-sized; Next takes whatever is left. A `Spacer` between
      // two intrinsically-sized buttons overflows the moment the labels get
      // long — which they do at the last step, in Indonesian, on a narrow phone.
      bottomBar: Row(
        children: [
          if (_step > 0) ...[
            TkButton.quiet(
              label: 'Kembali',
              onPressed: () => setState(() => _step -= 1),
            ),
            const SizedBox(width: TkSpace.xs),
          ],
          Expanded(
            child: TkButton(
              label: _step == _questionCount - 1 ? 'Selesai isi intake' : 'Lanjut',
              onPressed: _canProceed ? _next : null,
              expand: true,
            ),
          ),
        ],
      ),
      child: _buildQuestionStep(context),
    );
  }

  Widget _buildQuestionStep(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Replaces a bare "Pertanyaan 2 dari 4" line. Seeing how much is left
        // is the single most effective mitigation for the form-freeze response
        // — a stepped flow with no visible end reads as unbounded.
        TkStepIndicator(step: _step, total: _questionCount),
        const SizedBox(height: TkSpace.lg),
        Expanded(
          child: ListView(
            children: [
              Text(
                _questionFor(_step),
                style: context.type.titleLg.copyWith(color: colors.text),
              ),
              const SizedBox(height: TkSpace.lg),
              ..._optionsFor(_step),
            ],
          ),
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
          TkChoiceTile<DiagnosisStatus>(
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
        TkChoiceTile<_ModeAnswer>(
          label: option.$2,
          value: option.$1,
          groupValue: current,
          onSelected: onSelected,
        ),
    ];
  }
}

// `_OptionTile` used to live here — a big tappable card rather than a bare
// radio row, which was the right instinct. It is now `TkChoiceTile` in
// `core/design/components/tk_choice.dart`, unchanged in behaviour, so the
// photo-upload and settings screens can stop inventing their own.

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.successWash,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.check,
              size: 40,
              color: colors.text,
            ),
          ),
          const SizedBox(height: TkSpace.lg),
          Text(
            _confirmationCopy,
            textAlign: TextAlign.center,
            style: context.type.titleLg.copyWith(color: colors.text),
          ),
          const SizedBox(height: TkSpace.xl),
          TkButton(label: 'Selesai', onPressed: onDone, expand: true),
        ],
      ),
    );
  }
}
