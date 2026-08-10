import 'package:flutter/material.dart';

import 'tokens.dart';

/// Kafoo's Material theme, built from the tokens.
///
/// This exists so a screen gets the design system without asking for it. Before
/// 2026-08-10 `main.dart` built its theme from `ColorScheme.fromSeed`, which
/// derived twenty-odd colours from one terracotta seed and used none of the
/// values anybody had chosen — so every screen rendered in Material's
/// interpretation of Kafoo rather than Kafoo, in whatever font the handset
/// happened to pick.
///
/// **Nothing here invents a value.** Every colour and size comes from
/// `docs/design/DESIGN.md`, and where Material needs a slot the design does not
/// name, the nearest named token fills it rather than a new colour appearing.
ThemeData kafooTheme() {
  const colors = ColorScheme(
    brightness: Brightness.light,
    primary: KafooColors.primary,
    onPrimary: KafooColors.onPrimary,
    primaryContainer: KafooColors.primaryTint,
    onPrimaryContainer: KafooColors.primaryDeep,
    secondary: KafooColors.voice,
    onSecondary: KafooColors.onPrimary,
    secondaryContainer: KafooColors.voiceTint,
    onSecondaryContainer: KafooColors.voiceDeep,
    error: KafooColors.danger,
    onError: KafooColors.onPrimary,
    errorContainer: KafooColors.dangerTint,
    onErrorContainer: KafooColors.danger,
    surface: KafooColors.surface,
    onSurface: KafooColors.onSurface,
    // Material's name for "secondary text on a surface". Kafoo's textMuted is
    // deliberately darker than the greys Material would pick, because anything
    // lighter stops being readable in sunlight.
    onSurfaceVariant: KafooColors.textMuted,
    surfaceContainerHighest: KafooColors.surfaceSunken,
    outline: KafooColors.borderStrong,
    outlineVariant: KafooColors.border,
    shadow: KafooColors.onSurface,
    scrim: KafooColors.darkSurface,
    inverseSurface: KafooColors.darkSurface,
    onInverseSurface: KafooColors.surface,
    inversePrimary: KafooColors.primaryTint,
  );

  final text = _textTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: KafooColors.surface,
    fontFamily: KafooType.fontFamily,
    fontFamilyFallback: KafooType.fontFamilyFallback,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: KafooColors.surface,
      foregroundColor: KafooColors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // A hairline, not a shadow. Structure that matters has to survive
      // sunlight, and a shadow does not.
      shape: Border(
        bottom: BorderSide(color: KafooColors.border),
      ),
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: KafooColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // 18/400 is "body large": a primary button is read at arm's length or
        // glanced at while cooking.
        textStyle: KafooType.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
        disabledBackgroundColor: KafooColors.disabledFill,
        disabledForegroundColor: KafooColors.textDisabled,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // primaryDeep, not primary: a label at 14–16px in terracotta sits too
        // light against the surface, and thin Arabic strokes make it worse.
        foregroundColor: KafooColors.primaryDeep,
        textStyle: KafooType.label,
        minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
        disabledForegroundColor: KafooColors.textDisabled,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KafooColors.primaryDeep,
        backgroundColor: KafooColors.primaryTint,
        side: const BorderSide(color: KafooColors.primaryBorder, width: 1.5),
        textStyle: KafooType.label,
        minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KafooColors.surfaceRaised,
      // 16, and never smaller: below it iOS zooms on focus, and proof-reading
      // your own words in sunlight gets hard.
      hintStyle: KafooType.body.copyWith(color: KafooColors.textSubtle),
      labelStyle: KafooType.body.copyWith(color: KafooColors.textMuted),
      helperStyle: KafooType.bodySmall.copyWith(color: KafooColors.textMuted),
      errorStyle: KafooType.bodySmall.copyWith(color: KafooColors.danger),
      border: _inputBorder(KafooColors.borderStrong),
      enabledBorder: _inputBorder(KafooColors.borderStrong),
      focusedBorder: _inputBorder(KafooColors.primary, width: 2),
      errorBorder: _inputBorder(KafooColors.dangerBorder, width: 1.5),
      focusedErrorBorder: _inputBorder(KafooColors.danger, width: 2),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: KafooSpacing.md,
        vertical: KafooSpacing.rowGap,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KafooColors.surfaceRaised,
      selectedColor: KafooColors.primary,
      side: const BorderSide(color: KafooColors.borderStrong, width: 1.5),
      labelStyle: KafooType.label,
      secondaryLabelStyle: KafooType.label.copyWith(
        color: KafooColors.onPrimary,
      ),
      shape: const StadiumBorder(),
    ),
    cardTheme: CardThemeData(
      color: KafooColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KafooRadius.card),
        side: const BorderSide(color: KafooColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KafooColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: KafooElevation.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KafooRadius.sheet),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KafooColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KafooColors.darkSurface,
      contentTextStyle: KafooType.body.copyWith(color: KafooColors.surface),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1.5}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(KafooRadius.control),
      borderSide: BorderSide(color: color, width: width),
    );

/// Maps Kafoo's scale onto Material's slots.
///
/// The mapping is not one-to-one and cannot be: Material has fifteen slots
/// covering three sizes of five roles, and Kafoo has nine roles chosen for one
/// product. Each assignment below picks the Kafoo style whose *use* matches the
/// slot's use, so a widget reaching for `titleLarge` gets something sensible
/// rather than a Material default in the wrong font.
TextTheme _textTheme() => const TextTheme(
      displayLarge: KafooType.display,
      displayMedium: KafooType.display,
      displaySmall: KafooType.screenTitle,
      headlineLarge: KafooType.screenTitle,
      headlineMedium: KafooType.section,
      headlineSmall: KafooType.section,
      titleLarge: KafooType.section,
      titleMedium: KafooType.mealName,
      titleSmall: KafooType.label,
      bodyLarge: KafooType.bodyLarge,
      bodyMedium: KafooType.body,
      bodySmall: KafooType.bodySmall,
      labelLarge: KafooType.label,
      labelMedium: KafooType.label,
      labelSmall: KafooType.caption,
    ).apply(
      bodyColor: KafooColors.onSurface,
      displayColor: KafooColors.onSurface,
      fontFamily: KafooType.fontFamily,
      fontFamilyFallback: KafooType.fontFamilyFallback,
    );
