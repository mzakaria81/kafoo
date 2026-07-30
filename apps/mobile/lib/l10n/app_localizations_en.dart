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

  @override
  String get kitchenConvPromptDisplayName => 'What is your kitchen called?';

  @override
  String get kitchenConvPromptStory =>
      'Tell me about your cooking. What do you make and how?';

  @override
  String get kitchenConvPromptArea => 'Which area do you cook in?';

  @override
  String get kitchenConvPromptDeliveryTerms =>
      'How do people receive their food from you?';

  @override
  String get kitchenConvHintDisplayName => 'e.g. Om Ali\'s Kitchen';

  @override
  String get kitchenConvHintStory =>
      'e.g. Home-cooked food the old-fashioned way';

  @override
  String get kitchenConvHintArea => 'e.g. Maadi, Heliopolis';

  @override
  String get kitchenConvHintDeliveryTerms =>
      'e.g. Delivery within an hour, or pick up yourself';

  @override
  String get kitchenConvContinue => 'Continue';

  @override
  String get kitchenConvVoiceHint => 'Say your answer out loud';

  @override
  String get kitchenConvVoiceUnavailable =>
      'Voice recognition is not available. You can type your answer instead.';

  @override
  String get kitchenConvSummaryTitle => 'Here is what you told us';

  @override
  String get kitchenConvSummaryConfirm => 'Looks good, save';

  @override
  String get kitchenConvSummaryEdit => 'Change';

  @override
  String get kitchenConvLabelDisplayName => 'Kitchen name';

  @override
  String get kitchenConvLabelStory => 'Your story';

  @override
  String get kitchenConvLabelArea => 'Area';

  @override
  String get kitchenConvLabelDeliveryTerms => 'How food reaches people';

  @override
  String get kitchenConvLabelPhoto => 'Kitchen photo';

  @override
  String get kitchenConvPhotoAdd => 'Add a photo';

  @override
  String get kitchenConvSaveError =>
      'Something went wrong saving. Please try again.';

  @override
  String get kitchenConvPhotoError =>
      'The photo could not be uploaded. You can continue without one.';

  @override
  String get kitchenExistsTitle => 'You already have a kitchen';

  @override
  String get kitchenExistsBody =>
      'You already have a Kitchen Profile on this account. Taking you there now.';
}
