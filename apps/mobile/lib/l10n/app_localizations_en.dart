// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kafoo';

  @override
  String get publishMeal => 'Publish Meal';

  @override
  String get archiveMeal => 'Archive Meal';

  @override
  String get acceptOrder => 'Accept Order';

  @override
  String get rejectOrder => 'Reject Order';

  @override
  String get orderRejected =>
      'The Cook could not take this Order right now. Try another Meal, or order from another Cook.';

  @override
  String get networkUnavailable =>
      'No internet connection. Check that you are online and try again.';

  @override
  String get aiEstimateNotice =>
      'These are AI Assistant estimates. The Cook has not confirmed them yet.';

  @override
  String get signInTitle => 'Welcome to Kafoo';

  @override
  String get signInPhoneLabel => 'Your phone number';

  @override
  String get signInContinue => 'Continue';

  @override
  String signInRateLimited(int minutes) {
    return 'Too many attempts. Wait $minutes minutes and try again.';
  }

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeSubtitle(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String get codeWrongCode => 'Wrong code. Try again.';

  @override
  String get codeExpired => 'Code has expired. Request a new one.';

  @override
  String get codeResend => 'Send a new code';

  @override
  String get signInNetworkError =>
      'No internet connection. Check that you are online and try again.';
}
