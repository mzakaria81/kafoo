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
  String get mealConvPhotoAdd => 'ضيف صورة للأكلة';

  @override
  String get mealConvPromptPrice => 'بتبيعها بكام؟';

  @override
  String get mealConvHintPrice => 'سعر الطبق كامل بالجنيه';

  @override
  String get mealConvFallbackNotice =>
      'المساعد مقدرش يعرف نوع الأكلة، فمحتاج أسألك سؤالين كمان.';

  @override
  String get mealConvPromptCuisine => 'الأكلة دي من أنهي مطبخ؟';

  @override
  String get mealConvHintCuisine => 'اختار اللي أقرب لأكلتك';

  @override
  String get mealConvPromptCategory => 'ودي أكلة إيه؟ طبق رئيسي، حلو، شوربة؟';

  @override
  String get mealConvHintCategory => 'اختار اللي أقرب';

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

  @override
  String get cuisineEgyptian => 'مصري';

  @override
  String get cuisineLevantine => 'شامي';

  @override
  String get cuisineGulf => 'خليجي';

  @override
  String get cuisineSudanese => 'سوداني';

  @override
  String get cuisineMoroccan => 'مغربي';

  @override
  String get cuisineTurkish => 'تركي';

  @override
  String get cuisineItalian => 'إيطالي';

  @override
  String get cuisineAsian => 'آسيوي';

  @override
  String get cuisineAmerican => 'أمريكاني';

  @override
  String get cuisineOther => 'تاني';

  @override
  String get categoryMain => 'طبق رئيسي';

  @override
  String get categoryAppetizer => 'مقبلات';

  @override
  String get categorySoup => 'شوربة';

  @override
  String get categorySalad => 'سلطة';

  @override
  String get categorySide => 'طبق جنب';

  @override
  String get categoryDessert => 'حلو';

  @override
  String get categoryBakery => 'مخبوزات';

  @override
  String get categoryDrink => 'مشروب';

  @override
  String get categoryOther => 'تاني';

  @override
  String get mealSummaryEstimatesTitle => 'تقديرات المساعد';

  @override
  String get mealSummaryEstimatesNotice =>
      'دي تقديرات من المساعد، مش حاجة مؤكدة. راجعها وأكّدها قبل ما تنشر.';

  @override
  String get mealSummaryEstimateBadge => 'تقدير';

  @override
  String get mealSummaryApprove => 'تمام';

  @override
  String get mealSummaryApproved => 'اتأكد';

  @override
  String get mealSummaryNeedsApproval => 'لسه فيه تقديرات محتاجة موافقتك';

  @override
  String get mealSummaryLabelCuisine => 'نوع المطبخ';

  @override
  String get mealSummaryLabelCategory => 'نوع الطبق';

  @override
  String get mealSummaryLabelIngredients => 'المكونات';

  @override
  String get mealSummaryLabelCalories => 'السعرات';

  @override
  String get mealSummaryLabelAllergens => 'الحساسية';

  @override
  String mealSummaryCaloriesValue(int calories) {
    return '$calories سعرة';
  }

  @override
  String get mealSummaryNoEstimates =>
      'المساعد مقدرش يقدّر حاجة. اكتب التفاصيل بنفسك.';

  @override
  String get mealPublishError => 'مقدرناش ننشر الأكلة. جرب تاني.';

  @override
  String get mealPublishedConfirmation => 'الأكلة بقت على المنيو.';

  @override
  String publicMealPriceValue(String price) {
    return '$price جنيه';
  }

  @override
  String get publicMealOpenKitchen => 'شوف المطبخ';

  @override
  String get publicMealCaloriesUnknown => 'السعرات مش متحسبة';

  @override
  String get publicMealAllergensUnknown =>
      'مفيش حساسية متسجلة. لو عندك حساسية من حاجة، اسأل الطباخ.';

  @override
  String get publicMealNutritionFromCook => 'الأرقام دي من الطباخ نفسه.';

  @override
  String get myMealsTitle => 'أكلاتي';

  @override
  String get myMealsEmpty => 'لسه مافيش أكلات. ابدأ واحدة.';

  @override
  String get myMealsStatusDraft => 'مسودة';

  @override
  String get myMealsStatusPublished => 'على المنيو';

  @override
  String get myMealsStatusUnavailable => 'مش متاحة دلوقتي';

  @override
  String get myMealsStatusArchived => 'اتشالت خلاص';

  @override
  String get mealMakeUnavailable => 'شيلها من المنيو';

  @override
  String get mealMakeAvailable => 'رجّعها للمنيو';

  @override
  String get mealLastOnOfferWarning =>
      'دي آخر أكلة على المنيو. لو شيلتها، محدش هيلاقي مطبخك لحد ما ترجّع حاجة.';

  @override
  String get mealLastOnOfferConfirm => 'شيلها برضه';

  @override
  String get mealLastOnOfferCancel => 'سيبها زي ما هي';

  @override
  String get mealLoadError => 'مانفعش نجيب أكلاتك. جرب تاني.';

  @override
  String get mealAvailabilityError => 'مانفعش نغير حالة الأكلة. جرب تاني.';

  @override
  String get mealDeleteError => 'مانفعش نمسح المسودة. جرب تاني.';

  @override
  String get mealLoadRetry => 'حاول تاني';

  @override
  String get mealRetire => 'شيلها نهائي';

  @override
  String get mealRetireWarning =>
      'الأكلة دي هتتشال من المنيو نهائي ومش هترجع تاني أبداً. هتفضل محفوظة في قايمتك بس محدش تاني هيشوفها.';

  @override
  String get mealRetireConfirm => 'شيلها نهائي';

  @override
  String get mealRetireCancel => 'سيبها زي ما هي';

  @override
  String get mealDeleteDraft => 'امسح المسودة';

  @override
  String get mealDeleteDraftWarning =>
      'المسودة دي هتتمسح خالص ومش هتقدر ترجعها.';

  @override
  String get mealDeleteDraftConfirm => 'امسحها';

  @override
  String get mealEditTitle => 'عدّل الأكلة';

  @override
  String get mealEditSaved => 'اتغيّرت.';

  @override
  String get mealEditNoChange => 'مافيش حاجة اتغيّرت.';

  @override
  String get mealNeedsKitchenTitle => 'لسه معندكش مطبخ';

  @override
  String get mealNeedsKitchenBody =>
      'قبل ما تعرض أكلة، الناس لازم تعرف مين اللي بيطبخها. اعمل مطبخك الأول وبعدين كمّل.';

  @override
  String get mealNeedsKitchenAction => 'اعمل مطبخي';

  @override
  String get mealKitchenCheckError => 'مقدرناش نتأكد من مطبخك. جرب تاني.';

  @override
  String get mealKitchenCheckRetry => 'جرب تاني';

  @override
  String get myMealsNoPriceYet => 'لسه من غير سعر';

  @override
  String get myMealsUntitledDraft => 'مسودة من غير اسم';

  @override
  String get mealResumeDraft => 'كمّل الأكلة دي';
}
