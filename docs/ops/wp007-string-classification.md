# WP-007 — Arabic string gender-form classification

Source: `apps/mobile/lib/l10n/app_ar.arb`  
Rule basis: task brief + `decisions/0010-address-a-cook-in-their-own-grammatical-form.md`  
Scope: every non-`@` key. Read-only analysis; ARB untouched.

**Verdict key**

| Verdict | Meaning |
|---|---|
| `CONVERT` | Second person to the reader; spelling changes for a woman |
| `COOK-FORM` | Shown to a Customer (or mixed); describes a Cook — needs the **Cook's** stored form |
| `IDENTICAL` | Second person (or involves the reader) but spelled the same without diacritics |
| `N/A` | Does not address or describe a person in a gendered way |

Feminine proposals are Egyptian Arabic, conversational Cairo register.

| key | Arabic string | verdict | the exact word(s) that change | feminine form you propose |
|---|---|---|---|---|
| appTitle | كفو | N/A | — | — |
| publishMeal | انشر الأكلة | CONVERT | انشر | انشري الأكلة |
| archiveMeal | أرشف الأكلة | CONVERT | أرشف | أرشفي الأكلة |
| acceptOrder | اقبل الطلب | CONVERT | اقبل | اقبلي الطلب |
| rejectOrder | ارفض الطلب | CONVERT | ارفض | ارفضي الطلب |
| orderRejected | الطباخ مقدرش ياخد الطلب دلوقتي. جرب أكلة تانية أو اطلب من طباخ تاني. | COOK-FORM | الطباخ؛ مقدرش؛ ياخد؛ طباخ (second mention). Also Customer 2nd person: جرب؛ اطلب | feminine Cook branch: الطباخة مقدرتش تاخد الطلب دلوقتي. … من طباخة تانية. (Customer verbs جربي / اطلبي are a separate reader-form problem — see notes) |
| networkUnavailable | مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني. | CONVERT | اطمن؛ جرب | مفيش اتصال بالنت. اطمني إن النت شغال وجربي تاني. |
| aiEstimateNotice | دي تقديرات من المساعد الذكي، لسه محتاجة تأكيد من الطباخ. | COOK-FORM | الطباخ | … من الطباخة. (محتاجة agrees with تقديرات, not the Cook) |
| signInTitle | أهلاً بيك في كفو | IDENTICAL | — | object/prep. suffix ـك (بيك)؛ per rule identical. Colloquial writing often uses بيكي — see uncertain |
| signInPhoneLabel | رقم موبايلك | IDENTICAL | — | possessive ـك |
| signInContinue | كمّل | CONVERT | كمّل | كمّلي |
| signInRateLimited | جربت كتير. استنى {minutes} دقيقة وبعدين جرب تاني. | CONVERT | استنى؛ جرب | جربت كتير. استني {minutes} دقيقة وبعدين جربي تاني. (جربت = past, identical) |
| codeTitle | ادخل الكود | CONVERT | ادخل | ادخلي الكود |
| codeSubtitle | اتبعتلك كود على رقم {phone} | IDENTICAL | — | لك object suffix; verb is not 2nd-person active address |
| codeWrongCode | الكود غلط. جرب تاني. | CONVERT | جرب | الكود غلط. جربي تاني. |
| codeExpired | الكود انتهى. اطلب كود جديد. | CONVERT | اطلب | الكود انتهى. اطلبي كود جديد. |
| codeResend | ابعت كود جديد | CONVERT | ابعت | ابعتي كود جديد |
| signInNetworkError | مفيش اتصال بالنت. اطمن إن النت شغال وجرب تاني. | CONVERT | اطمن؛ جرب | مفيش اتصال بالنت. اطمني إن النت شغال وجربي تاني. |
| kitchenConvPromptDisplayName | مطبخك اسمه إيه؟ | IDENTICAL | — | possessive ـك |
| kitchenConvPromptStory | قولّي عن طبخك. بتعمل إيه وبتعمله إزاي؟ | CONVERT | قولّي؛ بتعمل؛ بتعمله | قوليلي عن طبخك. بتعملي إيه وبتعمليه إزاي؟ |
| kitchenConvPromptArea | في أنهي منطقة بتشتغل؟ | CONVERT | بتشتغل | في أنهي منطقة بتشتغلي؟ |
| kitchenConvPromptDeliveryTerms | إزاي الناس بتاخد أكلها منك؟ | IDENTICAL | — | منك suffix; بتاخد is 3rd person about الناس |
| kitchenConvHintDisplayName | مثلاً: مطبخ أم علي | N/A | — | — |
| kitchenConvHintStory | مثلاً: بنطبخ أكل بيتي على الطريقة القديمة | N/A | — | example / 1st person plural, not addressing the Cook |
| kitchenConvHintArea | مثلاً: المعادي، مصر الجديدة | N/A | — | — |
| kitchenConvHintDeliveryTerms | مثلاً: بنوصّل في ساعة أو بتيجي تاخد بنفسك | N/A | — | example of Cook's answer; inner «تاخد» addresses the Cook's customer, not the Cook. See uncertain |
| convContinue | كمّل | CONVERT | كمّل | كمّلي |
| convVoiceHint | قول إجابتك بصوتك | CONVERT | قول | قولي إجابتك بصوتك |
| convVoiceUnavailable | التعرف على الصوت مش متاح. ممكن تكتب إجابتك بدل كده. | CONVERT | تكتب | التعرف على الصوت مش متاح. ممكن تكتبي إجابتك بدل كده. |
| kitchenConvSummaryTitle | ده اللي قلته | IDENTICAL | — | past tense قلته |
| kitchenConvSummaryConfirm | تمام، احفظ | CONVERT | احفظ | تمام، احفظي |
| convEdit | غيّر | CONVERT | غيّر | غيّري |
| kitchenConvLabelDisplayName | اسم المطبخ | N/A | — | — |
| kitchenConvLabelStory | قصتك | IDENTICAL | — | possessive ـك |
| kitchenConvLabelArea | المنطقة | N/A | — | — |
| kitchenConvLabelDeliveryTerms | طريقة الاستلام | N/A | — | — |
| kitchenConvLabelPhoto | صورة المطبخ | N/A | — | noun صورة, not imperative صوّر |
| kitchenConvPhotoAdd | ضيف صورة | CONVERT | ضيف | ضيفي صورة |
| kitchenConvSaveError | حصل مشكلة أثناء الحفظ. جرب تاني. | CONVERT | جرب | حصل مشكلة أثناء الحفظ. جربي تاني. |
| kitchenConvPhotoError | الصورة ما اتحملتش. ممكن تكمل من غير صورة. | CONVERT | تكمل | الصورة ما اتحملتش. ممكن تكملي من غير صورة. |
| kitchenExistsTitle | عندك مطبخ بالفعل | IDENTICAL | — | عندك (ـك) |
| kitchenExistsBody | عندك مطبخ مسجّل على حسابك. هنروحله دلوقتي. | IDENTICAL | — | عندك / حسابك; هنروحله = 1st person plural |
| kitchenViewTitle | مطبخك | IDENTICAL | — | possessive ـك |
| kitchenEditCurrentValue | الحالي | N/A | — | — |
| kitchenEditNewValue | الجديد | N/A | — | — |
| kitchenEditSave | احفظ التغيير | CONVERT | احفظ | احفظي التغيير |
| kitchenEditCancel | إلغاء | N/A | — | noun |
| kitchenEditSaved | اتغيّر | N/A | — | about the value, not the person |
| removeAccountEntry | امسح حسابي | CONVERT | امسح | امسحي حسابي |
| removeAccountTitle | مسح الحساب | N/A | — | verbal noun |
| removeAccountBody | هيتمسح حسابك وكل حاجة فيه: مطبخك وصورته. مش هينفع نرجّعهم بعد كده. | IDENTICAL | — | possessive ـك; نرجّعهم = 1st person |
| removeAccountConfirm | امسح حسابي | CONVERT | امسح | امسحي حسابي |
| removeAccountCancel | رجوع | N/A | — | — |
| removeAccountError | مقدرناش نمسح الحساب. حسابك زي ما هو، جرب تاني. | CONVERT | جرب | … جربي تاني. (مقدرناش = 1st person) |
| recoveryEmailTitle | تحب تضيف إيميل؟ | CONVERT | تحب؛ تضيف | تحبي تضيفي إيميل؟ |
| recoveryEmailBody | لو ضاع منك رقمك، الإيميل هو اللي هيخليك توصل لحسابك تاني. مش مطلوب، وممكن تسيبه دلوقتي. | CONVERT | توصل؛ تسيبه | … هيخليك توصلي لحسابك تاني. … وممكن تسيبيه دلوقتي. (منك/رقمك/هيخليك/حسابك = ـك identical) |
| recoveryEmailLabel | الإيميل بتاعك | IDENTICAL | — | possessive ـك |
| recoveryEmailAttach | ضيف الإيميل | CONVERT | ضيف | ضيفي الإيميل |
| recoveryEmailDecline | مش دلوقتي | N/A | — | — |
| recoveryEmailAttached | تمام، ابعتنا لك رسالة تأكيد على الإيميل. | IDENTICAL | — | لك object suffix; ابعتنا = 1st person |
| recoveryEmailError | مقدرناش نضيف الإيميل. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| signInLostNumber | مش قادر توصل لرقمك؟ | CONVERT | قادر؛ توصل | مش قادرة توصلي لرقمك؟ |
| emailSignInTitle | ادخل بالإيميل | CONVERT | ادخل | ادخلي بالإيميل |
| emailSignInBody | لو كنت ضايف إيميل لحسابك قبل كده، اكتبه هنا وهنبعتلك كود. | CONVERT | كنت؛ ضايف؛ اكتبه | لو كنتي ضايفة إيميل لحسابك قبل كده، اكتبيه هنا وهنبعتلك كود. |
| emailSignInLabel | الإيميل | N/A | — | — |
| emailSignInUnknown | الإيميل ده مش مربوط بأي حساب. جرب تدخل برقم موبايلك. | CONVERT | جرب؛ تدخل | … جربي تدخلي برقم موبايلك. |
| changePhoneTitle | غيّر رقم الموبايل | CONVERT | غيّر | غيّري رقم الموبايل |
| changePhoneBody | اكتب الرقم الجديد. هنبعتلك كود عليه، ولما تأكده الرقم القديم هيبطل يوصل لحسابك. | CONVERT | اكتب؛ تأكده | اكتبي الرقم الجديد. … ولما تأكديه … |
| changePhoneLabel | الرقم الجديد | N/A | — | — |
| changePhoneEntry | غيّر رقم الموبايل | CONVERT | غيّر | غيّري رقم الموبايل |
| changePhoneDone | الرقم اتغيّر. الرقم القديم مبقاش يوصل لحسابك. | IDENTICAL | — | about the number; حسابك possessive |
| changePhoneError | مقدرناش نغيّر الرقم. رقمك القديم زي ما هو، جرب تاني. | CONVERT | جرب | … جربي تاني. |
| aiMealAnalysisInvalid | مش قادرين نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك. | CONVERT | جرب؛ اكتب | … جربي تاني، أو اكتبي التفاصيل بنفسك. (قادرين = we) |
| aiPromptNotStubbed | المساعد الذكي مش متاح دلوقتي. كمل بنفسك وهنجرب تاني بعدين. | CONVERT | كمل | … كملي بنفسك وهنجرب تاني بعدين. |
| analyzeMealUnauthorized | سجل دخولك الأول وجرب تاني. | CONVERT | سجل؛ جرب | سجّلي دخولك الأول وجربي تاني. |
| analyzeMealNotOwned | الأكلة دي مش ليك. | IDENTICAL | — | ليك object/prep. ـك |
| analyzeMealRateLimited | جربت كتير في وقت قليل. استنى شوية وجرب تاني. | CONVERT | استنى؛ جرب | جربت كتير في وقت قليل. استني شوية وجربي تاني. |
| analyzeMealTimeout | الرد اخد وقت طويل. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| analyzeMealInvalidResponse | مقدرناش نفهم رد المساعد الذكي. جرب تاني، أو اكتب التفاصيل بنفسك. | CONVERT | جرب؛ اكتب | … جربي تاني، أو اكتبي التفاصيل بنفسك. |
| analyzeMealProviderError | المساعد الذكي مش متاح دلوقتي. جرب تاني بعدين، أو اكتب التفاصيل بنفسك. | CONVERT | جرب؛ اكتب | … جربي تاني بعدين، أو اكتبي التفاصيل بنفسك. |
| analyzeMealServerError | حصل مشكلة من ناحيتنا. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| analyzeMealUnknownError | حصل مشكلة مش متوقعة. جرب تاني، أو اكتب التفاصيل بنفسك. | CONVERT | جرب؛ اكتب | … جربي تاني، أو اكتبي التفاصيل بنفسك. |
| mealSaveError | مقدرناش نحفظ الأكلة. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealPhotoError | الصورة ما اتحملتش. ممكن تكمل من غير صورة. | CONVERT | تكمل | … ممكن تكملي من غير صورة. |
| mealConvPromptDish | طبخت إيه؟ | IDENTICAL | — | past tense |
| mealConvHintDish | مثلاً: كشري، محشي، فراخ بانيه | N/A | — | — |
| mealConvPromptDescription | قولّي عنها. فيها إيه وبتتعمل إزاي؟ | CONVERT | قولّي | قوليلي عنها. فيها إيه وبتتعمل إزاي؟ (بتتعمل = about the dish) |
| mealConvHintDescription | مثلاً: عدس ورز ومكرونة، وبنحمّر البصل فوقها | N/A | — | example |
| mealConvPromptPhoto | في صورة للأكلة؟ | N/A | — | existential في |
| mealConvHintPhoto | الصورة بتخلّي الناس تطلب أكتر، وتقدر تعدّيها لو مش عايز | CONVERT | تقدر؛ عايز | … وتقدري تعدّيها لو مش عايزة (تعدّيها: stem ends in ي — identical; see uncertain) |
| mealConvPhotoDisclosure | لو بعت صورة، المساعد هيبصّ عليها عشان يقدّر المكوّنات والسعرات، ومش هنستخدمها في أي حاجة تانية. | IDENTICAL | — | بعت = past; rest 3rd/1st person |
| mealConvPhotoSkip | كمّل من غير صورة | CONVERT | كمّل | كمّلي من غير صورة |
| mealConvPhotoAdd | ضيف صورة للأكلة | CONVERT | ضيف | ضيفي صورة للأكلة |
| mealConvPromptPrice | بتبيعها بكام؟ | CONVERT | بتبيعها | بتبيعيها بكام؟ |
| mealConvHintPrice | سعر الطبق كامل بالجنيه | N/A | — | — |
| mealConvFallbackNotice | المساعد مقدرش يعرف نوع الأكلة، فمحتاج أسألك سؤالين كمان. | IDENTICAL | — | 1st person أسألك; ـك object suffix |
| mealConvPromptCuisine | الأكلة دي من أنهي مطبخ؟ | N/A | — | about the meal |
| mealConvHintCuisine | اختار اللي أقرب لأكلتك | CONVERT | اختار | اختاري اللي أقرب لأكلتك |
| mealConvPromptCategory | ودي أكلة إيه؟ طبق رئيسي، حلو، شوربة؟ | N/A | — | about the meal |
| mealConvHintCategory | اختار اللي أقرب | CONVERT | اختار | اختاري اللي أقرب |
| mealSummaryTitle | ده اللي قلته عن الأكلة | IDENTICAL | — | past tense |
| mealSummaryLabelDish | الأكلة | N/A | — | — |
| mealSummaryLabelDescription | التفاصيل | N/A | — | — |
| mealSummaryLabelPhoto | الصورة | N/A | — | — |
| mealSummaryLabelPrice | السعر | N/A | — | — |
| mealSummaryNoPhoto | من غير صورة | N/A | — | — |
| mealSummaryConfirm | تمام، انشرها | CONVERT | انشرها | تمام، انشريها |
| cuisineEgyptian | مصري | N/A | — | cuisine label, not a person |
| cuisineLevantine | شامي | N/A | — | — |
| cuisineGulf | خليجي | N/A | — | — |
| cuisineSudanese | سوداني | N/A | — | — |
| cuisineMoroccan | مغربي | N/A | — | — |
| cuisineTurkish | تركي | N/A | — | — |
| cuisineItalian | إيطالي | N/A | — | — |
| cuisineAsian | آسيوي | N/A | — | — |
| cuisineAmerican | أمريكاني | N/A | — | — |
| cuisineOther | تاني | N/A | — | — |
| categoryMain | طبق رئيسي | N/A | — | — |
| categoryAppetizer | مقبلات | N/A | — | — |
| categorySoup | شوربة | N/A | — | — |
| categorySalad | سلطة | N/A | — | — |
| categorySide | طبق جنب | N/A | — | — |
| categoryDessert | حلو | N/A | — | — |
| categoryBakery | مخبوزات | N/A | — | — |
| categoryDrink | مشروب | N/A | — | — |
| categoryOther | تاني | N/A | — | — |
| mealSummaryEstimatesTitle | تقديرات المساعد | N/A | — | — |
| mealSummaryEstimatesNotice | دي تقديرات من المساعد، مش حاجة مؤكدة. راجعها وأكّدها قبل ما تنشر. | CONVERT | راجعها؛ أكّدها؛ تنشر | … راجعيها وأكّديها قبل ما تنشري. |
| mealSummaryEstimateBadge | تقدير | N/A | — | — |
| mealSummaryApprove | تمام | N/A | — | — |
| mealSummaryApproved | اتأكد | N/A | — | state of the estimate |
| mealSummaryNeedsApproval | لسه فيه تقديرات محتاجة موافقتك | IDENTICAL | — | موافقتك possessive |
| mealSummaryLabelCuisine | نوع المطبخ | N/A | — | — |
| mealSummaryLabelCategory | نوع الطبق | N/A | — | — |
| mealSummaryLabelIngredients | المكونات | N/A | — | — |
| mealSummaryLabelCalories | السعرات | N/A | — | — |
| mealSummaryLabelAllergens | الحساسية | N/A | — | — |
| mealSummaryCaloriesValue | {calories} سعرة | N/A | — | — |
| mealSummaryNoEstimates | المساعد مقدرش يقدّر حاجة. اكتب التفاصيل بنفسك. | CONVERT | اكتب | … اكتبي التفاصيل بنفسك. |
| mealPublishError | مقدرناش ننشر الأكلة. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealPublishedConfirmation | الأكلة بقت على المنيو. | N/A | — | about the meal |
| publicMealPriceValue | {price} جنيه | N/A | — | — |
| publicMealOpenKitchen | شوف المطبخ | CONVERT | شوف | شوفي المطبخ — **Customer-facing**; not Cook form-of-address (see notes) |
| publicMealCaloriesUnknown | السعرات مش متحسبة | N/A | — | — |
| publicMealAllergensUnknown | مفيش حساسية متسجلة. لو عندك حساسية من حاجة، اسأل الطباخ. | COOK-FORM | الطباخ (and Customer 2nd person اسأل) | … اسألي الطباخة. (dual: Cook noun = COOK-FORM; اسأل = Customer reader — see notes) |
| publicMealNutritionFromCook | الأرقام دي من الطباخ نفسه. | COOK-FORM | الطباخ؛ نفسه | الأرقام دي من الطباخة نفسها. |
| myMealsTitle | أكلاتي | N/A | — | 1st person «my meals» label |
| myMealsEmpty | لسه مافيش أكلات. ابدأ واحدة. | CONVERT | ابدأ | لسه مافيش أكلات. ابدئي واحدة. |
| myMealsStatusDraft | مسودة | N/A | — | — |
| myMealsStatusPublished | على المنيو | N/A | — | — |
| myMealsStatusUnavailable | مش متاحة دلوقتي | N/A | — | about the meal |
| myMealsStatusArchived | اتشالت خلاص | N/A | — | about the meal |
| mealMakeUnavailable | شيلها من المنيو | CONVERT | شيلها | شيليها من المنيو |
| mealMakeAvailable | رجّعها للمنيو | CONVERT | رجّعها | رجّعيها للمنيو |
| mealLastOnOfferWarning | دي آخر أكلة على المنيو. لو شيلتها، محدش هيلاقي مطبخك لحد ما ترجّع حاجة. | CONVERT | ترجّع | … لحد ما ترجّعي حاجة. (شيلتها = past, identical; مطبخك possessive) |
| mealLastOnOfferConfirm | شيلها برضه | CONVERT | شيلها | شيليها برضه |
| mealLastOnOfferCancel | سيبها زي ما هي | CONVERT | سيبها | سيبيها زي ما هي |
| mealLoadError | مانفعش نجيب أكلاتك. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealAvailabilityError | مانفعش نغير حالة الأكلة. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealDeleteError | مانفعش نمسح المسودة. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealLoadRetry | حاول تاني | CONVERT | حاول | حاولي تاني |
| mealRetire | شيلها نهائي | CONVERT | شيلها | شيليها نهائي |
| mealRetireWarning | الأكلة دي هتتشال من المنيو نهائي ومش هترجع تاني أبداً. هتفضل محفوظة في قايمتك بس محدش تاني هيشوفها. | IDENTICAL | — | هترجع/هتفضل about the meal (3rd fem.); قايمتك possessive |
| mealRetireConfirm | شيلها نهائي | CONVERT | شيلها | شيليها نهائي |
| mealRetireCancel | سيبها زي ما هي | CONVERT | سيبها | سيبيها زي ما هي |
| mealDeleteDraft | امسح المسودة | CONVERT | امسح | امسحي المسودة |
| mealDeleteDraftWarning | المسودة دي هتتمسح خالص ومش هتقدر ترجعها. | CONVERT | هتقدر؛ ترجعها | … ومش هتقدري ترجعيها. |
| mealDeleteDraftConfirm | امسحها | CONVERT | امسحها | امسحيها |
| mealEditTitle | عدّل الأكلة | CONVERT | عدّل | عدّلي الأكلة |
| mealEditSaved | اتغيّرت. | N/A | — | about the meal |
| mealEditNoChange | مافيش حاجة اتغيّرت. | N/A | — | — |
| mealNeedsKitchenTitle | لسه معندكش مطبخ | IDENTICAL | — | معندكش (ـك) |
| mealNeedsKitchenBody | قبل ما تعرض أكلة، الناس لازم تعرف مين اللي بيطبخها. اعمل مطبخك الأول وبعدين كمّل. | CONVERT | تعرض؛ اعمل؛ كمّل | قبل ما تعرضي أكلة، … اعملي مطبخك الأول وبعدين كمّلي. |
| mealNeedsKitchenAction | اعمل مطبخي | CONVERT | اعمل | اعملي مطبخي |
| mealKitchenCheckError | مقدرناش نتأكد من مطبخك. جرب تاني. | CONVERT | جرب | … جربي تاني. |
| mealKitchenCheckRetry | جرب تاني | CONVERT | جرب | جربي تاني |
| myMealsNoPriceYet | لسه من غير سعر | N/A | — | — |
| myMealsUntitledDraft | مسودة من غير اسم | N/A | — | — |
| mealResumeDraft | كمّل الأكلة دي | CONVERT | كمّل | كمّلي الأكلة دي |

