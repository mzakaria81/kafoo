import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/discovery/presentation/opened_meal.dart';
import 'features/discovery/presentation/search_screen.dart';
import 'features/identity/data/account_repository.dart';
import 'features/identity/presentation/sign_in_screen.dart';
import 'features/kitchen_profile/data/kitchen_profile_repository.dart';
import 'features/kitchen_profile/presentation/public_kitchen_view.dart';
import 'home.dart';
import 'l10n/address_form.dart';
import 'l10n/app_localizations.dart';

// URL and key come from --dart-define at build time. They must never be
// hardcoded or committed.
//
// The name below must match the --dart-define in docs/ops/verifying-e1.md. It read
// SUPABASE_ANON_KEY until 2026-08-02 while the runbook passed SUPABASE_PUBLISHABLE_KEY, so a build
// following the documented command got an empty key: String.fromEnvironment returns "" for a name
// nobody defined, and nothing complained. That is the reason for the check in main().
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // THE FONT'S LICENCE, WHERE A PERSON CAN READ IT.
  //
  // IBM Plex Sans Arabic ships under the SIL Open Font License, which asks that
  // the notice travel with the font. It does travel inside each .ttf, and the
  // OFL accepts that — but "inside a binary metadata table" is not somewhere
  // anybody looks. Flutter aggregates licences from Dart packages only, so an
  // app's own asset folder is invisible to its licences page unless registered.
  //
  // NOTHING ROUTES TO THE LICENCES PAGE YET, and that is a founder decision
  // rather than an oversight. `settings_screen.dart` says in terms that the next
  // entry added there is its own stop-and-ask, not a follow-on — so the entry
  // that would reach `showLicensePage` is waiting on approval.
  //
  // Registering it anyway is still the right half to do now: the registration is
  // what makes the notice available, it is correct whether or not a route
  // exists, and the alternative is remembering to come back. But do not describe
  // Kafoo's attribution as "visible to a user" until that route exists — today
  // it is visible inside the font files and to Flutter, and no further.
  LicenseRegistry.addLicense(() => Stream.value(
        const LicenseEntryWithLineBreaks(
          ['IBM Plex Sans Arabic'],
          'Copyright 2019 IBM Corp. All rights reserved.\n\n'
          'This Font Software is licensed under the SIL Open Font License, '
          'Version 1.1. This licence is available at '
          'https://openfontlicense.org and is also carried in the metadata of '
          'each bundled font file.\n\n'
          'IBM Plex is a trademark of IBM Corp., registered in many '
          'jurisdictions worldwide. "Plex" is a Reserved Font Name under the '
          'OFL: a modified version of these faces — including a subset — must '
          'not carry it.',
        ),
      ));

  // Fail here, loudly, rather than at the first request with a confusing auth error. A missing
  // --dart-define is a build mistake, and an app that cannot reach Supabase cannot do anything
  // useful — so refusing to start is the honest outcome, not a harsh one.
  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase is not configured. Build with '
      '--dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_PUBLISHABLE_KEY=... '
      '(see docs/ops/verifying-e1.md).',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  // A ProviderScope, WHICH THE APP DID NOT HAVE. Every `@riverpod` provider in Kafoo reads
  // through one, and browse became the signed-out home in E3 as a ConsumerWidget — so the app
  // threw on its first frame for anyone without an account. Nothing caught it: `app_test` skips
  // `KafooApp` because `_AuthGate` needs a live Supabase, and every widget test builds its own
  // scope. A screen tested in isolation is not a screen that has been run.
  runApp(const ProviderScope(child: KafooApp()));
}

/// The Kafoo application root.
///
/// Egyptian Arabic is the default locale, not a fallback, so [locale] is fixed
/// to `ar` and every screen below must render correctly right-to-left.
class KafooApp extends StatelessWidget {
  const KafooApp({
    this.authState,
    this.accountRepository = const SupabaseAccountRepository(),
    this.kitchenProfileRepository = const SupabaseKitchenProfileRepository(),
    super.key,
  });

  /// The auth stream the gate listens to. Null means the real one.
  ///
  /// **THIS EXISTS SO THE APP CAN BE BOOTED IN A TEST**, which it could not be
  /// until 2026-08-10. `app_test.dart` said so in a comment — "KafooApp includes
  /// _AuthGate which requires a live Supabase instance" — and skipped the root
  /// entirely. Every widget test therefore built one screen with its own fakes,
  /// and the gate never once ran the app as a whole.
  ///
  /// Five defects in a single day came out of exactly that gap, all of them
  /// invisible to a green build and all of them obvious to a person holding a
  /// phone: the icon font that rendered as Chinese characters, the missing
  /// `ProviderScope`, four Cook screens with no route into them, a theme no test
  /// rendered through, and a correct sign-in code that navigated nowhere.
  ///
  /// A screen tested alone proves the screen. Only the app tested whole proves
  /// the seams, and the seams are where every one of those lived.
  final Stream<AuthState>? authState;

