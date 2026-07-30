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

  /// First question in the Kitchen Profile conversation: the kitchen's display name.
  ///
  /// In ar, this message translates to:
  /// **'مطبخك اسمه إيه؟'**
  String get kitchenConvPromptDisplayName;

  /// Second question: the Cook's story — what they cook and how.
  ///
  /// In ar, this message translates to:
  /// **'قولّي عن طبخك. بتعمل إيه وبتعمله إزاي؟'**
  String get kitchenConvPromptStory;

  /// Third question: which area the Cook operates in.
  ///
  /// In ar, this message translates to:
  /// **'في أنهي منطقة بتشتغل؟'**
  String get kitchenConvPromptArea;

  /// Fourth question: delivery or pickup terms.
  ///
  /// In ar, this message translates to:
  /// **'إزاي الناس بتاخد أكلها منك؟'**
  String get kitchenConvPromptDeliveryTerms;

  /// Hint text shown below the display name question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: مطبخ أم علي'**
  String get kitchenConvHintDisplayName;

  /// Hint text shown below the story question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: بنطبخ أكل بيتي على الطريقة القديمة'**
  String get kitchenConvHintStory;

  /// Hint text shown below the area question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: المعادي، مصر الجديدة'**
  String get kitchenConvHintArea;

  /// Hint text shown below the delivery terms question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: بنوصّل في ساعة أو بتيجي تاخد بنفسك'**
  String get kitchenConvHintDeliveryTerms;

  /// Button to confirm the current answer and proceed to the next step.
  ///
  /// In ar, this message translates to:
  /// **'كمّل'**
  String get kitchenConvContinue;

  /// Shown next to the microphone button — prompts the Cook to speak.
  ///
  /// In ar, this message translates to:
  /// **'قول إجابتك بصوتك'**
  String get kitchenConvVoiceHint;

  /// Shown when on-device speech recognition is not available. Offers typing as a fallback.
  ///
  /// In ar, this message translates to:
  /// **'التعرف على الصوت مش متاح. ممكن تكتب إجابتك بدل كده.'**
  String get kitchenConvVoiceUnavailable;

  /// Heading on the summary screen shown after all questions are answered.
  ///
  /// In ar, this message translates to:
  /// **'ده اللي قلته'**
  String get kitchenConvSummaryTitle;

  /// Button to confirm the summary and write the Kitchen Profile.
  ///
  /// In ar, this message translates to:
  /// **'تمام، احفظ'**
  String get kitchenConvSummaryConfirm;

  /// Button to edit a single answer on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'غيّر'**
  String get kitchenConvSummaryEdit;

  /// Label for the display name field on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'اسم المطبخ'**
  String get kitchenConvLabelDisplayName;

  /// Label for the story field on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'قصتك'**
  String get kitchenConvLabelStory;

  /// Label for the area field on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get kitchenConvLabelArea;

  /// Label for the delivery terms field on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الاستلام'**
  String get kitchenConvLabelDeliveryTerms;

  /// Label for the optional photo on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'صورة المطبخ'**
  String get kitchenConvLabelPhoto;

  /// Button to add a kitchen photo on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'ضيف صورة'**
  String get kitchenConvPhotoAdd;

  /// Shown if writing the Kitchen Profile to Supabase fails.
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة أثناء الحفظ. جرب تاني.'**
  String get kitchenConvSaveError;

  /// Shown if photo upload fails. The Cook can proceed without a photo (T038 requirement).
  ///
  /// In ar, this message translates to:
  /// **'الصورة ما اتحملتش. ممكن تكمل من غير صورة.'**
  String get kitchenConvPhotoError;

  /// Heading shown when a person who already has a Kitchen Profile tries to create another.
  ///
  /// In ar, this message translates to:
  /// **'عندك مطبخ بالفعل'**
  String get kitchenExistsTitle;

  /// Body text shown when redirecting an existing Cook to their own Kitchen Profile (T039, FR-009).
  ///
  /// In ar, this message translates to:
  /// **'عندك مطبخ مسجّل على حسابك. هنروحله دلوقتي.'**
  String get kitchenExistsBody;
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
