// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'كفو';

  @override
  String get publishMeal => 'انشر الأكلة';

  @override
  String get archiveMeal => 'أرشف الأكلة';

  @override
  String get acceptOrder => 'اقبل الطلب';

  @override
  String get rejectOrder => 'ارفض الطلب';

  @override
  String get orderRejected =>
      'الطباخ مقدرش ياخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخ تاني.';

  @override
  String get networkUnavailable =>
      'مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني.';

  @override
  String get aiEstimateNotice =>
      'دي تقديرات من المساعد الذكي، لسه محتاجة تأكيد من الطباخ.';

  @override
  String get signInTitle => 'أهلاً بيك في كفو';

  @override
  String get signInPhoneLabel => 'رقم موبايلك';

  @override
  String get signInContinue => 'كمّل';

  @override
  String signInRateLimited(int minutes) {
    return 'جربت كتير. استنى $minutes دقيقة وبعدين جرب تاني.';
  }

  @override
  String get codeTitle => 'ادخل الكود';

  @override
  String codeSubtitle(String phone) {
    return 'اتبعتلك كود على رقم $phone';
  }

  @override
  String get codeWrongCode => 'الكود غلط. جرب تاني.';

  @override
  String get codeExpired => 'الكود انتهى. اطلب كود جديد.';

  @override
  String get codeResend => 'ابعت كود جديد';

  @override
  String get signInNetworkError =>
      'مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني.';

  @override
  String get kitchenConvPromptDisplayName => 'مطبخك اسمه إيه؟';

  @override
  String get kitchenConvPromptStory => 'قولّي عن طبخك. بتعمل إيه وبتعمله إزاي؟';

  @override
  String get kitchenConvPromptArea => 'في أنهي منطقة بتشتغل؟';

  @override
  String get kitchenConvPromptDeliveryTerms => 'إزاي الناس بتاخد أكلها منك؟';

  @override
  String get kitchenConvHintDisplayName => 'مثلاً: مطبخ أم علي';

  @override
  String get kitchenConvHintStory =>
      'مثلاً: بنطبخ أكل بيتي على الطريقة القديمة';

  @override
  String get kitchenConvHintArea => 'مثلاً: المعادي، مصر الجديدة';

  @override
  String get kitchenConvHintDeliveryTerms =>
      'مثلاً: بنوصّل في ساعة أو بتيجي تاخد بنفسك';

  @override
  String get convContinue => 'كمّل';

  @override
  String get convVoiceHint => 'قول إجابتك بصوتك';

  @override
  String get convVoiceUnavailable =>
      'التعرف على الصوت مش متاح. ممكن تكتب إجابتك بدل كده.';

  @override
  String get kitchenConvSummaryTitle => 'ده اللي قلته';

  @override
  String get kitchenConvSummaryConfirm => 'تمام، احفظ';

  @override
  String get convEdit => 'غيّر';

  @override
  String get kitchenConvLabelDisplayName => 'اسم المطبخ';

  @override
  String get kitchenConvLabelStory => 'قصتك';

  @override
  String get kitchenConvLabelArea => 'المنطقة';

  @override
  String get kitchenConvLabelDeliveryTerms => 'طريقة الاستلام';

  @override
  String get kitchenConvLabelPhoto => 'صورة المطبخ';

  @override
  String get kitchenConvPhotoAdd => 'ضيف صورة';

  @override
  String get kitchenConvSaveError => 'حصل مشكلة أثناء الحفظ. جرب تاني.';

  @override
  String get kitchenConvPhotoError =>
      'الصورة ما اتحملتش. ممكن تكمل من غير صورة.';

  @override
  String get kitchenExistsTitle => 'عندك مطبخ بالفعل';

  @override
  String get kitchenExistsBody => 'عندك مطبخ مسجّل على حسابك. هنروحله دلوقتي.';

  @override
  String get kitchenViewTitle => 'مطبخك';

  @override
  String get kitchenEditCurrentValue => 'الحالي';

  @override
  String get kitchenEditNewValue => 'الجديد';

  @override
  String get kitchenEditSave => 'احفظ التغيير';

  @override
  String get kitchenEditCancel => 'إلغاء';

  @override
  String get kitchenEditSaved => 'اتغيّر';

  @override
  String get removeAccountEntry => 'امسح حسابي';

  @override
  String get removeAccountTitle => 'مسح الحساب';

  @override
  String get removeAccountBody =>
      'هيتمسح حسابك وكل حاجة فيه: مطبخك وصورته. مش هينفع نرجّعهم بعد كده.';

  @override
  String get removeAccountConfirm => 'امسح حسابي';

  @override
  String get removeAccountCancel => 'رجوع';

  @override
  String get removeAccountError =>
      'مقدرناش نمسح الحساب. حسابك زي ما هو، جرب تاني.';

  @override
  String get recoveryEmailTitle => 'تحب تضيف إيميل؟';

  @override
  String get recoveryEmailBody =>
      'لو ضاع منك رقمك، الإيميل هو اللي هيخليك توصل لحسابك تاني. مش مطلوب، وممكن تسيبه دلوقتي.';

  @override
  String get recoveryEmailLabel => 'الإيميل بتاعك';

  @override
  String get recoveryEmailAttach => 'ضيف الإيميل';

  @override
  String get recoveryEmailDecline => 'مش دلوقتي';

  @override
  String get recoveryEmailAttached =>
      'تمام، ابعتنا لك رسالة تأكيد على الإيميل.';

  @override
  String get recoveryEmailError => 'مقدرناش نضيف الإيميل. جرب تاني.';

  @override
  String get signInLostNumber => 'مش قادر توصل لرقمك؟';

  @override
  String get emailSignInTitle => 'ادخل بالإيميل';

  @override
  String get emailSignInBody =>
      'لو كنت ضايف إيميل لحسابك قبل كده، اكتبه هنا وهنبعتلك كود.';

  @override
  String get emailSignInLabel => 'الإيميل';

  @override
  String get emailSignInUnknown =>
      'الإيميل ده مش مربوط بأي حساب. جرب تدخل برقم موبايلك.';

  @override
  String get changePhoneTitle => 'غيّر رقم الموبايل';

  @override
  String get changePhoneBody =>
      'اكتب الرقم الجديد. هنبعتلك كود عليه، ولما تأكده الرقم القديم هيبطل يوصل لحسابك.';

  @override
  String get changePhoneLabel => 'الرقم الجديد';

  @override
  String get changePhoneEntry => 'غيّر رقم الموبايل';

  @override
  String get changePhoneDone => 'الرقم اتغيّر. الرقم القديم مبقاش يوصل لحسابك.';

  @override
  String get changePhoneError =>
      'مقدرناش نغيّر الرقم. رقمك القديم زي ما هو، جرب تاني.';

  @override
  String get aiMealAnalysisInvalid =>
      'مش قادرين نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك.';

  @override
  String get aiPromptNotStubbed =>
      'المساعد الذكي مش متاح دلوقتي. كمل بنفسك وهنجرب تاني بعدين.';

  @override
  String get analyzeMealUnauthorized => 'سجل دخولك الأول وجرب تاني.';

  @override
  String get analyzeMealNotOwned => 'الأكلة دي مش ليك.';

  @override
  String get analyzeMealRateLimited =>
      'جربت كتير في وقت قليل. استنى شوية وجرب تاني.';

  @override
  String get analyzeMealTimeout => 'الرد اخد وقت طويل. جرب تاني.';

  @override
  String get analyzeMealInvalidResponse =>
      'مقدرناش نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك.';

  @override
  String get analyzeMealProviderError =>
      'المساعد الذكي مش متاح دلوقتي. جرب تاني بعدين، أو اكتب التفاصيل بنفسك.';

  @override
  String get analyzeMealServerError => 'حصل مشكلة من ناحيتنا. جرب تاني.';

  @override
  String get analyzeMealUnknownError =>
      'حصل مشكلة مش متوقعة. جرب تاني، أو اكتب التفاصيل بنفسك.';

  @override
  String get mealSaveError => 'مقدرناش نحفظ الأكلة. جرب تاني.';

  @override
  String get mealPhotoError => 'الصورة ما اتحملتش. ممكن تكمل من غير صورة.';

  @override
  String get mealConvPromptDish => 'طبخت إيه؟';

  @override
  String get mealConvHintDish => 'مثلاً: كشري، محشي، فراخ بانيه';

  @override
  String get mealConvPromptDescription => 'قولّي عنها. فيها إيه وبتتعمل إزاي؟';

  @override
  String get mealConvHintDescription =>
      'مثلاً: عدس ورز ومكرونة، وبنحمّر البصل فوقها';

  @override
  String get mealConvPromptPhoto => 'في صورة للأكلة؟';

  @override
  String get mealConvHintPhoto =>
      'الصورة بتخلّي الناس تطلب أكتر، وتقدر تعدّيها لو مش عايز';

  @override
  String get mealConvPhotoDisclosure =>
      'لو بعت صورة، المساعد هيبصّ عليها عشان يقدّر المكوّنات والسعرات، ومش هنستخدمها في أي حاجة تانية.';

  @override
  String get mealConvPhotoSkip => 'كمّل من غير صورة';

  @override
  String get mealConvPromptPrice => 'بتبيعها بكام؟';

  @override
  String get mealConvHintPrice => 'سعر الطبق كامل بالجنيه';

  @override
  String get mealSummaryTitle => 'ده اللي قلته عن الأكلة';

  @override
  String get mealSummaryLabelDish => 'الأكلة';

  @override
  String get mealSummaryLabelDescription => 'التفاصيل';

  @override
  String get mealSummaryLabelPhoto => 'الصورة';

  @override
  String get mealSummaryLabelPrice => 'السعر';

  @override
  String get mealSummaryNoPhoto => 'من غير صورة';

  @override
  String get mealSummaryConfirm => 'تمام، انشرها';
}
