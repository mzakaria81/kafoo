/// Kafoo's shared widgets and design system.
///
/// Colors, spacing, and text styles come from `theme/`. A hardcoded value in a
/// widget is a finding — see `.claude/rules/dart.md`.
///
/// **Every widget here takes its user-facing strings from the caller.** This
/// package cannot reach the app's ARB files, and an Arabic sentence written
/// into a widget is a string outside localization — so labels, semantics and
/// placeholder warnings are all parameters, and the required ones are the rules
/// the design will not let a caller skip.
library;

export 'theme/numerals.dart';
export 'theme/theme.dart';
export 'theme/tokens.dart';
export 'theme/typography.dart';
export 'widgets/bottom_sheet.dart';
export 'widgets/button.dart';
export 'widgets/confirmation_gate.dart';
export 'widgets/empty_state.dart';
export 'widgets/filter_chip.dart';
export 'widgets/glance_word.dart';
export 'widgets/meal_card.dart';
export 'widgets/meal_row.dart';
export 'widgets/photo_placeholder.dart';
export 'widgets/spoken_banner.dart';
export 'widgets/talk_button.dart';
export 'widgets/text_field.dart';
