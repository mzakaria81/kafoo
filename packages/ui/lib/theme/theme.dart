import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Kafoo's [ThemeData].
///
/// This replaced `ColorScheme.fromSeed(seedColor: KafooColors.primary)`, and
/// the difference is not cosmetic. A seeded scheme keeps the seed and derives
/// every other colour from it by tonal mapping — so the surface, the error red,
/// and every container shade were Material's guesses, not the palette. Two of
/// those guesses actively contradict decisions the palette had already made:
/// the surface came out pure white rather than the warmed `#FFFBF7` that cuts
/// glare, and the error red came out in the same hue family as the terracotta
/// primary, which is exactly the collision `KafooColors.error` exists to avoid.
///
/// There is one theme, not a light/dark pair. Dark mode is deliberately
/// undefined: the primary usage context is bright daylight and a dark theme
/// built without that testing would be guesswork.
ThemeData kafooTheme({bool arabic = true}) {
  final textTheme = kafooTextTheme(arabic: arabic);

  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: KafooColors.primary,
      onPrimary: KafooColors.onPrimary,
      primaryContainer: KafooColors.primaryTint,
      onPrimaryContainer: KafooColors.primaryDeep,
      secondary: KafooColors.voice,
      onSecondary: KafooColors.onPrimary,
      secondaryContainer: KafooColors.voiceTint,
      onSecondaryContainer: KafooColors.voiceDeep,
      error: KafooColors.error,
      onError: KafooColors.onPrimary,
      errorContainer: KafooColors.errorTint,
      onErrorContainer: KafooColors.error,
      surface: KafooColors.surface,
      onSurface: KafooColors.onSurface,
      surfaceContainerLowest: KafooColors.surfaceRaised,
      surfaceContainerLow: KafooColors.surfaceSunken,
      onSurfaceVariant: KafooColors.textMuted,
      outline: KafooColors.borderInput,
      outlineVariant: KafooColors.border,
      scrim: KafooElevation.scrim,
    ),
    scaffoldBackgroundColor: KafooColors.surface,
    textTheme: textTheme,
    fontFamily: KafooType.fontFamily,
    fontFamilyFallback: KafooType.fontFamilyFallback,

    // Structure comes from a border, not a shadow: a soft shadow is nearly
    // invisible on a mid-range panel in direct sun, and a card whose only edge
    // is a shadow has no edge outdoors.
    cardTheme: CardThemeData(
      color: KafooColors.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KafooRadius.card),
        side: const BorderSide(color: KafooColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: KafooColors.border,
      thickness: 1,
      space: 1,
    ),

    // Padding, never a fixed height, so a button grows with scaled text instead
    // of clipping it. `minimumSize` sets the floor; `tapTargetSize` keeps the
    // 48dp target even where the visual is smaller.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KafooColors.primary,
        foregroundColor: KafooColors.onPrimary,
        disabledBackgroundColor: KafooColors.disabledFill,
        disabledForegroundColor: KafooColors.textDisabled,
        elevation: 0,
        minimumSize: const Size(0, KafooSpacing.minTapTarget),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KafooSpacing.lg,
          vertical: KafooSpacing.md,
        ),
        textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KafooColors.primaryDeep,
        disabledForegroundColor: KafooColors.textDisabled,
        minimumSize: const Size(0, KafooSpacing.minTapTarget),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: KafooColors.primaryTint,
        foregroundColor: KafooColors.primaryDeep,
        disabledForegroundColor: KafooColors.textDisabled,
        minimumSize: const Size(0, KafooSpacing.minTapTarget),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KafooSpacing.lg,
          vertical: KafooSpacing.md,
        ),
        textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        side: const BorderSide(color: KafooColors.primaryBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KafooColors.onSurface,
        minimumSize: const Size.square(KafooSpacing.minTapTarget),
      ),
    ),

    // Helper text always occupies its row, so an error message replaces it
    // rather than pushing the form down — a jumping form makes people lose
    // their place mid-entry.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KafooColors.surfaceRaised,
      helperMaxLines: 2,
      errorMaxLines: 2,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: KafooSpacing.md,
        vertical: 14,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: KafooColors.textSubtle),
      helperStyle: textTheme.labelSmall?.copyWith(color: KafooColors.textMuted),
      labelStyle: textTheme.labelLarge?.copyWith(color: KafooColors.textMuted),
      border: _inputBorder(KafooColors.borderInput),
      enabledBorder: _inputBorder(KafooColors.borderInput),
      focusedBorder: _inputBorder(KafooColors.primary),
      errorBorder: _inputBorder(KafooColors.error),
      focusedErrorBorder: _inputBorder(KafooColors.error),
      disabledBorder: _inputBorder(KafooColors.border),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KafooColors.surface,
      modalBarrierColor: KafooElevation.scrim,
      showDragHandle: true,
      dragHandleColor: KafooColors.borderStrong,
      dragHandleSize: Size(44, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KafooRadius.sheet),
        ),
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: KafooColors.surface,
      foregroundColor: KafooColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      shape: const Border(bottom: BorderSide(color: KafooColors.border)),
    ),

    // A chip is 40dp visually and 48dp to a finger. A row of 48dp-tall chips
    // looks like a row of buttons and dominates a screen it should merely
    // qualify — so the target is padded around the visual, not drawn as one.
    chipTheme: ChipThemeData(
      backgroundColor: KafooColors.surfaceRaised,
      selectedColor: KafooColors.primary,
      disabledColor: KafooColors.surfaceSunken,
      labelStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      secondaryLabelStyle: textTheme.labelLarge
          ?.copyWith(fontSize: 15, color: KafooColors.onPrimary),
      side: const BorderSide(color: KafooColors.borderStrong, width: 1.5),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KafooSpacing.md,
        vertical: 10,
      ),
      shape: const StadiumBorder(),
    ),

    // A chip is 40dp visually and 48dp to a finger; so is a small icon button.
    // Where the visual is smaller than the target, the target is padded around
    // it rather than the visual being grown to match.
    materialTapTargetSize: MaterialTapTargetSize.padded,

    // Nothing bounces or springs; a kitchen is calm.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(KafooRadius.control),
      borderSide: BorderSide(color: color, width: 1.5),
    );
