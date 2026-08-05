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
  String get convContinue => 'Continue';

  @override
  String get convVoiceHint => 'Say your answer out loud';

  @override
  String get convVoiceUnavailable =>
      'Voice recognition is not available. You can type your answer instead.';

  @override
  String get kitchenConvSummaryTitle => 'Here is what you told us';

  @override
  String get kitchenConvSummaryConfirm => 'Looks good, save';

  @override
  String get convEdit => 'Change';

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

  @override
  String get kitchenViewTitle => 'Your kitchen';

  @override
  String get kitchenEditCurrentValue => 'Current';

  @override
  String get kitchenEditNewValue => 'New';

  @override
  String get kitchenEditSave => 'Save change';

  @override
  String get kitchenEditCancel => 'Cancel';

  @override
  String get kitchenEditSaved => 'Changed';

  @override
  String get removeAccountEntry => 'Delete my account';

  @override
  String get removeAccountTitle => 'Delete account';

  @override
  String get removeAccountBody =>
      'Your account and everything in it will be deleted: your kitchen and its photo. This cannot be undone.';

  @override
  String get removeAccountConfirm => 'Delete my account';

  @override
  String get removeAccountCancel => 'Back';

  @override
  String get removeAccountError =>
      'We could not delete your account. It is unchanged — please try again.';

  @override
  String get recoveryEmailTitle => 'Add an email address?';

  @override
  String get recoveryEmailBody =>
      'If you lose your number, an email address is how you get back into your account. It is not required, and you can skip it.';

  @override
  String get recoveryEmailLabel => 'Your email address';

  @override
  String get recoveryEmailAttach => 'Add email';

  @override
  String get recoveryEmailDecline => 'Not now';

  @override
  String get recoveryEmailAttached =>
      'Done. We have sent a confirmation message to that address.';

  @override
  String get recoveryEmailError =>
      'We could not add that address. Please try again.';

  @override
  String get signInLostNumber => 'Can\'t reach your number?';

  @override
  String get emailSignInTitle => 'Sign in by email';

  @override
  String get emailSignInBody =>
      'If you added an email address to your account before, enter it here and we will send you a code.';

  @override
  String get emailSignInLabel => 'Email address';

  @override
  String get emailSignInUnknown =>
      'That address is not linked to any account. Try signing in with your phone number.';

  @override
  String get changePhoneTitle => 'Change phone number';

  @override
  String get changePhoneBody =>
      'Enter your new number. We will send a code to it, and once you confirm, the old number will stop reaching your account.';

  @override
  String get changePhoneLabel => 'New number';

  @override
  String get changePhoneEntry => 'Change phone number';

  @override
  String get changePhoneDone =>
      'Your number has changed. The old one no longer reaches your account.';

  @override
  String get changePhoneError =>
      'We could not change your number. Your old number still works — please try again.';

  @override
  String get aiMealAnalysisInvalid =>
      'We could not read the AI Assistant\'s reply. Try again, or fill the details in yourself.';

  @override
  String get aiPromptNotStubbed =>
      'The AI Assistant is not available right now. Carry on yourself and we will try again later.';

  @override
  String get analyzeMealUnauthorized => 'Sign in first and try again.';

  @override
  String get analyzeMealNotOwned => 'This Meal is not yours.';

  @override
  String get analyzeMealRateLimited =>
      'Too many attempts. Wait a bit and try again.';

  @override
  String get analyzeMealTimeout => 'The response took too long. Try again.';

  @override
  String get analyzeMealInvalidResponse =>
      'We could not understand the AI Assistant\'s reply. Try again, or fill the details in yourself.';

  @override
  String get analyzeMealProviderError =>
      'The AI Assistant is not available right now. Try again later, or fill the details in yourself.';

  @override
  String get analyzeMealServerError =>
      'Something went wrong on our side. Please try again.';

  @override
  String get analyzeMealUnknownError =>
      'An unexpected error occurred. Try again, or fill the details in yourself.';

  @override
  String get mealSaveError => 'We could not save the Meal. Please try again.';

  @override
  String get mealPhotoError =>
      'The photo could not be uploaded. You can continue without one.';

  @override
  String get mealConvPromptDish => 'What did you cook?';

  @override
  String get mealConvHintDish => 'For example: koshary, mahshi, panee chicken';

  @override
  String get mealConvPromptDescription =>
      'Tell me about it. What\'s in it and how is it made?';

  @override
  String get mealConvHintDescription =>
      'For example: lentils, rice and pasta, with fried onion on top';

  @override
  String get mealConvPromptPhoto => 'Is there a photo of the dish?';

  @override
  String get mealConvHintPhoto =>
      'A photo gets you more orders, and you can skip it if you would rather not';

  @override
  String get mealConvPhotoDisclosure =>
      'If you send a photo, the assistant will look at it to estimate the ingredients and calories. We will not use it for anything else.';

  @override
  String get mealConvPhotoSkip => 'Continue without a photo';

  @override
  String get mealConvPromptPrice => 'What do you sell it for?';

  @override
  String get mealConvHintPrice => 'The price of the whole dish, in pounds';

  @override
  String get mealSummaryTitle => 'Here is what you told me about this Meal';

  @override
  String get mealSummaryLabelDish => 'Meal';

  @override
  String get mealSummaryLabelDescription => 'Details';

  @override
  String get mealSummaryLabelPhoto => 'Photo';

  @override
  String get mealSummaryLabelPrice => 'Price';

  @override
  String get mealSummaryNoPhoto => 'No photo';

  @override
  String get mealSummaryConfirm => 'Looks right, publish it';

  @override
  String get cuisineEgyptian => 'Egyptian';

  @override
  String get cuisineLevantine => 'Levantine';

  @override
  String get cuisineGulf => 'Gulf';

  @override
  String get cuisineSudanese => 'Sudanese';

  @override
  String get cuisineMoroccan => 'Moroccan';

  @override
  String get cuisineTurkish => 'Turkish';

  @override
  String get cuisineItalian => 'Italian';

  @override
  String get cuisineAsian => 'Asian';

  @override
  String get cuisineAmerican => 'American';

  @override
  String get cuisineOther => 'Other';

  @override
  String get categoryMain => 'Main';

  @override
  String get categoryAppetizer => 'Appetizer';

  @override
  String get categorySoup => 'Soup';

  @override
  String get categorySalad => 'Salad';

  @override
  String get categorySide => 'Side';

  @override
  String get categoryDessert => 'Dessert';

  @override
  String get categoryBakery => 'Bakery';

  @override
  String get categoryDrink => 'Drink';

  @override
  String get categoryOther => 'Other';

  @override
  String get mealSummaryEstimatesTitle => 'The assistant\'s estimates';

  @override
  String get mealSummaryEstimatesNotice =>
      'These are estimates from the assistant, not confirmed facts. Check them and confirm each one before you publish.';

  @override
  String get mealSummaryEstimateBadge => 'Estimate';

  @override
  String get mealSummaryApprove => 'Looks right';

  @override
  String get mealSummaryApproved => 'Confirmed';

  @override
  String get mealSummaryNeedsApproval =>
      'Some estimates still need your confirmation';

  @override
  String get mealSummaryLabelCuisine => 'Cuisine';

  @override
  String get mealSummaryLabelCategory => 'Category';

  @override
  String get mealSummaryLabelIngredients => 'Ingredients';

  @override
  String get mealSummaryLabelCalories => 'Calories';

  @override
  String get mealSummaryLabelAllergens => 'Allergens';

  @override
  String mealSummaryCaloriesValue(int calories) {
    return '$calories kcal';
  }

  @override
  String get mealSummaryNoEstimates =>
      'The assistant could not estimate anything. Write the details yourself.';

  @override
  String get mealPublishError =>
      'We could not publish this Meal. Please try again.';

  @override
  String get mealPublishedConfirmation => 'This Meal is on the menu now.';

  @override
  String publicMealPriceValue(String price) {
    return '$price EGP';
  }

  @override
  String get publicMealOpenKitchen => 'See the kitchen';

  @override
  String get publicMealCaloriesUnknown => 'Calories not worked out';

  @override
  String get publicMealAllergensUnknown =>
      'No allergens listed. If you have an allergy, ask the Cook.';

  @override
  String get publicMealNutritionFromCook =>
      'These figures are the Cook\'s own.';
}