---

## 1. Counts

| verdict | count |
|---|---|
| CONVERT | 86 |
| COOK-FORM | 4 |
| IDENTICAL | 28 |
| N/A | 61 |
| **Total keys** | **179** |

ADR-0010’s “56 of 94” was an earlier snapshot of the file; the file has grown (E2 Meal strings). Actionable for the form-of-address sweep: **CONVERT 86 + COOK-FORM 4 = 90**.

---

## 2. Uncertain judgements (check by hand)

These are the rows I would not bet the product voice on without a native pass.

1. **signInTitle — `أهلاً بيك` → IDENTICAL**  
   Task rule: object/prep. ـك is identical (with `لك`, `هيخليك`). In real Cairo chat people often write **بيكي**. If you want the greeting to *feel* feminine on screen, this becomes CONVERT despite the suffix rule.

2. **analyzeMealNotOwned — `مش ليك` → IDENTICAL**  
   Same ـك rule. Spoken fem is still /lik/; writing sometimes stays ليك for both. Low risk either way.

3. **kitchenConvPromptStory / mealConvPromptDescription — `قولّي` → `قوليلي`**  
   Masc *ʾullī* (قول+لي) vs fem *ʾulīlī*. Proposed spelling **قوليلي** is common; **قولّيلي** also appears. Worth one native pick for the whole product, then reuse.

