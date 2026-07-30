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
}
