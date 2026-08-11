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
  String browseKitchenLabel(String kitchen) {
    return 'من $kitchen';
  }

  @override
  String get browseLoading => 'بنجيب الأكل...';

  @override
  String get browseNothingOnOffer =>
      'مفيش أكلات معروضة دلوقتي. ممكن نلاقي حاجة كمان شوية.';

  @override
  String get browseRetry => 'جرب تاني';

  @override
  String get browseSignInEntry => 'دخول';

  @override
  String get browseTitle => 'أكل النهاردة';

  @override
  String get discoveryLoadError => 'مش قادرين نعرض الأكل دلوقتي.';

  @override
  String get searchUnavailable =>
      'البحث مش شغال دلوقتي، بس الفرجة على الأكل الموجود شغالة عادي.';

  @override
  String mealCardSemanticLabel(String kitchen, String price, String title) {
    return '$title، $kitchen، $price';
  }

  @override
  String publishMeal(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'انشري الأكلة',
        'other': 'انشر الأكلة',
      },
    );
    return '$_temp0';
  }

  @override
  String archiveMeal(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'أرشفي الأكلة',
        'other': 'أرشف الأكلة',
      },
    );
    return '$_temp0';
  }

  @override
  String acceptOrder(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اقبلي الطلب',
        'other': 'اقبل الطلب',
      },
    );
    return '$_temp0';
  }

  @override
  String rejectOrder(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ارفضي الطلب',
        'other': 'ارفض الطلب',
      },
    );
    return '$_temp0';
  }

  @override
  String orderRejected(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine':
            'الطباخة مقدرتش تاخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخة تانية.',
        'other':
            'الطباخ مقدرش ياخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخ تاني.',
      },
    );
    return '$_temp0';
  }

  @override
  String networkUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اطمني إن النت شغال وجربي',
        'other': 'اطمن إن النت شغال وجرب',
      },
    );
    return 'مفيش اتصال بالنت. $_temp0 تاني.';
  }

  @override
  String aiEstimateNotice(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine': 'الطباخة.',
        'other': 'الطباخ.',
      },
    );
    return 'دي تقديرات من المساعد الذكي، لسه محتاجة تأكيد من $_temp0';
  }

  @override
  String get signInTitle => 'أهلاً بيك في كفو';

  @override
  String get signInPhoneLabel => 'رقم موبايلك';

  @override
  String signInContinue(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كمّلي',
        'other': 'كمّل',
      },
    );
    return '$_temp0';
  }

  @override
  String signInRateLimited(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربتي كتير. استني شوية وجربي تاني.',
        'other': 'جربت كتير. استنى شوية وجرب تاني.',
      },
    );
    return '$_temp0';
  }

  @override
  String codeTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ادخلي الكود',
        'other': 'ادخل الكود',
      },
    );
    return '$_temp0';
  }

  @override
  String codeSubtitle(String phone) {
    return 'اتبعتلك كود على رقم $phone';
  }

  @override
  String codeWrongCode(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'الكود غلط. جربي تاني.',
        'other': 'الكود غلط. جرب تاني.',
      },
    );
    return '$_temp0';
  }

  @override
  String codeExpired(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اطلبي',
        'other': 'اطلب',
      },
    );
    return 'الكود انتهى. $_temp0 كود جديد.';
  }

  @override
  String codeResend(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ابعتي كود جديد',
        'other': 'ابعت كود جديد',
      },
    );
    return '$_temp0';
  }

  @override
  String signInNetworkError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اطمني إن النت شغال وجربي',
        'other': 'اطمن إن النت شغال وجرب',
      },
    );
    return 'مفيش اتصال بالنت. $_temp0 تاني.';
  }

  @override
  String get kitchenConvPromptDisplayName => 'مطبخك اسمه إيه؟';

  @override
  String kitchenConvPromptStory(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'قوليلي عن طبخك. بتعملي إيه وبتعمليه',
        'other': 'قولّي عن طبخك. بتعمل إيه وبتعمله',
      },
    );
    return '$_temp0 إزاي؟';
  }

  @override
  String kitchenConvPromptArea(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'في أنهي منطقة بتشتغلي؟',
        'other': 'في أنهي منطقة بتشتغل؟',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvPromptDeliveryTerms => 'إزاي الناس بتاخد أكلها منك؟';

  @override
  String get kitchenConvPromptAddressForm =>
      'عشان أكلمك صح — أقولّك \"كمّل\" ولا \"كمّلي\"؟';

  @override
  String get kitchenConvAddressFormMasculine => 'كمّل';

  @override
  String get kitchenConvAddressFormFeminine => 'كمّلي';

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
  String convContinue(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كمّلي',
        'other': 'كمّل',
      },
    );
    return '$_temp0';
  }

  @override
  String convVoiceHint(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'قولي إجابتك بصوتك',
        'other': 'قول إجابتك بصوتك',
      },
    );
    return '$_temp0';
  }

  @override
  String convVoiceUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تكتبي',
        'other': 'تكتب',
      },
    );
    return 'التعرف على الصوت مش متاح. ممكن $_temp0 إجابتك بدل كده.';
  }

  @override
  String get kitchenConvSummaryTitle => 'ده اللي قلته';

  @override
  String kitchenConvSummaryConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تمام، احفظي',
        'other': 'تمام، احفظ',
      },
    );
    return '$_temp0';
  }

  @override
  String convEdit(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'غيّري',
        'other': 'غيّر',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvLabelDisplayName => 'اسم المطبخ';

  @override
  String get kitchenConvLabelStory => 'قصتك';

  @override
  String get kitchenConvLabelArea => 'المنطقة';

  @override
  String get kitchenConvLabelDeliveryTerms => 'طريقة الاستلام';

  @override
  String get kitchenConvLabelAddressForm => 'طريقة مخاطبتك';

  @override
  String get kitchenConvLabelPhoto => 'صورة المطبخ';

  @override
  String kitchenConvPhotoAdd(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ضيفي صورة',
        'other': 'ضيف صورة',
      },
    );
    return '$_temp0';
  }

  @override
  String kitchenConvSaveError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'حصل مشكلة أثناء الحفظ. $_temp0 تاني.';
  }

  @override
  String kitchenConvPhotoError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تكملي',
        'other': 'تكمل',
      },
    );
    return 'الصورة ما اتحملتش. ممكن $_temp0 من غير صورة.';
  }

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
  String kitchenEditSave(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'احفظي التغيير',
        'other': 'احفظ التغيير',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenEditCancel => 'إلغاء';

  @override
  String get kitchenEditSaved => 'اتغيّر';

  @override
  String removeAccountEntry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'امسحي حسابي',
        'other': 'امسح حسابي',
      },
    );
    return '$_temp0';
  }

  @override
  String get removeAccountTitle => 'مسح الحساب';

  @override
  String get removeAccountBody =>
      'هيتمسح حسابك وكل حاجة فيه: مطبخك وصورته. مش هينفع نرجّعهم بعد كده.';

  @override
  String removeAccountConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'امسحي حسابي',
        'other': 'امسح حسابي',
      },
    );
    return '$_temp0';
  }

  @override
  String get removeAccountCancel => 'رجوع';

  @override
  String removeAccountError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش نمسح الحساب. حسابك زي ما هو، $_temp0 تاني.';
  }

  @override
  String recoveryEmailTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تحبي تضيفي إيميل؟',
        'other': 'تحب تضيف إيميل؟',
      },
    );
    return '$_temp0';
  }

  @override
  String recoveryEmailBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'توصلي لحسابك تاني. مش مطلوب، وممكن تسيبيه',
        'other': 'توصل لحسابك تاني. مش مطلوب، وممكن تسيبه',
      },
    );
    return 'لو ضاع منك رقمك، الإيميل هو اللي هيخليك $_temp0 دلوقتي.';
  }

  @override
  String get recoveryEmailLabel => 'الإيميل بتاعك';

  @override
  String recoveryEmailAttach(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ضيفي الإيميل',
        'other': 'ضيف الإيميل',
      },
    );
    return '$_temp0';
  }

  @override
  String get recoveryEmailDecline => 'مش دلوقتي';

  @override
  String get recoveryEmailAttached =>
      'تمام، ابعتنا لك رسالة تأكيد على الإيميل.';

  @override
  String recoveryEmailError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش نضيف الإيميل. $_temp0 تاني.';
  }

  @override
  String signInLostNumber(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'مش قادرة توصلي لرقمك؟',
        'other': 'مش قادر توصل لرقمك؟',
      },
    );
    return '$_temp0';
  }

  @override
  String emailSignInTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ادخلي بالإيميل',
        'other': 'ادخل بالإيميل',
      },
    );
    return '$_temp0';
  }

  @override
  String emailSignInBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كنتي ضايفة إيميل لحسابك قبل كده، اكتبيه',
        'other': 'كنت ضايف إيميل لحسابك قبل كده، اكتبه',
      },
    );
    return 'لو $_temp0 هنا وهنبعتلك كود.';
  }

  @override
  String get emailSignInLabel => 'الإيميل';

  @override
  String emailSignInUnknown(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تدخلي',
        'other': 'جرب تدخل',
      },
    );
    return 'الإيميل ده مش مربوط بأي حساب. $_temp0 برقم موبايلك.';
  }

  @override
  String changePhoneTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'غيّري رقم الموبايل',
        'other': 'غيّر رقم الموبايل',
      },
    );
    return '$_temp0';
  }

  @override
  String changePhoneBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اكتبي الرقم الجديد. هنبعتلك كود عليه، ولما تأكديه',
        'other': 'اكتب الرقم الجديد. هنبعتلك كود عليه، ولما تأكده',
      },
    );
    return '$_temp0 الرقم القديم هيبطل يوصل لحسابك.';
  }

  @override
  String get changePhoneLabel => 'الرقم الجديد';

  @override
  String changePhoneEntry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'غيّري رقم الموبايل',
        'other': 'غيّر رقم الموبايل',
      },
    );
    return '$_temp0';
  }

  @override
  String get changePhoneDone => 'الرقم اتغيّر. الرقم القديم مبقاش يوصل لحسابك.';

  @override
  String changePhoneError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش نغيّر الرقم. رقمك القديم زي ما هو، $_temp0 تاني.';
  }

  @override
  String aiMealAnalysisInvalid(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تاني، أو اكتبي',
        'other': 'جرب تاني، أو اكتب',
      },
    );
    return 'مش قادرين نفهم رد المساعد الذكي. $_temp0 التفاصيل بنفسك.';
  }

  @override
  String aiPromptNotStubbed(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كملي',
        'other': 'كمل',
      },
    );
    return 'المساعد الذكي مش متاح دلوقتي. $_temp0 بنفسك وهنجرب تاني بعدين.';
  }

  @override
  String analyzeMealUnauthorized(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'سجّلي دخولك الأول وجربي',
        'other': 'سجل دخولك الأول وجرب',
      },
    );
    return '$_temp0 تاني.';
  }

  @override
  String get analyzeMealNotOwned => 'الأكلة دي مش ليك.';

  @override
  String analyzeMealRateLimited(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'استني شوية وجربي',
        'other': 'استنى شوية وجرب',
      },
    );
    return 'جربت كتير في وقت قليل. $_temp0 تاني.';
  }

  @override
  String analyzeMealTimeout(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'الرد اخد وقت طويل. $_temp0 تاني.';
  }

  @override
  String analyzeMealInvalidResponse(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تاني، أو اكتبي',
        'other': 'جرب تاني، أو اكتب',
      },
    );
    return 'مقدرناش نفهم رد المساعد الذكي. $_temp0 التفاصيل بنفسك.';
  }

  @override
  String analyzeMealProviderError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تاني بعدين، أو اكتبي',
        'other': 'جرب تاني بعدين، أو اكتب',
      },
    );
    return 'المساعد الذكي مش متاح دلوقتي. $_temp0 التفاصيل بنفسك.';
  }

  @override
  String analyzeMealServerError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'حصل مشكلة من ناحيتنا. $_temp0 تاني.';
  }

  @override
  String analyzeMealUnknownError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تاني، أو اكتبي',
        'other': 'جرب تاني، أو اكتب',
      },
    );
    return 'حصل مشكلة مش متوقعة. $_temp0 التفاصيل بنفسك.';
  }

  @override
  String mealSaveError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش نحفظ الأكلة. $_temp0 تاني.';
  }

  @override
  String mealPhotoError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تكملي',
        'other': 'تكمل',
      },
    );
    return 'الصورة ما اتحملتش. ممكن $_temp0 من غير صورة.';
  }

  @override
  String get mealConvPromptDish => 'طبخت إيه؟';

  @override
  String get mealConvHintDish => 'مثلاً: كشري، محشي، فراخ بانيه';

  @override
  String mealConvPromptDescription(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'قوليلي',
        'other': 'قولّي',
      },
    );
    return '$_temp0 عنها. فيها إيه وبتتعمل إزاي؟';
  }

  @override
  String get mealConvHintDescription =>
      'مثلاً: عدس ورز ومكرونة، وبنحمّر البصل فوقها';

  @override
  String get mealConvPromptPhoto => 'في صورة للأكلة؟';

  @override
  String mealConvHintPhoto(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'وتقدري تعدّيها لو مش عايزة',
        'other': 'وتقدر تعدّيها لو مش عايز',
      },
    );
    return 'الصورة بتخلّي الناس تطلب أكتر، $_temp0';
  }

  @override
  String get mealConvPhotoDisclosure =>
      'لو بعت صورة، المساعد هيبصّ عليها عشان يقدّر المكوّنات والسعرات، ومش هنستخدمها في أي حاجة تانية.';

  @override
  String mealConvPhotoSkip(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كمّلي من غير صورة',
        'other': 'كمّل من غير صورة',
      },
    );
    return '$_temp0';
  }

  @override
  String mealConvPhotoAdd(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ضيفي صورة للأكلة',
        'other': 'ضيف صورة للأكلة',
      },
    );
    return '$_temp0';
  }

  @override
  String mealConvPromptPrice(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'بتبيعيها بكام؟',
        'other': 'بتبيعها بكام؟',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvHintPrice => 'سعر الطبق كامل بالجنيه';

  @override
  String get mealConvFallbackNotice =>
      'المساعد مقدرش يعرف نوع الأكلة، فمحتاج أسألك سؤالين كمان.';

  @override
  String get mealConvPromptCuisine => 'الأكلة دي من أنهي مطبخ؟';

  @override
  String mealConvHintCuisine(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اختاري اللي أقرب لأكلتك',
        'other': 'اختار اللي أقرب لأكلتك',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvPromptCategory => 'ودي أكلة إيه؟ طبق رئيسي، حلو، شوربة؟';

  @override
  String mealConvHintCategory(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اختاري اللي أقرب',
        'other': 'اختار اللي أقرب',
      },
    );
    return '$_temp0';
  }

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
  String mealSummaryConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'تمام، انشريها',
        'other': 'تمام، انشرها',
      },
    );
    return '$_temp0';
  }

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
  String mealSummaryEstimatesNotice(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'راجعيها وأكّديها قبل ما تنشري.',
        'other': 'راجعها وأكّدها قبل ما تنشر.',
      },
    );
    return 'دي تقديرات من المساعد، مش حاجة مؤكدة. $_temp0';
  }

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
  String mealSummaryNoEstimates(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اكتبي',
        'other': 'اكتب',
      },
    );
    return 'المساعد مقدرش يقدّر حاجة. $_temp0 التفاصيل بنفسك.';
  }

  @override
  String mealPublishError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش ننشر الأكلة. $_temp0 تاني.';
  }

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
  String publicMealAllergensUnknown(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine': 'الطباخة.',
        'other': 'الطباخ.',
      },
    );
    return 'مفيش حساسية متسجلة. لو عندك حساسية من حاجة، اسأل $_temp0';
  }

  @override
  String publicMealNutritionFromCook(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine': 'الطباخة نفسها.',
        'other': 'الطباخ نفسه.',
      },
    );
    return 'الأرقام دي من $_temp0';
  }

  @override
  String get myMealsTitle => 'أكلاتي';

  @override
  String get newMealEntry => 'أكلة جديدة';

  @override
  String myMealsEmpty(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ابدئي',
        'other': 'ابدأ',
      },
    );
    return 'لسه مافيش أكلات. $_temp0 واحدة.';
  }

  @override
  String get myMealsStatusDraft => 'مسودة';

  @override
  String get myMealsStatusPublished => 'على المنيو';

  @override
  String get myMealsStatusUnavailable => 'مش متاحة دلوقتي';

  @override
  String get myMealsStatusArchived => 'اتشالت خلاص';

  @override
  String mealMakeUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'شيليها من المنيو',
        'other': 'شيلها من المنيو',
      },
    );
    return '$_temp0';
  }

  @override
  String mealMakeAvailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'رجّعيها للمنيو',
        'other': 'رجّعها للمنيو',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLastOnOfferWarning(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'ترجّعي',
        'other': 'ترجّع',
      },
    );
    return 'دي آخر أكلة على المنيو. لو شيلتها، محدش هيلاقي مطبخك لحد ما $_temp0 حاجة.';
  }

  @override
  String mealLastOnOfferConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'شيليها برضه',
        'other': 'شيلها برضه',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLastOnOfferCancel(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'سيبيها زي ما هي',
        'other': 'سيبها زي ما هي',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLoadError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مانفعش نجيب أكلاتك. $_temp0 تاني.';
  }

  @override
  String mealAvailabilityError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مانفعش نغير حالة الأكلة. $_temp0 تاني.';
  }

  @override
  String mealDeleteError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مانفعش نمسح المسودة. $_temp0 تاني.';
  }

  @override
  String mealLoadRetry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'حاولي تاني',
        'other': 'حاول تاني',
      },
    );
    return '$_temp0';
  }

  @override
  String mealRetire(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'شيليها نهائي',
        'other': 'شيلها نهائي',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealRetireWarning =>
      'الأكلة دي هتتشال من المنيو نهائي ومش هترجع تاني أبداً. هتفضل محفوظة في قايمتك بس محدش تاني هيشوفها.';

  @override
  String mealRetireConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'شيليها نهائي',
        'other': 'شيلها نهائي',
      },
    );
    return '$_temp0';
  }

  @override
  String mealRetireCancel(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'سيبيها زي ما هي',
        'other': 'سيبها زي ما هي',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteDraft(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'امسحي المسودة',
        'other': 'امسح المسودة',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteDraftWarning(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'هتقدري ترجعيها.',
        'other': 'هتقدر ترجعها.',
      },
    );
    return 'المسودة دي هتتمسح خالص ومش $_temp0';
  }

  @override
  String mealDeleteDraftConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'امسحيها',
        'other': 'امسحها',
      },
    );
    return '$_temp0';
  }

  @override
  String mealEditTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'عدّلي الأكلة',
        'other': 'عدّل الأكلة',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealEditSaved => 'اتغيّرت.';

  @override
  String get mealEditNoChange => 'مافيش حاجة اتغيّرت.';

  @override
  String get mealNeedsKitchenTitle => 'لسه معندكش مطبخ';

  @override
  String mealNeedsKitchenBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'تعرضي أكلة، الناس لازم تعرف مين اللي بيطبخها. اعملي مطبخك الأول وبعدين كمّلي.',
        'other':
            'تعرض أكلة، الناس لازم تعرف مين اللي بيطبخها. اعمل مطبخك الأول وبعدين كمّل.',
      },
    );
    return 'قبل ما $_temp0';
  }

  @override
  String mealNeedsKitchenAction(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'اعملي مطبخي',
        'other': 'اعمل مطبخي',
      },
    );
    return '$_temp0';
  }

  @override
  String mealKitchenCheckError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي',
        'other': 'جرب',
      },
    );
    return 'مقدرناش نتأكد من مطبخك. $_temp0 تاني.';
  }

  @override
  String mealKitchenCheckRetry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'جربي تاني',
        'other': 'جرب تاني',
      },
    );
    return '$_temp0';
  }

  @override
  String get myMealsNoPriceYet => 'لسه من غير سعر';

  @override
  String get myMealsUntitledDraft => 'مسودة من غير اسم';

  @override
  String mealResumeDraft(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'كمّلي الأكلة دي',
        'other': 'كمّل الأكلة دي',
      },
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSearchTitle => 'البحث بالمساعد الذكي';

  @override
  String get settingsSearchExplanation =>
      'علشان نلاقي الأكل المطلوب، الكلام اللي بيتكتب في البحث بيروح لخدمة بره كفو بتفهم معناه. لو ده مقفول، البحث مش هيشتغل، والفرجة على الأكل هتفضل شغالة زي ما هي.';

  @override
  String get settingsSearchStorageNote =>
      'الرد ده محفوظ على الموبايل ده بس. كفو مش بيسجل الكلام اللي بيتكتب في البحث، ولا بيحتفظ بالرد عنده.';

  @override
  String get searchLabel => 'أكل إيه النهاردة؟';

  @override
  String get searchHint => 'حاجة سخنة من غير لحمة في المهندسين';

  @override
  String get searchAction => 'بحث';

  @override
  String get searchRunning => 'بندوّر على الأكل...';

  @override
  String get searchVoiceHint => 'بالصوت';

  @override
  String get searchVoiceUnavailable =>
      'الصوت مش شغال على الموبايل ده دلوقتي. الكتابة شغالة عادي.';

  @override
  String get searchIsOff =>
      'البحث مقفول. ينفع يتفتح من الإعدادات في أي وقت، والتفرج على الأكل شغال زي ما هو.';

  @override
  String get searchFoundNothing =>
      'ملقيناش حاجة زي كده. ده كل اللي معروض دلوقتي.';

  @override
  String get searchExclusionNotUnderstood =>
      'فهمنا إن في حاجة المفروض تتشال من الأكل، بس مش عارفين هي إيه — فما اتشالتش أي أكلة على أساسها. نجرب اسم الأكلة لوحده.';

  @override
  String searchFilteredOn(String food) {
    return 'شيلنا الأكلات المكتوب فيها $food. ده على حسب اللي الطباخين كتبوه وتقدير المساعد الذكي — مش معناه إن باقي الأكلات مفيهاش $food.';
  }

  @override
  String searchNarrowedToArea(String area) {
    return 'النتايج من $area بس.';
  }

  @override
  String searchAreaEmpty(String area) {
    return 'مفيش أكل معروض في $area دلوقتي.';
  }

  @override
  String get searchAreaChoose =>
      'بس في أكل في المناطق دي. كفو مش عارف المسافة بين المناطق، والتوصيل اتفاق بين الزبون والطباخ.';

  @override
  String get searchConsentQuestion =>
      'علشان كفو يفهم الكلام ويلاقي الأكل المناسب، لازم يبعت اللي اتكتب في البحث لخدمة بره كفو. كفو نفسه مش بيسجل الكلام ده ولا بيحتفظ بيه. ولو الكلام اتقال بالصوت، الموبايل نفسه هو اللي بيحوّله لكتابة. نبعته؟';

  @override
  String get searchConsentAgree => 'أيوه، ابعتوه';

  @override
  String get searchConsentRefuse => 'لأ، متبعتوهوش';

  @override
  String get searchConsentNote =>
      'لو الرد لأ، البحث مش هيشتغل والفرجة على الأكل هتفضل شغالة. الرد هيتحفظ على الموبايل ده بس، وينفع يتغير من الإعدادات في أي وقت.';

  @override
  String exclusionName(String food) {
    String _temp0 = intl.Intl.selectLogic(
      food,
      {
        'meat': 'لحمة',
        'chicken': 'فراخ',
        'fish': 'سمك',
        'shellfish': 'جمبري ومحار',
        'egg': 'بيض',
        'dairy': 'ألبان',
        'peanut': 'فول سوداني',
        'nuts': 'مكسرات',
        'sesame': 'سمسم',
        'gluten': 'جلوتين',
        'onion': 'بصل',
        'garlic': 'توم',
        'other': 'الحاجة دي',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealNoLongerOnOffer =>
      'الأكلة دي مبقتش معروضة. الطباخ شالها من المنيو دلوقتي.';

  @override
  String get searchAreasUnknown =>
      'مش قادرين نعرف دلوقتي المناطق اللي فيها أكل. جرب تاني كمان شوية.';

  @override
  String get searchJudgementNothingAnswers => 'مفيش أكلة هنا زي كده بالظبط.';

  @override
  String searchJudgementAlternatives(
      int count, String first, String second, String third) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «$first» و«$second» و«$third»',
      two:
          'مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «$first» و«$second»',
      one: 'مفيش أكلة هنا زي كده بالظبط. من اللي معروض دلوقتي: «$first»',
    );
    return '$_temp0';
  }

  @override
  String signInPhoneNotMobile(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'الرقم ده مش شكله رقم موبايل مصري. اكتبي رقمك كده: 01xxxxxxxxx',
        'other': 'الرقم ده مش شكله رقم موبايل مصري. اكتب رقمك كده: 01xxxxxxxxx',
      },
    );
    return '$_temp0';
  }

  @override
  String signInCodeNotSent(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'مقدرناش نبعت كود على الرقم ده. اتأكدي من الرقم وجربي تاني.',
        'other': 'مقدرناش نبعت كود على الرقم ده. اتأكد من الرقم وجرب تاني.',
      },
    );
    return '$_temp0';
  }

  @override
  String get searchVoiceNeedsArabic =>
      'عشان الصوت يشتغل، لازم اللغة العربية تكون مفعّلة في إعدادات التعرف على الصوت بتاعة الموبايل. الكتابة شغالة عادي.';

  @override
  String convVoiceNeedsArabic(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'عشان الصوت يشتغل، لازم اللغة العربية تكون مفعّلة في إعدادات التعرف على الصوت بتاعة الموبايل. تقدري تكتبي إجابتك بدل كده.',
        'other':
            'عشان الصوت يشتغل، لازم اللغة العربية تكون مفعّلة في إعدادات التعرف على الصوت بتاعة الموبايل. تقدر تكتب إجابتك بدل كده.',
      },
    );
    return '$_temp0';
  }

  @override
  String get photoPlaceholder => 'مكان صورة مؤقت — مش هينزل في النسخة النهائية';
}
