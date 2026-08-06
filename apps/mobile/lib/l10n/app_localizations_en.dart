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
  String get discoveryLoadError =>
      'We couldn\'t load the food right now. Let\'s try again in a moment.';

  @override
  String publishMeal(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Publish Meal',
        'other': 'Publish Meal',
      },
    );
    return '$_temp0';
  }

  @override
  String archiveMeal(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Archive Meal',
        'other': 'Archive Meal',
      },
    );
    return '$_temp0';
  }

  @override
  String acceptOrder(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Accept Order',
        'other': 'Accept Order',
      },
    );
    return '$_temp0';
  }

  @override
  String rejectOrder(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Reject Order',
        'other': 'Reject Order',
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
            'The Cook could not take this Order right now. Try another Meal, or order from another Cook.',
        'other':
            'The Cook could not take this Order right now. Try another Meal, or order from another Cook.',
      },
    );
    return '$_temp0';
  }

  @override
  String networkUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'No internet connection. Check that you are online and try again.',
        'other':
            'No internet connection. Check that you are online and try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String aiEstimateNotice(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine':
            'These are AI Assistant estimates. The Cook has not confirmed them yet.',
        'other':
            'These are AI Assistant estimates. The Cook has not confirmed them yet.',
      },
    );
    return '$_temp0';
  }

  @override
  String get signInTitle => 'Welcome to Kafoo';

  @override
  String get signInPhoneLabel => 'Your phone number';

  @override
  String signInContinue(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Continue',
        'other': 'Continue',
      },
    );
    return '$_temp0';
  }

  @override
  String signInRateLimited(int minutes, String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Too many attempts. Wait $minutes minutes and try again.',
        'other': 'Too many attempts. Wait $minutes minutes and try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String codeTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Enter the code',
        'other': 'Enter the code',
      },
    );
    return '$_temp0';
  }

  @override
  String codeSubtitle(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String codeWrongCode(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Wrong code. Try again.',
        'other': 'Wrong code. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String codeExpired(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Code has expired. Request a new one.',
        'other': 'Code has expired. Request a new one.',
      },
    );
    return '$_temp0';
  }

  @override
  String codeResend(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Send a new code',
        'other': 'Send a new code',
      },
    );
    return '$_temp0';
  }

  @override
  String signInNetworkError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'No internet connection. Check that you are online and try again.',
        'other':
            'No internet connection. Check that you are online and try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvPromptDisplayName => 'What is your kitchen called?';

  @override
  String kitchenConvPromptStory(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Tell me about your cooking. What do you make and how?',
        'other': 'Tell me about your cooking. What do you make and how?',
      },
    );
    return '$_temp0';
  }

  @override
  String kitchenConvPromptArea(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Which area do you cook in?',
        'other': 'Which area do you cook in?',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvPromptDeliveryTerms =>
      'How do people receive their food from you?';

  @override
  String get kitchenConvPromptAddressForm =>
      'So I address you properly — do I say \"kammil\" or \"kammili\"?';

  @override
  String get kitchenConvAddressFormMasculine => 'Kammil';

  @override
  String get kitchenConvAddressFormFeminine => 'Kammili';

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
  String convContinue(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Continue',
        'other': 'Continue',
      },
    );
    return '$_temp0';
  }

  @override
  String convVoiceHint(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Say your answer out loud',
        'other': 'Say your answer out loud',
      },
    );
    return '$_temp0';
  }

  @override
  String convVoiceUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'Voice recognition is not available. You can type your answer instead.',
        'other':
            'Voice recognition is not available. You can type your answer instead.',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvSummaryTitle => 'Here is what you told us';

  @override
  String kitchenConvSummaryConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Looks good, save',
        'other': 'Looks good, save',
      },
    );
    return '$_temp0';
  }

  @override
  String convEdit(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Change',
        'other': 'Change',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenConvLabelDisplayName => 'Kitchen name';

  @override
  String get kitchenConvLabelStory => 'Your story';

  @override
  String get kitchenConvLabelArea => 'Area';

  @override
  String get kitchenConvLabelDeliveryTerms => 'How food reaches people';

  @override
  String get kitchenConvLabelAddressForm => 'How we address you';

  @override
  String get kitchenConvLabelPhoto => 'Kitchen photo';

  @override
  String kitchenConvPhotoAdd(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Add a photo',
        'other': 'Add a photo',
      },
    );
    return '$_temp0';
  }

  @override
  String kitchenConvSaveError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Something went wrong saving. Please try again.',
        'other': 'Something went wrong saving. Please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String kitchenConvPhotoError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'The photo could not be uploaded. You can continue without one.',
        'other':
            'The photo could not be uploaded. You can continue without one.',
      },
    );
    return '$_temp0';
  }

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
  String kitchenEditSave(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Save change',
        'other': 'Save change',
      },
    );
    return '$_temp0';
  }

  @override
  String get kitchenEditCancel => 'Cancel';

  @override
  String get kitchenEditSaved => 'Changed';

  @override
  String removeAccountEntry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Delete my account',
        'other': 'Delete my account',
      },
    );
    return '$_temp0';
  }

  @override
  String get removeAccountTitle => 'Delete account';

  @override
  String get removeAccountBody =>
      'Your account and everything in it will be deleted: your kitchen and its photo. This cannot be undone.';

  @override
  String removeAccountConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Delete my account',
        'other': 'Delete my account',
      },
    );
    return '$_temp0';
  }

  @override
  String get removeAccountCancel => 'Back';

  @override
  String removeAccountError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'We could not delete your account. It is unchanged — please try again.',
        'other':
            'We could not delete your account. It is unchanged — please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String recoveryEmailTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Add an email address?',
        'other': 'Add an email address?',
      },
    );
    return '$_temp0';
  }

  @override
  String recoveryEmailBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'If you lose your number, an email address is how you get back into your account. It is not required, and you can skip it.',
        'other':
            'If you lose your number, an email address is how you get back into your account. It is not required, and you can skip it.',
      },
    );
    return '$_temp0';
  }

  @override
  String get recoveryEmailLabel => 'Your email address';

  @override
  String recoveryEmailAttach(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Add email',
        'other': 'Add email',
      },
    );
    return '$_temp0';
  }

  @override
  String get recoveryEmailDecline => 'Not now';

  @override
  String get recoveryEmailAttached =>
      'Done. We have sent a confirmation message to that address.';

  @override
  String recoveryEmailError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not add that address. Please try again.',
        'other': 'We could not add that address. Please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String signInLostNumber(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Can\'t reach your number?',
        'other': 'Can\'t reach your number?',
      },
    );
    return '$_temp0';
  }

  @override
  String emailSignInTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Sign in by email',
        'other': 'Sign in by email',
      },
    );
    return '$_temp0';
  }

  @override
  String emailSignInBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'If you added an email address to your account before, enter it here and we will send you a code.',
        'other':
            'If you added an email address to your account before, enter it here and we will send you a code.',
      },
    );
    return '$_temp0';
  }

  @override
  String get emailSignInLabel => 'Email address';

  @override
  String emailSignInUnknown(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'That address is not linked to any account. Try signing in with your phone number.',
        'other':
            'That address is not linked to any account. Try signing in with your phone number.',
      },
    );
    return '$_temp0';
  }

  @override
  String changePhoneTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Change phone number',
        'other': 'Change phone number',
      },
    );
    return '$_temp0';
  }

  @override
  String changePhoneBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'Enter your new number. We will send a code to it, and once you confirm, the old number will stop reaching your account.',
        'other':
            'Enter your new number. We will send a code to it, and once you confirm, the old number will stop reaching your account.',
      },
    );
    return '$_temp0';
  }

  @override
  String get changePhoneLabel => 'New number';

  @override
  String changePhoneEntry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Change phone number',
        'other': 'Change phone number',
      },
    );
    return '$_temp0';
  }

  @override
  String get changePhoneDone =>
      'Your number has changed. The old one no longer reaches your account.';

  @override
  String changePhoneError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'We could not change your number. Your old number still works — please try again.',
        'other':
            'We could not change your number. Your old number still works — please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String aiMealAnalysisInvalid(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'We could not read the AI Assistant\'s reply. Try again, or fill the details in yourself.',
        'other':
            'We could not read the AI Assistant\'s reply. Try again, or fill the details in yourself.',
      },
    );
    return '$_temp0';
  }

  @override
  String aiPromptNotStubbed(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'The AI Assistant is not available right now. Carry on yourself and we will try again later.',
        'other':
            'The AI Assistant is not available right now. Carry on yourself and we will try again later.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealUnauthorized(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Sign in first and try again.',
        'other': 'Sign in first and try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String get analyzeMealNotOwned => 'This Meal is not yours.';

  @override
  String analyzeMealRateLimited(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Too many attempts. Wait a bit and try again.',
        'other': 'Too many attempts. Wait a bit and try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealTimeout(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'The response took too long. Try again.',
        'other': 'The response took too long. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealInvalidResponse(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'We could not understand the AI Assistant\'s reply. Try again, or fill the details in yourself.',
        'other':
            'We could not understand the AI Assistant\'s reply. Try again, or fill the details in yourself.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealProviderError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'The AI Assistant is not available right now. Try again later, or fill the details in yourself.',
        'other':
            'The AI Assistant is not available right now. Try again later, or fill the details in yourself.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealServerError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Something went wrong on our side. Please try again.',
        'other': 'Something went wrong on our side. Please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String analyzeMealUnknownError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'An unexpected error occurred. Try again, or fill the details in yourself.',
        'other':
            'An unexpected error occurred. Try again, or fill the details in yourself.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealSaveError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not save the Meal. Please try again.',
        'other': 'We could not save the Meal. Please try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealPhotoError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'The photo could not be uploaded. You can continue without one.',
        'other':
            'The photo could not be uploaded. You can continue without one.',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvPromptDish => 'What did you cook?';

  @override
  String get mealConvHintDish => 'For example: koshary, mahshi, panee chicken';

  @override
  String mealConvPromptDescription(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Tell me about it. What\'s in it and how is it made?',
        'other': 'Tell me about it. What\'s in it and how is it made?',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvHintDescription =>
      'For example: lentils, rice and pasta, with fried onion on top';

  @override
  String get mealConvPromptPhoto => 'Is there a photo of the dish?';

  @override
  String mealConvHintPhoto(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'A photo gets you more orders, and you can skip it if you would rather not',
        'other':
            'A photo gets you more orders, and you can skip it if you would rather not',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvPhotoDisclosure =>
      'If you send a photo, the assistant will look at it to estimate the ingredients and calories. We will not use it for anything else.';

  @override
  String mealConvPhotoSkip(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Continue without a photo',
        'other': 'Continue without a photo',
      },
    );
    return '$_temp0';
  }

  @override
  String mealConvPhotoAdd(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Add a photo of the Meal',
        'other': 'Add a photo of the Meal',
      },
    );
    return '$_temp0';
  }

  @override
  String mealConvPromptPrice(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'What do you sell it for?',
        'other': 'What do you sell it for?',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvHintPrice => 'The price of the whole dish, in pounds';

  @override
  String get mealConvFallbackNotice =>
      'The AI Assistant couldn\'t work out what kind of food this is, so there are two more questions.';

  @override
  String get mealConvPromptCuisine => 'Which kind of cooking is this Meal?';

  @override
  String mealConvHintCuisine(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Pick the closest one',
        'other': 'Pick the closest one',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealConvPromptCategory =>
      'And what sort of dish is it? A main, a dessert, a soup?';

  @override
  String mealConvHintCategory(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Pick the closest one',
        'other': 'Pick the closest one',
      },
    );
    return '$_temp0';
  }

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
  String mealSummaryConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Looks right, publish it',
        'other': 'Looks right, publish it',
      },
    );
    return '$_temp0';
  }

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
  String mealSummaryEstimatesNotice(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'These are estimates from the assistant, not confirmed facts. Check them and confirm each one before you publish.',
        'other':
            'These are estimates from the assistant, not confirmed facts. Check them and confirm each one before you publish.',
      },
    );
    return '$_temp0';
  }

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
  String mealSummaryNoEstimates(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'The assistant could not estimate anything. Write the details yourself.',
        'other':
            'The assistant could not estimate anything. Write the details yourself.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealPublishError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not publish this Meal. Please try again.',
        'other': 'We could not publish this Meal. Please try again.',
      },
    );
    return '$_temp0';
  }

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
  String publicMealAllergensUnknown(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine':
            'No allergens listed. If you have an allergy, ask the Cook.',
        'other': 'No allergens listed. If you have an allergy, ask the Cook.',
      },
    );
    return '$_temp0';
  }

  @override
  String publicMealNutritionFromCook(String cookForm) {
    String _temp0 = intl.Intl.selectLogic(
      cookForm,
      {
        'feminine': 'These figures are the Cook\'s own.',
        'other': 'These figures are the Cook\'s own.',
      },
    );
    return '$_temp0';
  }

  @override
  String get myMealsTitle => 'My Meals';

  @override
  String myMealsEmpty(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'No Meals yet. Start one.',
        'other': 'No Meals yet. Start one.',
      },
    );
    return '$_temp0';
  }

  @override
  String get myMealsStatusDraft => 'Draft';

  @override
  String get myMealsStatusPublished => 'On the menu';

  @override
  String get myMealsStatusUnavailable => 'Not available right now';

  @override
  String get myMealsStatusArchived => 'Retired';

  @override
  String mealMakeUnavailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Take it off the menu',
        'other': 'Take it off the menu',
      },
    );
    return '$_temp0';
  }

  @override
  String mealMakeAvailable(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Put it back on the menu',
        'other': 'Put it back on the menu',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLastOnOfferWarning(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'This is the last Meal on your menu. If you take it off, nobody will find your kitchen until you put something back.',
        'other':
            'This is the last Meal on your menu. If you take it off, nobody will find your kitchen until you put something back.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLastOnOfferConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Take it off anyway',
        'other': 'Take it off anyway',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLastOnOfferCancel(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Leave it on the menu',
        'other': 'Leave it on the menu',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLoadError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not load your Meals. Try again.',
        'other': 'We could not load your Meals. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealAvailabilityError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not change the Meal. Try again.',
        'other': 'We could not change the Meal. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We could not delete the draft. Try again.',
        'other': 'We could not delete the draft. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealLoadRetry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Try again',
        'other': 'Try again',
      },
    );
    return '$_temp0';
  }

  @override
  String mealRetire(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Retire it permanently',
        'other': 'Retire it permanently',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealRetireWarning =>
      'This Meal comes off the menu for good and can never go back on. It stays in your list, but nobody else will see it again.';

  @override
  String mealRetireConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Retire it permanently',
        'other': 'Retire it permanently',
      },
    );
    return '$_temp0';
  }

  @override
  String mealRetireCancel(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Leave it as it is',
        'other': 'Leave it as it is',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteDraft(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Delete the draft',
        'other': 'Delete the draft',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteDraftWarning(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'This draft will be deleted for good and cannot be brought back.',
        'other':
            'This draft will be deleted for good and cannot be brought back.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealDeleteDraftConfirm(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Delete it',
        'other': 'Delete it',
      },
    );
    return '$_temp0';
  }

  @override
  String mealEditTitle(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Edit the Meal',
        'other': 'Edit the Meal',
      },
    );
    return '$_temp0';
  }

  @override
  String get mealEditSaved => 'Changed.';

  @override
  String get mealEditNoChange => 'Nothing changed.';

  @override
  String get mealNeedsKitchenTitle => 'You don\'t have a kitchen yet';

  @override
  String mealNeedsKitchenBody(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine':
            'Before you offer a Meal, people need to know who is cooking it. Set up your kitchen first, then carry on.',
        'other':
            'Before you offer a Meal, people need to know who is cooking it. Set up your kitchen first, then carry on.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealNeedsKitchenAction(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Set up my kitchen',
        'other': 'Set up my kitchen',
      },
    );
    return '$_temp0';
  }

  @override
  String mealKitchenCheckError(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'We couldn\'t check your kitchen. Try again.',
        'other': 'We couldn\'t check your kitchen. Try again.',
      },
    );
    return '$_temp0';
  }

  @override
  String mealKitchenCheckRetry(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Try again',
        'other': 'Try again',
      },
    );
    return '$_temp0';
  }

  @override
  String get myMealsNoPriceYet => 'No price yet';

  @override
  String get myMealsUntitledDraft => 'Untitled draft';

  @override
  String mealResumeDraft(String addressForm) {
    String _temp0 = intl.Intl.selectLogic(
      addressForm,
      {
        'feminine': 'Carry on with this Meal',
        'other': 'Carry on with this Meal',
      },
    );
    return '$_temp0';
  }
}