4. **mealConvHintPhoto — `تعدّيها`**  
   Stem already ends in ي (عدّى). I left it identical and only changed **تقدر → تقدري**, **عايز → عايزة**. Confirm a speaker wouldn’t write تعدّيها differently.

5. **kitchenConvHintDeliveryTerms — N/A**  
   Example answer containing `بتيجي تاخد بنفسك`. Inner second person is the Cook speaking to *their* customer. Not Kafoo→Cook. If hints are ever read as product voice addressing the Cook, **تاخد → تاخدي** would flip this to CONVERT.

6. **orderRejected — COOK-FORM with embedded Customer imperatives**  
   Three jobs in one string: (a) Cook third person `الطباخ مقدرش ياخد`, (b) generic `طباخ تاني`, (c) Customer `جرب` / `اطلب`. Cook form-of-address fixes (a)/(b). (c) needs the *Customer’s* form if you ever store one — today you don’t. Do not wire (c) to the Cook’s preference.

7. **publicMealAllergensUnknown — same dual problem**  
   `الطباخ` = COOK-FORM. `اسأل` / `عندك` = Customer reader. Same trap as orderRejected.

8. **publicMealOpenKitchen — marked CONVERT but Customer-only**  
   Linguistically `شوف → شوفي`. Implementation must **not** feed the Cook’s form-of-address into Customer UI. Either leave masculine default for Customers, or a future Customer preference. Flagged CONVERT so it is not skipped linguistically; product decision still open.

