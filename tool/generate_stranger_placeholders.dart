// Dev tooling — not part of the app. Run with:
//   dart run tool/generate_stranger_placeholders.dart
//
// Generates clearly-marked placeholder avatars for
// `assets/stranger_library/`, one solid colour per age group so they are
// visually distinguishable even without reading the filename, with
// "PLACEHOLDER" + the age-group name burned into the pixels so nobody
// mistakes one for a real curated photo if it ever renders on screen.
//
// TODO(IT-2): delete these and drop the real curated 10–15 image set here
// before demo (§5.3) — see assets/stranger_library/.gitkeep for the naming
// convention the loader expects.
import 'dart:io';

import 'package:image/image.dart' as img;

const _ageGroups = <String, List<int>>{
  'child': [0xFF, 0xC9, 0x7A], // warm amber
  'teen': [0x7A, 0xD1, 0xC4], // teal
  'adult': [0x8E, 0xA8, 0xE8], // blue
  'elderly': [0xC9, 0xA8, 0xD1], // mauve
};

const _imagesPerGroup = 2;
const _size = 160;

void main() {
  final outDir = Directory('assets/stranger_library');
  if (!outDir.existsSync()) {
    stderr.writeln('assets/stranger_library/ not found — run from the repo root.');
    exit(1);
  }

  for (final entry in _ageGroups.entries) {
    final ageGroup = entry.key;
    final rgb = entry.value;

    for (var i = 1; i <= _imagesPerGroup; i++) {
      final image = img.Image(width: _size, height: _size);
      img.fill(image, color: img.ColorRgb8(rgb[0], rgb[1], rgb[2]));

      img.drawString(
        image,
        'PLACEHOLDER',
        font: img.arial14,
        x: 10,
        y: 16,
        color: img.ColorRgb8(0, 0, 0),
      );
      img.drawString(
        image,
        ageGroup.toUpperCase(),
        font: img.arial24,
        y: _size ~/ 2 - 10,
        color: img.ColorRgb8(0, 0, 0),
      );
      img.drawString(
        image,
        '#$i',
        font: img.arial14,
        y: _size - 26,
        color: img.ColorRgb8(0, 0, 0),
      );

      final path = '${outDir.path}/stranger_${ageGroup}_${i.toString().padLeft(2, '0')}.png';
      File(path).writeAsBytesSync(img.encodePng(image));
      stdout.writeln('wrote $path');
    }
  }
}
