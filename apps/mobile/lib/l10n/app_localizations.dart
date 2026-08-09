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

  /// Names the kitchen behind a Meal on a browse card. 'Who cooked this' is the first question a Customer asks.
  ///
  /// In ar, this message translates to:
  /// **'من {kitchen}'**
  String browseKitchenLabel(String kitchen);

  /// Announced to a screen reader while the first load runs. Silence is indistinguishable from a broken app.
  ///
  /// In ar, this message translates to:
  /// **'بنجيب الأكل...'**
  String get browseLoading;

  /// FR-006. Shown when no Cook anywhere has a Meal on offer. Must be words rather than an empty screen, and must NOT be shown while the first load is running or for a failure. Customer-facing and UNGENDERED per ADR-0010: the first version said 'تعالى بص' — two masculine imperatives — which addressed every woman browsing as a man. First-person plural has no gender in Arabic, which is why the action lives on a button instead of in the sentence. FLAG: wants a native Cairene ear.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أكلات معروضة دلوقتي. ممكن نلاقي حاجة كمان شوية.'**
  String get browseNothingOnOffer;

  /// Retry button on the browse error state. Pull-to-refresh exposes no semantics action, so it cannot be the only way back. Customer-facing and ungendered per ADR-0010 — a bare imperative that is identical in both forms.
  ///
  /// In ar, this message translates to:
  /// **'جرب تاني'**
  String get browseRetry;

  /// Entry to signing in, shown to someone with no account. A bare verbal noun: ungendered per ADR-0010, and in the app's own register — 'تسجيل الدخول' was the MSA calque of the English and rendered a 352dp button on a 320dp screen at 200% text scale, clipping the title to nothing.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get browseSignInEntry;

  /// Title of the browse screen: the Meals Cooks currently have on offer. Customer-facing, so no addressForm select (ADR-0010).
  ///
  /// In ar, this message translates to:
  /// **'أكل النهاردة'**
  String get browseTitle;

  /// Shown to a Customer when the list of Meals on offer cannot be loaded. Customer-facing and ungendered per ADR-0010. States the fact only — the retry is browseRetry on a real button, because the previous copy promised a retry that nothing performed and the screen had no control to press.
  ///
  /// In ar, this message translates to:
  /// **'مش قادرين نعرض الأكل دلوقتي.'**
  String get discoveryLoadError;

  /// Shown to a Customer when search cannot run — the model provider is unreachable, or the request failed. Says search specifically rather than 'something went wrong', because the screen falls back to browsing and the Customer should be able to tell which of the two they are looking at. Customer-facing and ungendered per ADR-0010 — it read 'تقدر تتفرج' until 2026-08-07, which is masculine, in a string that predates the search screen and had been marked ungendered.
  ///
  /// In ar, this message translates to:
  /// **'البحث مش شغال دلوقتي، بس الفرجة على الأكل الموجود شغالة عادي.'**
  String get searchUnavailable;

  /// How a Meal card reads aloud. Composed here rather than in packages/ui so the separator follows the locale — a hardcoded Arabic comma is announced or mispaused by many English voices.
  ///
  /// In ar, this message translates to:
  /// **'{title}، {kitchen}، {price}'**
  String mealCardSemanticLabel(String kitchen, String price, String title);

  /// Action a Cook takes to move a Meal from draft to published.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{انشري الأكلة} other{انشر الأكلة}}'**
  String publishMeal(String addressForm);

  /// Action a Cook takes to retire a Meal. Never 'delete' — archived Meals stay readable for Order history.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{أرشفي الأكلة} other{أرشف الأكلة}}'**
  String archiveMeal(String addressForm);

  /// Action the owning Cook takes to agree to cook an Order.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{اقبلي الطلب} other{اقبل الطلب}}'**
  String acceptOrder(String addressForm);

  /// Action the owning Cook takes to decline an Order.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ارفضي الطلب} other{ارفض الطلب}}'**
  String rejectOrder(String addressForm);

  /// Shown to a Customer when a Cook rejects their Order. Actionable: names what to do next. Customer-directed verbs (جرب / اطلب; EN Try / order) stay ungendered in both branches — Kafoo stores no form of address for Customers; wiring those verbs to cookForm would be wrong. Only the Cook-describing clause differs by cookForm.
  ///
  /// In ar, this message translates to:
  /// **'{cookForm, select, feminine{الطباخة مقدرتش تاخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخة تانية.} other{الطباخ مقدرش ياخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخ تاني.}}'**
  String orderRejected(String cookForm);

  /// Shown when a request fails for connectivity reasons.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت. {addressForm, select, feminine{اطمني إن النت شغال وجربي} other{اطمن إن النت شغال وجرب}} تاني.'**
  String networkUnavailable(String addressForm);

  /// Shown beside calories and allergens whose source is 'ai'. An AI estimate is never presented as verified fact. cookForm describes the Cook who must confirm estimates, not the reader.
  ///
  /// In ar, this message translates to:
  /// **'دي تقديرات من المساعد الذكي، لسه محتاجة تأكيد من {cookForm, select, feminine{الطباخة.} other{الطباخ.}}'**
  String aiEstimateNotice(String cookForm);

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
  /// **'{addressForm, select, feminine{كمّلي} other{كمّل}}'**
  String signInContinue(String addressForm);

  /// Shown when Supabase rate-limits the OTP request. {minutes} is the wait time.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{جربت كتير. استني {minutes} دقيقة وبعدين جربي تاني.} other{جربت كتير. استنى {minutes} دقيقة وبعدين جرب تاني.}}'**
  String signInRateLimited(int minutes, String addressForm);

  /// Heading on the OTP code entry screen.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ادخلي الكود} other{ادخل الكود}}'**
  String codeTitle(String addressForm);

  /// Tells the person which number the OTP was sent to.
  ///
  /// In ar, this message translates to:
  /// **'اتبعتلك كود على رقم {phone}'**
  String codeSubtitle(String phone);

  /// Shown when the OTP is incorrect.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{الكود غلط. جربي تاني.} other{الكود غلط. جرب تاني.}}'**
  String codeWrongCode(String addressForm);

  /// Shown when the OTP has expired (distinct from wrong code).
  ///
  /// In ar, this message translates to:
  /// **'الكود انتهى. {addressForm, select, feminine{اطلبي} other{اطلب}} كود جديد.'**
  String codeExpired(String addressForm);

  /// Button to request a new OTP without restarting sign-in.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ابعتي كود جديد} other{ابعت كود جديد}}'**
  String codeResend(String addressForm);

  /// Shown when sign-in fails due to connectivity, not a wrong code.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت. {addressForm, select, feminine{اطمني إن النت شغال وجربي} other{اطمن إن النت شغال وجرب}} تاني.'**
  String signInNetworkError(String addressForm);

  /// First question in the Kitchen Profile conversation: the kitchen's display name.
  ///
  /// In ar, this message translates to:
  /// **'مطبخك اسمه إيه؟'**
  String get kitchenConvPromptDisplayName;

  /// Second question: the Cook's story — what they cook and how.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{قوليلي عن طبخك. بتعملي إيه وبتعمليه} other{قولّي عن طبخك. بتعمل إيه وبتعمله}} إزاي؟'**
  String kitchenConvPromptStory(String addressForm);

  /// Third question: which area the Cook operates in.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{في أنهي منطقة بتشتغلي؟} other{في أنهي منطقة بتشتغل؟}}'**
  String kitchenConvPromptArea(String addressForm);

  /// Fourth question: delivery or pickup terms.
  ///
  /// In ar, this message translates to:
  /// **'إزاي الناس بتاخد أكلها منك؟'**
  String get kitchenConvPromptDeliveryTerms;

  /// Fifth Kitchen Profile conversation question: asks which grammatical form of address to use. Deliberately first-person only so the question itself is not gendered. No addressForm placeholder.
  ///
  /// In ar, this message translates to:
  /// **'عشان أكلمك صح — أقولّك \"كمّل\" ولا \"كمّلي\"؟'**
  String get kitchenConvPromptAddressForm;

  /// Answer label choosing masculine form of address (ungendered label text).
  ///
  /// In ar, this message translates to:
  /// **'كمّل'**
  String get kitchenConvAddressFormMasculine;

  /// Answer label choosing feminine form of address (ungendered label text).
  ///
  /// In ar, this message translates to:
  /// **'كمّلي'**
  String get kitchenConvAddressFormFeminine;

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
  /// **'{addressForm, select, feminine{كمّلي} other{كمّل}}'**
  String convContinue(String addressForm);

  /// Shown next to the microphone button — prompts the Cook to speak.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{قولي إجابتك بصوتك} other{قول إجابتك بصوتك}}'**
  String convVoiceHint(String addressForm);

  /// Shown when on-device speech recognition is not available. Offers typing as a fallback.
  ///
  /// In ar, this message translates to:
  /// **'التعرف على الصوت مش متاح. ممكن {addressForm, select, feminine{تكتبي} other{تكتب}} إجابتك بدل كده.'**
  String convVoiceUnavailable(String addressForm);

  /// Heading on the summary screen shown after all questions are answered.
  ///
  /// In ar, this message translates to:
  /// **'ده اللي قلته'**
  String get kitchenConvSummaryTitle;

  /// Button to confirm the summary and write the Kitchen Profile.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{تمام، احفظي} other{تمام، احفظ}}'**
  String kitchenConvSummaryConfirm(String addressForm);

  /// Button to edit a single answer on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{غيّري} other{غيّر}}'**
  String convEdit(String addressForm);

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

  /// Label for the form-of-address row on the Kitchen Profile summary. Takes no placeholder: it names the setting rather than addressing the Cook, and the Cook may be about to change the very value it would switch on.
  ///
  /// In ar, this message translates to:
  /// **'طريقة مخاطبتك'**
  String get kitchenConvLabelAddressForm;

  /// Label for the optional photo on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'صورة المطبخ'**
  String get kitchenConvLabelPhoto;

  /// Button to add a kitchen photo on the summary screen.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ضيفي صورة} other{ضيف صورة}}'**
  String kitchenConvPhotoAdd(String addressForm);

  /// Shown if writing the Kitchen Profile to Supabase fails.
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة أثناء الحفظ. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String kitchenConvSaveError(String addressForm);

  /// Shown if photo upload fails. The Cook can proceed without a photo (T038 requirement).
  ///
  /// In ar, this message translates to:
  /// **'الصورة ما اتحملتش. ممكن {addressForm, select, feminine{تكملي} other{تكمل}} من غير صورة.'**
  String kitchenConvPhotoError(String addressForm);

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

  /// Heading on the Cook's own Kitchen Profile screen.
  ///
  /// In ar, this message translates to:
  /// **'مطبخك'**
  String get kitchenViewTitle;

  /// Labels the value as it stands now, kept visible while a change is being made (US5 scenario 2).
  ///
  /// In ar, this message translates to:
  /// **'الحالي'**
  String get kitchenEditCurrentValue;

  /// Labels the field holding the replacement value.
  ///
  /// In ar, this message translates to:
  /// **'الجديد'**
  String get kitchenEditNewValue;

  /// Button confirming a single-detail change.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{احفظي التغيير} other{احفظ التغيير}}'**
  String kitchenEditSave(String addressForm);

  /// Button abandoning a single-detail change, leaving the previous value in place.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get kitchenEditCancel;

  /// Brief confirmation shown after one detail changes.
  ///
  /// In ar, this message translates to:
  /// **'اتغيّر'**
  String get kitchenEditSaved;

  /// Entry point to account removal. Plain and literal — no euphemism, and no harder to find than creating the account was.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{امسحي حسابي} other{امسح حسابي}}'**
  String removeAccountEntry(String addressForm);

  /// Heading on the removal screen.
  ///
  /// In ar, this message translates to:
  /// **'مسح الحساب'**
  String get removeAccountTitle;

  /// States plainly what removal takes with it. No guilt, no retention offer, no reason field (FR-034).
  ///
  /// In ar, this message translates to:
  /// **'هيتمسح حسابك وكل حاجة فيه: مطبخك وصورته. مش هينفع نرجّعهم بعد كده.'**
  String get removeAccountBody;

  /// The single confirmation button. There is no second are-you-sure.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{امسحي حسابي} other{امسح حسابي}}'**
  String removeAccountConfirm(String addressForm);

  /// Leaves the removal screen with nothing changed. Removal is abandonable part-way (FR-035).
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get removeAccountCancel;

  /// Shown when removal fails. States that the account is intact, so nobody is left unsure whether they are half-erased.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نمسح الحساب. حسابك زي ما هو، {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String removeAccountError(String addressForm);

  /// Heading on the recovery email invitation, shown once after a Kitchen Profile is confirmed.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{تحبي تضيفي إيميل؟} other{تحب تضيف إيميل؟}}'**
  String recoveryEmailTitle(String addressForm);

  /// The one sentence FR-028 requires: plainly what it is for. Says it is optional in the same breath.
  ///
  /// In ar, this message translates to:
  /// **'لو ضاع منك رقمك، الإيميل هو اللي هيخليك {addressForm, select, feminine{توصلي لحسابك تاني. مش مطلوب، وممكن تسيبيه} other{توصل لحسابك تاني. مش مطلوب، وممكن تسيبه}} دلوقتي.'**
  String recoveryEmailBody(String addressForm);

  /// Label for the email input on the invitation.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل بتاعك'**
  String get recoveryEmailLabel;

  /// Button attaching the address to the existing account.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ضيفي الإيميل} other{ضيف الإيميل}}'**
  String recoveryEmailAttach(String addressForm);

  /// Button declining the invitation. Declining withholds nothing.
  ///
  /// In ar, this message translates to:
  /// **'مش دلوقتي'**
  String get recoveryEmailDecline;

  /// Shown after the address is attached and a confirmation message is sent.
  ///
  /// In ar, this message translates to:
  /// **'تمام، ابعتنا لك رسالة تأكيد على الإيميل.'**
  String get recoveryEmailAttached;

  /// Shown when attaching the address fails.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نضيف الإيميل. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String recoveryEmailError(String addressForm);

  /// Discreet route for someone who has lost their phone number. Speaks to the situation, not the mechanism — registration never mentions email (SC-009).
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{مش قادرة توصلي لرقمك؟} other{مش قادر توصل لرقمك؟}}'**
  String signInLostNumber(String addressForm);

  /// Heading on the email sign-in screen, reached only from the lost-number route.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ادخلي بالإيميل} other{ادخل بالإيميل}}'**
  String emailSignInTitle(String addressForm);

  /// Explains that this route works only for an address already attached from inside the account (FR-007).
  ///
  /// In ar, this message translates to:
  /// **'لو {addressForm, select, feminine{كنتي ضايفة إيميل لحسابك قبل كده، اكتبيه} other{كنت ضايف إيميل لحسابك قبل كده، اكتبه}} هنا وهنبعتلك كود.'**
  String emailSignInBody(String addressForm);

  /// Label for the email field on the email sign-in screen.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل'**
  String get emailSignInLabel;

  /// Shown when the address is not attached to any identity. An address can never claim an identity it was not attached to from within.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل ده مش مربوط بأي حساب. {addressForm, select, feminine{جربي تدخلي} other{جرب تدخل}} برقم موبايلك.'**
  String emailSignInUnknown(String addressForm);

  /// Heading on the change-of-number screen.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{غيّري رقم الموبايل} other{غيّر رقم الموبايل}}'**
  String changePhoneTitle(String addressForm);

  /// States that the old number stops reaching the identity immediately once confirmed (FR-026).
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{اكتبي الرقم الجديد. هنبعتلك كود عليه، ولما تأكديه} other{اكتب الرقم الجديد. هنبعتلك كود عليه، ولما تأكده}} الرقم القديم هيبطل يوصل لحسابك.'**
  String changePhoneBody(String addressForm);

  /// Label for the new phone number field.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الجديد'**
  String get changePhoneLabel;

  /// Entry point to the change-of-number flow.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{غيّري رقم الموبايل} other{غيّر رقم الموبايل}}'**
  String changePhoneEntry(String addressForm);

  /// Confirmation shown after the new number is verified.
  ///
  /// In ar, this message translates to:
  /// **'الرقم اتغيّر. الرقم القديم مبقاش يوصل لحسابك.'**
  String get changePhoneDone;

  /// Shown when the change fails, stating the old number still works.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نغيّر الرقم. رقمك القديم زي ما هو، {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String changePhoneError(String addressForm);

  /// Shown when the AI Assistant's reply fails schema validation. The Cook always has a working path without it.
  ///
  /// In ar, this message translates to:
  /// **'مش قادرين نفهم رد المساعد الذكي. {addressForm, select, feminine{جربي تاني، أو اكتبي} other{جرب تاني، أو اكتب}} التفاصيل بنفسك.'**
  String aiMealAnalysisInvalid(String addressForm);

  /// Shown when no provider is configured for a prompt. Reachable only from a misconfigured build, but a Cook must still be told something actionable.
  ///
  /// In ar, this message translates to:
  /// **'المساعد الذكي مش متاح دلوقتي. {addressForm, select, feminine{كملي} other{كمل}} بنفسك وهنجرب تاني بعدين.'**
  String aiPromptNotStubbed(String addressForm);

  /// Shown when the Edge Function rejects the request because the Cook is not signed in.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{سجّلي دخولك الأول وجربي} other{سجل دخولك الأول وجرب}} تاني.'**
  String analyzeMealUnauthorized(String addressForm);

  /// Shown when the Cook tries to analyze a Meal that belongs to someone else.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة دي مش ليك.'**
  String get analyzeMealNotOwned;

  /// Shown when the model provider rate-limits the request.
  ///
  /// In ar, this message translates to:
  /// **'جربت كتير في وقت قليل. {addressForm, select, feminine{استني شوية وجربي} other{استنى شوية وجرب}} تاني.'**
  String analyzeMealRateLimited(String addressForm);

  /// Shown when the model provider times out.
  ///
  /// In ar, this message translates to:
  /// **'الرد اخد وقت طويل. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String analyzeMealTimeout(String addressForm);

  /// Shown when the model provider returns a response that fails validation.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نفهم رد المساعد الذكي. {addressForm, select, feminine{جربي تاني، أو اكتبي} other{جرب تاني، أو اكتب}} التفاصيل بنفسك.'**
  String analyzeMealInvalidResponse(String addressForm);

  /// Shown when the model provider has an auth, upstream, or configuration error.
  ///
  /// In ar, this message translates to:
  /// **'المساعد الذكي مش متاح دلوقتي. {addressForm, select, feminine{جربي تاني بعدين، أو اكتبي} other{جرب تاني بعدين، أو اكتب}} التفاصيل بنفسك.'**
  String analyzeMealProviderError(String addressForm);

  /// Shown when Kafoo's own infrastructure has a problem (meal lookup, prompt missing, misconfigured).
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة من ناحيتنا. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String analyzeMealServerError(String addressForm);

  /// Fallback for any unrecognised error code from the Edge Function. A new code appearing later must degrade to a message, never to a crash.
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة مش متوقعة. {addressForm, select, feminine{جربي تاني، أو اكتبي} other{جرب تاني، أو اكتب}} التفاصيل بنفسك.'**
  String analyzeMealUnknownError(String addressForm);

  /// Shown when creating, updating, or publishing a Meal fails.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نحفظ الأكلة. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealSaveError(String addressForm);

  /// Shown when uploading a Meal photo fails. The Cook can proceed without a photo.
  ///
  /// In ar, this message translates to:
  /// **'الصورة ما اتحملتش. ممكن {addressForm, select, feminine{تكملي} other{تكمل}} من غير صورة.'**
  String mealPhotoError(String addressForm);

  /// First question in the Meal conversation: what the Cook made. Becomes the Meal's title.
  ///
  /// In ar, this message translates to:
  /// **'طبخت إيه؟'**
  String get mealConvPromptDish;

  /// Hint below the dish question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: كشري، محشي، فراخ بانيه'**
  String get mealConvHintDish;

  /// Second question: the description every AI-inferred field is derived from.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{قوليلي} other{قولّي}} عنها. فيها إيه وبتتعمل إزاي؟'**
  String mealConvPromptDescription(String addressForm);

  /// Hint below the description question.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: عدس ورز ومكرونة، وبنحمّر البصل فوقها'**
  String get mealConvHintDescription;

  /// Third question: the optional photograph. The only step a Cook may decline.
  ///
  /// In ar, this message translates to:
  /// **'في صورة للأكلة؟'**
  String get mealConvPromptPhoto;

  /// Hint below the photo question. Says plainly that it can be skipped.
  ///
  /// In ar, this message translates to:
  /// **'الصورة بتخلّي الناس تطلب أكتر، {addressForm, select, feminine{وتقدري تعدّيها لو مش عايزة} other{وتقدر تعدّيها لو مش عايز}}'**
  String mealConvHintPhoto(String addressForm);

  /// FR-029 disclosure, shown before a photo is used for estimates. Must appear before the Cook chooses.
  ///
  /// In ar, this message translates to:
  /// **'لو بعت صورة، المساعد هيبصّ عليها عشان يقدّر المكوّنات والسعرات، ومش هنستخدمها في أي حاجة تانية.'**
  String get mealConvPhotoDisclosure;

  /// Button that declines the photo and continues the conversation.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{كمّلي من غير صورة} other{كمّل من غير صورة}}'**
  String mealConvPhotoSkip(String addressForm);

  /// Button to attach a photo to a Meal during the conversation (T041).
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{ضيفي صورة للأكلة} other{ضيف صورة للأكلة}}'**
  String mealConvPhotoAdd(String addressForm);

  /// Fourth question: the price of the whole Meal.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{بتبيعيها بكام؟} other{بتبيعها بكام؟}}'**
  String mealConvPromptPrice(String addressForm);

  /// Hint below the price question. Says whole dish, matching how calories are estimated.
  ///
  /// In ar, this message translates to:
  /// **'سعر الطبق كامل بالجنيه'**
  String get mealConvHintPrice;

  /// Notice before fallback cuisine/category questions when the AI Assistant could not estimate them (T096/FR-014).
  ///
  /// In ar, this message translates to:
  /// **'المساعد مقدرش يعرف نوع الأكلة، فمحتاج أسألك سؤالين كمان.'**
  String get mealConvFallbackNotice;

  /// Fallback question: which cuisine the Meal belongs to, asked only when the estimate is missing.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة دي من أنهي مطبخ؟'**
  String get mealConvPromptCuisine;

  /// Hint below the fallback cuisine question.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{اختاري اللي أقرب لأكلتك} other{اختار اللي أقرب لأكلتك}}'**
  String mealConvHintCuisine(String addressForm);

  /// Fallback question: what sort of dish it is, asked only when the estimate is missing.
  ///
  /// In ar, this message translates to:
  /// **'ودي أكلة إيه؟ طبق رئيسي، حلو، شوربة؟'**
  String get mealConvPromptCategory;

  /// Hint below the fallback category question.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{اختاري اللي أقرب} other{اختار اللي أقرب}}'**
  String mealConvHintCategory(String addressForm);

  /// Heading of the Meal summary, shown before anything is on offer.
  ///
  /// In ar, this message translates to:
  /// **'ده اللي قلته عن الأكلة'**
  String get mealSummaryTitle;

  /// Label for the Meal's title on the summary.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة'**
  String get mealSummaryLabelDish;

  /// Label for the description on the summary.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get mealSummaryLabelDescription;

  /// Label for the photo row on the summary.
  ///
  /// In ar, this message translates to:
  /// **'الصورة'**
  String get mealSummaryLabelPhoto;

  /// Label for the price on the summary.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get mealSummaryLabelPrice;

  /// Shown in place of a photo when the Cook declined one.
  ///
  /// In ar, this message translates to:
  /// **'من غير صورة'**
  String get mealSummaryNoPhoto;

  /// Confirms the summary and puts the Meal on offer. FR-004: nothing is offered before this.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{تمام، انشريها} other{تمام، انشرها}}'**
  String mealSummaryConfirm(String addressForm);

  /// Display name for the cuisineEgyptian value.
  ///
  /// In ar, this message translates to:
  /// **'مصري'**
  String get cuisineEgyptian;

  /// Display name for the cuisineLevantine value.
  ///
  /// In ar, this message translates to:
  /// **'شامي'**
  String get cuisineLevantine;

  /// Display name for the cuisineGulf value.
  ///
  /// In ar, this message translates to:
  /// **'خليجي'**
  String get cuisineGulf;

  /// Display name for the cuisineSudanese value.
  ///
  /// In ar, this message translates to:
  /// **'سوداني'**
  String get cuisineSudanese;

  /// Display name for the cuisineMoroccan value.
  ///
  /// In ar, this message translates to:
  /// **'مغربي'**
  String get cuisineMoroccan;

  /// Display name for the cuisineTurkish value.
  ///
  /// In ar, this message translates to:
  /// **'تركي'**
  String get cuisineTurkish;

  /// Display name for the cuisineItalian value.
  ///
  /// In ar, this message translates to:
  /// **'إيطالي'**
  String get cuisineItalian;

  /// Display name for the cuisineAsian value.
  ///
  /// In ar, this message translates to:
  /// **'آسيوي'**
  String get cuisineAsian;

  /// Display name for the cuisineAmerican value.
  ///
  /// In ar, this message translates to:
  /// **'أمريكاني'**
  String get cuisineAmerican;

  /// Display name for the cuisineOther value.
  ///
  /// In ar, this message translates to:
  /// **'تاني'**
  String get cuisineOther;

  /// Display name for the categoryMain value.
  ///
  /// In ar, this message translates to:
  /// **'طبق رئيسي'**
  String get categoryMain;

  /// Display name for the categoryAppetizer value.
  ///
  /// In ar, this message translates to:
  /// **'مقبلات'**
  String get categoryAppetizer;

  /// Display name for the categorySoup value.
  ///
  /// In ar, this message translates to:
  /// **'شوربة'**
  String get categorySoup;

  /// Display name for the categorySalad value.
  ///
  /// In ar, this message translates to:
  /// **'سلطة'**
  String get categorySalad;

  /// Display name for the categorySide value.
  ///
  /// In ar, this message translates to:
  /// **'طبق جنب'**
  String get categorySide;

  /// Display name for the categoryDessert value.
  ///
  /// In ar, this message translates to:
  /// **'حلو'**
  String get categoryDessert;

  /// Display name for the categoryBakery value.
  ///
  /// In ar, this message translates to:
  /// **'مخبوزات'**
  String get categoryBakery;

  /// Display name for the categoryDrink value.
  ///
  /// In ar, this message translates to:
  /// **'مشروب'**
  String get categoryDrink;

  /// Display name for the categoryOther value.
  ///
  /// In ar, this message translates to:
  /// **'تاني'**
  String get categoryOther;

  /// Heading of the AI estimate section on the Meal summary.
  ///
  /// In ar, this message translates to:
  /// **'تقديرات المساعد'**
  String get mealSummaryEstimatesTitle;

  /// FR-012: AI-derived values are shown as estimates, never as verified fact.
  ///
  /// In ar, this message translates to:
  /// **'دي تقديرات من المساعد، مش حاجة مؤكدة. {addressForm, select, feminine{راجعيها وأكّديها قبل ما تنشري.} other{راجعها وأكّدها قبل ما تنشر.}}'**
  String mealSummaryEstimatesNotice(String addressForm);

  /// Marks a single value as an AI estimate rather than something the Cook said.
  ///
  /// In ar, this message translates to:
  /// **'تقدير'**
  String get mealSummaryEstimateBadge;

  /// Approves one AI estimate. Founder rule: each must be approved or edited before publishing.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get mealSummaryApprove;

  /// State of an estimate the Cook has already approved.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد'**
  String get mealSummaryApproved;

  /// Why the publish action is unavailable — estimates are still unapproved.
  ///
  /// In ar, this message translates to:
  /// **'لسه فيه تقديرات محتاجة موافقتك'**
  String get mealSummaryNeedsApproval;

  /// Label for the AI-suggested cuisine.
  ///
  /// In ar, this message translates to:
  /// **'نوع المطبخ'**
  String get mealSummaryLabelCuisine;

  /// Label for the AI-suggested category.
  ///
  /// In ar, this message translates to:
  /// **'نوع الطبق'**
  String get mealSummaryLabelCategory;

  /// Label for the AI-extracted ingredients.
  ///
  /// In ar, this message translates to:
  /// **'المكونات'**
  String get mealSummaryLabelIngredients;

  /// Label for the AI-estimated calories for the whole Meal.
  ///
  /// In ar, this message translates to:
  /// **'السعرات'**
  String get mealSummaryLabelCalories;

  /// Label for the AI-suggested allergens.
  ///
  /// In ar, this message translates to:
  /// **'الحساسية'**
  String get mealSummaryLabelAllergens;

  /// Calories with their unit. Never string-concatenate a number.
  ///
  /// In ar, this message translates to:
  /// **'{calories} سعرة'**
  String mealSummaryCaloriesValue(int calories);

  /// Shown when the AI Assistant produced nothing usable (FR-014).
  ///
  /// In ar, this message translates to:
  /// **'المساعد مقدرش يقدّر حاجة. {addressForm, select, feminine{اكتبي} other{اكتب}} التفاصيل بنفسك.'**
  String mealSummaryNoEstimates(String addressForm);

  /// Shown when putting the Meal on offer fails.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش ننشر الأكلة. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealPublishError(String addressForm);

  /// Confirms the Meal is now on offer.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة بقت على المنيو.'**
  String get mealPublishedConfirmation;

  /// The price of the whole Meal on the Customer's public view. The price is passed through as the exact string stored in the database — never reformatted, never rounded.
  ///
  /// In ar, this message translates to:
  /// **'{price} جنيه'**
  String publicMealPriceValue(String price);

  /// Link from a Meal to the Kitchen Profile of the Cook offering it (FR-025). Addresses the Customer in the second person (شوف / See). Kafoo stores no form of address for Customers; do not wire to addressForm or cookForm. Left ungendered on purpose.
  ///
  /// In ar, this message translates to:
  /// **'شوف المطبخ'**
  String get publicMealOpenKitchen;

  /// Shown when a Meal carries no calorie figure. A missing estimate is stated, never rendered as an empty row or a zero.
  ///
  /// In ar, this message translates to:
  /// **'السعرات مش متحسبة'**
  String get publicMealCaloriesUnknown;

  /// Shown when a Meal lists no allergens. Says nothing was listed rather than implying the Meal is safe — a Customer with an allergy must not read a blank as an all-clear. Customer-directed verb (اسأل / ask) stays ungendered in both branches — Kafoo stores no form of address for Customers; wiring it to cookForm would be wrong. Only الطباخ/الطباخة differs by cookForm.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حساسية متسجلة. لو عندك حساسية من حاجة، اسأل {cookForm, select, feminine{الطباخة.} other{الطباخ.}}'**
  String publicMealAllergensUnknown(String cookForm);

  /// Provenance line shown when nutrition_source is 'cook' — the Cook changed the figures, so they are theirs rather than an AI estimate. No Customer-directed verb. cookForm genders the Cook being described (الطباخ نفسه / الطباخة نفسها). Wiring this to the reader's form would be wrong.
  ///
  /// In ar, this message translates to:
  /// **'الأرقام دي من {cookForm, select, feminine{الطباخة نفسها.} other{الطباخ نفسه.}}'**
  String publicMealNutritionFromCook(String cookForm);

  /// Heading on the Cook's own list of Meals, showing every status including drafts.
  ///
  /// In ar, this message translates to:
  /// **'أكلاتي'**
  String get myMealsTitle;

  /// Shown when the Cook has no Meals at any status.
  ///
  /// In ar, this message translates to:
  /// **'لسه مافيش أكلات. {addressForm, select, feminine{ابدئي} other{ابدأ}} واحدة.'**
  String myMealsEmpty(String addressForm);

  /// Status word for a Meal still in draft, not yet on offer.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get myMealsStatusDraft;

  /// Status word for a Meal on offer and visible to Customers.
  ///
  /// In ar, this message translates to:
  /// **'على المنيو'**
  String get myMealsStatusPublished;

  /// Status word for a Meal temporarily off the menu.
  ///
  /// In ar, this message translates to:
  /// **'مش متاحة دلوقتي'**
  String get myMealsStatusUnavailable;

  /// Status word for a Meal retired permanently.
  ///
  /// In ar, this message translates to:
  /// **'اتشالت خلاص'**
  String get myMealsStatusArchived;

  /// Action a Cook takes to take a published Meal off the menu.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{شيليها من المنيو} other{شيلها من المنيو}}'**
  String mealMakeUnavailable(String addressForm);

  /// Action a Cook takes to put an unavailable Meal back on the menu.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{رجّعيها للمنيو} other{رجّعها للمنيو}}'**
  String mealMakeAvailable(String addressForm);

  /// Warning shown before a Cook takes their last Meal off the menu, explaining that their kitchen will become undiscoverable.
  ///
  /// In ar, this message translates to:
  /// **'دي آخر أكلة على المنيو. لو شيلتها، محدش هيلاقي مطبخك لحد ما {addressForm, select, feminine{ترجّعي} other{ترجّع}} حاجة.'**
  String mealLastOnOfferWarning(String addressForm);

  /// Confirmation button on the last-Meal warning dialog — proceeds with taking the Meal off the menu.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{شيليها برضه} other{شيلها برضه}}'**
  String mealLastOnOfferConfirm(String addressForm);

  /// Cancel button on the last-Meal warning dialog — leaves the Meal on the menu.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{سيبيها زي ما هي} other{سيبها زي ما هي}}'**
  String mealLastOnOfferCancel(String addressForm);

  /// Shown when fetching the Cook's own Meals fails.
  ///
  /// In ar, this message translates to:
  /// **'مانفعش نجيب أكلاتك. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealLoadError(String addressForm);

  /// Shown when changing a Meal's status fails.
  ///
  /// In ar, this message translates to:
  /// **'مانفعش نغير حالة الأكلة. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealAvailabilityError(String addressForm);

  /// Shown when deleting a draft Meal fails.
  ///
  /// In ar, this message translates to:
  /// **'مانفعش نمسح المسودة. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealDeleteError(String addressForm);

  /// Retries loading the Cook's own Meal list after a failure. Its own key rather than a borrowed one from the conversation flow — a retry button that says "continue" is copy rot.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{حاولي تاني} other{حاول تاني}}'**
  String mealLoadRetry(String addressForm);

  /// Action a Cook takes to retire a published or unavailable Meal permanently. Shown on the Cook's Meal list row.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{شيليها نهائي} other{شيلها نهائي}}'**
  String mealRetire(String addressForm);

  /// Warning shown in the retirement confirmation dialog. States plainly that the Meal leaves the menu for good but stays in the Cook's list.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة دي هتتشال من المنيو نهائي ومش هترجع تاني أبداً. هتفضل محفوظة في قايمتك بس محدش تاني هيشوفها.'**
  String get mealRetireWarning;

  /// Confirmation button on the retirement dialog. Same words as the action itself — plain and unambiguous rather than a riddle.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{شيليها نهائي} other{شيلها نهائي}}'**
  String mealRetireConfirm(String addressForm);

  /// Cancel button on the retirement dialog — leaves the Meal at its current status.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{سيبيها زي ما هي} other{سيبها زي ما هي}}'**
  String mealRetireCancel(String addressForm);

  /// Action a Cook takes to delete a draft Meal that was never on offer.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{امسحي المسودة} other{امسح المسودة}}'**
  String mealDeleteDraft(String addressForm);

  /// Warning shown in the draft-deletion confirmation dialog. States plainly that the draft is gone for good.
  ///
  /// In ar, this message translates to:
  /// **'المسودة دي هتتمسح خالص ومش {addressForm, select, feminine{هتقدري ترجعيها.} other{هتقدر ترجعها.}}'**
  String mealDeleteDraftWarning(String addressForm);

  /// Confirmation button on the draft-deletion dialog.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{امسحيها} other{امسحها}}'**
  String mealDeleteDraftConfirm(String addressForm);

  /// Heading on the Meal edit screen.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{عدّلي الأكلة} other{عدّل الأكلة}}'**
  String mealEditTitle(String addressForm);

  /// Brief confirmation shown after a single-field change on the Meal edit screen.
  ///
  /// In ar, this message translates to:
  /// **'اتغيّرت.'**
  String get mealEditSaved;

  /// Shown when a Cook closes an edit row without changing anything.
  ///
  /// In ar, this message translates to:
  /// **'مافيش حاجة اتغيّرت.'**
  String get mealEditNoChange;

  /// Heading shown when a Cook without a Kitchen Profile tries to offer a Meal (FR-017, T040).
  ///
  /// In ar, this message translates to:
  /// **'لسه معندكش مطبخ'**
  String get mealNeedsKitchenTitle;

  /// Body text explaining why a Kitchen Profile is needed before a Meal can be offered.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما {addressForm, select, feminine{تعرضي أكلة، الناس لازم تعرف مين اللي بيطبخها. اعملي مطبخك الأول وبعدين كمّلي.} other{تعرض أكلة، الناس لازم تعرف مين اللي بيطبخها. اعمل مطبخك الأول وبعدين كمّل.}}'**
  String mealNeedsKitchenBody(String addressForm);

  /// Button that opens the Kitchen Profile conversation so the Cook can create one.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{اعملي مطبخي} other{اعمل مطبخي}}'**
  String mealNeedsKitchenAction(String addressForm);

  /// Shown when the Kitchen Profile existence check fails (network or server error).
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نتأكد من مطبخك. {addressForm, select, feminine{جربي} other{جرب}} تاني.'**
  String mealKitchenCheckError(String addressForm);

  /// Button that re-runs the Kitchen Profile existence check.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{جربي تاني} other{جرب تاني}}'**
  String mealKitchenCheckRetry(String addressForm);

  /// Shown on a draft Meal in the Cook's list when the price question has not been answered yet.
  ///
  /// In ar, this message translates to:
  /// **'لسه من غير سعر'**
  String get myMealsNoPriceYet;

  /// Shown in place of a draft's dish name when the Cook has not answered the first question yet. The schema allows a title-less row, so the list must render one rather than break on it.
  ///
  /// In ar, this message translates to:
  /// **'مسودة من غير اسم'**
  String get myMealsUntitledDraft;

  /// Action a Cook takes on a draft Meal to resume the conversation where they left off, rather than starting a new one.
  ///
  /// In ar, this message translates to:
  /// **'{addressForm, select, feminine{كمّلي الأكلة دي} other{كمّل الأكلة دي}}'**
  String mealResumeDraft(String addressForm);

  /// Title of Kafoo's only Settings screen, and the tooltip on the way in. Customer-facing and ungendered per ADR-0010 — a bare noun.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// Label on the one switch Settings holds. Uses the SAME Arabic name for the AI Assistant as the five strings that already existed — a second name for one concept is what the glossary forbids, and introducing one in two new strings would have made it seven strings with two names. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'البحث بالمساعد الذكي'**
  String get settingsSearchTitle;

  /// FR-029c and FR-029e. Says what the switch does in terms of consequence: the words leave, and turning it off makes search UNAVAILABLE rather than worse. Customer-facing and ungendered per ADR-0010 — written in the first-person plural and the passive, because every second-person verb here carries gender. The habitual takes ب- in Egyptian: 'تفهم' without it is the MSA subjunctive and reads as a press release. FLAG: wants a native Cairene ear.
  ///
  /// In ar, this message translates to:
  /// **'علشان نلاقي الأكل المطلوب، الكلام اللي بيتكتب في البحث بيروح لخدمة بره كفو بتفهم معناه. لو ده مقفول، البحث مش هيشتغل، والفرجة على الأكل هتفضل شغالة زي ما هي.'**
  String get settingsSearchExplanation;

  /// FR-029d and SC-011. The part a Customer has no way to verify and every reason to want told. 'الكلام اللي بيتبحث بيه' was a passive built to dodge a gendered verb and read as machine translation; it borrows the phrasing settingsSearchExplanation already uses. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'الرد ده محفوظ على الموبايل ده بس. كفو مش بيسجل الكلام اللي بيتكتب في البحث، ولا بيحتفظ بالرد عنده.'**
  String get settingsSearchStorageNote;

  /// Label on the ONE search input, which carries the phrase, the exclusion and the area together. ADDRESSES NOBODY AT ALL, and that is the point: 'نفسك في إيه؟' is written identically for a woman and a man and PRONOUNCED nafsak or nafsik — and a TextField label is read aloud by TalkBack and VoiceOver, where Arabic text-to-speech will diacritise it masculine. ADR-0010's 'spelled identically' test was made for reading; this string is spoken. FLAG: it is colder than what it replaced, and the founder should hear both read aloud.
  ///
  /// In ar, this message translates to:
  /// **'أكل إيه النهاردة؟'**
  String get searchLabel;

  /// Example inside the search field, showing that one sentence carries all three things. Deliberately verbless — every Egyptian verb for wanting is gendered, and an example that addresses a man teaches the input is for men. Customer-facing and ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'حاجة سخنة من غير لحمة في المهندسين'**
  String get searchHint;

  /// Tooltip on the search button. A bare verbal noun: ungendered per ADR-0010, where the imperative دوّر/دوّري is not.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get searchAction;

  /// Announced to a screen reader while a search runs. Silence is indistinguishable from a broken app. First-person plural, which has no gender in Arabic.
  ///
  /// In ar, this message translates to:
  /// **'بندوّر على الأكل...'**
  String get searchRunning;

  /// Label on the microphone in search. A bare prepositional phrase rather than an imperative — اتكلم/اتكلمي is the gendered pair ADR-0010 rules out. Customer-facing.
  ///
  /// In ar, this message translates to:
  /// **'بالصوت'**
  String get searchVoiceHint;

  /// FR-008: typing is never the degraded path, and a missing Arabic speech locale is the likeliest real outcome on an Egyptian handset (research.md §3). Said plainly rather than left as a dead microphone. Names the phone rather than an abstraction, and avoids 'مش بيدعم', which is tech register. Customer-facing and ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مش شغال على الموبايل ده دلوقتي. الكتابة شغالة عادي.'**
  String get searchVoiceUnavailable;

  /// FR-029e. Shown when a Customer has refused. Says search is OFF, not that it is failing — and says browsing still works in the same breath, because the two are different things and only one of them has stopped. Ungendered per ADR-0010: تقدر/تقدري was replaced with ينفع, which has no addressee at all.
  ///
  /// In ar, this message translates to:
  /// **'البحث مقفول. ينفع يتفتح من الإعدادات في أي وقت، والتفرج على الأكل شغال زي ما هو.'**
  String get searchIsOff;

  /// FR-012: the fallback when nothing matched is browse. Says what happened and hands over to what is on offer underneath. 'بالوصف ده' was a calque of 'matching that description'. First-person plural, ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'ملقيناش حاجة زي كده. ده كل اللي معروض دلوقتي.'**
  String get searchFoundNothing;

  /// THE SENTENCE THE WHOLE EXCLUSION DESIGN EXISTS FOR. A negation Kafoo recognised without recognising the food must reach the Customer as words: without this the results look exactly like results for a request with no exclusion in it, and the Customer is served the thing they asked to avoid. Never says a Meal is safe. IT DOES NOT QUOTE THE WORD BACK, and that is a trade taken deliberately on 2026-08-07: the value `discover` carried was not a word but the whole remainder of the sentence after the negation marker, which crossed the network and landed in error bodies for a screen that only read whether it was set. Trust outranks actionability in the priority order, so the sentence earns its actionability from the closing clause instead. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'فهمنا إن في حاجة المفروض تتشال من الأكل، بس مش عارفين هي إيه — فما اتشالتش أي أكلة على أساسها. نجرب اسم الأكلة لوحده.'**
  String get searchExclusionNotUnderstood;

  /// STATES WHAT WAS FILTERED ON AND NEVER THAT A MEAL IS SAFE. meals.allergens is frequently an AI estimate carrying nutrition_source, so the strongest true statement is what was removed and where that came from. A Customer with an allergy is exactly the person who would act on a safety claim, which is why Kafoo does not make one about food it did not cook. THE PLACEHOLDER APPEARS TWICE ON PURPOSE: the closing clause said 'خالية منها', a feminine pronoun, and seven of the twelve exclusions are masculine — so the sentence that has to sound trustworthy carried an agreement error. Repeating the noun cannot disagree with itself. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'شيلنا الأكلات المكتوب فيها {food}. ده على حسب اللي الطباخين كتبوه وتقدير المساعد الذكي — مش معناه إن باقي الأكلات مفيهاش {food}.'**
  String searchFilteredOn(String food);

  /// Says what the search was narrowed to, in the Cook's own words. FR-024b: no distance, and no ordering by proximity — Kafoo holds no location for anyone. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'النتايج من {area} بس.'**
  String searchNarrowedToArea(String area);

  /// FR-024. Kafoo says the named area is empty rather than silently showing kitchens elsewhere. First-person negation, ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أكل معروض في {area} دلوقتي.'**
  String searchAreaEmpty(String area);

  /// FR-024a, FR-024b and FR-024c in one sentence. Names the areas that do have food and leaves the choosing to the Customer; states plainly that Kafoo holds no notion of distance and is not promising that anyone there delivers. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'بس في أكل في المناطق دي. كفو مش عارف المسافة بين المناطق، والتوصيل اتفاق بين الزبون والطباخ.'**
  String get searchAreaChoose;

  /// FR-029a. Asked ONCE, at the first attempt to search, and never on arrival — browsing must not require an answer. Says the words leave before they leave. TWO CORRECTIONS ON 2026-08-07. The reassurance read 'مش بيتسجل عندنا' one clause after naming the outside service, so a Customer would read it as covering that service, which Kafoo cannot promise anything about — Kafoo is now the named subject. And the whole thing said 'typed' while the same switch unlocks the microphone, so the speaking case is named. Ends in the first-person plural, which has no gender. FLAG: wants a native Cairene ear.
  ///
  /// In ar, this message translates to:
  /// **'علشان كفو يفهم الكلام ويلاقي الأكل المناسب، لازم يبعت اللي اتكتب في البحث لخدمة بره كفو. كفو نفسه مش بيسجل الكلام ده ولا بيحتفظ بيه. ولو الكلام اتقال بالصوت، الموبايل نفسه هو اللي بيحوّله لكتابة. نبعته؟'**
  String get searchConsentQuestion;

  /// Agreeing to the disclosure. Addressed to Kafoo in the plural, so it is ungendered per ADR-0010 while a Customer speaking about themselves would not be.
  ///
  /// In ar, this message translates to:
  /// **'أيوه، ابعتوه'**
  String get searchConsentAgree;

  /// Refusing. Same size and same prominence as agreeing — a refusal that is harder to reach than agreement is the dark pattern the trust rules forbid by name. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'لأ، متبعتوهوش'**
  String get searchConsentRefuse;

  /// FR-029c, FR-029d and FR-029e, under the question, so refusing is an informed answer rather than a leap. Future tense: at the moment this is read no answer exists yet, and this paragraph is the one making the promise about storage. Ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'لو الرد لأ، البحث مش هيشتغل والفرجة على الأكل هتفضل شغالة. الرد هيتحفظ على الموبايل ده بس، وينفع يتغير من الإعدادات في أي وقت.'**
  String get searchConsentNote;

  /// Turns an exclusion id into a word a Customer reads. The ids in packages/domain/lib/exclusion.dart are stable names that are never shown to anyone, so the interface cannot state what it filtered on without this. One ICU select rather than twelve keys, so a new exclusion is one line in two files rather than four. The `other` branch is what a Customer sees if the vocabulary gains an entry before this does — vague, and never wrong. Ungendered per ADR-0010. The shellfish branch enumerates rather than saying مأكولات بحرية, which means seafood and therefore includes fish — a SEPARATE exclusion that was not applied, so the one sentence whose job is to state exactly what was filtered would have overstated it.
  ///
  /// In ar, this message translates to:
  /// **'{food, select, meat{لحمة} chicken{فراخ} fish{سمك} shellfish{جمبري ومحار} egg{بيض} dairy{ألبان} peanut{فول سوداني} nuts{مكسرات} sesame{سمسم} gluten{جلوتين} onion{بصل} garlic{توم} other{الحاجة دي}}'**
  String exclusionName(String food);

  /// FR-005. Shown on top of a Meal that went off offer between being ranked and being opened — the one freshness case a Customer actually meets. Says what happened rather than showing an error, and the Meal stays on screen underneath because losing what somebody was reading is the worse answer. Customer-facing and ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة دي مبقتش معروضة. الطباخ شالها من المنيو دلوقتي.'**
  String get mealNoLongerOnOffer;

  /// FR-024a. Shown when a Customer's named area is empty AND Kafoo could not find out which areas do have food — the browse load failed, or no Cook wrote an area at all. It is NOT browseNothingOnOffer: telling a Customer the whole marketplace is empty when Kafoo simply has not been told is a lie by a different route, and it lands right after telling them their own area is empty. Customer-facing and ungendered per ADR-0010.
  ///
  /// In ar, this message translates to:
  /// **'مش قادرين نعرف دلوقتي المناطق اللي فيها أكل. جرب تاني كمان شوية.'**
  String get searchAreasUnknown;

  /// Shown above the results when the AI Assistant judges that none of them answers what the Customer asked for. THE RESULTS STAY ON SCREEN UNDERNEATH — the judgement says something about a set, it never edits one. No second person anywhere: Arabic marks gender on `you` and has no neutral form, so the sentence is about the food rather than about the person who asked. Says `زي كده` rather than `مطابقة للطلب`: the second is spec-sheet Modern Standard, and `الطلب` is Kafoo's word for an ORDER, so a Customer reads it as being about an Order they placed.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أكلة هنا زي كده بالظبط.'**
  String get searchJudgementNothingAnswers;

  /// The same sentence with the Meals the AI Assistant named instead — real titles of Meals already on the screen, never words a model wrote. `من اللي معروض` and not `الموجود`: the second claims these are everything on offer while up to 47 other Meals sit visible underneath it. THE JOINING GRAMMAR IS HERE AND NOT IN DART. It was a hardcoded `، ` in a widget, so the English locale rendered Arabic commas and never said `and` — Arabic repeats و before every item and English uses one `and` before the last, which is why no single separator can serve both. There is no full stop after the list: after a Latin-script title it resolves to the paragraph direction and lands to the LEFT of the name. EACH NAME IS INSIDE «…» BECAUSE A TITLE CAN ITSELF BE A CLAIM. A Cook who titles their Meal `الأكثر طلباً والأقرب ليك` would otherwise have Kafoo assert most-ordered and nearest-to-you in its own first-party voice, with no order counts and no location — FR-016 and FR-017 — and carry a gendered second person into a sentence that has none. Quoting does not make the words untrue, it makes clear who said them.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «{first}»} =2{مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «{first}» و«{second}»} other{مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «{first}» و«{second}» و«{third}»}}'**
  String searchJudgementAlternatives(
      int count, String first, String second, String third);
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
