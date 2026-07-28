import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kafoo_ui/ui.dart';

void main() {
  runApp(const KafooApp());
}

/// The Kafoo application root.
///
/// Egyptian Arabic is the default locale, not a fallback, so [locale] is fixed
/// to `ar` and every screen below must render correctly right-to-left.
class KafooApp extends StatelessWidget {
  /// Creates the application root.
  const KafooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => 'Kafoo',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: KafooColors.primary),
        useMaterial3: true,
      ),
      home: const _Placeholder(),
    );
  }
}

/// Temporary landing surface until the first feature lands.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Text('كفو'),
        ),
      ),
    );
  }
}
