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
  String get kitchenConvContinue => 'كمّل';

  @override
  String get kitchenConvVoiceHint => 'قول إجابتك بصوتك';

  @override
  String get kitchenConvVoiceUnavailable =>
      'التعرف على الصوت مش متاح. ممكن تكتب إجابتك بدل كده.';

  @override
  String get kitchenConvSummaryTitle => 'ده اللي قلته';

  @override
  String get kitchenConvSummaryConfirm => 'تمام، احفظ';

  @override
  String get kitchenConvSummaryEdit => 'غيّر';

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
}
