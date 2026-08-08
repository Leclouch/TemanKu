/// Guardian photo upload flow — **IT-2, Day 2.**
///
/// Source-of-truth §5.1/§5.4/§5.5: every photo passes the quality gate
/// on-device before it is ever kept; a pass writes straight to
/// [PhotoRepository] with **no network call, no auto-upload** (§10 — photos
/// are local-only by default). Variety toward five photos per category is a
/// **soft nudge, never a hard gate** (§5.4) — nothing here disables
/// continuing on a low photo count.
///
/// Scope boundary from the task brief, worth restating because it is easy to
/// blur: this screen judges **photo usability** (via the quality gate) only.
/// It never judges photo *correctness* — whether a photo actually belongs in
/// its category is the guardian's manual choice above, never inferred from
/// pixels.
///
/// A quality-gate pass never auto-saves. It hands off to a full-screen
/// preview ([_PhotoPreview]) — the captured photo shown large, plus its
/// label — with a confirm/retake bar at the bottom. Nothing reaches
/// [PhotoRepository] until the guardian actively confirms.
///
/// Object-name suggestion (§5.2, `photo_pipeline/classifier_service.dart`)
/// is wired in for [ModuleDefinition.usesClassifier] modules (Makanan) only:
/// on a quality-gate pass, [ClassifierService.suggestLabel] runs *before*
/// the preview shows, pre-filling the preview's editable name field. Below
/// the classifier's own confidence threshold the field is simply empty and
/// the guardian can type a name right there — matching §5.2's "silent AI"
/// framing: the classifier's silence is never a reason to make the guardian
/// wait, only a reason to ask instead of guess. [_SavedNudge]'s "ketuk untuk
/// ubah" remains as the §5.5 standing-correction path for photos already
/// saved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/photo.dart';
import 'package:temanku/photo_pipeline/quality_gate/quality_gate.dart';
import 'package:temanku/widgets/edit_label_dialog.dart';
import 'package:temanku/widgets/photo_image.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// Suggested variety target per category (§5.4) — a coaching number shown as
/// encouragement copy, never a gate. Same "placeholder pending calibration"
/// caveat as other tunable constants in this codebase
/// (`engine/advancement/advancement_tracker.dart`'s streak count): §5.4 names
/// five as the source-of-truth target, so this one is pinned, not guessed.
const int suggestedPhotosPerCategory = 5;

enum _UploadStage { idle, checking, retake, previewing, saved }

