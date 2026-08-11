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
    // Explicit, because an unset tertiary resolves to `secondary` — the voice
    // teal, which ADR-0013 reserves to mean "the machine is talking". Any widget
    // reaching for tertiary would have spoken in the assistant's colour.
    tertiary: KafooColors.primaryDeep,
    onTertiary: KafooColors.onPrimary,
    tertiaryContainer: KafooColors.primaryTint,
    onTertiaryContainer: KafooColors.primaryDeep,
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
    // All six surfaceContainer roles were unset, so every one resolved to
    // `surface` and an M3 Dialog rendered at 1.00:1 against the page behind it —
    // no boundary at all except the scrim. ADR-0013 makes the confirmation gate
    // the one surface in Kafoo that must be unmistakably in front of everything
    // else, so a dialog with no edge is the worst possible slot to leave to a
    // fallback.
    surfaceContainerLowest: KafooColors.surfaceRaised,
    surfaceContainerLow: KafooColors.surfaceRaised,
    surfaceContainer: KafooColors.surfaceSunken,
    surfaceContainerHigh: KafooColors.surfaceRaised,
    surfaceContainerHighest: KafooColors.surfaceSunken,
    // TEXT-SAFE, AND THAT IS THE WHOLE POINT. This slot held `borderStrong`
    // for one afternoon — a 1.54:1 border colour — while THIRTEEN call sites in
    // the app read `colorScheme.outline` as a text colour. The old seeded theme
    // gave them 4.28:1; the border value gave them 1.54:1, which in a bright
    // kitchen is absent rather than faint.
    //
    // What went invisible: the "this is an AI estimate" notice beside allergens,
    // the sentence telling a Cook she must approve those estimates before
    // publishing, and her own Meal's draft/published status. Health-adjacent
    // guesses presented as fact, which business-rules.md calls out by name.
    //
    // So this slot is a text colour and must stay one. Anything drawing an
    // actual border names `KafooColors.border`, `borderStrong` or
    // `borderMeaningful` directly, and the token test asserts every ColorScheme
    // slot used as text clears AA.
    outline: KafooColors.textSubtle,
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
    // Pinned, so the tap-target floor cannot move with the platform.
    // adaptivePlatformDensity yields 48dp on a phone and 40dp on a desktop
    // target — which is what `apps/mobile/web/` renders as in a browser.
    visualDensity: VisualDensity.standard,
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
        minimumSize: _minTarget,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
        disabledBackgroundColor: KafooColors.disabledFill,
        disabledForegroundColor: KafooColors.textDisabled,
        // The sub-AA label is deliberate and WCAG exempts it. The fill is 1.17:1
        // against the page, though, so without this outline there is no
        // button-shaped thing at all — just faint letters, and "you cannot use
        // this yet" reads identically to "there is nothing here".
        disabledIconColor: KafooColors.textDisabled,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // primaryDeep, not primary: a label at 14–16px in terracotta sits too
        // light against the surface, and thin Arabic strokes make it worse.
        foregroundColor: KafooColors.primaryDeep,
        textStyle: KafooType.label,
        minimumSize: _minTarget,
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
        minimumSize: _minTarget,
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
      // All three agree at 16 on purpose. Material paints a floated label at
      // 0.75x, so a 16px label became an effective 12px once the field had
      // content — below the 13px floor this design system declares, on the one
      // remaining clue about what the field is for. floatingLabelStyle is set
      // explicitly to escape that multiplier.
      hintStyle: KafooType.body.copyWith(color: KafooColors.textSubtle),
      labelStyle: KafooType.body.copyWith(color: KafooColors.textMuted),
      floatingLabelStyle: KafooType.label.copyWith(
        fontSize: 14,
        color: KafooColors.textMuted,
      ),
      helperStyle: KafooType.bodySmall.copyWith(color: KafooColors.textMuted),
      errorStyle: KafooType.bodySmall.copyWith(color: KafooColors.danger),
      // borderMeaningful, not borderStrong: at 1.54:1 an empty field has no
      // visible edge in sunlight, and typing is what a Cook falls back to when
      // speech fails her. A boundary that is the only marker of an interactive
      // region has to clear 3:1.
      border: _inputBorder(KafooColors.borderMeaningful),
      enabledBorder: _inputBorder(KafooColors.borderMeaningful),
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
      // WidgetStateProperty, because only ChoiceChip consults
      // secondaryLabelStyle. FilterChip and InputChip take labelStyle — and a
      // non-null labelStyle makes them skip their own colour defaults — so a
      // selected filter chip was painted with NO colour at all over the
      // terracotta fill. Nobody could read which dietary filter was on. No chip
      // exists in the app yet; the trap was armed for whoever added the first.
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => KafooType.label.copyWith(
          color: states.contains(WidgetState.selected)
              ? KafooColors.onPrimary
              : KafooColors.onSurface,
        ),
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
    dialogTheme: DialogThemeData(
      backgroundColor: KafooColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KafooRadius.card),
        side: const BorderSide(color: KafooColors.borderMeaningful),
      ),
      titleTextStyle: KafooType.section.copyWith(color: KafooColors.onSurface),
      contentTextStyle: KafooType.body.copyWith(color: KafooColors.onSurface),
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

/// The button minimum.
///
/// **Not `Size.fromHeight`, which is `Size(double.infinity, 48)`.** That threw
/// "BoxConstraints forces an infinite width" for any button inside an unbounded
/// Row — so «أيوة» beside «لأ» on a confirmation gate would have been a red
/// screen — and it forced every button in the app to full width whether the
/// screen wanted that or not. A caller that wants full width says so with
/// `SizedBox(width: double.infinity)` or `Expanded`.
///
/// It is a default, not a guarantee: a parent `SizedBox(height: 36)` still wins,
/// because ConstrainedBox clamps a minimum against the incoming maximum. The
/// real check is the rendered-geometry assertion in the accessibility sweep.
const _minTarget = Size(64, KafooSpacing.minTapTarget);

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
