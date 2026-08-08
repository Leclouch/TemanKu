import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:temanku/core/design/design.dart';

/// Renders a photo from [Photo.localPath] — **shared component, jointly owned.**
///
/// [localPath] is either a real on-device file path (guardian-uploaded
/// photos, both `InMemoryPhotoRepository`'s legacy fakes and
/// `LocalPhotoRepository`'s real files) or a bundled `assets/...` path
/// (Keluarga's stranger-library distractors —
/// `photo_pipeline/stranger_library/`, wrapped as a synthetic [Photo] by
/// `MatchModeController`/`TapModeController`). This widget is the one place
/// that tells those two apart so no screen has to.
///
/// Falls back to a neutral placeholder icon — never a crash, never a broken-
/// image glyph — when the path can't be loaded at all: a fake test path, or
/// a file the guardian since deleted outside the app.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.localPath,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final String localPath;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = localPath.startsWith('assets/')
        ? Image.asset(localPath, fit: fit, errorBuilder: _fallback)
        : Image.file(File(localPath), fit: fit, errorBuilder: _fallback);
    return ClipRRect(borderRadius: borderRadius, child: image);
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stackTrace) {
    final colors = context.colors;
    // Neutral chrome, not a feedback token — a missing file is a setup gap,
    // and must never render in the same colour an answer outcome uses.
    return Container(
      color: colors.surfaceTinted,
      alignment: Alignment.center,
      child: Icon(LucideIcons.image, color: colors.textMuted),
    );
  }
}