/// Capture (camera) or pick (gallery), run the quality gate, and — on a
/// pass — show [_PhotoPreview] for the guardian to confirm before anything
/// is persisted. A quality-gate fail loops back to capture with a friendly
/// retake prompt and saves nothing, same as before.
class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({
    super.key,
    required this.childId,
    required this.module,
  });

  final String childId;
  final ModuleId module;

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();

  PhotoCategory _category = PhotoCategory.target;
  AgeGroup? _ageGroup;
  _UploadStage _stage = _UploadStage.idle;
  String? _retakePrompt;
  bool _nudgeVisible = false;

  /// The photo just saved by [_confirmSave] — held only so [_SavedNudge] can
  /// show/edit its label without re-querying the repository. Cleared
  /// whenever the nudge isn't showing.
  Photo? _lastSaved;

  /// A quality-gate-passed photo awaiting the guardian's confirmation in
  /// [_PhotoPreview] — set by [_capture], cleared by [_confirmSave] or
  /// [_retake]. Never reaches [PhotoRepository] until confirmed.
  String? _pendingImagePath;

  /// Modules whose distractors are bundled assets (Keluarga today —
  /// `photo_pipeline/stranger_library/`) never have the guardian photograph
  /// a "not family" person at all — that would be exactly the third-party
  /// consent problem bundling distractors was chosen to avoid. Every photo
  /// the guardian uploads here is a target, and it needs a name and an age
  /// group (§4.4 — stranger_library compares against it) instead of a
  /// category choice.
  bool get _needsPersonDetails => _definitionFor(widget.module).usesBundledDistractors;

  bool get _canCapture {
    if (!_needsPersonDetails) return true;
    return _nameController.text.trim().isNotEmpty && _ageGroup != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    // The system picker can outlive this screen — a guardian can navigate
    // away (or the screen can be popped some other way) while it's open.
    if (!mounted) return;
    if (picked == null) return; // Guardian cancelled — stay idle, nothing saved.

    setState(() {
      _stage = _UploadStage.checking;
      _nudgeVisible = false;
    });

    final result = await ref.read(qualityGateProvider).check(picked.path);
    if (!mounted) return;

    if (!result.passed) {
      setState(() {
        _stage = _UploadStage.retake;
        _retakePrompt = qualityIssueRetakePrompt[result.issue];
      });
      return;
    }

    // Makanan only (usesClassifier — §5.2; Keluarga's is permanently false,
    // it already collected the name above, before capture). Below the
    // classifier's own confidence threshold this leaves the field empty
    // rather than guessing — the guardian fills it in on the preview below,
    // or leaves it for the §5.5 standing-correction path after saving.
    if (_definitionFor(widget.module).usesClassifier) {
      final suggestion = await ref.read(classifierServiceProvider).suggestLabel(
            imagePath: picked.path,
            module: widget.module,
          );
      // Checked before touching _nameController too — it's disposed the
      // moment this screen is, and setting .text on a disposed
      // ChangeNotifier throws just as surely as setState does.
      if (!mounted) return;
      _nameController.text = suggestion?.label ?? '';
    }

    if (!mounted) return;
    setState(() {
      _stage = _UploadStage.previewing;
      _pendingImagePath = picked.path;
    });
  }

  /// The guardian confirmed [_pendingImagePath] in [_PhotoPreview] — only
  /// now does anything reach [PhotoRepository].
  Future<void> _confirmSave() async {
    final path = _pendingImagePath;
    if (path == null) return;

    final saved = await ref.read(photoRepositoryProvider).addPhoto(
          childId: widget.childId,
          module: widget.module,
          // TODO(IT-2): copy into permanent encrypted local storage (§11) —
          // the picker hands back a transient cache path, not durable
          // storage. The in-memory fake this screen is built against doesn't
          // care, but a real PhotoRepository implementation will need the
          // copy step to happen here, before this call.
          localPath: path,
          category: _needsPersonDetails ? PhotoCategory.target : _category,
          label: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          ageGroup: _needsPersonDetails ? _ageGroup : null,
        );

    if (!mounted) return;
    setState(() {
      _stage = _UploadStage.saved;
      _nudgeVisible = true;
      _lastSaved = saved;
      _pendingImagePath = null;
      // A fresh name/suggestion is wanted for the next photo either way —
      // Keluarga because a new person needs a new name (age group tends to
      // repeat, so that one's left as the guardian's last choice), Makanan
      // because the next photo gets its own classifier suggestion.
      _nameController.clear();
    });
  }

  /// The guardian rejected [_pendingImagePath] in [_PhotoPreview] — back to
  /// capture, nothing saved, same as a quality-gate fail.
  void _retake() {
    setState(() {
      _stage = _UploadStage.idle;
      _pendingImagePath = null;
      if (_definitionFor(widget.module).usesClassifier) _nameController.clear();
    });
  }

  void _dismissNudge() => setState(() => _nudgeVisible = false);

  /// §5.5 standing correction, reached from [_SavedNudge]'s "ketuk untuk
  /// ubah" — covers both cases the classifier's silence-or-guess split
  /// leaves the guardian: confirming/fixing a suggested label, or supplying
  /// one the classifier had none for.
  Future<void> _editLabel() async {
    final photo = _lastSaved;
    if (photo == null) return;

    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => EditLabelDialog(initialLabel: photo.label ?? ''),
    );
    if (newLabel == null || newLabel.isEmpty || newLabel == photo.label) return;

    final updated = photo.copyWith(label: newLabel);
    await ref.read(photoRepositoryProvider).updatePhoto(updated);
    if (!mounted) return;
    setState(() => _lastSaved = updated);
  }

  @override
  Widget build(BuildContext context) {
    final definition = _definitionFor(widget.module);
    final busy = _stage == _UploadStage.checking;

    // The preview stage replaces the whole body and owns its own bottom bar,
    // so it opts out of TkScreen's padding and scrolling rather than
    // nesting two scroll views.
    if (_stage == _UploadStage.previewing) {
      return TkScreen(
        title: 'Tambah foto · ${definition.displayName}',
        maxWidth: TemanKuMetrics.contentMaxWidth,
        scrollable: false,
        padding: EdgeInsets.zero,
        child: _PhotoPreview(
          imagePath: _pendingImagePath!,
          definition: definition,
          needsPersonDetails: _needsPersonDetails,
          nameController: _nameController,
          category: _category,
          ageGroup: _ageGroup,
          onConfirm: () => _confirmSave(),
          onRetake: _retake,
        ),
      );
    }

    return TkScreen(
      title: 'Tambah foto · ${definition.displayName}',
      maxWidth: TemanKuMetrics.contentMaxWidth,
      decor: const TkScreenDecor(),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.images),
          tooltip: 'Lihat semua foto',
          onPressed: () => context.push(Routes.photoLibraryFor(widget.childId, widget.module)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_nudgeVisible)
            _SavedNudge(
              onDismiss: _dismissNudge,
              label: definition.usesClassifier ? _lastSaved?.label : null,
              onEditLabel: definition.usesClassifier ? _editLabel : null,
            ),
          if (_needsPersonDetails)
            _PersonDetailsFields(
              nameController: _nameController,
              ageGroup: _ageGroup,
              enabled: !busy,
              onAgeGroupChanged: (g) => setState(() => _ageGroup = g),
              onNameChanged: () => setState(() {}), // refresh _canCapture
            )
          else
            _CategoryPicker(
              definition: definition,
              value: _category,
              onChanged: busy ? null : (c) => setState(() => _category = c),
            ),
          const SizedBox(height: TkSpace.lg),
          if (_stage == _UploadStage.retake) ...[
            _RetakeBanner(message: _retakePrompt!),
            const SizedBox(height: TkSpace.md),
          ],
          _CaptureButtons(
            busy: busy,
            retrying: _stage == _UploadStage.retake,
            enabled: _canCapture,
            onCamera: () => _capture(ImageSource.camera),
            onGallery: () => _capture(ImageSource.gallery),
          ),
          const SizedBox(height: TkSpace.xl),
          _CountEncouragement(
            childId: widget.childId,
            module: widget.module,
            category: _needsPersonDetails ? PhotoCategory.target : _category,
          ),
        ],
      ),
    );
  }
}