9. **networkUnavailable / sign-in / code / recovery / change-phone strings**  
   Shared identity surfaces: reader may be Cook or Customer, often before a Kitchen Profile (and form-of-address) exists. CONVERT is correct linguistically; runtime may need a default (ADR leans to asking Cooks in onboarding — Customers may stay on a default branch).

10. **emailSignInBody — `كنت ضايف` → `كنتي ضايفة`**  
    Past *kunt/kunti* is one of the few past forms Egyptians often **write** differently. I marked CONVERT. If you apply the brief’s “past tense = identical” strictly, only **ضايف → ضايفة** and **اكتبه → اكتبيه** would remain — but leaving كنت unisex reads slightly off for many women.

11. **archiveMeal — `أرشف`**  
    Loan imperative; feminine **أرشفي** is fine. Alternative product voice: **شيليها من النشر** / keep archive as noun label only. Not wrong — slightly stiff.

12. **myMealsEmpty — `ابدأ واحدة` → `ابدئي واحدة`**  
    Spelling ابدئي vs ابدأي varies. Prefer **ابدئي** in EA UI.

13. **mealNeedsKitchenBody — `مين اللي بيطبخها`**  
    Left unchanged: about “whoever cooks it,” not the addressee. If rewritten to address the Cook (“إنتي اللي بتطبخيها”) it would CONVERT hard — better not.

