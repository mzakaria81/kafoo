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
  String get convContinue;

  /// Shown next to the microphone button — prompts the Cook to speak.
  ///
  /// In ar, this message translates to:
  /// **'قول إجابتك بصوتك'**
  String get convVoiceHint;

  /// Shown when on-device speech recognition is not available. Offers typing as a fallback.
  ///
  /// In ar, this message translates to:
  /// **'التعرف على الصوت مش متاح. ممكن تكتب إجابتك بدل كده.'**
  String get convVoiceUnavailable;

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
  String get convEdit;

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
  /// **'احفظ التغيير'**
  String get kitchenEditSave;

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
  /// **'امسح حسابي'**
  String get removeAccountEntry;

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
  /// **'امسح حسابي'**
  String get removeAccountConfirm;

  /// Leaves the removal screen with nothing changed. Removal is abandonable part-way (FR-035).
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get removeAccountCancel;

  /// Shown when removal fails. States that the account is intact, so nobody is left unsure whether they are half-erased.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نمسح الحساب. حسابك زي ما هو، جرب تاني.'**
  String get removeAccountError;

  /// Heading on the recovery email invitation, shown once after a Kitchen Profile is confirmed.
  ///
  /// In ar, this message translates to:
  /// **'تحب تضيف إيميل؟'**
  String get recoveryEmailTitle;

  /// The one sentence FR-028 requires: plainly what it is for. Says it is optional in the same breath.
  ///
  /// In ar, this message translates to:
  /// **'لو ضاع منك رقمك، الإيميل هو اللي هيخليك توصل لحسابك تاني. مش مطلوب، وممكن تسيبه دلوقتي.'**
  String get recoveryEmailBody;

  /// Label for the email input on the invitation.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل بتاعك'**
  String get recoveryEmailLabel;

  /// Button attaching the address to the existing account.
  ///
  /// In ar, this message translates to:
  /// **'ضيف الإيميل'**
  String get recoveryEmailAttach;

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
  /// **'مقدرناش نضيف الإيميل. جرب تاني.'**
  String get recoveryEmailError;

  /// Discreet route for someone who has lost their phone number. Speaks to the situation, not the mechanism — registration never mentions email (SC-009).
  ///
  /// In ar, this message translates to:
  /// **'مش قادر توصل لرقمك؟'**
  String get signInLostNumber;

  /// Heading on the email sign-in screen, reached only from the lost-number route.
  ///
  /// In ar, this message translates to:
  /// **'ادخل بالإيميل'**
  String get emailSignInTitle;

  /// Explains that this route works only for an address already attached from inside the account (FR-007).
  ///
  /// In ar, this message translates to:
  /// **'لو كنت ضايف إيميل لحسابك قبل كده، اكتبه هنا وهنبعتلك كود.'**
  String get emailSignInBody;

  /// Label for the email field on the email sign-in screen.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل'**
  String get emailSignInLabel;

  /// Shown when the address is not attached to any identity. An address can never claim an identity it was not attached to from within.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل ده مش مربوط بأي حساب. جرب تدخل برقم موبايلك.'**
  String get emailSignInUnknown;

  /// Heading on the change-of-number screen.
  ///
  /// In ar, this message translates to:
  /// **'غيّر رقم الموبايل'**
  String get changePhoneTitle;

  /// States that the old number stops reaching the identity immediately once confirmed (FR-026).
  ///
  /// In ar, this message translates to:
  /// **'اكتب الرقم الجديد. هنبعتلك كود عليه، ولما تأكده الرقم القديم هيبطل يوصل لحسابك.'**
  String get changePhoneBody;

  /// Label for the new phone number field.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الجديد'**
  String get changePhoneLabel;

  /// Entry point to the change-of-number flow.
  ///
  /// In ar, this message translates to:
  /// **'غيّر رقم الموبايل'**
  String get changePhoneEntry;

  /// Confirmation shown after the new number is verified.
  ///
  /// In ar, this message translates to:
  /// **'الرقم اتغيّر. الرقم القديم مبقاش يوصل لحسابك.'**
  String get changePhoneDone;

  /// Shown when the change fails, stating the old number still works.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نغيّر الرقم. رقمك القديم زي ما هو، جرب تاني.'**
  String get changePhoneError;

  /// Shown when the AI Assistant's reply fails schema validation. The Cook always has a working path without it.
  ///
  /// In ar, this message translates to:
  /// **'مش قادرين نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك.'**
  String get aiMealAnalysisInvalid;

  /// Shown when no provider is configured for a prompt. Reachable only from a misconfigured build, but a Cook must still be told something actionable.
  ///
  /// In ar, this message translates to:
  /// **'المساعد الذكي مش متاح دلوقتي. كمل بنفسك وهنجرب تاني بعدين.'**
  String get aiPromptNotStubbed;

  /// Shown when the Edge Function rejects the request because the Cook is not signed in.
  ///
  /// In ar, this message translates to:
  /// **'سجل دخولك الأول وجرب تاني.'**
  String get analyzeMealUnauthorized;

  /// Shown when the Cook tries to analyze a Meal that belongs to someone else.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة دي مش ليك.'**
  String get analyzeMealNotOwned;

  /// Shown when the model provider rate-limits the request.
  ///
  /// In ar, this message translates to:
  /// **'جربت كتير في وقت قليل. استنى شوية وجرب تاني.'**
  String get analyzeMealRateLimited;

  /// Shown when the model provider times out.
  ///
  /// In ar, this message translates to:
  /// **'الرد اخد وقت طويل. جرب تاني.'**
  String get analyzeMealTimeout;

  /// Shown when the model provider returns a response that fails validation.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك.'**
  String get analyzeMealInvalidResponse;

  /// Shown when the model provider has an auth, upstream, or configuration error.
  ///
  /// In ar, this message translates to:
  /// **'المساعد الذكي مش متاح دلوقتي. جرب تاني بعدين، أو اكتب التفاصيل بنفسك.'**
  String get analyzeMealProviderError;

  /// Shown when Kafoo's own infrastructure has a problem (meal lookup, prompt missing, misconfigured).
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة من ناحيتنا. جرب تاني.'**
  String get analyzeMealServerError;

  /// Fallback for any unrecognised error code from the Edge Function. A new code appearing later must degrade to a message, never to a crash.
  ///
  /// In ar, this message translates to:
  /// **'حصل مشكلة مش متوقعة. جرب تاني، أو اكتب التفاصيل بنفسك.'**
  String get analyzeMealUnknownError;

  /// Shown when creating, updating, or publishing a Meal fails.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نحفظ الأكلة. جرب تاني.'**
  String get mealSaveError;

  /// Shown when uploading a Meal photo fails. The Cook can proceed without a photo.
  ///
  /// In ar, this message translates to:
  /// **'الصورة ما اتحملتش. ممكن تكمل من غير صورة.'**
  String get mealPhotoError;

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
  /// **'قولّي عنها. فيها إيه وبتتعمل إزاي؟'**
  String get mealConvPromptDescription;

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
  /// **'الصورة بتخلّي الناس تطلب أكتر، وتقدر تعدّيها لو مش عايز'**
  String get mealConvHintPhoto;

  /// FR-029 disclosure, shown before a photo is used for estimates. Must appear before the Cook chooses.
  ///
  /// In ar, this message translates to:
  /// **'لو بعت صورة، المساعد هيبصّ عليها عشان يقدّر المكوّنات والسعرات، ومش هنستخدمها في أي حاجة تانية.'**
  String get mealConvPhotoDisclosure;

  /// Button that declines the photo and continues the conversation.
  ///
  /// In ar, this message translates to:
  /// **'كمّل من غير صورة'**
  String get mealConvPhotoSkip;

  /// Fourth question: the price of the whole Meal.
  ///
  /// In ar, this message translates to:
  /// **'بتبيعها بكام؟'**
  String get mealConvPromptPrice;

  /// Hint below the price question. Says whole dish, matching how calories are estimated.
  ///
  /// In ar, this message translates to:
  /// **'سعر الطبق كامل بالجنيه'**
  String get mealConvHintPrice;

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
  /// **'تمام، انشرها'**
  String get mealSummaryConfirm;

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
  /// **'دي تقديرات من المساعد، مش حاجة مؤكدة. راجعها وأكّدها قبل ما تنشر.'**
  String get mealSummaryEstimatesNotice;

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
  /// **'المساعد مقدرش يقدّر حاجة. اكتب التفاصيل بنفسك.'**
  String get mealSummaryNoEstimates;

  /// Shown when putting the Meal on offer fails.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش ننشر الأكلة. جرب تاني.'**
  String get mealPublishError;

  /// Confirms the Meal is now on offer.
  ///
  /// In ar, this message translates to:
  /// **'الأكلة بقت على المنيو.'**
  String get mealPublishedConfirmation;

  /// Heading shown when a Cook without a Kitchen Profile tries to offer a Meal (FR-017, T040).
  ///
  /// In ar, this message translates to:
  /// **'لسه معندكش مطبخ'**
  String get mealNeedsKitchenTitle;

  /// Body text explaining why a Kitchen Profile is needed before a Meal can be offered.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما تعرض أكلة، الناس لازم تعرف مين اللي بيطبخها. اعمل مطبخك الأول وبعدين كمّل.'**
  String get mealNeedsKitchenBody;

  /// Button that opens the Kitchen Profile conversation so the Cook can create one.
  ///
  /// In ar, this message translates to:
  /// **'اعمل مطبخي'**
  String get mealNeedsKitchenAction;

  /// Shown when the Kitchen Profile existence check fails (network or server error).
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نتأكد من مطبخك. جرب تاني.'**
  String get mealKitchenCheckError;

  /// Button that re-runs the Kitchen Profile existence check.
  ///
  /// In ar, this message translates to:
  /// **'جرب تاني'**
  String get mealKitchenCheckRetry;
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