/// The confirm-before-saving screen — replaces the whole capture body while
/// [_UploadStage.previewing]. Shows the just-picked photo large, its label
/// (editable for Makanan, a read-only recap for Keluarga since that name was
/// already typed above, before capture), and a bottom bar that is the only
/// path to actually saving anything.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.imagePath,
    required this.definition,
    required this.needsPersonDetails,
    required this.nameController,
    required this.category,
    required this.ageGroup,
    required this.onConfirm,
    required this.onRetake,
  });

  final String imagePath;
  final ModuleDefinition definition;
  final bool needsPersonDetails;
  final TextEditingController nameController;
  final PhotoCategory category;
  final AgeGroup? ageGroup;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TkSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PhotoImage(localPath: imagePath, borderRadius: TkRadius.md),
                  ),
                ),
                const SizedBox(height: TkSpace.lg),
                if (needsPersonDetails)
                  // Already collected above, before capture — this is a
                  // recap, not a new input.
                  Text(
                    [
                      nameController.text,
                      if (ageGroup != null) _ageGroupLabel[ageGroup]!,
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: context.type.titleLg.copyWith(color: colors.text),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TkBadge(
                      label: category == PhotoCategory.target
                          ? definition.targetCategoryLabel
                          : definition.distractorCategoryLabel,
                      tone: TkBadgeTone.accent,
                    ),
                  ),
                  const SizedBox(height: TkSpace.md),
                  Text('Nama benda ini:', style: context.type.title.copyWith(color: colors.text)),
                  const SizedBox(height: TkSpace.xs),
                  // No local `border:` override — the outline, radius and
                  // focus treatment all come from inputDecorationTheme.
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'apa nama benda ini?'),
                  ),
                ],
              ],
            ),
          ),
        ),
        // The confirmation bar — deliberately the only way anything below
        // reaches PhotoRepository (see _PhotoUploadScreenState._confirmSave).
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(color: colors.border, width: TkStroke.regular),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(TkSpace.md),
              child: Row(
                children: [
                  Expanded(
                    child: TkButton.secondary(
                      label: 'Ambil ulang',
                      onPressed: onRetake,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: TkSpace.sm),
                  Expanded(
                    child: TkButton(
                      label: 'Pakai foto ini',
                      onPressed: onConfirm,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final ModuleDefinition definition;
  final PhotoCategory value;
  final ValueChanged<PhotoCategory>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto ini termasuk:', style: context.type.title.copyWith(color: colors.text)),
        const SizedBox(height: TkSpace.xs),
        SegmentedButton<PhotoCategory>(
          segments: [
            ButtonSegment(
              value: PhotoCategory.target,
              label: Text(definition.targetCategoryLabel),
              icon: Icon(LucideIcons.circle, size: 12, color: definition.targetStyle.color),
            ),
            ButtonSegment(
              value: PhotoCategory.distractor,
              label: Text(definition.distractorCategoryLabel),
              icon: Icon(LucideIcons.circle, size: 12, color: definition.distractorStyle.color),
            ),
          ],
          selected: {value},
          onSelectionChanged:
              onChanged == null ? null : (selection) => onChanged!(selection.first),
        ),
      ],
    );
  }
}

const Map<AgeGroup, String> _ageGroupLabel = {
  AgeGroup.child: 'Anak-anak',
  AgeGroup.teen: 'Remaja',
  AgeGroup.adult: 'Dewasa',
  AgeGroup.elderly: 'Lansia',
};

/// Replaces [_CategoryPicker] for modules with bundled distractors (§4.4) —
/// every photo here is a family member, so instead of choosing a category
/// the guardian names the person and tags their age group directly (never a
/// classifier: `content/keluarga/keluarga_module.dart` sets usesClassifier
/// false permanently).
class _PersonDetailsFields extends StatelessWidget {
  const _PersonDetailsFields({
    required this.nameController,
    required this.ageGroup,
    required this.enabled,
    required this.onAgeGroupChanged,
    required this.onNameChanged,
  });

  final TextEditingController nameController;
  final AgeGroup? ageGroup;
  final bool enabled;
  final ValueChanged<AgeGroup> onAgeGroupChanged;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nama / hubungan keluarga:', style: context.type.title.copyWith(color: colors.text)),
        const SizedBox(height: TkSpace.xs),
        TextField(
          controller: nameController,
          enabled: enabled,
          onChanged: (_) => onNameChanged(),
          decoration: const InputDecoration(hintText: 'mis. Ibu, Kakak Sari'),
        ),
        const SizedBox(height: TkSpace.lg),
        Text('Kelompok usia:', style: context.type.title.copyWith(color: colors.text)),
        const SizedBox(height: TkSpace.xs),
        SegmentedButton<AgeGroup>(
          segments: [
            for (final group in AgeGroup.values)
              ButtonSegment(value: group, label: Text(_ageGroupLabel[group]!)),
          ],
          selected: {if (ageGroup != null) ageGroup!},
          emptySelectionAllowed: true,
          onSelectionChanged: enabled
              ? (selection) {
                  if (selection.isNotEmpty) onAgeGroupChanged(selection.first);
                }
              : null,
        ),
      ],
    );
  }
}

