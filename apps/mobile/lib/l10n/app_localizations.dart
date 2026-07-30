import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// The application name, shown in the task switcher.
  ///
  /// In ar, this message translates to:
  /// **'كفو'**
  String get appTitle;

  /// Action a Cook takes to move a Meal from draft to published.
  ///
  /// In ar, this message translates to:
  /// **'انشر الأكلة'**
  String get publishMeal;

  /// Action a Cook takes to retire a Meal. Never 'delete' — archived Meals stay readable for Order history.
  ///
  /// In ar, this message translates to:
  /// **'أرشف الأكلة'**
  String get archiveMeal;

  /// Action the owning Cook takes to agree to cook an Order.
  ///
  /// In ar, this message translates to:
  /// **'اقبل الطلب'**
  String get acceptOrder;

  /// Action the owning Cook takes to decline an Order.
  ///
  /// In ar, this message translates to:
  /// **'ارفض الطلب'**
  String get rejectOrder;

  /// Shown to a Customer when a Cook rejects their Order. Actionable: names what to do next.
  ///
  /// In ar, this message translates to:
  /// **'الطباخ مقدرش ياخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخ تاني.'**
  String get orderRejected;

  /// Shown when a request fails for connectivity reasons.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني.'**
  String get networkUnavailable;

  /// Shown beside calories and allergens whose source is 'ai'. An AI estimate is never presented as verified fact.
  ///
  /// In ar, this message translates to:
  /// **'دي تقديرات من المساعد الذكي، لسه محتاجة تأكيد من الطباخ.'**
  String get aiEstimateNotice;

  /// Heading on the phone-number sign-in screen.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بيك في كفو'**
  String get signInTitle;

  /// Label for the phone number input field.
  ///
  /// In ar, this message translates to:
  /// **'رقم موبايلك'**
  String get signInPhoneLabel;

  /// Button to submit the phone number and request an OTP.
  ///
  /// In ar, this message translates to:
  /// **'كمّل'**
  String get signInContinue;

  /// Shown when Supabase rate-limits the OTP request. {minutes} is the wait time.
  ///
  /// In ar, this message translates to:
  /// **'جربت كتير. استنى {minutes} دقيقة وبعدين جرب تاني.'**
  String signInRateLimited(int minutes);

  /// Heading on the OTP code entry screen.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الكود'**
  String get codeTitle;

  /// Tells the person which number the OTP was sent to.
  ///
  /// In ar, this message translates to:
  /// **'اتبعتلك كود على رقم {phone}'**
  String codeSubtitle(String phone);

  /// Shown when the OTP is incorrect.
  ///
  /// In ar, this message translates to:
  /// **'الكود غلط. جرب تاني.'**
  String get codeWrongCode;

  /// Shown when the OTP has expired (distinct from wrong code).
  ///
  /// In ar, this message translates to:
  /// **'الكود انتهى. اطلب كود جديد.'**
  String get codeExpired;

  /// Button to request a new OTP without restarting sign-in.
  ///
  /// In ar, this message translates to:
  /// **'ابعت كود جديد'**
  String get codeResend;

  /// Shown when sign-in fails due to connectivity, not a wrong code.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني.'**
  String get signInNetworkError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