  /// Injected for the same reason.
  final AccountRepository accountRepository;
  final KitchenProfileRepository kitchenProfileRepository;

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
      // The design system, not Material's guess at it. `ColorScheme.fromSeed`
      // stood here until 2026-08-10: it derived twenty-odd colours from the one
      // terracotta seed and used none of the values anybody had chosen, in
      // whatever font the handset happened to install. See ADR-0013 and
      // `docs/design/DESIGN.md`.
      //
      // `arabic: true` because [locale] above is pinned to `ar` — Arabic
      // line-heights run higher than Latin and the two must not be unified. If
      // the locale is ever unpinned, this follows it.
      theme: kafooTheme(arabic: true),
      // Above the Navigator on purpose. A pushed route is not a descendant of
      // the widget that pushed it, so a scope placed inside [home] would be
      // invisible to every screen reached by pushing — which is all of them.
      builder: (context, child) => _AddressFormLoader(
        authState: authState,
        repository: kitchenProfileRepository,
        child: child!,
      ),
      home: _AuthGate(
        authState: authState,
        accountRepository: accountRepository,
        kitchenProfileRepository: kitchenProfileRepository,
      ),
    );
  }
}

/// Routes between sign-in and the signed-in surface based on auth state.
/// Uses [Supabase.instance.client.auth.onAuthStateChange] — a stream and a
/// builder, no state-management package (E1 deliberate decision, research.md §7).
class _AuthGate extends StatelessWidget {
  const _AuthGate({
    this.authState,
    required this.accountRepository,
    required this.kitchenProfileRepository,
  });

  final Stream<AuthState>? authState;
  final AccountRepository accountRepository;
  final KitchenProfileRepository kitchenProfileRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authState ?? Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return SignedInHome(
            kitchenProfileRepository: kitchenProfileRepository,
          );
        }
        // Signed out, a person sees FOOD, not a sign-in form.
        //
        // This changed in E3 and it is the most visible decision in the epic.
        // Discovery works without an account by design — the read policies
        // cover `anon`, and the whole reason Kafoo has a surface reachable
        // without installing anything is that a person arriving from a shared
        // link is the least willing to sign up first. SC-001 makes it a
        // requirement rather than a preference: a Meal's full details must be
        // reachable within three actions of arriving, WITHOUT signing in.
        // Putting a sign-in form in front of that would fail it by one action
        // and, worse, would ask for a commitment before showing anything worth
        // committing to.
        //
        // Signing in stays one tap away, in the bar, for the Cook who came
        // here to cook.
        return _SignedOutHome(accountRepository: accountRepository);
      },
    );
  }
}

/// Reads the signed-in Cook's form of address once, and publishes it to
/// everything below.
///
/// It renders its child immediately in the unset form and swaps in the stored
/// one when the read lands, rather than holding a spinner over the whole
/// signed-in surface. A grammatical preference is not worth a blocked first
/// frame against a 2 s launch budget, and the unset form is a correct sentence
/// rather than a placeholder — so the worst case is one repaint, not a flash of
/// something wrong.
///
/// Someone who is not a Cook has no Kitchen Profile and therefore no stored
/// form. They get `other`, which is the same answer they got before this
/// existed.
class _AddressFormLoader extends StatefulWidget {
  const _AddressFormLoader({
    required this.child,
    required this.repository,
    this.authState,
  });

  final KitchenProfileRepository repository;

  /// Injected for the same reason as [KafooApp.authState] — this loader reached
  /// `Supabase.instance` directly and was the last thing keeping the app root
  /// out of a test.
  final Stream<AuthState>? authState;

  final Widget child;

  @override
  State<_AddressFormLoader> createState() => _AddressFormLoaderState();
}

class _AddressFormLoaderState extends State<_AddressFormLoader> {
  late final StreamSubscription<AuthState> _auth;
  AddressForm? _form;

  @override
  void initState() {
    super.initState();
    // Re-read on every auth change rather than once at startup. Signing in is
    // what makes a Kitchen Profile readable at all, and signing out must drop
    // the previous Cook's form — otherwise the next person on the same device
    // is addressed in a stranger's grammar.
    _auth =
        (widget.authState ?? Supabase.instance.client.auth.onAuthStateChange)
            .listen((_) {
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    unawaited(_auth.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.repository.findMine();
    if (!mounted) return;
    // A failed read is not worth surfacing: the consequence is that a Cook is
    // addressed in the unset form for this launch, which every Cook was until
    // ADR-0010. Blocking the home screen on it would be the larger failure.
    final form = switch (result) {
      Success(value: final profile?) => profile.addressForm,
      _ => null,
    };
    if (form != _form) setState(() => _form = form);
  }

  @override
  Widget build(BuildContext context) => AddressFormScope(
        form: icuAddressForm(_form),
        child: widget.child,
      );
}

/// What a person sees before they have an account.
///
/// Browsing, and a way in. See the note in [_AuthGate] for why this is food
/// rather than a form.
class _SignedOutHome extends StatelessWidget {
  const _SignedOutHome({required this.accountRepository});

  final AccountRepository accountRepository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SearchScreen(
      entry: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignInScreen(repository: accountRepository),
          ),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        child: Text(l10n.browseSignInEntry),
      ),
      // OpenedMeal rather than PublicMealView directly, so a Meal that went off
      // offer between being ranked and being opened says so — FR-005. It passes
      // the Cook's OWN stored form on, which PublicMealView makes required
      // precisely so E3 could not default it and describe a Cook in a
      // stranger's grammar (ADR-0010).
      onOpen: (item) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OpenedMeal(
            item: item,
            onOpenKitchen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PublicKitchenView(profile: item.kitchen),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