class _CaptureButtons extends StatelessWidget {
  const _CaptureButtons({
    required this.busy,
    required this.retrying,
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final bool retrying;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    if (busy) return const TkLoading(label: 'Memeriksa foto…');

    return Column(
      children: [
        TkButton(
          label: retrying ? 'Coba lagi dengan kamera' : 'Ambil foto',
          icon: LucideIcons.camera,
          onPressed: enabled ? onCamera : null,
          expand: true,
        ),
        const SizedBox(height: TkSpace.sm),
        TkButton.secondary(
          label: retrying ? 'Pilih foto lain dari galeri' : 'Pilih dari galeri',
          icon: LucideIcons.images,
          onPressed: enabled ? onGallery : null,
          expand: true,
        ),
        if (!enabled) ...[
          const SizedBox(height: TkSpace.xs),
          // A disabled primary action always says why. A dead control with
          // no explanation is the "freeze" trigger the ADHD guidance calls
          // out — the guardian cannot tell broken from not-yet-ready.
          Text(
            'Isi nama dan kelompok usia dulu.',
            textAlign: TextAlign.center,
            style: context.type.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _RetakeBanner extends StatelessWidget {
  const _RetakeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Deliberately the same neutral weight as the child screen's "try again"
    // state (§12) — no alarm colour, even on a guardian surface. This is the
    // one place on the guardian side that legitimately paints in
    // neutralFeedback: it *is* a "try again", just addressed to the adult.
    return Container(
      padding: const EdgeInsets.all(TkSpace.md),
      decoration: BoxDecoration(
        color: colors.neutralWash,
        borderRadius: TkRadius.md,
        border: Border.all(color: colors.neutralFeedback, width: TkStroke.regular),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.refreshCw, color: colors.text, size: 20),
          const SizedBox(width: TkSpace.sm),
          Expanded(
            child: Text(message, style: context.type.bodySm.copyWith(color: colors.text)),
          ),
        ],
      ),
    );
  }
}

class _SavedNudge extends StatelessWidget {
  const _SavedNudge({required this.onDismiss, this.label, this.onEditLabel});

  final VoidCallback onDismiss;

  /// The saved photo's current label. Null either because this module has
  /// no classifier (Keluarga — [onEditLabel] is also null then, see below)
  /// or because the classifier saved this one unconfident/unlabeled.
  final String? label;

  /// Non-null only for classifier-enabled modules (Makanan) — opens the
  /// §5.5 correction dialog. Keluarga already collects its name up front,
  /// so this stays null there and no edit affordance renders.
  final VoidCallback? onEditLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: TkSpace.lg),
      padding: const EdgeInsets.all(TkSpace.md),
      decoration: BoxDecoration(
        // The success wash, because this is genuinely a "that worked" moment
        // — the one place on the guardian surface that earns it.
        color: colors.successWash,
        borderRadius: TkRadius.md,
        border: Border.all(color: colors.successFeedback, width: TkStroke.regular),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleCheck, color: colors.text, size: 20),
              const SizedBox(width: TkSpace.sm),
              Expanded(
                child: Text(
                  'Bagus! Tambahkan satu lagi yang berbeda ya, biar makin lengkap.',
                  style: context.type.bodySm.copyWith(color: colors.text),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                tooltip: 'Tutup',
                onPressed: onDismiss,
                iconSize: 18,
                constraints: const BoxConstraints(
                  minWidth: TemanKuMetrics.minTouchTarget,
                  minHeight: TemanKuMetrics.minTouchTarget,
                ),
              ),
            ],
          ),
          if (onEditLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: TkSpace.xxl),
              child: InkWell(
                onTap: onEditLabel,
                borderRadius: TkRadius.xs,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: TemanKuMetrics.minTouchTarget),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label != null
                          ? 'Tersimpan sebagai "$label" — bukan itu? Ketuk untuk ubah.'
                          : 'Wali tahu nama benda ini? Ketuk untuk kasih nama.',
                      style: context.type.bodySm.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountEncouragement extends ConsumerWidget {
  const _CountEncouragement({
    required this.childId,
    required this.module,
    required this.category,
  });

  final String childId;
  final ModuleId module;
  final PhotoCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photoRepositoryProvider);
    final colors = context.colors;

    return StreamBuilder<List<Photo>>(
      stream: photos.watchPhotos(childId: childId, module: module),
      builder: (context, snapshot) {
        final count =
            snapshot.data?.where((p) => p.category == category).length ?? 0;
        final met = count >= suggestedPhotosPerCategory;
        // Encouragement copy only (§5.4) — this never disables the capture
        // buttons above, regardless of the count.
        //
        // The dots are a soft nudge made visible, not a progress bar toward
        // a gate: past the suggested count they simply stop filling, and no
        // state anywhere reads them.
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < suggestedPhotosPerCategory; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < count ? colors.successFeedback : colors.border,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: TkSpace.xs),
            Text(
              met
                  ? 'Sudah $count foto — cukup untuk kategori ini. Boleh tambah lagi kalau mau.'
                  : '$count dari $suggestedPhotosPerCategory disarankan untuk kategori ini.',
              textAlign: TextAlign.center,
              style: context.type.caption.copyWith(color: colors.textMuted),
            ),
          ],
        );
      },
    );
  }
}
