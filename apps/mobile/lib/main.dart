import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/identity/presentation/remove_account_screen.dart';
import 'features/identity/presentation/sign_in_screen.dart';
import 'features/kitchen_profile/presentation/conversation.dart';
import 'l10n/app_localizations.dart';

// URL and key come from --dart-define at build time. They must never be
// hardcoded or committed.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  runApp(const KafooApp());
}

/// The Kafoo application root.
///
/// Egyptian Arabic is the default locale, not a fallback, so [locale] is fixed
/// to `ar` and every screen below must render correctly right-to-left.
class KafooApp extends StatelessWidget {
  const KafooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => 'Kafoo',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: KafooColors.primary),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Routes between sign-in and the signed-in surface based on auth state.
/// Uses [Supabase.instance.client.auth.onAuthStateChange] — a stream and a
/// builder, no state-management package (E1 deliberate decision, research.md §7).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return const _SignedInHome();
        }
        return const SignInScreen();
      },
    );
  }
}

/// The signed-in surface.
///
/// Deliberately thin — browsing and Meals arrive in later epics. What it must
/// carry now is the two things E1 delivers: becoming a Cook, and leaving.
class _SignedInHome extends StatelessWidget {
  const _SignedInHome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KitchenConversationScreen(),
                  ),
                ),
                child: Text(l10n.kitchenViewTitle),
              ),
              const Spacer(),
              // SC-011: leaving is reachable in one step from the first screen
              // after signing in — no deeper than joining was. It is not buried
              // under a settings tree, because burying it is the dark pattern
              // this requirement exists to prevent.
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: KafooColors.danger,
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemoveAccountScreen(),
                  ),
                ),
                child: Text(l10n.removeAccountEntry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
