/// The design system's single import.
///
/// ```dart
/// import 'package:temanku/core/design/design.dart';
/// ```
///
/// Brings in the tokens ([TemanKuColors], [TemanKuTypography], [TkSpace],
/// [TkRadius], [TkStroke], [TkMotion], [TemanKuMetrics]), the `context.colors`
/// / `context.type` / `context.motion` accessors, and every `Tk*` component.
///
/// `core/theme/temanku_theme.dart` re-exports this file, so the older import
/// path keeps working — see that file's own note.
library;

export 'package:temanku/core/design/components/tk_button.dart';
export 'package:temanku/core/design/components/tk_card.dart';
export 'package:temanku/core/design/components/tk_choice.dart';
export 'package:temanku/core/design/components/tk_decor.dart';
export 'package:temanku/core/design/components/tk_screen.dart';
export 'package:temanku/core/design/components/tk_status.dart';
export 'package:temanku/core/design/theme.dart';
export 'package:temanku/core/design/tokens.dart';