14. **Cuisine/category adjectives (`مصري`, `شامي`, …)**  
    N/A as dish taxonomy. They are grammatically masculine adjectives agreeing with مطبخ/أكل implied — not form-of-address. Do not branch these on the Cook.

15. **Imperative + object clitic clusters** (`انشرها`, `شيلها`, `سيبها`, `امسحها`, `راجعها`, `أكّدها`, `رجّعها`)  
    Proposed fem inserts ي before the clitic: **انشريها، شيليها، سيبيها، …**. This is the normal EA pattern; confirm one house style (with/without shadda continuity) and apply everywhere.

16. **aiEstimateNotice — only `الطباخ` → `الطباخة`**  
    `محتاجة` already agrees with تقديرات. No verb branch. Simplest COOK-FORM in the file.

17. **publicMealNutritionFromCook — `نفسه` → `نفسها`**  
    Agreement with الطباخة, not a second-person issue. Easy to miss if someone only greps verbs.

---

## 3. Awkward feminine / better rewritten than branched

| key | issue | recommendation |
|---|---|---|
| orderRejected | One string mixes Cook third-person gender with Customer imperatives | Split into two keys later, or accept a compound ICU (`cookForm` × optional future `readerForm`). Branching only `cookForm` leaves Customer verbs masculine for women Customers |
| publicMealAllergensUnknown | Same mix: `اسأل` + `الطباخ` | Prefer rewrite to avoid Customer imperative: e.g. «مفيش حساسية متسجلة. لو فيه حساسية، كلّمي الطباخة.» still needs Cook form on الطباخ/ة; or keep and dual-select |
| archiveMeal | `أرشف` is not everyday Cairo speech | Consider product synonym at conversion time (`شيلي من المنيو` already exists elsewhere) rather than a rare feminine loan |
| kitchenConvPromptStory | `قوليلي عن طبخك. بتعملي إيه وبتعمليه إزاي؟` is correct but dense | Optional softer rewrite: «حكيلي عن طبخك…» (حكيلي works for both in many speakers’ writing — could shrink a branch). Only if you want fewer selects |
| signInLostNumber | `مش قادرة توصلي لرقمك؟` is natural | Keep; do not rewrite to avoid gender — this is the ADR’s poster example of why the work exists |
| mealMakeUnavailable / mealRetire / confirms | `شيليها` repeated | Fine in EA; not awkward. No rewrite needed |

---

## 4. COOK-FORM inventory (complete)

Every string that describes a Cook to someone else (not only the two ADR named):

| key | Cook-referring piece | feminine sketch |
|---|---|---|
| orderRejected | الطباخ مقدرش ياخد … طباخ تاني | الطباخة مقدرتش تاخد … طباخة تانية |
| aiEstimateNotice | من الطباخ | من الطباخة |
| publicMealAllergensUnknown | اسأل الطباخ | … الطباخة (plus Customer verb if branched) |
| publicMealNutritionFromCook | من الطباخ نفسه | من الطباخة نفسها |

No other key in this file third-persons a Cook with gendered morphology. (`بيطبخها` in mealNeedsKitchenBody is generic “who cooks it,” not a specific Cook’s form.)
