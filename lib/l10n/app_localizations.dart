import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../models/week_availability.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Global null-safe localization helper with fallback to English
  /// Returns fallback (default 'N/A') if value is null or empty
  String _safeGet(String key, {String fallback = 'N/A'}) {
    // Try current language first
    final langMap = _localizedValues[locale.languageCode];
    if (langMap != null) {
      final value = langMap[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    
    // Fallback to English if key not found in current language
    final enMap = _localizedValues['en'];
    if (enMap != null) {
      final enValue = enMap[key];
      if (enValue != null && enValue.isNotEmpty) {
        return enValue;
      }
    }
    
    // Final fallback
    return fallback;
  }
  

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('he', ''), // Hebrew
    Locale('ar', ''), // Arabic  
    Locale('en', ''), // English
  ];

  // Hebrew translations
  static const Map<String, Map<String, String>> _localizedValues = {
    'he': {
      'appTitle': 'שכונתי',
      'hello': 'שלום',
      'helloName': 'שלום, {name}',
      'connected': 'מחובר',
      'notConnected': 'לא מחובר',
      'disconnected': 'מנותק',
      'welcomeBack': 'ברוך הבא חזור',
      'welcome': 'ברוך הבא לשכונה החכמה שלך',
      'welcomeSubtitle': 'הירשם כאורח במשך 3 חודשים ללא עלות וקבל גישה מלאה לכל השירותים',
      'joinCommunity': 'הצטרף לקהילה שלנו',
      'fullName': 'שם מלא',
      'email': 'אימייל',
      'password': 'סיסמה',
      'emailAndPassword': 'אימייל וסיסמה',
      'continueWithGoogle': 'המשך עם גוגל',
      'loginWithShchunati': 'התחבר עם שכונתי',
      'continueWithoutRegistration': 'המשך ללא הרשמה',
      'pleaseRegisterFirst': 'עליך להירשם קודם כדי לבצע פעולה זו',
      'or': 'או',
      'byContinuingYouAgree': 'על ידי המשך השימוש באפליקציה, אתה מסכים ל:',
      'termsOfService': 'תנאי שימוש',
      'privacyPolicy': 'מדיניות פרטיות',
      'termsButton': 'תנאי שימוש',
      'privacyButton': 'מדיניות פרטיות',
      'termsAndPrivacyButton': 'תנאי שימוש ומדיניות פרטיות',
      'copyright': '© 2025 שכונתי. כל הזכויות שמורות.',
      'aboutButton': 'אודות האפליקציה',
      'aboutTitle': 'אודות אפליקציית שכונתי',
      'aboutAppName': 'שכונתי',
      'aboutDescription': 'אפליקציית "שכונתי" היא פלטפורמה דיגיטלית המחברת בין מבקשי שירותים לנותני שירותים בקהילה המקומית. האפליקציה מאפשרת לך לפרסם בקשות עזרה, להציע שירותים, לתקשר עם שכנים ולנהל עסקאות בצורה בטוחה ונוחה.\n\nהאפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל. האפליקציה פועלת כמתווכת בלבד ואינה מתערבת בעסקאות או בשירותים בין המשתמשים.',
      'aboutVersion': 'גרסה',
      'aboutSupport': 'תמיכה',
      'aboutSupportDescription': 'לשאלות, בעיות או בקשות, אנא פנה לתמיכה',
      'aboutSupportEmail': 'support@shchunati.com',
      'aboutSupportSubject': 'שאלה/בקשה - אפליקציית שכונתי',
      'aboutClickToContact': 'לחץ ליצירת קשר',
      'aboutLegalTitle': 'מסמכים משפטיים',
      'aboutFooter': '© 2025 שכונתי. כל הזכויות שמורות.',
      'newRegistration': 'הרשמה חדשה',
      'forgotPassword': 'שכחתי סיסמה',
      'pleaseEnterEmail': 'אנא הזן כתובת אימייל',
      'verifyEmailBelongsToYou': 'וודא שהאימייל שייך לך! אם תזין אימייל של מישהו אחר, הוא יקבל את קישור איפוס הסיסמה.',
      'sendLink': 'שלח קישור',
      'passwordResetLinkSentTo': 'קישור לאיפוס סיסמה נשלח ל-',
      'applyingLanguage': 'מחיל שפה...',
      'userType': 'סוג משתמש',
      'personal': 'פרטי',
      'business': 'עסקי',
      'limitedAccess': 'גישה מוגבלת',
      'fullAccess': 'גישה מלאה',
      'register': 'הרשמה',
      'login': 'התחברות',
      'alreadyHaveAccount': 'יש לך כבר חשבון? התחבר',
      'noAccount': 'אין לך חשבון? הרשם',
      'home': 'בית',
      'notifications': 'התראות',
      'chat': 'צ\'אט',
      'profile': 'פרופיל',
      'myRequests': 'בקשות בטיפול שלי',
      'myRequestsMenu': 'בקשות שלי', // לתפריט התחתון
      'serviceProviders': 'עסקים ועצמאיים',
      'openRequestsForTreatment': 'בקשות פתוחות לטיפול',
      'newRequest': 'בקשה חדשה',
      'logout': 'התנתק',
      'language': 'שפה',
      'selectLanguage': 'בחר שפה',
      'hebrew': 'עברית',
      'arabic': 'ערבית',
      'english': 'אנגלית',
      'theme': 'ערכת נושא',
      'lightTheme': 'בהיר',
      'darkTheme': 'כהה',
      'systemTheme': 'מערכת',
      'goldTheme': 'זהב',
      'searchHint': 'חיפוש בקשות...',
      'searchProvidersHint': 'חיפוש עסקים ועצמאיים...',
      'location': 'מיקום',
      'nearMe': 'קרוב אליי',
      'wholeVillage': 'כל הכפר',
      'city': 'כל העיר',
      'category': 'קטגוריה',
      'all': 'הכל',
      'maintenance': 'תחזוקה',
      'education': 'חינוך',
      'transport': 'הובלה',
      'shopping': 'קניות',
      'urgent': 'דחוף',
      'canHelp': 'אני יכול לעזור',
      'requestTitleExample': 'צריך תיקון ברז',
      'requestDescriptionExample': 'הברז במטבח דולף, צריך אינסטלטור',
      'requestTitle2': 'שיעור מתמטיקה',
      'requestDescription2': 'מחפש מורה פרטי למתמטיקה לכיתה י׳',
      'requestTitle3': 'הובלה קטנה',
      'requestDescription3': 'צריך עזרה בהובלת רהיט קטן',
      'enterName': 'אנא הכנס שם מלא',
      'enterEmail': 'אנא הכנס אימייל',
      'invalidEmail': 'אימייל לא תקין',
      'enterPassword': 'אנא הכנס סיסמה',
      'weakPassword': 'סיסמה חלשה מדי',
             'signUpSuccess': 'נרשמת בהצלחה! עכשיו התחבר עם הפרטים שלך',
             'loginSuccess': 'התחברת בהצלחה!',
             'ok': 'אישור',
             'noResults': 'לא נמצאו תוצאות עבור',
             'noRequests': 'אין בקשות זמינות',
             'save': 'שמור',
             'requestTitle': 'כותרת הבקשה',
             'requestDescription': 'תיאור הבקשה',
             'images': 'תמונות',
             'addImages': 'הוסף תמונות',
             'clear': 'נקה',
      'sendMessage': 'שלח הודעה',
      'noMessages': 'אין הודעות',
      'you': 'אתה',
      'otherUser': 'משתמש אחר',
      'phoneNumber': 'מספר טלפון',
      'enterPhoneNumber': 'הכנס מספר טלפון (אופציונלי)',
      'clearChat': 'נקה צ\'אט',
      'clearChatConfirm': 'האם אתה בטוח שברצונך למחוק את כל ההודעות בצ\'אט?',
      'cancel': 'ביטול',
      'delete': 'מחק',
      'chatCleared': 'הצ\'אט נוקה בהצלחה',
      'open': 'פתוח',
      'inProgress': 'בטיפול',
      'completed': 'טופל',
      'cancelled': 'בוטל',
      'free': 'חינמי',
      'paid': 'בתשלום',
      'deadline': 'תאריך יעד',
      'selectDeadline': 'בחר תאריך יעד',
      'targetAudience': 'קהל יעד',
      'distance': 'מרחק',
      'village': 'כפר',
      'maxDistance': 'מרחק מקסימלי (ק״מ)',
      'selectVillage': 'בחר כפר',
      'selectCategories': 'בחר קטגוריות',
      'requestType': 'סוג בקשה',
      'selectRequestType': 'בחר סוג בקשה',
      'selectTargetAudience': 'בחר קהל יעד',
      'allCategories': 'כל הקטגוריות',
      'expired': 'פג תוקף',
      'editRequest': 'ערוך בקשה',
      'deleteRequest': 'מחק בקשה',
      'confirmDelete': 'האם אתה בטוח שברצונך למחוק בקשה זו?',
      'requestDeleted': 'הבקשה נמחקה בהצלחה',
      'requestUpdated': 'הבקשה עודכנה בהצלחה',
      'newMessage': 'הודעה חדשה',
      'unreadMessages': 'הודעות שלא נקראו',
      'publishAllTypes': 'פרסום כל סוגי הבקשות',
      'respondFreeOnly': 'מתן מענה רק לבקשות חינמיות',
      'respondFreeAndPaid': 'מתן מענה לבקשות חינמיות ובקשות לפי תחום עיסוק שלך',
      'businessCategories': 'תחומי עיסוק',
      'selectBusinessCategories': 'בחר תחומי עיסוק',
      'availability': 'זמינות',
      'availabilityDescription': 'ימים ושעות העבודה שלך',
      'availableAllWeek': 'זמין כל השבוע',
      'editAvailability': 'ערוך זמינות',
      'selectDaysAndHours': 'בחר ימים ושעות',
      'day': 'יום',
      'startTime': 'שעת התחלה',
      'endTime': 'שעת סיום',
      'selectTime': 'בחר שעה',
      'availabilityUpdated': 'הזמינות עודכנה בהצלחה',
      'errorUpdatingAvailability': 'שגיאה בעדכון הזמינות',
      'noAvailabilityDefined': 'לא הוגדרה זמינות',
      'daySunday': 'ראשון',
      'dayMonday': 'שני',
      'dayTuesday': 'שלישי',
      'dayWednesday': 'רביעי',
      'dayThursday': 'חמישי',
      'dayFriday': 'שישי',
      'daySaturday': 'שבת',
      'subscriptionPayment': 'תשלום מנוי',
      'payWithBit': 'שלם עם ביט',
      'annualSubscription': 'מנוי שנתי - 10 ש״ח',
      'subscriptionDescription': 'גישה לבקשות בתשלום לפי תחומי העיסוק שלך',
      'activateSubscription': 'הפעל מנוי',
      'subscriptionStatus': 'סטטוס מנוי',
      'active': 'פעיל',
      'inactive': 'לא פעיל',
      'expiryDate': 'תאריך פג תוקף',
      // הודעות שגיאה
      'emailNotRegistered': 'אימייל זה אינו רשום במערכת',
      'wrongPassword': 'הסיסמה שגויה',
      'emailAlreadyRegistered': 'אימייל זה רשום במערכת',
      'userAlreadyRegistered': 'משתמש זה כבר רשום במערכת',
      'userAlreadyRegisteredPleaseLogin': 'משתמש זה כבר רשום במערכת. אנא התחבר עם האימייל והסיסמה שלך',
      'emailOrPasswordWrong': 'האימייל או הסיסמה שגויים',
      'loginError': 'שגיאה בהתחברות',
      'retry': 'נסה שוב',
      'registrationError': 'שגיאה בהרשמה',
      // הודעות הצלחה
      'loggedInSuccessfully': 'התחברת בהצלחה!',
      'registeredSuccessfully': 'נרשמת בהצלחה! עכשיו התחבר עם הפרטים שלך',
      'googleLoginSuccess': 'התחברות מוצלחת דרך גוגל!',
      // הודעות נוספות
      'userGuide': 'מדריך משתמש',
      'managePayments': 'ניהול תשלומים במזומן',
      'payCash': 'שלם במזומן',
      'cashPayment': 'תשלום במזומן',
      'sendPaymentRequest': 'שלח בקשת תשלום',
      'manageCashPayments': 'ניהול תשלומים במזומן',
      'logoutTitle': 'התנתקות',
      'logoutMessage': 'האם אתה בטוח שברצונך להתנתק?',
      'logoutButton': 'התנתקות',
      'errorLoggingOut': 'שגיאה בהתנתקות: {error}',
      'monthlyLimitReached': 'הגעת למגבלת הבקשות החודשיות',
      'monthlyLimitMessage': 'הגעת למגבלת הבקשות החודשיות שלך ({count} בקשות).',
      'youCan': 'באפשרותך:',
      'waitForNextMonth': 'לחכות לחודש הבא שמתחיל ב-{date}',
      'upgradeSubscription': 'לשדרג מנוי לקבלת יותר בקשות חודשיות',
      'upgradeSubscriptionInProfile': 'שדרג מנוי בפרופיל',
      // הודעות נוספות
      'welcomeMessage': 'ברוכים הבאים!',
      'welcomeToApp': 'ברוכים הבאים לאפליקציית "שכונתי"!',
      'fillAllFields': 'אנא מלא את כל השדות',
      'rememberMe': 'זכור אותי',
      'saveCredentialsQuestion': 'האם תרצה לשמור את פרטי הכניסה שלך?',
      'saveCredentialsInfo': 'אם תבחר כן, תוכל להיכנס אוטומטית בפעם הבאה',
      'saveCredentialsText': 'שמור את פרטי הכניסה שלי',
      'autoLoginText': 'אני רוצה להיכנס אוטומטית בפעם הבאה',
      'noThanks': 'לא, תודה',
      'requestsFromNeighborhood': 'בקשות מהשכונה',
      'allNotificationsInNeighborhood': 'כל ההתראות בשכונתי',
      'manageNotifications': 'נהל כל ההתראות',
      'notificationOptions': 'מגוון אפשורויות לקבלת התראות על בקשות חדשות',
      // טקסטים ממסך ניהול התראות
      'errorLoadingPreferences': 'שגיאה בטעינת העדפות: {error}',
      'requestLocationInRangeFixed': 'כאשר המיקום של הבקשה נמצא בטווח החשיפה והמיקום הקבוע שלי או המיקום הקבוע שלי נמצא בטווח החשיפה של הבקשה',
      'requestLocationInRangeMobile': 'כאשר המיקום של הבקשה נמצא בטווח החשיפה והמיקום הנייד שלי או המיקום הנייד שלי נמצא בטווח החשיפה של הבקשה',
      'requestLocationInRangeFixedOrMobile': 'כאשר המיקום של הבקשה נמצא בטווח החשיפה והמיקום הקבוע או הנייד שלי או המיקום הקבוע או הנייד שלי נמצא בטווח החשיפה של הבקשה',
      'notInterestedInPaidRequestNotifications': 'לא מעוניין לקבל התראות על בקשות בתשלום חדשות',
      'subscriptionNotifications': 'התראות על מנויים',
      'whenSubscriptionExpires': 'כאשר תקופת המנוי שלי נגמרת',
      'subscriptionReminderBeforeExpiry': 'תזכורת טרם סיום תקופת מנוי (שבוע לפני)',
      'guestPeriodExtensionTwoWeeks': 'הארכת תקופת אורח בשבועיים חינם',
      'subscriptionUpgrade': 'שדרוג מנוי',
      'requestStatusNotifications': 'התראות על סטטוס ונתוני בקשה',
      'interestInRequest': 'התעניינות/אי התעניינות בבקשה',
      'newChatMessages': 'הודעות חדשות בצ\'אט',
      'serviceCompletionAndRating': 'סיום ודירוג שירות',
      'radiusExpansionShareRating': 'הגדלת טווח חשיפה (שיתוף/דירוג)',
      // טקסטים ממסך התראות
      'userNotConnected': 'משתמש לא מחובר',
      'clearAllNotifications': 'נקה כל ההתראות',
      'markAllAsRead': 'סמן הכל כנקרא',
      'notificationsBlocked': 'התראות חסומות - אנא הפעל הרשאות התראות בהגדרות הטלפון',
      'enableNotifications': 'הפעל התראות',
      'error': 'שגיאה',
      'errorMessage': 'שגיאה: {error}',
      'noNewNotifications': 'אין התראות חדשות',
      'notificationInfo': 'כאשר מישהו יגיב לבקשות שלך או יציע עזרה,\nתקבל התראה כאן',
      'openRequest': 'פתח בקשה',
      'errorUpdatingNotification': 'שגיאה בעדכון התראה: {error}',
      'allNotificationsMarkedAsRead': 'כל ההתראות סומנו כנקראו',
      'errorUpdatingNotifications': 'שגיאה בעדכון התראות: {error}',
      'clearAllNotificationsTitle': 'נקה כל ההתראות',
      'clearAllNotificationsMessage': 'האם אתה בטוח שברצונך למחוק את כל ההתראות? פעולה זו לא ניתנת לביטול.',
      'clearAll': 'נקה הכל',
      'allNotificationsDeletedSuccessfully': 'כל ההתראות נמחקו בהצלחה',
      'errorDeletingNotifications': 'שגיאה במחיקת התראות: {error}',
      'deleteNotification': 'מחק התראה',
      'deleteNotificationMessage': 'האם אתה בטוח שברצונך למחוק את ההתראה "{title}"?',
      'notificationDeletedSuccessfully': 'ההתראה נמחקה בהצלחה',
      'errorDeletingNotification': 'שגיאה במחיקת ההתראה: {error}',
      'minutesAgo': 'לפני {count} דקות',
      'hoursAgo': 'לפני {count} שעות',
      'daysAgo': 'לפני {count} ימים',
      // הודעות נוספות
      'understood': 'הבנתי',
      'openTutorial': 'פתח מדריך',
      // Terms and Privacy
      'termsAndPrivacyTitle': 'תנאי שימוש ומדיניות פרטיות',
      'welcomeToTermsScreen': 'ברוכים הבאים לאפליקציה שלנו',
      'agreeAndContinue': 'מסכים וממשיך',
      'doNotAgree': 'לא מסכים',
      'importantNote': 'חשוב לדעת',
      'termsMayBeUpdated': 'תנאי השימוש ומדיניות הפרטיות עשויים להתעדכן מעת לעת.\nתוכל למצוא את הגרסה העדכנית ביותר באפליקציה.',
      'byContinuingYouConfirm': 'על ידי המשך השימוש באפליקציה, אתה מאשר שקראת והבנת את תנאי השימוש ומדיניות הפרטיות, ואתה מסכים להם.',
      'mustAcceptTerms': 'חשוב: עליך לאשר את תנאי השימוש ומדיניות הפרטיות כדי להמשיך להשתמש באפליקציה.',
      // Terms of Service
      'termsOfServiceIntro': 'ברוכים הבאים לאפליקציית "שכונתי". השימוש באפליקציה כפוף לתנאים הבאים. אנא קרא אותם בעיון:\n\nהאפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל (להלן: "החברה").',
      'termsSection1': 'האפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל (להלן: "החברה"). השימוש באפליקציה מותנה בקבלת תנאי השימוש הללו.',
      'termsSection2': 'השימוש באפליקציה מיועד למשתמשים מעל גיל 18 בלבד. החברה שומרת על זכותה לבקש הוכחת גיל בכל שלב.',
      'termsSection3': 'האפליקציה מיועדת לעזרה הדדית בין שכנים - חיבור בין מבקשי עזרה לנותני עזרה בקהילה המקומית.',
      'termsSection4': 'המשתמש מתחייב לספק מידע אמיתי ומדויק בלבד, לרבות פרטי מיקום ופרטי יצירת קשר.',
      'termsSection5': 'האפליקציה היא פלטפורמת שוק מקוון המחברת בין מבקשי שירותים לנותני שירותים. האפליקציה מאפשרת למשתמשים לפרסם בקשות עזרה חינמיות ובתשלום, ולהציע שירותים מקצועיים ומסחריים בתמורה לתשלום. השימוש באפליקציה למטרות מסחריות ומקצועיות מותר במסגרת תנאי השימוש הללו. החברה פועלת כמתווכת בלבד ואינה אחראית לאיכות השירותים, למהימנות המשתמשים, לנזקים, להונאה, למחלוקות או להפסדים כספיים.',
      'termsSection6': 'המשתמשים אחראים באופן בלעדי לתוכן שהם מפרסמים ולכל אינטראקציה עם משתמשים אחרים.',
      'termsSection7': 'שכונתי היא מתווכת בלבד ואינה אחראית לאיכות השירותים, למהימנות המשתמשים או לנזקים כלשהם.',
      'termsSection8': 'המשתמש מתחייב לדווח על התנהגות לא הולמת, פוגענית או מסוכנת מיד לתמיכה או לרשויות הרלוונטיות.',
      'termsSection10': 'החברה שומרת לעצמה את הזכות להפסיק את השירות, לחסום משתמשים או להסיר תוכן בכל עת.',
      'termsSection11': 'המשתמש אחראי לשמירה על סיסמת הכניסה שלו ולאבטחת המידע האישי שלו.',
      'termsSection12': 'כל מחלוקת תיפתר על פי החוק הישראלי ובהתאם לדיני מדינת ישראל.',
      // Mutual Help and Safety
      'mutualHelpAndSafety': 'עזרה הדדית ובטיחות',
      'mutualHelpSection1': 'האפליקציה היא פלטפורמת שוק מקוון המחברת בין אנשים. אתה בוחר בעצמך עם מי לתקשר, למי להציע שירותים או ממי לקבל שירותים, וכל אינטראקציה כזו היא על אחריותך הבלעדית. דירוגים ומשוב של משתמשים יכולים לסייע בבניית אמון, אך אינם מהווים ערובה לאיכות, מהימנות או בטיחות. החברה אינה אחראית לכל נזק, התנהגות לא הולמת, הונאה או איכות שירותים ירודה.',
      'mutualHelpSection2': 'אין חובה חוקית לספק שירות, אך מומלץ לעמוד בהתחייבויות שניתנו לאחרים.',
      'mutualHelpSection3': 'מערכת הדירוגים והביקורות חייבת להיות אמיתית ומדויקת. דירוגים כוזבים או פוגעניים יובילו לחסימת המשתמש.',
      'mutualHelpSection4': 'במקרה של חשד לסכנה, התנהגות לא הולמת או ניצול, יש לדווח מיד לתמיכה או לרשויות הרלוונטיות.',
      'mutualHelpSection5': 'אנו שומרים לעצמנו את הזכות לחסום משתמשים שמפרים את הכללים או מתנהגים בצורה לא הולמת.',
      'mutualHelpSection6': 'התשלומים בין משתמשים הם באחריותם הבלעדית. שכונתי אינה אחראית לתשלומים או לעסקאות בין המשתמשים.',
      'mutualHelpSection8': 'במקרה של בעיה או סכסוך, אנו ממליצים לנסות לפתור את הבעיה בדרכי שלום לפני פנייה לתמיכה.',
      // Privacy Policy
      'privacyPolicyIntro': 'מדיניות פרטיות זו מתארת כיצד אנו אוספים, משתמשים ומגנים על המידע האישי שלך באפליקציית "שכונתי":\n\nהאפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל (להלן: "החברה").',
      'privacySection1': 'האפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל (להלן: "החברה"). אנו מכבדים את פרטיות המשתמשים ומתחייבים להגן על המידע האישי שלך.',
      'privacySection2': 'המידע האישי נאסף לצורך מתן השירותים, לרבות מיקום גיאוגרפי לחיבור שכנים, פרטי יצירת קשר ומידע על בקשות עזרה.',
      'privacySection3': 'אנו לא נמכור או נשתף את המידע האישי עם צדדים שלישיים ללא הסכמה מפורשת, למעט במקרים הנדרשים על פי חוק.',
      'privacySection4': 'המידע נשמר בשרתים מאובטחים ומוצפנים. מיקום גיאוגרפי נשמר באופן מוצפן ולא מועבר לצדדים שלישיים.',
      'privacySection5': 'יש לך בקרה מלאה על מי רואה את המידע שלך. תוכל להגדיר רמות פרטיות שונות עבור בקשות שונות.',
      'privacySection6': 'המשתמש רשאי לבקש לגשת, לתקן או למחוק את המידע האישי שלו בכל עת.',
      'privacySection7': 'אנו משתמשים בעוגיות (cookies) ובטכנולוגיות דומות לשיפור חוויית המשתמש ולניתוח השימוש באפליקציה.',
      'privacySection8': 'האפליקציה משתמשת בשירותי Firebase של Google (Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging) לאבטחה, אחסון נתונים ושירותי התראות. המידע מועבר לשרתי Firebase המוגנים בהצפנה מתקדמת ותחת מדיניות הפרטיות של Google.',
      'privacySection9': 'האפליקציה דורשת גישה למיקום הגיאוגרפי שלך כדי לחבר אותך עם שכנים בקרבת מקום. המיקום נשמר באופן מוצפן ומשמש רק לצורך הצגת בקשות עזרה רלוונטיות. תוכל לבטל את הגישה למיקום בכל עת בהגדרות המכשיר.',
      'privacySection10': 'האפליקציה דורשת גישה למיקרופון שלך לצורך יצירת הודעות קוליות. ההקלטות נשמרות בשרתי Firebase המוצפנים ומשמשות רק לצורך תקשורת בין משתמשים. תוכל לבטל את הגישה למיקרופון בכל עת בהגדרות המכשיר.',
      'privacySection11': 'האפליקציה דורשת גישה למצלמה ולגלריה שלך לצורך העלאת תמונות לבקשות עזרה. התמונות נשמרות בשרתי Firebase Storage המוצפנים ומשמשות רק לצורך הצגת בקשות עזרה. תוכל לבטל את הגישה למצלמה/גלריה בכל עת בהגדרות המכשיר.',
      'privacySection12': 'אנו נוקטים באמצעי אבטחה סבירים כדי להגן על המידע שלך מפני גישה בלתי מורשית, שימוש או חשיפה.',
      'privacySection13': 'במקרה של פריצת אבטחה או חשיפת מידע, נדווח על כך בהקדם האפשרי וננקוט בצעדים מתאימים.',
      'privacySection14': 'אנו מתחייבים לעדכן את המשתמשים על כל שינוי במדיניות הפרטיות באמצעות האפליקציה או בדרכים אחרות.',
      'privacySection15': 'האפליקציה עשויה להכיל קישורים לאתרים או שירותים של צדדים שלישיים. איננו אחראים למדיניות הפרטיות שלהם.',
      'tutorialHint': 'כדי ללמוד איך להשתמש באפליקציה, לחץ על אייקון המדריך (📚) בתפריט העליון.',
      // Profile Screen
      'extendTrialPeriod': 'הארכת תקופת ניסיון',
      'extendTrialPeriodByTwoWeeks': 'הארך תקופת ניסיון בשבועיים',
      'youAreInWeek': 'אתה נמצא בשבוע',
      'youAreInFirstWeekMessage': 'אתה נמצא בשבוע הראשון שלך! תוכל לראות כל הבקשות (חינם ובתשלום) מכל הקטגוריות.',
      'yourRating': 'הדירוג שלך',
      'noRatingsYet': 'עדיין לא קיבלת דירוגים',
      'detailedRatings': 'דירוגים מפורטים',
      'basedOnRating': 'מבוסס על {count} דירוג',
      'basedOnRatings': 'מבוסס על {count} דירוגים',
      'reliability': 'אמינות',
      'attitude': 'יחס',
      'fairPrice': 'מחיר הוגן',
      'editDisplayName': 'עריכת שם תצוגה',
      'editPhoneNumber': 'עריכת מספר טלפון',
      'afterSavingNameWillUpdate': 'לאחר השמירה, השם יתעדכן בכל מקום באפליקציה',
      'phonePrefix': 'קידומת',
      'enterNumberWithoutPrefix': 'הזן את המספר ללא הקידומת',
      'select': 'בחר',
      'forExample': 'למשל',
      // My Requests Screen
      'noRequestsInMyRequests': 'אין בקשות',
      'createNewRequestToStart': 'צור בקשה חדשה כדי להתחיל',
      // In Progress Requests Screen
      'noInterestedRequests': 'אין לך בקשות בטיפול',
      'clickInterestedOnRequests': 'לחץ "אני מעוניין" על בקשות שמעניינות אותך ב"כל הבקשות"',
      'howItWorks': 'איך זה עובד?',
      'howItWorksSteps': '1. עבור ל"כל הבקשות"\n2. לחץ "אני מעוניין" על בקשות שמעניינות אותך\n3. הבקשות יופיעו כאן ב"בקשות בטיפול שלי"',
      // Category Selection
      'selectMainCategoryThen': 'בחר תחום ראשי ואז',
      'selectMainCategoryThenUpTo': 'בחר תחום ראשי ואז עד',
      'subCategories': 'תחומי משנה',
      // Buttons
      'close': 'סגור',
      'startProcess': 'התחל תהליך',
      'maybeLater': 'אולי מאוחר יותר',
      'rateNow': 'דרג עכשיו',
      'startEarning': 'התחל להרוויח',
      // Trial Extension Dialog
      'toExtendTrialPeriod': 'כדי להאריך את תקופת הניסיון שלך בשבועיים, עליך לבצע את הפעולות הבאות:',
      'shareAppTo5Friends': 'שתף את האפליקציה ל-5 חברים (WhatsApp, SMS, Email)',
      'rateApp5Stars': 'דרג את האפליקציה בחנות 5 כוכבים',
      'publishNewRequest': 'פרסם בקשה חדשה בכל תחום שתרצה',
      'serviceRequiresAppointment': 'השירות דורש תור',
      'serviceRequiresAppointmentHint': 'אם השירות דורש קביעת תור, בחר באפשרות זו',
      'canReceiveByDelivery': 'אפשר לקבל במשלוח?',
      'canReceiveByDeliveryHint': 'אפשר לקבל השירות באמצעות שליחים?',
      'publishAd': 'פרסם מודעה',
      // Subscription Details Dialogs
      'yourBusinessSubscriptionDetails': 'פרטי המנוי העסקי שלך',
      'yourPersonalSubscriptionDetails': 'פרטי המנוי הפרטי שלך',
      'yourGuestSubscriptionDetails': 'פרטי המנוי האורח שלך',
      'yourFreeSubscription': 'המנוי החינם שלך',
      'yourBusinessSubscriptionIncludes': 'המנוי העסקי שלך כולל:',
      'yourPersonalSubscriptionIncludes': 'המנוי הפרטי שלך כולל:',
      'yourTrialPeriodIncludes': 'תקופת הניסיון שלך כוללת:',
      'yourFreeSubscriptionIncludes': 'המנוי החינם שלך כולל:',
      'requestsPerMonth': '{count} בקשות בחודש',
      'publishUpToRequestsPerMonth': 'פרסום עד {count} בקשות בחודש',
      'publishOneRequestPerMonth': 'פרסום בקשה אחת בלבד בחודש',
      'rangeWithBonuses': 'טווח: {range} ק"מ + בונוסים',
      'exposureUpToKm': 'חשיפה עד {km} קילומטר מהמיקום שלך',
      'seesFreeAndPaidRequests': 'רואה בקשות חינם ובתשלום',
      'seesOnlyFreeRequests': 'רואה רק בקשות חינם',
      'accessToAllRequestTypes': 'גישה לכל סוגי הבקשות באפליקציה',
      'accessToFreeRequestsOnly': 'גישה לבקשות חינם בלבד',
      'selectedBusinessAreas': 'תחומי עיסוק נבחרים',
      'yourBusinessAreas': 'תחומי העיסוק שלך: {areas}',
      'noBusinessAreasSelected': 'לא נבחרו',
      'paymentPerYear': 'תשלום: {amount}₪ לשנה',
      'oneTimePaymentForFullYear': 'תשלום חד-פעמי לשנה שלמה',
      'noPayment': 'ללא תשלום',
      'freeSubscriptionAvailable': 'המנוי החינם זמין ללא עלות',
      'trialPeriodDays': 'תקופת ניסיון: {days} ימים',
      'fullAccessToAllFeatures': 'גישה מלאה לכל התכונות ללא תשלום',
      'yourSubscriptionActiveUntil': 'המנוי שלך פעיל עד {date}',
      'unknown': 'לא ידוע',
      'yourTrialActiveForDays': 'תקופת הניסיון שלך פעילה עוד {days} ימים',
      'subscriptionExpiredSwitchToFree': 'המנוי שלך עבר לסוג "פרטי חינם", שדרג עכשיו למנוי "פרטי מנוי" או "עסקי"',
      'afterTrialAutoSwitchToFree': 'אחרי תקופת הניסיון, תעבור אוטומטית למנוי פרטי חינם. תוכל לשדרג בכל עת.',
      // Subscription Type Selection Dialog
      'selectSubscriptionType': 'בחירת סוג מנוי',
      'chooseYourSubscriptionType': 'בחר את סוג המנוי שלך:',
      'privateSubscriptionFeatures': '• 1 בקשה בחודש\n• טווח: 0-3 ק"מ\n• רואה רק בקשות חינם\n• ללא תחומי עיסוק',
      'privatePaidSubscriptionFeatures': '• 5 בקשות בחודש\n• טווח: 0-5 ק"מ\n• רואה רק בקשות חינם\n• ללא תחומי עיסוק\n• תשלום: 30₪ לשנה',
      'businessSubscriptionFeatures': '• 10 בקשות בחודש\n• טווח: 0-8 ק"מ\n• רואה בקשות חינם ובתשלום\n• בחירת תחומי עיסוק\n• תשלום: 70₪ לשנה',
      // Activate Subscription Dialog
      'activateSubscriptionWithType': 'הפעלת מנוי {type}',
      'subscriptionTypeWithType': 'מנוי {type}',
      'perYear': '₪{price} לשנה',
      'businessAreas': 'תחומי עיסוק: {areas}',
      'howToPay': 'איך לשלם:',
      'paymentInstructions': '1. בחר דרך תשלום: BIT (PayMe) או כרטיס אשראי (PayMe)\n2. השלם את הסכום (₪{price}) - המנוי יופעל אוטומטית\n3. אם יש בעיה, פנה לתמיכה',
      'payViaPayMe': 'שלם דרך PayMe (Bit או כרטיס אשראי)',
      // Pending Approval Dialog
      'requestPendingApprovalNew': 'בקשה בתהליך אישור ⏳',
      'youHaveRequestForSubscription': 'יש לך בקשה ל{type} והיא בטיפול.',
      'cannotSendAnotherRequest': 'לא ניתן לשלוח בקשה נוספת עד שהמנהל יאשר או ידחה את הבקשה הנוכחית.',
      // System Admin Dialog
      'systemAdministrator': 'מנהל מערכת',
      'adminFullAccessMessage': 'כמנהל מערכת, יש לך גישה מלאה לכל הפונקציות ללא צורך בתשלום.\n\nסוג המנוי שלך קבוע: עסקי מנוי עם גישה לכל תחומי העיסוק.',
      // Cash Payment Dialog
      'cashPaymentTitle': 'دفع نقدي',
      'subscriptionDetails': 'פרטי המנוי:',
      'subscriptionTypeLabel': 'סוג מנוי: {type}',
      'priceLabel': 'מחיר: ₪{price}',
      'sendPaymentRequestNew': 'إرسال طلب الدفع',
      'completeAllActionsWithinHour': 'יש לבצע את כל הפעולות תוך שעה אחת',
      'granting14DayExtension': 'מעניק הארכה של 14 ימים...',
      'extensionGrantedSuccessfully': 'הארכה של 14 ימים ניתנה בהצלחה!',
      'errorGrantingExtension': 'שגיאה במתן הארכה',
      'shareAppTo5FriendsForTrial': 'שתף את האפליקציה ל-5 חברים',
      'rateApp5StarsForTrial': 'דרג את האפליקציה בחנות 5 כוכבים',
      'publishNewRequestForTrial': 'פרסם בקשה חדשה',
      'remainingTime': 'נותר זמן',
      'timeExpired': 'הזמן הסתיים',
      'shareAppOpened': 'שיתוף האפליקציה נפתח. אנא שתף ל-5 חברים כדי להשלים את הדרישה.',
      'appStoreOpened': 'חנות האפליקציות נפתחה. אנא דרג 5 כוכבים כדי להשלים את הדרישה.',
      'navigateToNewRequest': 'מעבר למסך יצירת בקשה. אנא פרסם בקשה כדי להשלים את הדרישה.',
      'notCompleted': 'לא הושלם',
      'helpUsImproveApp': 'עזור לנו לשפר את האפליקציה',
      // Share App Dialog
      'shareAppTitle': 'שתף אפליקציה',
      'shareAppForTrialExtension': 'שתף אפליקציה להארכת תקופת ניסיון',
      'chooseHowToShare': 'בחר איך תרצה לשתף את האפליקציה:',
      'sendToFriendsWhatsApp': 'שלח לחברים ב-WhatsApp',
      'sendEmail': 'שלח במייל',
      'openShareOptions': 'פתח אפשרויות שיתוף',
      'copyToClipboard': 'העתק ללוח',
      'copyTextToShare': 'העתק טקסט לשיתוף',
      'generalShare': 'שיתוף כללי',
      'shareToFacebookMessenger': 'שיתוף ב-Messenger',
      'shareToInstagram': 'שתף ב-Instagram',
      'openingWhatsApp': 'פותח WhatsApp...',
      'openingWhatsAppWeb': 'פותח WhatsApp Web...',
      'openingMessagesApp': 'פותח אפליקציית הודעות...',
      'openingEmailApp': 'פותח אפליקציית מייל...',
      'openingShareOptions': 'פותח אפשרויות שיתוף...',
      'textCopiedToClipboard': 'הטקסט הועתק ללוח! שתף אותו עם חברים',
      'errorOpeningShare': 'שגיאה בפתיחת שיתוף',
      'errorOpeningShareDialog': 'שגיאה בפתיחת דיאלוג השיתוף',
      'errorCopying': 'שגיאה בהעתקה',
      'errorOpeningShareOptions': 'שגיאה בפתיחת אפשרויות השיתוף',
      'copyTextFromClipboard': 'העתק את הטקסט מהלוח',
      // Rate App Dialog
      'rateAppTitle': 'דרג אפליקציה',
      'howWasYourExperience': 'איך הייתה החוויה שלך?',
      'yourRatingHelpsUs': 'הדירוג שלך עוזר לנו לשפר את האפליקציה ולהגיע לעוד משתמשים.',
      'highRatingMoreNeighbors': '⭐ דירוג גבוה = יותר שכנים = יותר עזרה הדדית!',
      'errorOpeningStore': 'שגיאה בפתיחת החנות',
      'cannotOpenAppStore': 'לא ניתן לפתוח את חנות האפליקציות',
      // Recommend to Friends Dialog
      'recommendToFriendsTitle': 'המלץ לחברים',
      'lovedTheAppHelpUsGrow': 'אהבת את האפליקציה? עזור לנו לצמוח!',
      'shareWithFriends': '🎯 שתף עם חברים',
      'rateUs': '⭐ דרג אותנו',
      'tellAboutYourExperience': '💬 ספר על החוויה שלך',
      'everyRecommendationHelps': 'כל המלצה עוזרת לנו להגיע לעוד שכנים שמחפשים עזרה הדדית!',
      // Rewards Dialog
      'rewardsForRecommenders': 'תגמולים לממליצים',
      'recommendAppAndGetRewards': 'המלץ על האפליקציה וקבל תגמולים!',
      'pointsPerRecommendation': '🎁 10 נקודות - כל המלצה',
      'pointsFor5StarRating': '⭐ 5 נקודות - דירוג 5 כוכבים',
      'pointsForPositiveReview': '💬 3 נקודות - ביקורת חיובית',
      'pointsPriorityFeatures': 'נקודות = עדיפות בבקשות + תכונות מיוחדות!',
      'guestPeriodStarted': 'ברוכים הבאים! תקופת אורח החלה',
      'firstWeekMessage': 'אתה נמצא בשבוע הראשון שלך - תוכל לראות כל הבקשות (חינם ובתשלום) מכל הקטגוריות!',
      'guestModeWithCategories': 'מצב אורח - תחומי עיסוק מוגדרים',
      'guestModeNoCategories': 'מצב אורח - ללא תחומי עיסוק',
      'helpSent': 'הצעת עזרה נשלחה!',
      'unhelpConfirmation': 'האם אתה בטוח שברצונך לבטל את ההתעניינות בבקשה זו?',
      'unhelpSent': 'בוטלה התעניינות בבקשה',
      'categoryDataUpdated': 'נתוני הקטגוריות עודכנו בהצלחה',
      'nameDisplayInfo': 'השם יופיע בבקשות שאתה יוצר, ובמפות מפרסמי הבקשות',
      'validPrefixes': 'קידומות תקפות: 050-059 (10 ספרות), 02,03,04,08,09 (9 ספרות), 072-079 (10 ספרות)',
      'agreeToDisplayPhone': 'אני מסכים להציג את מספר הטלפון שלי בבקשות שאני יוצר, וליצירת קשר איתי במידה ואני נותן שירות',
      // טקסטים ממסך פרופיל
      'notConnectedToSystem': 'לא מחובר למערכת',
      'pleaseLoginToSeeProfile': 'אנא התחבר כדי לראות את הפרופיל שלך',
      'loadingProfile': 'טוען פרופיל...',
      'errorLoadingProfile': 'שגיאה בטעינת הפרופיל',
      'tryAgain': 'נסה שוב',
      'userProfileNotFound': 'לא נמצא פרופיל משתמש',
      'creatingProfile': 'יוצר פרופיל...',
      'createProfile': 'צור פרופיל',
      'setBusinessFields': 'הגדר תחומי עיסוק',
      'toReceiveRelevantNotifications': 'כדי לקבל התראות על בקשות רלוונטיות, עליך לבחור עד שני תחומי עיסוק:',
      'iDoNotProvidePaidServices': 'אני לא נותן שירות כלשהו תמורת תשלום',
      'ifYouSelectThisOption': 'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
      'orSelectBusinessAreas': 'או בחר תחומי עיסוק:',
      'selectBusinessAreasToReceiveRelevantRequests': 'בחר תחומי עיסוק כדי לקבל בקשות רלוונטיות:',
      'allAds': 'כל המודעות',
      'adsCount': '{count} מודעות',
      'ifYouProvideService': 'אם אתה נותן שירות כלשהו, הגדר את תחומי העיסוק שלך וקבל גישה לבקשות בתשלום.\n\nתוכל לשנות את תחומי העיסוק שלך בכל עת בפרופיל שלך.',
      'later': 'מאוחר יותר',
      'chooseNow': 'בחר עכשיו',
      'tutorialsResetSuccess': 'הודעות ההדרכה אופסו בהצלחה',
      
      // Tutorial Center - Categories
      'tutorialCategoryHome': 'מסך הבית',
      'tutorialCategoryRequests': 'בקשות',
      'tutorialCategoryChat': 'צ\'אט',
      'tutorialCategoryProfile': 'פרופיל',
      'tutorialTutorialsAvailable': '{count} הדרכות זמינות',
      
      // Tutorial Center - Home Screen
      'tutorialHomeBasicsTitle': 'תכולת מסך הבית',
      'tutorialHomeBasicsDescription': 'למד כיצד לנווט במסך הבית ולהשתמש בפונקציות הבסיסיות',
      'tutorialHomeBasicsContent': '''יסודות מסך הבית

מה תמצא במסך הבית:
• רשימת בקשות - כל הבקשות הזמינות בקהילה
• חיפוש - חפש בקשות לפי מילות מפתח
• סינון - סנן בקשות לפי קטגוריה, מיקום ומחיר
• בקשות בטיפול שלי - בקשות שפרסמת או פנית אליהן

איך להשתמש:
1. לצפייה בבקשה - לחץ על בקשה מהרשימה
2. לחיפוש - השתמש בשורת החיפוש העליונה
3. לסינון - לחץ על כפתור "סינון בקשות"
4. לבקשות בטיפול שלי - לחץ על "בקשות בטיפול שלי"''',
      
      'tutorialHomeSearchTitle': 'חיפוש וסינון',
      'tutorialHomeSearchDescription': 'איך למצוא בקשות ספציפיות במהירות',
      'tutorialHomeSearchContent': '''חיפוש וסינון

חיפוש:
• מילות מפתח - הזן מילים רלוונטיות
• חיפוש בזמן אמת - התוצאות מתעדכנות תוך כדי הקלדה
• חיפוש בכל השדות - שם, תיאור, קטגוריה

סינון בקשות:
• סוג בקשה - חינם או בתשלום
• קטגוריות - בחר תחומי עיסוק ספציפיים
• דחיפות - רגיל, דחוף (24 שעות), דחוף מאוד (עכשיו)
• מיקום וטווח - חפש בקרבת מקום מסוים (מיקום נייד או קבוע)
• טווח חשיפה - הגדר טווח בקילומטרים

טווחי חשיפה בסינון:
הטווח המקסימלי בסינון תלוי בסוג המשתמש שלך:
• אורח: עד 5 ק"מ
• פרטי חינם: עד 3 ק"מ
• פרטי מנוי: עד 5 ק"מ
• עסקי מנוי: עד 8 ק"מ

הערה: הטווחים הם קבועים ולא משתנים לפי המלצות או דירוגים.

טיפים:
• השתמש במילות מפתח קצרות וברורות
• נסה חיפושים שונים לאותה בקשה
• בחר טווח חשיפה שיתאים למקום שלך
• שמור סינונים מועדפים''',
      
      // Tutorial Center - Requests
      'tutorialCreateRequestTitle': 'יצירת בקשה חדשה',
      'tutorialCreateRequestDescription': 'איך ליצור בקשה לעזרה או שירות',
      'tutorialCreateRequestContent': '''יצירת בקשה חדשה

שלבים ליצירת בקשה:
1. לחץ על + - בפינה הימנית התחתונה
2. בחר קטגוריה - תחום העיסוק המתאים
3. כתוב תיאור - הסבר מה אתה צריך
4. הגדר מחיר - אם רלוונטי (חינם או בתשלום)
5. בחר מיקום - איפה אתה נמצא
6. הגדר טווח חשיפה - כמה ק"מ מהמיקום שלך (לפי סוג המשתמש שלך)
7. פרסם - שלח את הבקשה לקהילה

טווחי חשיפה לפי סוג משתמש:
• אורח: עד 5 ק"מ
• פרטי חינם: עד 3 ק"מ
• פרטי מנוי: עד 5 ק"מ
• עסקי מנוי: עד 8 ק"מ

הערה: הטווחים הם קבועים ולא משתנים לפי המלצות או דירוגים.

טיפים לכתיבה טובה:
• תיאור ברור - הסבר בדיוק מה אתה צריך
• פרטים חשובים - זמן, מקום, דחיפות
• תמונה - הוסף תמונה אם זה עוזר להסביר
• מחיר הוגן - הצע מחיר סביר או בחר "חינם"
• טווח חשיפה - בחר טווח שיתאים למיקום שלך ולסוג הבקשה

הגבלות לפי סוג משתמש:
• פרטי חינם: 1 בקשה בחודש
• פרטי מנוי: 5 בקשות בחודש
• עסקי מנוי: 10 בקשות בחודש

דוגמה טובה:
"צריך עזרה בהעברת רהיטים מדירה לדירה בירושלים. 
יש 3 ארונות, 2 שולחנות ומיטות. 
מוכן לשלם 200-300 שקל. 
מועד: סוף השבוע הקרוב."''',
      
      'tutorialManageRequestsTitle': 'ניהול בקשות',
      'tutorialManageRequestsDescription': 'איך לנהל את הבקשות שלך',
      'tutorialManageRequestsContent': '''ניהול בקשות

בקשות שפרסמת:
• צפייה בפניות - ראה מי פנה אליך
• עריכת בקשה - עדכן פרטים או מחיר
• סגירת בקשה - כשהתקבל עזרה
• מחיקת בקשה - אם כבר לא רלוונטית

בקשות בטיפול שלי (שפנית אליהן):
• מעקב סטטוס - ראה אם התקבלת
• צ'אט עם המפרסם - תקשורת ישירה
• ביטול פנייה - אם שינית דעתך

טיפים לניהול:
• עדכן סטטוס - סמן כשהבקשה הושלמה
• תקשור בצ'אט - שאל שאלות לפני התחייבות
• בדוק פרופילים - ראה דירוגים של נותני שירות
• היה מנומס - תגיב בזמן ובכבוד''',
      
      // Tutorial Center - Chat
      'tutorialChatBasicsTitle': 'תכולת הצ\'אט',
      'tutorialChatBasicsDescription': 'איך להשתמש במערכת הצ\'אט',
      'tutorialChatBasicsContent': '''יסודות הצ'אט

איך נכנסים לצ'אט:
1. מבקשה שפרסמת - לחץ על "צ'אט" ליד פנייה
2. מבקשה שפנית אליה - לחץ על "צ'אט" בבקשה
3. מהמסך "בקשות בטיפול שלי" - לחץ על כפתור הצ'אט

פונקציות הצ'אט:
• שליחת הודעות - טקסט והודעות קוליות
• עריכת הודעות - לחץ ארוך על הודעה ששלחת
• מחיקת הודעות - לחץ ארוך ובחר "מחק"
• סגירת צ'אט - אם לא רוצה יותר לתקשר

סימני קריאה:
• וי אחד - הודעה נשלחה
• שני וי - הודעה נקראה על ידי הנמען
• וי זוהר - הודעה נקראה לאחרונה

כללי התנהגות:
• היה מנומס - השתמש בשפה נאותה
• תגיב בזמן - אל תשאיר הודעות ללא מענה
• היה ברור - הסבר בדיוק מה אתה צריך
• שמור על פרטיות - אל תעביר מידע אישי''',
      
      'tutorialChatAdvancedTitle': 'פונקציות מתקדמות',
      'tutorialChatAdvancedDescription': 'פונקציות מתקדמות של הצ\'אט',
      'tutorialChatAdvancedContent': '''פונקציות מתקדמות

עריכת הודעות:
1. לחץ ארוך על הודעה ששלחת
2. בחר "ערוך" מהתפריט
3. ערוך את הטקסט והשמור
4. ההודעה תסומן כ"נערכה"

מחיקת הודעות:
1. לחץ ארוך על הודעה ששלחת
2. בחר "מחק" מהתפריט
3. אשר את המחיקה
4. ההודעה תימחק לצמיתות

סגירת צ'אט:
• מתי לסגור - כשאתה לא רוצה יותר לתקשר
• איך לסגור - תפריט (3 נקודות) > "סגור צ'אט"
• פתיחה מחדש - אפשר לפתוח צ'אט סגור
• הודעת מערכת - תישלח הודעה על סגירת הצ'אט

ניקוי צ'אט:
• מחיקת היסטוריה - תפריט > "נקה צ'אט"
• השפעה - מוחק את כל ההודעות
• לא ניתן לשחזר - פעולה סופית''',
      
      // Tutorial Center - Profile
      'tutorialProfileSetupTitle': 'הגדרת פרופיל',
      'tutorialProfileSetupDescription': 'איך להגדיר את הפרופיל שלך',
      'tutorialProfileSetupContent': '''הגדרת פרופיל

מידע בסיסי:
• שם - השם שלך (חובה)
• אימייל - כתובת אימייל (חובה)
• תמונה - תמונת פרופיל (אופציונלי)
• מיקום - איפה אתה נמצא (חובה)
• טווח חשיפה - עד כמה ק"מ מהמיקום שלך (לפי סוג המשתמש)

טווחי חשיפה בפרופיל:
• אורח: עד 5 ק"מ
• פרטי חינם: עד 3 ק"מ
• פרטי מנוי: עד 5 ק"מ
• עסקי מנוי: עד 8 ק"מ

הערה: הגדרת מיקום קבוע וטווח חשיפה מותרת רק למשתמשים: אורח, עסקי מנוי.

מידע עסקי (למנויים עסקיים):
• תחומי עיסוק - בחר כמה תחומי עיסוק שתרצה (עסקי מנוי בלבד)
• תיאור - הסבר על השירותים שלך
• מחירים - מחירון כללי
• זמינות - מתי אתה זמין

הגדרות פרטיות:
• מספר טלפון - אם רוצה שיוצג
• הצגת טלפון - הסכמה להציג במפה (רק למנויים עסקיים)
• הגדרות התראות - איזה התראות לקבל

הארכת תקופת ניסיון (משתמשי אורח):
אם אתה משתמש אורח, אתה יכול להאריך את תקופת הניסיון בשבועיים על ידי:
1. שיתוף האפליקציה ל-5 חברים (WhatsApp, SMS, Email)
2. דירוג האפליקציה בחנות 5 כוכבים
3. פרסום בקשה חדשה בכל תחום שתרצה

כל הפעולות חייבות להתבצע תוך שעה אחת מתחילת התהליך.

טיפים לפרופיל טוב:
• תמונה מקצועית - תמונה ברורה ונעימה
• תיאור מפורט - הסבר מה אתה מציע
• מידע אמיתי - אל תכתוב דברים לא נכונים
• עדכון קבוע - עדכן מידע כשמשתנה
• מיקום מדויק - עדכן מיקום כדי לקבל הצעות רלוונטיות''',
      
      'tutorialSubscriptionTitle': 'מנויים ותשלומים',
      'tutorialSubscriptionDescription': 'איך לנהל מנוי ותשלומים',
      'tutorialSubscriptionContent': '''מנויים ותשלומים

סוגי משתמשים ומנויים:
• אורח - גישה בסיסית ללא תשלום
• פרטי חינם - גישה בסיסית ללא תשלום
• פרטי מנוי - פונקציות מתקדמות (30₪ לשנה)
• עסקי מנוי - פרסום שירותים (70₪ לשנה)

מה כלול בכל סוג:

אורח:
• טווח חשיפה: 5 ק"מ
• צפייה בבקשות חינם
• פנייה לבקשות (מוגבל)
• צ'אט בסיסי
• אפשרות להאריך תקופת ניסיון בפעולות מיוחדות

פרטי חינם:
• טווח חשיפה: 3 ק"מ
• צפייה בבקשות חינם
• פנייה לבקשות (1 בקשה בחודש)
• צ'אט בסיסי

פרטי מנוי (30₪ לשנה):
• טווח חשיפה: 5 ק"מ
• כל מה שבפרטי חינם +
• פרסום בקשות (5 בקשות בחודש)
• צפייה רק בבקשות חינם
• ללא תחומי עיסוק

עסקי מנוי (70₪ לשנה):
• טווח חשיפה: 8 ק"מ
• כל מה שבפרטי מנוי +
• פרסום בקשות (10 בקשות בחודש)
• צפייה בבקשות חינם ובתשלום
• בחירת תחומי עיסוק
• הופעה במפת נותני שירות
• דירוגים מפורטים

הערות חשובות:
• טווחי חשיפה קבועים - כל סוג משתמש מקבל טווח מקסימלי קבוע
• אין בונוסים - הטווחים לא משתנים לפי המלצות או דירוגים
• תקופת ניסיון לאורחים - משתמשי אורח יכולים להאריך את תקופת הניסיון בפעולות מיוחדות
• תשלום שנתי - מנויים משולמים פעם בשנה

תשלומים:
• אמצעי תשלום - BIT (PayMe), כרטיס אשראי (PayMe)
• תשלום שנתי - חד פעמי לשנה
• הפעלה אוטומטית - המנוי מופעל אוטומטית לאחר התשלום
• תמיכה - פנה לתמיכה אם יש בעיה''',
      
      // Tutorial Center - General
      'tutorialMarkedAsRead': 'הדרכה סומנה כנקראה',
      'tutorialClose': 'סגור',
      'tutorialRead': 'קראתי',
      'subscriptionTypeChanged': 'סוג המנוי שונה ל- {type}',
      'errorChangingSubscriptionType': 'שגיאה בשינוי סוג המנוי: {error}',
      'permissionsRequired': 'הרשאות נדרשות',
      'imagePermissionRequired': 'נדרשת הרשאת גישה לתמונות. אנא עבור להגדרות האפליקציה והפעל את ההרשאה.',
      'openSettings': 'פתח הגדרות',
      'imagePermissionRequiredTryAgain': 'נדרשת הרשאת גישה לתמונות. אנא נסה שוב.',
      'chooseAction': 'בחר פעולה',
      'chooseFromGallery': 'בחר מהגלריה',
      'takePhoto': 'צלם תמונה',
      'deletePhoto': 'מחק תמונה',
      'profileImageUpdatedSuccess': 'תמונת הפרופיל עודכנה בהצלחה',
      'profileImageDeletedSuccess': 'תמונת הפרופיל נמחקה בהצלחה',
      'errorDeletingProfileImage': 'שגיאה במחיקת תמונת הפרופיל',
      'profileCreatedSuccess': 'פרופיל נוצר בהצלחה כ-{type}',
      'errorCreatingProfile': 'שגיאה ביצירת פרופיל: {error}',
      'errorCreatingProfileAlt': 'שגיאה ביצירת הפרופיל: {error}',
      'checkingLocationPermissions': 'בודק הרשאות מיקום...',
      'locationPermissionsRequired': 'נדרשות הרשאות מיקום כדי לעדכן מיקום. אנא הפעל הרשאות מיקום בהגדרות המכשיר',
      'locationServicesDisabled': 'שירותי המיקום כבויים. אנא הפעל אותם בהגדרות המכשיר',
      'locationServiceDisabledTitle': 'שירות המיקום כבוי',
      'locationServiceDisabledMessage': 'שירות המיקום במכשיר שלך כבוי. שירות המיקום חיוני לאפליקציה כדי:\n\n• להציג לך בקשות רלוונטיות באזור שלך\n• לאפשר לך לראות בקשות על המפה\n• לסנן בקשות לפי מיקום וטווח חשיפה\n• לקבל התראות על בקשות חדשות באזור שלך\n• להציג את המיקום שלך במפות של מפרסמי בקשות\n\nאם יש לך מיקום קבוע בפרופיל, הוא ימשיך לעבוד גם כששירות המיקום כבוי.\n\nאנא הפעל את שירות המיקום בהגדרות המכשיר.',
      'enableLocationServiceTitle': 'הפעל שירותי מיקום בטלפון',
      'enableLocationServiceMessage': 'כדי להשתמש בסינון לפי מיקום נייד, עליך להפעיל את שירותי המיקום בטלפון שלך.\n\nשירותי המיקום חיוניים כדי:\n• לקבל את המיקום הנוכחי שלך\n• לעדכן את המיקום באופן אוטומטי\n• לסנן בקשות לפי מיקום וטווח חשיפה\n• לקבל התראות על בקשות חדשות באזור שלך',
      'enableLocationService': 'הפעל שירותי מיקום',
      'gettingCurrentLocation': 'מקבל מיקום נוכחי...',
      'savingLocationAndRadius': 'שומר מיקום וטווח חשיפה...',
      'fixedLocationAndRadiusUpdated': 'המיקום הקבוע וטווח החשיפה עודכנו בהצלחה!',
      'noLocationSelected': 'לא נבחר מיקום',
      'deletingFixedLocation': 'מחיקת מיקום קבוע',
      'deleteFixedLocationQuestion': 'האם אתה בטוח שברצונך למחוק את המיקום הקבוע?\n\nלאחר המחיקה, תופיע במפות רק כששירות המיקום פעיל בטלפון.',
      'deletingLocation': 'מוחק מיקום...',
      'fixedLocationDeletedSuccess': 'המיקום הקבוע נמחק בהצלחה!',
      'errorDeletingLocation': 'שגיאה במחיקת מיקום: {error}',
      'shareApp': 'שתף אפליקציה',
      'rateApp': 'דרג אפליקציה',
      'recommendToFriends': 'המלץ לחברים',
      'rewards': 'תגמולים',
      'resetTutorialMessages': 'איפוס הודעות הדרכה',
      'debugSwitchToFree': '🔧 עבור לפרטי חינם',
      'debugSwitchToPersonal': '🔧 עבור לפרטי מנוי',
      'debugSwitchToBusiness': '🔧 עבור לעסקי מנוי',
      'debugSwitchToGuest': '🔧 עבור לאורח',
      'contact': 'צור קשר',
      'deleteAccount': 'מחק חשבון',
      'update': 'עדכן',
      'firstNameLastName': 'שם פרטי ומשפחה/חברה/עסק/כינוי',
      'enterFirstNameLastName': 'הזן שם פרטי ומשפחה/חברה/עסק/כינוי',
      'clickUpdateToChangeName': 'לחץ על "עדכן" כדי לשנות את השם. השם יישמר אוטומטית',
      'allBusinessFields': 'כל תחומי העיסוק',
      'businessFields': 'תחומי עיסוק',
      'edit': 'ערוך',
      'noBusinessFieldsDefined': 'אין תחומי עיסוק מוגדרים',
      'toReceiveNotifications': 'כדי לקבל התראות על בקשות רלוונטיות, עליך לבחור עד שני תחומי עיסוק:',
      'ifYouCheckThisOption': 'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
      'monthlyRequests': 'בקשות חודשיות',
      'publishedRequestsThisMonth': 'פורסמו {count} בקשות החודש (ללא הגבלה)',
      'remainingRequestsThisMonth': 'נשאר לך {count} בקשות לפרסום החודש',
      'reachedMonthlyRequestLimit': 'הגעת למגבלת הבקשות החודשית',
      'wantMoreUpgradeSubscription': 'רוצה יותר? שדרג מנוי',
      'fixedLocation': 'מיקום קבוע',
      'updateLocationAndRadius': 'עדכן מיקום וטווח',
      'adminCanUpdateLocation': 'מנהל - ניתן לעדכן מיקום כמו כל משתמש אחר',
      'fixedLocationDefined': 'מיקום קבוע מוגדר',
      'villageNotDefined': 'לא הוגדר כפר',
      'youWillAppearInRange': '✅ אתה תופיע בטווח הבקשות שהתפרסמו המתאימות לתחום העיסוק שלך, גם אם שירות המיקום לא פעיל בטלפון שלך',
      'deleteLocation': 'מחק מיקום',
      'noFixedLocationDefined': 'לא הוגדר מיקום קבוע וטווח חשיפה',
      'asServiceProvider': 'כנותן שירות, הגדרת מיקום קבוע וטווח חשיפה חיונית:',
      'locationBenefits': '• תקבל התראות על בקשות רלוונטיות לתחום העיסוק שלך\n• תופיע במפות של מפרסמי הבקשות ויוכלו לפנות אליך\n• שירות מיקום קבוע ימשיך לשרת אותך גם כששירות מיקום כבוי בטלפון שלך',
      'systemManagement': 'ניהול מערכת',
      'manageInquiries': 'ניהול פניות',
      'manageGuests': 'ניהול אורחים',
      'additionalInfo': 'מידע נוסף',
      'joinDate': 'תאריך הצטרפות',
      'helpUsGrow': 'עזור לנו לצמוח',
      'recommendAppToFriends': 'המלץ על האפליקציה לחברים וקבל תגמולים!',
      'approved': '✅ מאושר',
      'subscriptionPendingApproval': '{type} בתהליך אישור',
      'waitingForAdminApproval': '⏳ ממתין לאישור מנהל',
      'rejected': 'נדחה',
      'upgradeRequestRejected': '❌ בקשת השדרוג נדחתה',
      'privateFreeStatus': 'פרטי חינם',
      'freeAccessToFreeRequests': '🆓 גישה לבקשות חינמיות',
      'errorLoadingData': 'שגיאה בטעינת נתונים: {error}',
      'wazeNotInstalled': 'Waze לא מותקן במכשיר',
      'errorOpeningWaze': 'שגיאה בפתיחת Waze',
      'requestApprovalPending': 'בקשה בתהליך אישור ⏳',
      'upgradeSubscriptionTitle': 'שדרוג מנוי 🚀',
      'chooseSubscriptionType': 'בחר סוג מנוי:',
      'upgradeToBusiness': 'שדרוג לעסקי מנוי:',
      'noUpgradeOptionsAvailable': 'אין אפשרויות שדרוג זמינות',
      'privateFreeType': 'פרטי (חינם)',
      'privateFreeDescription': '• 1 בקשה בחודש\n• טווח: 0-3 ק"מ\n• רואה רק בקשות חינם\n• ללא תחומי עיסוק',
      'upgrade': 'שדרג',
      'deleteAccountTitle': 'מחיקת חשבון',
      'deleteAccountConfirm': 'האם אתה בטוח שברצונך למחוק את החשבון שלך?',
      'thisActionWillDeletePermanently': 'פעולה זו תמחק לצמיתות:',
      'yourLoginCredentials': 'פרטי הכניסה שלך',
      'yourPersonalInfo': 'המידע האישי בפרופיל',
      'allYourPublishedRequests': 'כל הבקשות שפרסמת',
      'allYourInterestedRequests': 'כל הפניות שפנית אליהן',
      'allYourChats': 'כל הצ\'אטים שלך',
      'allYourMessages': 'כל ההודעות ששלחת וקיבלת',
      'allYourImages': 'כל התמונות והקבצים',
      'allYourData': 'כל הנתונים וההיסטוריה',
      'thisActionCannotBeUndone': 'פעולה זו איננה ניתנת לשחזור!',
      'passwordConfirmation': 'אישור סיסמה',
      'passwordConfirmationMessage': 'כדי למחוק את החשבון, אנא הזן את הסיסמה שלך לאישור:',
      'passwordRequired': 'אנא הזן את הסיסמה',
      'thisActionWillDeleteAccountPermanently': 'פעולה זו תמחק את החשבון לצמיתות!',
      'deletingAccount': 'מוחק את החשבון...',
      'noUserFound': 'לא נמצא משתמש מחובר',
      'accountDeletedSuccess': 'החשבון נמחק בהצלחה',
      'deletingAccountProgress': 'מוחק חשבון...',
      'deleteUser': 'מחיקת משתמש',
      'googleUserDeleteTitle': 'מחיקת משתמש',
      'loggedInWithGoogle': 'התחברת דרך Google',
      'clickConfirmToDeletePermanently': 'לחץ "אישור" כדי למחוק את החשבון לצמיתות.\nפעולה זו איננה ניתנת לשחזור!',
      'contactScreenTitle': 'יצירת קשר',
      'contactScreenSubtitle': 'נותרת עם שאלות? משהו לא ברור? נשמח לשמוע ממך',
      'contactOperatorInfo': 'האפליקציה "שכונתי" מופעלת על ידי "אקסטרים טכנולוגיות" – עסק רשום כחוק בישראל. התמיכה זמינה גם לבקשות פרטיות ומחיקת חשבון.',
      'contactName': 'שם',
      'contactNameHint': 'הזן את שמך',
      'contactNameRequired': 'אנא הזן את שמך',
      'contactEmail': 'אימייל',
      'contactEmailHint': 'הזן את כתובת האימייל שלך',
      'contactEmailRequired': 'אנא הזן את כתובת האימייל',
      'contactEmailInvalid': 'אנא הזן כתובת אימייל תקינה',
      'contactMessage': 'הודעה',
      'contactMessageHint': 'טקסט חופשי',
      'contactMessageRequired': 'אנא הזן את הודעתך',
      'contactMessageTooShort': 'אנא הזן הודעה מפורטת יותר (לפחות 10 תווים)',
      'contactSend': 'שליחה',
      'contactSuccess': 'הפנייה נשלחה בהצלחה! נחזור אליך בהקדם',
      'contactError': 'שגיאה בשליחת הפנייה: {error}',
      'errorLoadingRating': 'שגיאה בטעינת הדירוג',
      'noRatingAvailable': 'אין דירוג זמין',
      'trialPeriodInfo': 'מידע על תקופת הניסיון שלך',
      'chatClosed': 'הצ\'אט נסגר - לא ניתן לשלוח הודעות',
      'messageLimitReached': 'הגעת למגבלת 50 הודעות - לא ניתן לשלוח הודעות נוספות',
      'messagesRemaining': 'אזהרה: נותרו {count} הודעות בלבד',
      'loginMethod': 'שיטת כניסה: {method}',
      'saveLoginCredentials': 'שמור פרטי כניסה',
      // הודעות נוספות מ-home_screen
      'confirmCancelInterest': 'אישור ביטול עניין',
      'requestLabel': 'בקשה',
      'categoryLabel': 'תחום',
      'typeLabel': 'סוג',
      'paidType': 'בתשלום',
      'freeType': 'חינמי',
      'editBusinessCategories': 'ערוך תחומי עיסוק',
      'actionConfirmation': 'אישור פעולה',
      'noNotificationsSelected': 'בחרת שלא תקבל התראות על בקשות חדשות. האם להמשיך?',
      'no': 'לא',
      'yes': 'כן',
      'errorGeneral': 'שגיאה: {error}',
      'seeMoreSelectFields': 'אתה רואה בקשות בתשלום רק מתחומי העיסוק שבחרת. כדי לראות יותר בקשות, בחר תחומי עיסוק נוספים בפרופיל.',
      'trialPeriodEnded': 'שבוע הניסיון הסתיים',
      'selectBusinessFieldsInProfile': 'כדי לראות בקשות בתשלום, בחר תחומי עיסוק בפרופיל שלך.',
      'afterUpdateCanContact': 'לאחר עדכון הפרופיל, תוכל ליצור קשר עם המפרסמים דרך הפרטים המופיעים בבקשה.',
      'businessFieldsNotMatch': 'תחומי עיסוק לא מתאימים',
      'requestFromCategory': 'הבקשה הזו היא מתחום "{category}" ולא מתאימה לתחומי העיסוק שלך.',
      'updateBusinessFieldsHint': 'במידה ותרצה לפנות ליוצר הבקשה, עליך לעדכן את תחומי העיסוק שלך בפרופיל כך שיתאימו לקטגוריה של הבקשה.',
      'updateBusinessFields': 'ערוך תחומי עיסוק',
      'updateBusinessFieldsTitle': 'עדכן תחומי עיסוק',
      'cancelInterest': 'ביטול עניין',
      // הודעות נוספות
      'afterCancelNoChat': 'לאחר הביטול, לא תוכל לראות את הצ\'אט עם יוצר הבקשה.',
      'yesCancelInterest': 'כן, בטל עניין',
      'requestFromField': 'הבקשה הזאת היא בתחום "{category}".',
      'updateFieldsToContact': 'אם אתה נותן שירות בתחום זה, עליך קודם לעדכן תחומי עיסוק בפרופיל ולאחר מכן תוכל לפנות ליוצר הבקשה.',
      'confirmAction': 'אישור פעולה',
      'selectedNoNotifications': 'בחרת שלא תקבל התראות על בקשות חדשות. האם להמשיך?',
      'notificationPermissionRequiredForFilter': 'עליך לאשר קבלת התראות כדי לקבל התראות על בקשות חדשות.\n\nאם לא תאשר, לא תקבל התראות על בקשות חדשות.',
      'continue': 'המשך',
      'loadingRequestsError': 'שגיאה בטעינת הבקשות',
      // טקסטים נוספים ממסך הבית
      'requestsFromAdvertisers': 'השכונה החכמה שלי',
      'allRequests': 'בקשות בשכונה',
      'advancedFilter': 'סינון בקשות',
      'goToAllRequests': 'עבור לכל הבקשות',
      'filterSaved': 'הסינון נשמר',
      'saveFilter': 'שמור סינון',
      'savedFilter': 'סינון שמור',
      'savedFilterFound': 'נמצא סינון שמור מהפעם הקודמת. האם ברצונך לשחזר אותו?',
      'allTypes': 'כל הסוגים',
      'allSubCategories': 'כל התת-תחומים',
      // טקסטים ממסך סינון בקשות
      'urgency': 'דחיפות',
      'normal': 'רגיל',
      'within24Hours': 'תוך 24 שעות',
      'now': 'דחוף',
      'within24HoursAndNow': 'תוך 24 שעות וגם דחוף',
      'requestRange': 'טווח הבקשות שלך',
      'km': 'ק"מ',
      'filterByFixedLocation': 'סנן בקשות על פי המיקום הקבוע וטווח החשיפה שהגדרתי בפרופיל שלי',
      'mustDefineFixedLocation': 'עליך להגדיר מיקום קבוע וטווח חשיפה בפרופיל תחילה',
      'filterByMobileLocation': 'סנן בקשות על פי המיקום הנייד שלי וטווח החשיפה שלי (תוך כדי תנועה)',
      'selectRange': 'בחר טווח',
      'setLocationAndRange': 'לחץ לבחירת מיקום וטווח חשיפה נוספים',
      'kmFromSelectedLocation': '{distance} ק״מ ממיקום שנבחר במפה',
      'kmFromMobileLocation': '{distance} ק״מ מהמיקום הנייד',
      'kmFromFixedLocation': '{distance} ק״מ ממיקום קבוע',
      'receiveNotificationsForNewRequests': 'קבל התראות על בקשות חדשות מתאימות לסינון שהגדרת',
      'noPaidServicesMessage': 'הגדרת שאתה לא נותן שירותים בתשלום - תוכל לראות רק בקשות חינמיות',
      'showToProvidersOutsideRange': 'על פי המיקום שבחרת, הבקשה שלך נמצאת באיזור {region}, האם אתה מעוניין שהבקשה שלך תופיע אצל כל נותני השירות מתחום {category} מאיזור {region}?',
      'yesAllProvidersInRegion': 'כן, כל נותני השירות באיזור {region}',
      'noOnlyInRange': 'לא, רק בטווח שהגדרתי',
      'showToAllUsersOrProviders': 'האם אתה מעוניין שבקשה זו תופיע לכל נותני השירות מכל התחומים באפליקציה או רק לנותני שירות מתחום {category} שבחרת?',
      'yesToAllUsers': 'כן לכל נותני השירות מכל התחומים',
      'onlyToProvidersInCategory': 'רק לנותני שירות מתחום {category}',
      'northRegion': 'צפון',
      'centerRegion': 'מרכז',
      'southRegion': 'דרום',
      'mainCategory': 'תחום ראשי',
      'subCategory': 'תת-תחום',
      // טקסטים ממסך בקשה חדשה
      'selectCategory': 'בחירת קטגוריה',
      'pleaseSelectCategoryFirst': 'אנא בחר תחום קודם',
      'title': 'כותרת',
      'enterTitle': 'אנא הזן כותרת',
      'description': 'תיאור',
      'enterDescription': 'אנא הזן תיאור',
      'urgencyLevel': 'רמת דחיפות',
      'normalUrgency': 'רגיל',
      'within24HoursUrgency': 'תוך 24 שעות',
      'nowUrgency': 'דחוף',
      'imagesForRequest': 'תמונות לבקשה',
      'youCanAddImages': 'באפשרותך להוסיף תמונות שיעזרו להבין את הבקשה טוב יותר',
      'limit5Images': 'מגבלת 5 תמונות',
      'selectImages': 'בחר תמונות',
      'selectedImagesCount': 'נבחרו {count} תמונות',
      'enterFullPrefixAndNumber': 'הזן קידומת ומספר מלאים',
      'invalidPhoneNumber': 'מספר טלפון לא תקין',
      'invalidPrefix': 'קידומת לא תקפה',
      'freeRequestsDescription': 'בקשות חינם: כל סוגי המשתמשים יכולים לעזור (ללא הגבלת קטגוריה)',
      'paidRequestsDescription': 'בקשות בתשלום: רק משתמשים עם קטגוריות מתאימות יכולים לעזור',
      'permissionRequiredImages': 'נדרשת הרשאת גישה לתמונות',
      'permissionRequiredCamera': 'נדרשת הרשאת גישה למצלמה',
      'errorSelectingImages': 'שגיאה בבחירת תמונות',
      'errorTakingPhoto': 'שגיאה בצילום תמונה',
      'errorUploadingImages': 'שגיאה בהעלאת תמונות',
      'imageAddedSuccessfully': 'תמונה נוספה בהצלחה',
      'cannotAddMoreThan5Images': 'לא ניתן להוסיף יותר מ-5 תמונות',
      'alreadyHas5Images': 'כבר יש 5 תמונות. מחק תמונות כדי להוסיף חדשות.',
      'addedImagesCount': 'נוספו {count} תמונות',
      'multiplePhotoCapture': 'צילום תמונות מרובות',
      'clickOkToCapture': 'לחץ "אישור" כדי לצלם תמונה נוספת',
      'shareNow': 'שתף עכשיו',
      'pleaseSelectCategory': 'אנא בחר קטגוריה לבקשה',
      'pleaseSelectLocation': 'נא לבחור מיקום לבקשה',
      'creatingRequest': 'יוצר בקשה...',
      'requestLimits': 'הגבלות הבקשות שלך',
      'maxRequestsPerMonth': 'מקסימום בקשות בחודש: {max}',
      'maxSearchRange': 'טווח חיפוש מקסימלי: {radius} ק"מ',
      'newRequestTutorialTitle': 'יצירת בקשה חדשה',
      'newRequestTutorialMessage': 'כאן תוכל ליצור בקשה חדשה ולקבל עזרה מהקהילה. כתוב תיאור ברור, בחר קטגוריה, הגדר מיקום וטווח חשיפה (לפי סוג המשתמש שלך), ופרסם את הבקשה.',
      'writeRequestDescription': 'כתיבת תיאור הבקשה',
      'selectAppropriateCategory': 'בחירת קטגוריה מתאימה',
      'selectLocationAndExposure': 'בחירת מיקום וטווח חשיפה',
      'setPriceFreeOrPaid': 'הגדרת מחיר (חינם או בתשלום)',
      'publishRequest': 'פרסום הבקשה',
      'locationInfoTitle': 'מידע על בחירת מיקום',
      'howToSelectLocation': 'איך לבחור מיקום נכון:',
      'selectLocationInstructions': '📍 בחר מיקום מדויק ככל האפשר\n🎯 הטווח יקבע כמה אנשים יראו את הבקשה\n📱 השתמש במפה כדי לבחור את המיקום המדויק',
      'locationSelectionTips': 'טיפים לבחירת מיקום:',
      'locationSelectionTipsDetails': '🏠 בחר את הכתובת המדויקת\n🚗 אם זה ברחוב, בחר את הצד הנכון\n🏢 אם זה בבניין, בחר את הכניסה הראשית\n📍 השתמש בחיפוש כתובת לדיוק מקסימלי\n📏 הטווח המינימלי הוא 0.1 ק"מ',
      'selectMainCategoryThenSub': 'בחר תחום ראשי ואז תחום משנה',
      'selectSubCategoriesUpTo': 'בחר תחומי משנה (עד {max} מכל התחומים):',
      'clearSelection': 'נקה בחירה',
      'prefix': 'קידומת',
      'phoneNumberLabel': 'מספר טלפון',
      'selectLocation': 'בחר מיקום',
      'selectDeadlineOptional': 'בחר תאריך יעד (אופציונלי)',
      'price': 'מחיר',
      'optional': 'אופציונלי',
      'willingToPay': 'מוכן לשלם',
      'howMuchWillingToPay': '(אופציונלי) כמה מוכן לשלם?',
      'upToOneMonth': 'עד חודש מהיום',
      // טקסטים ממסך בחירת מיקום
      'selectLocationTitle': 'בחירת מיקום',
      'currentLocation': 'מיקום נוכחי',
      'gettingLocation': 'מקבל מיקום...',
      'exposureCircle': 'מעגל חשיפה',
      'kilometers': 'קילומטרים',
      'dragSliderToChange': 'גרור את הסליידר כדי לשנות את גודל מעגל החשיפה',
      'maxRangeWithBonuses': 'טווח מקסימלי: {radius} ק"מ (כולל בונוסים)',
      'notificationsWillBeSent': 'התראות יישלחו רק למשתמשים שמיקום הסינון שלהם בתוך ישראל ובטווח',
      'selectedLocation': 'מיקום נבחר',
      'selectedLocationLabel': 'מיקום נבחר:',
      // טקסטים ממסך בקשות שלי
      'statusOpen': 'פתוח',
      'statusCompleted': 'טופל',
      'statusCancelled': 'בוטל',
      'statusInProgress': 'בטיפול',
      'mapOfRelevantHelpers': 'מפת נותני שירות רלוונטיים',
      'helpersInRange': 'יש {count} נותני שירות מתאימים בטווח של {radius} ק״מ',
      'updatesEvery30Seconds': 'מתעדכן כל 10 שניות',
      'yourRequestLocation': 'מיקום הבקשה שלך',
      'subscribedHelpers': 'נותני שירות מנויים',
      'range': 'טווח',
      'chatWith': 'צ\'אט עם {name}',
      'chatClosedWith': 'צ\'אט סגור עם {name}',
      'markAsCompleted': 'סמן כטופל',
      'cancelCompleted': 'בטל טופל',
      'mapAvailableOnly': 'מפה זמינה רק לבקשות בתשלום',
      'goToSeeSubscribedHelpers': 'עבור לראות נותני שירות מנויים באזור',
      'rangeKm': 'טווח: {radius} ק״מ',
      'helpers': 'עוזרים',
      'helpersCount': 'עוזרים: {count}',
      'likes': 'לייקים',
      'likesCount': 'לייקים: {count}',
      'deadlineLabel': 'תאריך יעד',
      'deadlineExpired': 'תאריך יעד: פג תוקף',
      'deadlineDate': 'תאריך יעד: {date}',
      'helpersWhoShowedInterest': 'עוזרים שהביעו עניין:',
      'noHelpersAvailable': 'אין עוזרים זמינים',
      // טקסטים ממסך בית
      'requestWithoutPhone': 'בקשה ללא מספר טלפון',
      'deadlineDateHome': 'תאריך יעד: {date}',
      'interestedCallers': '{count} פונים מעוניינים',
      'publishedBy': 'פורסם על ידי: {name}',
      'publishedByUser': 'פורסם על ידי: משתמש',
      'iAmInterested': 'אני מעוניין',
      'iAmNotInterested': 'אני לא מעוניין',
      'clickIAmInterestedToShowPhone': 'לחץ "אני מעוניין" כדי להציג מספר טלפון',
      // טקסטים נוספים ממסך פניות שלי
      'chatButton': 'צ\'אט',
      'chatClosedButton': 'צ\'אט סגור',
      'request': 'בקשה',
      'helloIAm': 'שלום! אני {name}{badge}',
      'newInField': 'מתחום {category}',
      'interestedInHelping': 'מעוניין לעזור לך עם הבקשה שלך. איך אוכל לעזור?',
      'canSendUpTo50Messages': 'ניתן לשלוח עד 50 הודעות בצ\'אט זה. הודעות מערכת לא נספרות במגבלה.',
      // Chat screen messages
      'loadingMessages': 'טוען הודעות...',
      'errorLoadingMessages': 'שגיאה: {error}',
      'messageDeleted': 'הודעה נמחקה',
      'messageDeletedSuccessfully': 'ההודעה נמחקה בהצלחה',
      'chatClosedCannotSend': 'הצ\'אט נסגר - לא ניתן לשלוח הודעות',
      'closeChat': 'סגור צ\'אט',
      'closeChatTitle': 'סגירת צ\'אט',
      'closeChatMessage': 'האם אתה בטוח שברצונך לסגור את הצ\'אט? לאחר הסגירה לא ניתן יהיה לשלוח הודעות נוספות.',
      'reopenChat': 'פתח צ\'אט מחדש',
      'chatClosedBy': 'הצ\'אט נסגר על ידי {name}. לא ניתן לשלוח הודעות נוספות.',
      'chatClosedStatus': 'הצ\'אט נסגר',
      'chatClosedSuccessfully': 'הצ\'אט נסגר בהצלחה',
      'chatReopened': 'הצ\'אט נפתח מחדש',
      'chatReopenedBy': 'הצ\'אט נפתח מחדש על ידי {name}.',
      'errorClosingChat': 'שגיאה בסגירת הצ\'אט',
      // Splash screen
      'initializing': 'מאתחל...',
      'ready': 'מוכן!',
      'errorInitialization': 'שגיאה באתחול: {error}',
      'strongNeighborhoodInAction': 'שכונה חזקה בפעולה',
      // Voice messages
      'recording': 'מקליט...',
      'errorLoadingVoiceMessage': 'שגיאה בטעינת ההודעה הקולית: {error}',
      // Trial extension
      'guestPeriodExtendedTwoWeeks': 'תקופת האורח שלך הורחבה בשבועיים! 🎉',
      'thankYouForActions': 'תודה על הפעולות שביצעת. תקופת האורח שלך הורחבה בעוד 14 ימים.',
      // My Requests Screen
      'fullScreenMap': 'מפה - מסך מלא',
      'fixedLocationClickForDetails': 'מיקום קבוע - לחץ לפרטים מלאים',
      'mobileLocationClickForDetails': 'מיקום נייד - לחץ לפרטים מלאים',
      'overallRating': 'דירוג כללי: {rating}',
      'ratings': 'דירוגים:',
      'reliabilityLabel': 'אמינות',
      'availabilityLabel': 'זמינות',
      'attitudeLabel': 'יחס',
      'fairPriceLabel': 'מחיר הוגן',
      'navigateToServiceProvider': 'נווט למיקום נותן השירות',
      'phone': 'טלפון: {phone}',
      'cannotCallNumber': 'לא ניתן להתקשר למספר: {phone}',
      'errorCalling': 'שגיאה בהתקשרות: {error}',
      'loadingRequests': 'טוען בקשות...',
      'errorLoading': 'שגיאה: {error}',
      'openFullScreen': 'פתח מסך מלא',
      'refreshMap': 'רענון מפה',
      'minimalRatings': 'דירוגים מינימליים:',
      'generalRating': 'כללי: {rating}+',
      'reliabilityRating': 'אמינות: {rating}+',
      'availabilityRating': 'זמינות: {rating}+',
      'attitudeRating': 'יחס: {rating}+',
      'priceRating': 'מחיר: {rating}+',
      'helper': 'עוזר',
      'chatReopenedCanSend': 'הצ\'אט נפתח מחדש - ניתן לשלוח הודעות',
      'requestReopenedChatsReopened': 'הבקשה חזרה למצב פתוח והצ\'אטים נפתחו מחדש',
      'deleteRequestTitle': 'מחיקת בקשה',
      'deleteRequestConfirm': 'האם אתה בטוח שברצונך למחוק את הבקשה? פעולה זו לא ניתנת לביטול.',
      'requestDeletedSuccess': 'הבקשה נמחקה בהצלחה',
      'errorDeletingRequest': 'שגיאה במחיקת הבקשה: {error}',
      'deletedImagesFromStorage': 'נמחקו {count} תמונות מ-Storage',
      'errorDeletingImages': 'שגיאה במחיקת תמונות: {error}',
      'errorOpeningChat': 'שגיאה בפתיחת הצ\'אט: {error}',
      // Home Screen
      'privateFree': 'פרטי חינם',
      'privateSubscription': 'פרטי מנוי',
      'businessSubscription': 'עסקי מנוי',
      'businessNoSubscription': 'עסקי ללא מנוי',
      'admin': 'מנהל',
      'rangeInfo': 'מידע על הטווח שלך',
      'currentRange': 'הטווח הנוכחי שלך: {radius} ק"מ',
      'subscriptionType': 'סוג מנוי: {type}',
      'baseRange': 'טווח בסיסי: {radius} ק"מ',
      'bonuses': 'בונוסים: +{bonus} ק"מ',
      'bonusDetails': 'פירוט הבונוסים:',
      'howToImproveRange': 'איך לשפר את הטווח:',
      'recommendAppBonus': '🎉 המלץ על האפליקציה לחברים (+0.2 ק"מ לכל המלצה)',
      'getHighRatingsBonus': '⭐ קבל דירוגים גבוהים (+0.5-1.5 ק"מ)',
      'subscriptionRequired': 'מנוי נדרש',
      'subscriptionRequiredMessage': 'כדי לראות בקשות בתשלום, אנא הפעל את המנוי שלך',
      'businessFieldsRequired': 'תחומי עיסוק נדרשים',
      'businessFieldsRequiredMessage': 'כדי לראות בקשות בתשלום, אנא בחר תחומי עיסוק בפרופיל',
      'categoryRestriction': 'הגבלת קטגוריה',
      'categoryRestrictionMessage': 'תחום העיסוק "{category}" שבחרת אינו אחד מתחומי העיסוק שלך. במידה ותרצה לראות בקשות בתשלום בקטגוריה זו, עדכן את תחומי העיסוק שלך בפרופיל.',
      'reachedEndOfList': 'הגעת לסוף הרשימה',
      'noMoreRequestsAvailable': 'אין עוד בקשות זמינות',
      // Profile Screen
      'completeYourProfile': 'השלם את הפרופיל שלך',
      'completeProfileMessage': 'כדי לקבל עזרה טובה יותר, מומלץ להשלים את הפרטים בפרופיל שלך: תמונה, תיאור קצר, מיקום וטווח חשיפה. הטווח המקסימלי תלוי בסוג המשתמש שלך .',
      'whatYouCanDo': 'מה תוכל לעשות:',
      'uploadProfilePicture': 'העלאת תמונת פרופיל',
      'updatePersonalDetails': 'עדכון פרטים אישיים',
      'updateLocationAndExposureRange': 'עדכון מיקום וטווח חשיפה',
      'selectSubscriptionTypeIfRelevant': 'בחירת סוג מנוי (אם רלוונטי)',
      'errorUploadingImage': 'שגיאה בהעלאת תמונה',
      'noPermissionToUpload': 'אין הרשאה להעלות תמונות. אנא פנה למנהל המערכת.',
      'networkError': 'שגיאת רשת. אנא בדוק את החיבור לאינטרנט.',
      'errorStoringImage': 'שגיאה באחסון התמונה. אנא נסה שוב.',
      'user': 'משתמש',
      'errorUpdatingLocation': 'שגיאה בעדכון המיקום',
      'errorLocationPermissions': 'שגיאה בהרשאות מיקום. אנא בדוק את ההגדרות',
      'errorNetworkLocation': 'שגיאת רשת. אנא בדוק את החיבור לאינטרנט',
      'timeoutError': 'פסק זמן. אנא נסה שוב',
      'deleteFixedLocationTitle': 'מחיקת מיקום קבוע',
      'deleteFixedLocationMessage': 'האם אתה בטוח שברצונך למחוק את המיקום הקבוע?\n\nלאחר המחיקה, תופיע במפות רק כששירות המיקום פעיל בטלפון.',
      'selectUpToTwoFields': 'כדי לקבל התראות על בקשות רלוונטיות, עליך לבחור עד שני תחומי עיסוק:',
      'onlyFreeRequestsMessage': 'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
      // Payment request messages
      'paymentRequestSentSuccessfully': 'בקשת התשלום נשלחה בהצלחה, נבדוק הבקשה שלך בהקדם!',
      'errorSendingPaymentRequest': 'שגיאה בשליחת בקשת התשלום. נסה שוב מאוחר יותר.',
      'accountDeletedSuccessfully': 'החשבון נמחק בהצלחה',
      'errorLoggingOutMessage': 'שגיאה בהתנתקות: {error}',
      'systemAdminCannotChangeSubscription': 'מנהל מערכת לא יכול לשנות את סוג המנוי',
      'pendingRequestExists': 'יש לך בקשה ממתינה לאישור. לא ניתן לשלוח בקשה נוספת.',
      'providerFilterSaved': 'סינון נותני שירות נשמר',
      'errorDeletingUsers': 'שגיאה במחיקת המשתמשים: {error}',
      'requestsDeletedSuccessfully': 'נמחקו {count} בקשות בהצלחה',
      'errorDeletingRequests': 'שגיאה במחיקת הבקשות: {error}',
      'documentsDeletedSuccessfully': 'נמחקו {count} מסמכים מהקולקציות בהצלחה.{errors}',
      'errorDeletingCollections': 'שגיאה במחיקת הקולקציות: {error}',
      'systemAdmin': 'מנהל מערכת - גישה מלאה לכל הפונקציות (עסקי מנוי)',
      'manageUsers': 'ניהול משתמשים',
      'requestStatistics': 'סטטיסטיקות בקשות',
      'deleteAllUsers': 'מחיקת כל המשתמשים',
      'deleteAllRequests': 'מחק כל הבקשות',
      'deleteAllCollections': 'מחק כל הקולקציות',
      'subscription': 'מנוי',
      'privateSubscriptionType': 'פרטי מנוי',
      'businessSubscriptionType': 'עסקי מנוי',
      'rejectionReason': 'סיבה: {reason}',
      'remainingRequests': 'נשארו לך רק {count} בקשות!',
      'wantMoreUpgrade': 'רוצה יותר? שדרג מנוי',
      'guest': 'אורח',
      // Share Service
      'interestingRequestInApp': '🎯 בקשה מעניינת ב-"שכונתי"!',
      'locationNotSpecified': 'מיקום לא צוין',
      'wantToHelpDownloadApp': '💡 רוצה לעזור? הורד את האפליקציה "שכונתי" וצור קשר ישיר!',
      // App Sharing Service
      'appDescription': '"שכונתי" - האפליקציה שמחברת בין שכנים לעזרה הדדית אמיתית',
      'yourRangeIncreased': 'הטווח שלך גדל!',
      'chooseHowToShareApp': 'בחר איך תרצה לשתף את האפליקציה:',
      'sendToWhatsApp': 'שלח לחברים ב-WhatsApp',
      'shareOnMessenger': 'שלח ב-Messenger',
      'shareOnInstagram': 'שתף ב-Instagram',
      // Home screen additional
      'removeRequestConfirm': 'האם אתה בטוח שברצונך להסיר את הבקשה ממסך "{screen}"? הבקשה לא תימחק, רק תוסר מהרשימה.',
      'requestRemoved': 'הבקשה הוסרה ממסך "{screen}"',
      'errorRemovingRequest': 'שגיאה בהסרת הבקשה: {error}',
      'interestCancelled': 'ביטלת את העניין שלך בבקשה',
      'cannotCallThisNumber': 'לא ניתן להתקשר למספר זה',
      'errorCreatingChat': 'שגיאה ביצירת צ\'אט: {error}',
      'savedFilterRestored': 'הסינון השמור הוחזר בהצלחה',
      'errorRestoringFilter': 'שגיאה בשחזור הסינון: {error}',
      'goToProfileToActivateSubscription': 'אנא עבור למסך פרופיל דרך התפריט התחתון כדי להפעיל מנוי',
      'selectRequestRange': 'בחירת טווח בקשות',
      'selectLocationAndRangeOnMap': 'בחר מיקום וטווח במפה',
      'newNotification': 'התראה חדשה!',
      'setFixedLocationInProfile': 'הגדר מיקום קבוע בפרופיל',
      'clearFilter': 'נקה סינון',
      'changeFilter': 'שנה סינון',
      'filter': 'סנן וקבל התראות',
      'filterServiceProviders': 'סנן נותני שירות',
      'loginWithoutVerification': 'התחבר ללא אימות',
      'refresh': 'רענן',
      'addedLike': 'הוספת לייק! ❤️',
      'removedLike': 'הסרת לייק',
      'filterOptions': 'אפשרויות סינון',
      'saveFilterForNextTime': 'שמור את הסינון לפעם הבאה',
      // Profile screen additional
      'deleteFixedLocation': 'מחיקת מיקום קבוע',
      'requestPendingApproval': 'בקשה בתהליך אישור ⏳',
      'privateSubscriptionPrice': 'פרטי מנוי - 30₪/שנה',
      'businessSubscriptionPrice': 'עסקי מנוי - 70₪/שנה',
      'upgradeToBusinessSubscription': 'שדרוג לעסקי מנוי:',
      // Share service
      'interestingRequestInShchunati': '🎯 בקשה מעניינת ב-"שכונתי"!',
      // App sharing service
      'shchunatiAppDescription': '"שכונתי" - האפליקציה שמחברת בין שכנים לעזרה הדדית אמיתית',
      'yourRangeGrew': 'הטווח שלך גדל!',
      'sendToMessenger': 'שלח ב-Messenger',
      // Chat screen additional
      'communicationWithServiceProvider': 'תקשורת עם נותן השירות',
      'communicationWithServiceProviderMessage': 'כאן תוכל לתקשר עם נותן השירות, לשאול שאלות ולתאם את הפרטים.',
      'messageOptions': 'אפשרויות הודעה',
      'whatDoYouWantToDoWithMessage': 'מה תרצה לעשות עם ההודעה?',
      'editMessage': 'עריכת הודעה',
      'typeNewMessage': 'הקלד את ההודעה החדשה...',
      'messageEditedSuccessfully': 'ההודעה נערכה בהצלחה',
      'errorEditingMessage': 'שגיאה בעריכת ההודעה: {error}',
      'deleteMessageTitle': 'מחיקת הודעה',
      'deleteMessageConfirm': 'האם אתה בטוח שברצונך למחוק את ההודעה?',
      'deleteChat': 'מחק צ\'אט',
      'errorSendingVoiceMessage': 'שגיאה בשליחת הודעה קולית: {error}',
      'reached50MessageLimit': 'הגעת למגבלת 50 הודעות - לא ניתן לשלוח הודעות נוספות',
      'warningMessagesRemaining': 'אזהרה: נותרו {count} הודעות בלבד',
      'errorSendingMessage': 'שגיאה בשליחת הודעה: {error}',
      'deleteChatTitle': 'מחיקת צ\'אט',
      'deleteChatConfirm': 'האם אתה בטוח שברצונך למחוק את הצ\'אט? פעולה זו לא ניתנת לביטול.',
      'chatDeletedSuccessfully': 'הצ\'אט נמחק בהצלחה',
      'errorDeletingChat': 'שגיאה במחיקת הצ\'אט: {error}',
      'cannotReopenChatDeletedByRequester': 'לא ניתן לפתוח את הצ\'אט מחדש - הצ\'אט נמחק על ידי מבקש השירות',
      'cannotReopenChatDeletedByProvider': 'לא ניתן לפתוח את הצ\'אט מחדש - הצ\'אט נמחק על ידי נותן השירות',
      'deleteMyMessagesConfirm': 'האם אתה בטוח שברצונך למחוק את ההודעות שלך?\nהמשתמש השני ימשיך לראות את ההודעות שלו.',
      'myMessagesDeletedSuccessfully': 'ההודעות שלך נמחקו בהצלחה',
      'errorDeletingMyMessages': 'שגיאה במחיקת ההודעות: {error}',
      // Network aware widget
      'connectionRestored': 'החיבור שוחזר!',
      'stillNoConnection': 'עדיין אין חיבור',
      'processing': 'מעבד...',
      'noInternetConnection': 'אין חיבור לאינטרנט',
      // Tutorial dialog
      'dontShowAgain': 'לא להציג שוב',
      // Edit request screen
      'imageAccessPermissionRequired': 'נדרשת הרשאת גישה לתמונות',
      'cameraAccessPermissionRequired': 'נדרשת הרשאת גישה למצלמה',
      'imagesDeletedFromStorage': 'נמחקו {count} תמונות מ-Storage',
      'pleaseEnterTitle': 'אנא הזן כותרת',
      'pleaseEnterDescription': 'אנא הזן תיאור',
      'userNotLoggedIn': 'משתמש לא מחובר',
      'pleaseSelectLocationForRequest': 'נא לבחור מיקום לבקשה',
      'errorUpdatingRequest': 'שגיאה בעדכון: {error}',
      'deleteImages': 'מחיקת תמונות',
      'deleteAllImagesConfirm': 'האם אתה בטוח שברצונך למחוק את כל התמונות? התמונות יימחקו גם מ-Storage.',
      'deleteAll': 'מחק הכל',
      'allImagesDeletedSuccessfully': 'כל התמונות נמחקו בהצלחה',
      'updatingRequest': 'מעדכן בקשה...',
      'selectMainCategoryThenSubcategory': 'בחר תחום ראשי ואז תחום משנה:',
      'imagesSelected': '{count} תמונות נבחרו',
      'clickToSelectLocation': 'לחץ לבחירת מיקום',
      'deadlineDateSelected': 'תאריך יעד: {day}/{month}/{year}',
      'urgencyTags': 'תגיות דחיפות',
      'selectTagsForRequest': 'בחר תגיות המתאימות לבקשה שלך:',
      'minRatingForHelpers': 'דירוג מינימלי של עוזרים',
      'allRatings': 'כל הדירוגים',
      'customTag': 'תגית מותאמת אישית',
      'writeCustomTag': 'כתוב תגית קצרה משלך',
      'deleteImage': 'מחיקת תמונה',
      'deleteImageConfirm': 'האם אתה בטוח שברצונך למחוק את התמונה?',
      'imageDeletedSuccessfully': 'תמונה נמחקה בהצלחה',
      'errorDeletingImage': 'שגיאה במחיקת תמונה: {error}',
      'imageRemovedFromList': 'תמונה הוסרה מהרשימה',
      // Service providers count dialog
      'noServiceProvidersInCategory': 'אין עדיין נותני שירות בתחום זה',
      'serviceProvidersInCategory': 'מספר נותני שירות בתחום זה: {count}',
      'noServiceProvidersInCategoryMessage': 'אין עדיין נותני שירות מהתחום שבחרת.',
      'theFieldYouSelected': 'התחום שבחרת',
      'confirmMinimalRadius': 'אישור טווח מינימלי',
      'minimalRadiusWarning': 'הטווח שבחרת הוא 0.1 ק"מ בלבד. זה טווח מאוד קטן שיגביל את החשיפה של הבקשה שלך. האם אתה בטוח שברצונך להמשיך עם טווח זה?',
      'allRequestsFromCategory': 'כל הבקשות מתחום {category}',
      'serviceProvidersInCategoryMessage': 'נמצאו {count} נותני שירות זמינים בתחום זה.',
      'continueCreatingRequestMessage': 'תמשיך ליצור את הבקשה - בעתיד יתווספו נותני שירות מתחום זה.',
      'helpGrowCommunity': 'עזור לנו להגדיל את הקהילה!',
      'shareAppToGrowProviders': 'שתף את האפליקציה עם חברים ועמיתים כדי שיותר נותני שירות יוכלו להצטרף.',
      // תגיות דחיפות
      'tagSuddenLeak': '❗ נזילה פתאומית',
      'tagPowerOutage': '⚡ הפסקת חשמל',
      'tagLockedOut': '🔒 תקוע מחוץ לבית',
      'tagUrgentBeforeShabbat': '🔧 תיקון דחוף לפני שבת',
      'tagCarStuck': '🚨 רכב נתקע בדרך',
      'tagJumpStart': '🔋 התנעה / כבלים',
      'tagQuickParkingRepair': '🧰 תיקון מהיר בחניה',
      'tagMovingToday': '🧳 עזרה במעבר דירה היום',
      'tagUrgentBabysitter': '🍼 בייביסיטר דחוף',
      'tagExamTomorrow': '📚 שיעור לפני מבחן מחר',
      'tagSickChild': '🧸 עזרה עם ילד חולה',
      'tagZoomLessonNow': '👩‍🏫 שיעור בזום עכשיו',
      'tagUrgentDocument': '📄 מסמך דחוף',
      'tagMeetingToday': '🤝 פגישה היום',
      'tagPresentationTomorrow': '📊 מצגת מחר',
      'tagUrgentTranslation': '🌐 תרגום דחוף',
      'tagWeddingToday': '💒 חתונה היום',
      'tagUrgentGift': '🎁 מתנה דחופה',
      'tagEventTomorrow': '🎉 אירוע מחר',
      'tagUrgentCraftRepair': '🔧 תיקון מלאכה דחוף',
      'tagUrgentAppointment': '🏥 תור דחוף',
      'tagEmergencyCare': '🚑 טיפול חירום',
      'tagUrgentTherapy': '💆 טיפול דחוף',
      'tagHealthEmergency': '⚕️ חירום בריאותי',
      'tagUrgentITSupport': '💻 תמיכה טכנית דחופה',
      'tagSystemDown': '🖥️ מערכת לא עובדת',
      'tagUrgentTechRepair': '🔧 תיקון טכני דחוף',
      'tagDataRecovery': '💾 שחזור נתונים',
      'tagUrgentTutoring': '📖 שיעור דחוף',
      'tagExamPreparation': '📝 הכנה למבחן',
      'tagUrgentCourse': '🎓 קורס דחוף',
      'tagCertificationUrgent': '🏆 הסמכה דחופה',
      'tagPartyToday': '🎊 מסיבה היום',
      'tagUrgentEntertainment': '🎭 בידור דחוף',
      'tagEventSetup': '🎪 הכנת אירוע',
      'tagUrgentPhotography': '📸 צילום דחוף',
      'tagUrgentGardenCare': '🌱 טיפול בגן דחוף',
      'tagTreeEmergency': '🌳 חירום עץ',
      'tagUrgentCleaning': '🧹 ניקיון דחוף',
      'tagPestControl': '🐛 הדברת מזיקים',
      'tagUrgentCatering': '🍽️ קייטרינג דחוף',
      'tagPartyFood': '🍕 אוכל למסיבה',
      'tagUrgentDelivery': '🚚 משלוח דחוף',
      'tagSpecialDiet': '🥗 דיאטה מיוחדת',
      'tagUrgentTraining': '💪 אימון דחוף',
      'tagCompetitionPrep': '🏆 הכנה לתחרות',
      'tagInjuryRecovery': '🩹 החלמה מפציעה',
      'tagUrgentCoaching': '🏃 אימון דחוף',
      'tagEventToday': '🎉 אירוע היום',
      'tagUrgentBeforeEvent': '💄 דחוף לפני אירוע',
      'tagUrgentBeautyFix': '✨ תיקון יופי דחוף',
      'tagUrgentPurchase': '🛒 קנייה דחופה',
      'tagUrgentSale': '💰 מכירה דחופה',
      'tagEventShopping': '🎁 קניות לאירוע היום',
      'tagUrgentProduct': '📦 מוצר דחוף',
      'tagUrgentDeliveryToday': '📦 משלוח דחוף היום',
      'tagUrgentMoving': '🚚 הובלה דחופה',
      'tagUrgentRoadRepair': '🔧 תיקון דחוף בדרך',
      'tagUrgentTowing': '🚛 גרירה דחופה',
      'tagUrgentPostRenovation': '🧹 ניקיון דחוף אחרי שיפוץ',
      'tagUrgentConsultation': '💼 ייעוץ דחוף',
      'tagUrgentMeeting': '🤝 פגישה דחופה',
      'tagUrgentElderlyHelp': '👴 עזרה דחופה לקשיש',
      'tagUrgentVolunteering': '❤️ התנדבות דחופה',
      'tagUrgentPetCare': '🐾 טיפול דחוף בבעלי חיים',
    },
    'ar': {
      'appTitle': 'حارتي',
      'hello': 'مرحباً',
      'helloName': 'مرحباً، {name}',
      'connected': 'متصل',
      'notConnected': 'غير متصل',
      'disconnected': 'منقطع',
      'welcomeBack': 'مرحباً بعودتك',
      'welcome': 'اهلا بك في حارتك الذكية',
      'welcomeSubtitle': 'سجل كضيف لمدة 3 أشهر مجاناً واستفد من جميع الخدمات دون قيود',
      'joinCommunity': 'انضم إلى مجتمعنا',
      'fullName': 'الاسم الكامل',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'emailAndPassword': 'البريد الإلكتروني وكلمة المرور',
      'yourAccount': 'حسابك',
      'continueWithGoogle': 'المتابعة مع جوجل',
      'loginWithShchunati': 'تسجيل الدخول مع حارتي',
      'continueWithoutRegistration': 'المتابعة دون تسجيل',
      'pleaseRegisterFirst': 'يجب عليك التسجيل أولاً لتنفيذ هذا الإجراء',
      'or': 'أو',
      'byContinuingYouAgree': 'من خلال متابعة استخدام التطبيق، أنت توافق على:',
      'termsOfService': 'شروط الخدمة',
      'privacyPolicy': 'سياسة الخصوصية',
      'termsButton': 'شروط الخدمة',
      'privacyButton': 'سياسة الخصوصية',
      'termsAndPrivacyButton': 'شروط الاستخدام وسياسة الخصوصية',
      'copyright': '© 2025 حارتي. جميع الحقوق محفوظة.',
      'aboutButton': 'حول التطبيق',
      'aboutTitle': 'حول تطبيق حارتي',
      'aboutAppName': 'حارتي',
      'aboutDescription': 'تطبيق "حارتي" هو منصة رقمية تربط بين طالبي الخدمات ومقدمي الخدمات في المجتمع المحلي. يتيح لك التطبيق نشر طلبات المساعدة، وعرض الخدمات، والتواصل مع الجيران، وإدارة المعاملات بطريقة آمنة ومريحة.\n\nيتم تشغيل التطبيق بواسطة "اكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل. يعمل التطبيق كوسيط فقط ولا يتدخل في المعاملات أو الخدمات بين المستخدمين.',
      'aboutVersion': 'الإصدار',
      'aboutSupport': 'الدعم',
      'aboutSupportDescription': 'للأسئلة أو المشاكل أو الطلبات، يرجى الاتصال بالدعم',
      'aboutSupportEmail': 'support@shchunati.com',
      'aboutSupportSubject': 'سؤال/طلب - تطبيق حارتي',
      'aboutClickToContact': 'انقر للاتصال',
      'aboutLegalTitle': 'الوثائق القانونية',
      'aboutFooter': '© 2025 حارتي. جميع الحقوق محفوظة.',
      'newRegistration': 'تسجيل جديد',
      'forgotPassword': 'نسيت كلمة المرور',
      'pleaseEnterEmail': 'يرجى إدخال عنوان البريد الإلكتروني',
      'verifyEmailBelongsToYou': 'تأكد من أن البريد الإلكتروني يخصك! إذا أدخلت بريد إلكتروني لشخص آخر، فسيحصل على رابط إعادة تعيين كلمة المرور.',
      'sendLink': 'إرسال الرابط',
      'passwordResetLinkSentTo': 'تم إرسال رابط إعادة تعيين كلمة المرور إلى ',
      'applyingLanguage': 'تطبيق اللغة...',
      'userType': 'نوع المستخدم',
      'personal': 'شخصي',
      'business': 'تجاري',
      'limitedAccess': 'وصول محدود',
      'fullAccess': 'وصول كامل',
      'register': 'تسجيل',
      'login': 'تسجيل الدخول',
      'alreadyHaveAccount': 'هل لديك حساب؟ سجل الدخول',
      'noAccount': 'ليس لديك حساب؟ سجل',
      'home': 'الرئيسية',
      'notifications': 'الإشعارات',
      'chat': 'الدردشة',
      'profile': 'الملف الشخصي',
      'myRequests': 'طلبات قيد المعالجة', // למסך הבית
      'myRequestsMenu': 'طلباتي', // לתפריט התחתון
      'openRequestsForTreatment': 'طلبات مفتوحة للعلاج',
      'newRequest': 'طلب جديد',
      'logout': 'تسجيل الخروج',
      'language': 'اللغة',
      'selectLanguage': 'اختر اللغة',
      'hebrew': 'العبرية',
      'arabic': 'العربية',
      'english': 'الإنجليزية',
      'theme': 'المظهر',
      'lightTheme': 'فاتح',
      'darkTheme': 'داكن',
      'systemTheme': 'النظام',
      'goldTheme': 'ذهبي',
      'searchHint': 'البحث في الطلبات...',
      'searchProvidersHint': 'البحث عن الشركات والمستقلين...',
      'location': 'الموقع',
      'nearMe': 'قريب مني',
      'wholeVillage': 'كامل القرية',
      'city': 'كامل المدينة',
      'category': 'الفئة',
      'all': 'الكل',
      'maintenance': 'صيانة',
      'education': 'تعليم',
      'transport': 'نقل',
      'shopping': 'تسوق',
      'urgent': 'عاجل',
      'canHelp': 'يمكنني المساعدة',
      'requestTitleExample': 'يحتاج إصلاح صنبور',
      'requestDescriptionExample': 'الصنبور في المطبخ يتسرب، يحتاج سباك',
      'requestTitle2': 'درس رياضيات',
      'requestDescription2': 'أبحث عن مدرس خصوصي للرياضيات للصف العاشر',
      'requestTitle3': 'نقل صغير',
      'requestDescription3': 'يحتاج مساعدة في نقل قطعة أثاث صغيرة',
      'enterName': 'يرجى إدخال الاسم الكامل',
      'enterEmail': 'يرجى إدخال البريد الإلكتروني',
      'invalidEmail': 'بريد إلكتروني غير صحيح',
      'enterPassword': 'يرجى إدخال كلمة المرور',
      'weakPassword': 'كلمة مرور ضعيفة جداً',
             'signUpSuccess': 'تم التسجيل بنجاح! الآن سجل الدخول ببياناتك',
             'loginSuccess': 'تم تسجيل الدخول بنجاح!',
             'ok': 'موافق',
             'noResults': 'لم يتم العثور على نتائج لـ',
             'noRequests': 'لا توجد طلبات متاحة',
             'save': 'حفظ',
             'requestTitle': 'عنوان الطلب',
             'requestDescription': 'وصف الطلب',
             'images': 'الصور',
             'addImages': 'إضافة صور',
             'clear': 'مسح',
      'sendMessage': 'إرسال رسالة',
      'noMessages': 'لا توجد رسائل',
      'you': 'أنت',
      'otherUser': 'مستخدم آخر',
      'phoneNumber': 'رقم الهاتف',
      'enterPhoneNumber': 'أدخل رقم الهاتف (اختياري)',
      'clearChat': 'مسح المحادثة',
      'clearChatConfirm': 'هل أنت متأكد من أنك تريد حذف جميع الرسائل في المحادثة؟',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'chatCleared': 'تم مسح المحادثة بنجاح',
      'open': 'مفتوح',
      'inProgress': 'قيد المعالجة',
      'completed': 'تم',
      'cancelled': 'ملغي',
      'free': 'مجاني',
      'paid': 'مدفوع',
      'deadline': 'تاريخ انتهاء الطلب',
      'selectDeadline': 'اختر تاريخ انتهاء الطلب',
      'targetAudience': 'الجمهور المستهدف',
      'distance': 'المسافة',
      'village': 'القرية',
      'maxDistance': 'أقصى مسافة (كم)',
      'selectVillage': 'اختر القرية',
      'selectCategories': 'اختر الفئات',
      'requestType': 'نوع الطلب',
      'selectRequestType': 'اختر نوع الطلب',
      'selectTargetAudience': 'اختر الجمهور المستهدف',
      'allCategories': 'جميع الفئات',
      'expired': 'منتهي الصلاحية',
      'editRequest': 'تعديل الطلب',
      'deleteRequest': 'حذف الطلب',
      'confirmDelete': 'هل أنت متأكد من حذف هذا الطلب؟',
      'requestDeleted': 'تم حذف الطلب بنجاح',
      'requestUpdated': 'تم تحديث الطلب بنجاح',
      'newMessage': 'رسالة جديدة',
      'unreadMessages': 'رسائل غير مقروءة',
      'publishAllTypes': 'نشر جميع أنواع الطلبات',
      'respondFreeOnly': 'الرد على الطلبات المجانية فقط',
      'respondFreeAndPaid': 'الرد على الطلبات المجانية والمدفوعة حسب مجال عملك',
      'businessCategories': 'مجالات العمل',
      'selectBusinessCategories': 'اختر مجالات العمل',
      'availability': 'التوفر',
      'availabilityDescription': 'أيام وساعات عملك',
      'availableAllWeek': 'متاح طوال الأسبوع',
      'editAvailability': 'تعديل التوفر',
      'selectDaysAndHours': 'اختر الأيام والساعات',
      'day': 'يوم',
      'startTime': 'وقت البدء',
      'endTime': 'وقت الانتهاء',
      'selectTime': 'اختر الوقت',
      'availabilityUpdated': 'تم تحديث التوفر بنجاح',
      'errorUpdatingAvailability': 'خطأ في تحديث التوفر',
      'noAvailabilityDefined': 'لم يتم تحديد التوفر',
      'daySunday': 'الأحد',
      'dayMonday': 'الإثنين',
      'dayTuesday': 'الثلاثاء',
      'dayWednesday': 'الأربعاء',
      'dayThursday': 'الخميس',
      'dayFriday': 'الجمعة',
      'daySaturday': 'السبت',
      'subscriptionPayment': 'دفع الاشتراك',
      'payWithBit': 'ادفع مع بت',
      'annualSubscription': 'اشتراك سنوي - 10 شيكل',
      'subscriptionDescription': 'الوصول للطلبات المدفوعة حسب مجالات عملك',
      'activateSubscription': 'تفعيل الاشتراك',
      'subscriptionStatus': 'حالة الاشتراك',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'expiryDate': 'تاريخ انتهاء الصلاحية',
      // הודעות שגיאה
      'emailNotRegistered': 'هذا البريد الإلكتروني غير مسجل في النظام',
      'wrongPassword': 'كلمة المرور خاطئة',
      'emailAlreadyRegistered': 'هذا البريد الإلكتروني مسجل في النظام',
      'userAlreadyRegistered': 'هذا المستخدم مسجل بالفعل في النظام',
      'userAlreadyRegisteredPleaseLogin': 'هذا المستخدم مسجل بالفعل في النظام. يرجى تسجيل الدخول باستخدام بريدك الإلكتروني وكلمة المرور',
      'emailOrPasswordWrong': 'البريد الإلكتروني أو كلمة المرور خاطئة',
      'loginError': 'خطأ في تسجيل الدخول',
      'retry': 'حاول مرة أخرى',
      'registrationError': 'خطأ في التسجيل',
      // הודעות הצלחה
      'loggedInSuccessfully': 'تم تسجيل الدخول بنجاح!',
      'registeredSuccessfully': 'تم التسجيل بنجاح! الآن سجل الدخول ببياناتك',
      'googleLoginSuccess': 'تم تسجيل الدخول بنجاح عبر Google!',
      // הודעות נוספות
      'userGuide': 'دليل المستخدم',
      'managePayments': 'إدارة المدفوعات النقدية',
      'payCash': 'ادفع نقداً',
      'cashPayment': 'دفع نقدي',
      'sendPaymentRequest': 'إرسال طلب الدفع',
      'manageCashPayments': 'إدارة المدفوعات النقدية',
      'logoutTitle': 'تسجيل الخروج',
      'logoutMessage': 'هل أنت متأكد من أنك تريد تسجيل الخروج؟',
      'logoutButton': 'تسجيل الخروج',
      'errorLoggingOut': 'خطأ في تسجيل الخروج: {error}',
      'monthlyLimitReached': 'لقد وصلت إلى حد الطلبات الشهرية',
      'monthlyLimitMessage': 'لقد وصلت إلى حد الطلبات الشهرية ({count} طلبات).',
      'youCan': 'يمكنك:',
      'waitForNextMonth': 'انتظار الشهر القادم الذي يبدأ في {date}',
      'upgradeSubscription': 'ترقية الاشتراك للحصول على المزيد من الطلبات الشهرية',
      'upgradeSubscriptionInProfile': 'ترقية الاشتراك في الملف الشخصي',
      'welcomeMessage': 'مرحباً!',
      'welcomeToApp': 'مرحباً بك في تطبيق "حارتي"!',
      'fillAllFields': 'يرجى ملء جميع الحقول',
      'rememberMe': 'تذكرني',
      'saveCredentialsQuestion': 'هل ترغب في حفظ بيانات تسجيل الدخول؟',
      'saveCredentialsInfo': 'إذا اخترت نعم، يمكنك تسجيل الدخول تلقائياً في المرة القادمة',
      'saveCredentialsText': 'احفظ بيانات تسجيل الدخول الخاصة بي',
      'autoLoginText': 'أريد تسجيل الدخول تلقائياً في المرة القادمة',
      'noThanks': 'لا، شكراً',
      'requestsFromNeighborhood': 'الطلبات من الحي',
      'allNotificationsInNeighborhood': 'جميع الإشعارات في حارتي',
      'manageNotifications': 'إدارة جميع الإشعارات',
      'notificationOptions': 'خيارات متنوعة لتلقي إشعارات حول الطلبات الجديدة',
      // טקסטים ממסך ניהול התראות
      'errorLoadingPreferences': 'خطأ في تحميل التفضيلات: {error}',
      'requestLocationInRangeFixed': 'عندما يكون موقع الطلب ضمن نطاق التعرض وموقعي الثابت أو موقعي الثابت ضمن نطاق التعرض للطلب',
      'requestLocationInRangeMobile': 'عندما يكون موقع الطلب ضمن نطاق التعرض وموقعي المحمول أو موقعي المحمول ضمن نطاق التعرض للطلب',
      'requestLocationInRangeFixedOrMobile': 'عندما يكون موقع الطلب ضمن نطاق التعرض وموقعي الثابت أو المحمول أو موقعي الثابت أو المحمول ضمن نطاق التعرض للطلب',
      'notInterestedInPaidRequestNotifications': 'غير مهتم بتلقي إشعارات حول طلبات مدفوعة جديدة',
      'subscriptionNotifications': 'إشعارات الاشتراكات',
      'whenSubscriptionExpires': 'عندما تنتهي فترة اشتراكي',
      'subscriptionReminderBeforeExpiry': 'تذكير قبل انتهاء فترة الاشتراك (أسبوع قبل)',
      'guestPeriodExtensionTwoWeeks': 'تمديد فترة الضيف لمدة أسبوعين مجاناً',
      'subscriptionUpgrade': 'ترقية الاشتراك',
      'requestStatusNotifications': 'إشعارات حول حالة وبيانات الطلب',
      'interestInRequest': 'الاهتمام/عدم الاهتمام بالطلب',
      'newChatMessages': 'رسائل محادثة جديدة',
      'serviceCompletionAndRating': 'إكمال وتقييم الخدمة',
      'radiusExpansionShareRating': 'زيادة نطاق التعرض (مشاركة/تقييم)',
      // טקסטים ממסך התראות
      'userNotConnected': 'المستخدم غير متصل',
      'clearAllNotifications': 'مسح جميع الإشعارات',
      'markAllAsRead': 'وضع علامة مقروءة على الكل',
      'notificationsBlocked': 'الإشعارات محظورة - يرجى تفعيل أذونات الإشعارات في إعدادات الهاتف',
      'enableNotifications': 'تفعيل الإشعارات',
      'error': 'خطأ',
      'errorMessage': 'خطأ: {error}',
      'noNewNotifications': 'لا توجد إشعارات جديدة',
      'notificationInfo': 'عندما يرد شخص ما على طلباتك أو يعرض المساعدة،\nستتلقى إشعاراً هنا',
      'openRequest': 'فتح الطلب',
      'errorUpdatingNotification': 'خطأ في تحديث الإشعار: {error}',
      'allNotificationsMarkedAsRead': 'تم وضع علامة مقروءة على جميع الإشعارات',
      'errorUpdatingNotifications': 'خطأ في تحديث الإشعارات: {error}',
      'clearAllNotificationsTitle': 'مسح جميع الإشعارات',
      'clearAllNotificationsMessage': 'هل أنت متأكد من أنك تريد حذف جميع الإشعارات؟ لا يمكن التراجع عن هذا الإجراء.',
      'clearAll': 'مسح الكل',
      'allNotificationsDeletedSuccessfully': 'تم حذف جميع الإشعارات بنجاح',
      'errorDeletingNotifications': 'خطأ في حذف الإشعارات: {error}',
      'deleteNotification': 'حذف الإشعار',
      'deleteNotificationMessage': 'هل أنت متأكد من أنك تريد حذف الإشعار "{title}"?',
      'notificationDeletedSuccessfully': 'تم حذف الإشعار بنجاح',
      'errorDeletingNotification': 'خطأ في حذف الإشعار: {error}',
      'minutesAgo': 'منذ {count} دقائق',
      'hoursAgo': 'منذ {count} ساعات',
      'daysAgo': 'منذ {count} أيام',
      // הודעות נוספות
      'understood': 'فهمت',
      'openTutorial': 'افتح الدليل',
      // Terms and Privacy
      'termsAndPrivacyTitle': 'شروط الخدمة وسياسة الخصوصية',
      'welcomeToTermsScreen': 'مرحباً بك في تطبيقنا',
      'agreeAndContinue': 'أوافق وأتابع',
      'doNotAgree': 'لا أوافق',
      'importantNote': 'مهم أن تعرف',
      'termsMayBeUpdated': 'قد يتم تحديث شروط الخدمة وسياسة الخصوصية من وقت لآخر.\nيمكنك العثور على أحدث إصدار في التطبيق.',
      'byContinuingYouConfirm': 'من خلال متابعة استخدام التطبيق، أنت تؤكد أنك قرأت وفهمت شروط الخدمة وسياسة الخصوصية، وأنك توافق عليها.',
      'mustAcceptTerms': 'مهم: يجب عليك الموافقة على شروط الخدمة وسياسة الخصوصية للمتابعة في استخدام التطبيق.',
      // Terms of Service
      'termsOfServiceIntro': 'مرحباً بك في تطبيق "حارتي". استخدام التطبيق يخضع للشروط التالية. يرجى قراءتها بعناية:\n\nيتم تشغيل تطبيق "حارتي" بواسطة "أكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل (يشار إليها فيما يلي: "الشركة").',
      'termsSection1': 'يتم تشغيل تطبيق "حارتي" بواسطة "أكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل (يشار إليها فيما يلي: "الشركة"). استخدام التطبيق مشروط بقبول شروط الخدمة هذه.',
      'termsSection2': 'استخدام التطبيق مخصص للمستخدمين الذين تزيد أعمارهم عن 18 عاماً فقط. تحتفظ الشركة بحقها في طلب إثبات العمر في أي مرحلة.',
      'termsSection3': 'التطبيق مخصص للمساعدة المتبادلة بين الجيران - ربط طالبي المساعدة بمقدمي المساعدة في المجتمع المحلي.',
      'termsSection4': 'يتعهد المستخدم بتقديم معلومات صحيحة ودقيقة فقط، بما في ذلك تفاصيل الموقع وتفاصيل الاتصال.',
      'termsSection5': 'التطبيق هو منصة سوق إلكتروني تربط بين طالبي الخدمات ومقدمي الخدمات. يسمح التطبيق للمستخدمين بنشر طلبات المساعدة المجانية والمدفوعة، وعرض الخدمات المهنية والتجارية مقابل الدفع. يُسمح بالاستخدام التجاري والمهني للتطبيق في إطار شروط الخدمة هذه. تعمل الشركة كوسيط فقط ولا تتحمل المسؤولية عن جودة الخدمات، أو موثوقية المستخدمين، أو أي أضرار، أو احتيال، أو خلافات، أو خسائر مالية.',
      'termsSection6': 'المستخدمون مسؤولون حصرياً عن المحتوى الذي ينشرونه وعن أي تفاعل مع مستخدمين آخرين.',
      'termsSection7': 'حارتي هي وسيط فقط ولا تتحمل المسؤولية عن جودة الخدمات أو موثوقية المستخدمين أو أي أضرار.',
      'termsSection8': 'يتعهد المستخدم بالإبلاغ عن أي سلوك غير لائق أو مسيء أو خطير فوراً للدعم أو للسلطات ذات الصلة.',
      'termsSection10': 'تحتفظ الشركة بحقها في إيقاف الخدمة أو حظر المستخدمين أو إزالة المحتوى في أي وقت.',
      'termsSection11': 'المستخدم مسؤول عن الحفاظ على كلمة مرور الدخول الخاصة به وأمن معلوماته الشخصية.',
      'termsSection12': 'سيتم حل أي نزاع وفقاً للقانون الإسرائيلي ووفقاً لقوانين دولة إسرائيل.',
      // Mutual Help and Safety
      'mutualHelpAndSafety': 'المساعدة المتبادلة والسلامة',
      'mutualHelpSection1': 'التطبيق هو منصة سوق إلكتروني تربط بين الأشخاص. أنت تختار بنفسك مع من تتواصل، لمن تقدم الخدمات، أو من تطلب الخدمات، وكل تفاعل من هذا القبيل هو على مسؤوليتك الحصرية. يمكن أن تساعد التقييمات وملاحظات المستخدمين في بناء الثقة، لكنها لا تشكل ضماناً للجودة، أو الموثوقية، أو السلامة. الشركة لا تتحمل المسؤولية عن أي ضرر، أو سلوك غير لائق، أو احتيال، أو جودة خدمات رديئة.',
      'mutualHelpSection2': 'لا يوجد التزام قانوني لتقديم الخدمة، ولكن يُنصح بالوفاء بالالتزامات المقدمة للآخرين.',
      'mutualHelpSection3': 'يجب أن يكون نظام التقييمات والمراجعات صحيحاً ودقيقاً. التقييمات الكاذبة أو المسيئة ستؤدي إلى حظر المستخدم.',
      'mutualHelpSection4': 'في حالة الاشتباه في خطر أو سلوك غير لائق أو استغلال، يجب الإبلاغ فوراً للدعم أو للسلطات ذات الصلة.',
      'mutualHelpSection5': 'نحتفظ بحقنا في حظر المستخدمين الذين ينتهكون القواعد أو يتصرفون بشكل غير لائق.',
      'mutualHelpSection6': 'المدفوعات بين المستخدمين هي مسؤوليتهم الحصرية. حارتي ليست مسؤولة عن المدفوعات أو المعاملات بين المستخدمين.',
      'mutualHelpSection8': 'في حالة وجود مشكلة أو نزاع، نوصي بمحاولة حل المشكلة بطرق سلمية قبل الاتصال بالدعم.',
      // Privacy Policy
      'privacyPolicyIntro': 'تصف سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك الشخصية في تطبيق "حارتي":\n\nيتم تشغيل تطبيق "حارتي" بواسطة "أكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل (يشار إليها فيما يلي: "الشركة").',
      'privacySection1': 'يتم تشغيل تطبيق "حارتي" بواسطة "أكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل (يشار إليها فيما يلي: "الشركة"). نحترم خصوصية المستخدمين ونتعهد بحماية معلوماتك الشخصية.',
      'privacySection2': 'يتم جمع المعلومات الشخصية لتقديم الخدمات، بما في ذلك الموقع الجغرافي لربط الجيران وتفاصيل الاتصال ومعلومات حول طلبات المساعدة.',
      'privacySection3': 'لن نبيع أو نشارك معلوماتك الشخصية مع أطراف ثالثة دون موافقة صريحة، باستثناء الحالات المطلوبة بموجب القانون.',
      'privacySection4': 'يتم حفظ المعلومات على خوادم آمنة ومشفرة. يتم حفظ الموقع الجغرافي بشكل مشفر ولا يتم نقله إلى أطراف ثالثة.',
      'privacySection5': 'لديك سيطرة كاملة على من يرى معلوماتك. يمكنك تعيين مستويات خصوصية مختلفة لطلبات مختلفة.',
      'privacySection6': 'يحق للمستخدم طلب الوصول أو تصحيح أو حذف معلوماته الشخصية في أي وقت.',
      'privacySection7': 'نستخدم ملفات تعريف الارتباط (cookies) وتقنيات مماثلة لتحسين تجربة المستخدم وتحليل استخدام التطبيق.',
      'privacySection8': 'يستخدم التطبيق خدمات Firebase من Google (Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging) للأمان وتخزين البيانات وخدمات الإشعارات. يتم نقل المعلومات إلى خوادم Firebase المحمية بتشفير متقدم وتحت سياسة خصوصية Google.',
      'privacySection9': 'يتطلب التطبيق الوصول إلى موقعك الجغرافي لربطك بالجيران في المنطقة المجاورة. يتم حفظ الموقع بشكل مشفر ويُستخدم فقط لعرض طلبات المساعدة ذات الصلة. يمكنك إلغاء الوصول إلى الموقع في أي وقت من إعدادات الجهاز.',
      'privacySection10': 'يتطلب التطبيق الوصول إلى الميكروفون الخاص بك لإنشاء رسائل صوتية. يتم حفظ التسجيلات على خوادم Firebase المشفرة وتُستخدم فقط للتواصل بين المستخدمين. يمكنك إلغاء الوصول إلى الميكروفون في أي وقت من إعدادات الجهاز.',
      'privacySection11': 'يتطلب التطبيق الوصول إلى الكاميرا والمعرض الخاص بك لرفع الصور لطلبات المساعدة. يتم حفظ الصور على خوادم Firebase Storage المشفرة وتُستخدم فقط لعرض طلبات المساعدة. يمكنك إلغاء الوصول إلى الكاميرا/المعرض في أي وقت من إعدادات الجهاز.',
      'privacySection12': 'نتخذ إجراءات أمنية معقولة لحماية معلوماتك من الوصول غير المصرح به أو الاستخدام أو الكشف.',
      'privacySection13': 'في حالة حدوث خرق أمني أو كشف للمعلومات، سنبلغ بذلك في أقرب وقت ممكن ونتخذ الإجراءات المناسبة.',
      'privacySection14': 'نتعهد بإبلاغ المستخدمين عن أي تغييرات في سياسة الخصوصية من خلال التطبيق أو بطرق أخرى.',
      'privacySection15': 'قد يحتوي التطبيق على روابط لمواقع أو خدمات أطراف ثالثة. نحن لسنا مسؤولين عن سياسة الخصوصية الخاصة بهم.',
      'tutorialHint': 'لتتعلم كيفية استخدام التطبيق، اضغط على أيقونة الدليل (📚) في القائمة العلوية.',
      // Profile Screen
      'extendTrialPeriod': 'تمديد فترة التجربة',
      'extendTrialPeriodByTwoWeeks': 'مدد فترة التجربة لمدة أسبوعين',
      'youAreInWeek': 'أنت في الأسبوع',
      'youAreInFirstWeekMessage': 'أنت في أسبوعك الأول! يمكنك رؤية جميع الطلبات (مجانية ومدفوعة) من جميع الفئات.',
      'yourRating': 'تقييمك',
      'noRatingsYet': 'لم تحصل على تقييمات بعد',
      'detailedRatings': 'تقييمات مفصلة',
      'basedOnRating': 'بناءً على {count} تقييم',
      'basedOnRatings': 'بناءً على {count} تقييمات',
      'reliability': 'الموثوقية',
      'attitude': 'السلوك',
      'fairPrice': 'السعر العادل',
      'editDisplayName': 'تعديل اسم العرض',
      'editPhoneNumber': 'تعديل رقم الهاتف',
      'afterSavingNameWillUpdate': 'بعد الحفظ، سيتم تحديث الاسم في جميع أنحاء التطبيق',
      'phonePrefix': 'المقدمة',
      'enterNumberWithoutPrefix': 'أدخل الرقم بدون المقدمة',
      'select': 'اختر',
      'forExample': 'مثلاً',
      // My Requests Screen
      'noRequestsInMyRequests': 'لا توجد طلبات',
      'createNewRequestToStart': 'أنشئ طلباً جديداً للبدء',
      // In Progress Requests Screen
      'noInterestedRequests': 'ليس لديك طلبات قيد المعالجة',
      'clickInterestedOnRequests': 'انقر "أنا مهتم" على الطلبات التي تهمك في "جميع الطلبات"',
      'howItWorks': 'كيف يعمل؟',
      'howItWorksSteps': '1. انتقل إلى "جميع الطلبات"\n2. انقر "أنا مهتم" على الطلبات التي تهمك\n3. ستظهر الطلبات هنا في "طلباتي قيد المعالجة"',
      // Category Selection
      'selectMainCategoryThen': 'اختر المجال الرئيسي ثم',
      'selectMainCategoryThenUpTo': 'اختر المجال الرئيسي ثم حتى',
      'subCategories': 'المجالات الفرعية',
      // Buttons
      'close': 'إغلاق',
      'startProcess': 'ابدأ العملية',
      'maybeLater': 'ربما لاحقاً',
      'rateNow': 'قيم الآن',
      'startEarning': 'ابدأ الكسب',
      // Trial Extension Dialog
      'toExtendTrialPeriod': 'لتمديد فترة التجربة لمدة أسبوعين، يجب عليك تنفيذ الإجراءات التالية:',
      'shareAppTo5Friends': 'شارك التطبيق مع 5 أصدقاء (WhatsApp, SMS, Email)',
      'rateApp5Stars': 'قيم التطبيق في المتجر بـ 5 نجوم',
      'publishNewRequest': 'انشر طلباً جديداً في أي مجال تريده',
      'serviceRequiresAppointment': 'الخدمة تتطلب موعداً',
      'serviceRequiresAppointmentHint': 'إذا كانت الخدمة تتطلب تحديد موعد، اختر هذا الخيار',
      'canReceiveByDelivery': 'هل يمكن الاستلام بالتوصيل؟',
      'canReceiveByDeliveryHint': 'هل يمكن الحصول على الخدمة من خلال المندوبين؟',
      'publishAd': 'انشر إعلاناً',
      // Subscription Details Dialogs
      'yourBusinessSubscriptionDetails': 'تفاصيل اشتراكك التجاري',
      'yourPersonalSubscriptionDetails': 'تفاصيل اشتراكك الشخصي',
      'yourGuestSubscriptionDetails': 'تفاصيل اشتراكك كضيف',
      'yourFreeSubscription': 'اشتراكك المجاني',
      'yourBusinessSubscriptionIncludes': 'يشمل اشتراكك التجاري:',
      'yourPersonalSubscriptionIncludes': 'يشمل اشتراكك الشخصي:',
      'yourTrialPeriodIncludes': 'تشمل فترة التجربة الخاصة بك:',
      'yourFreeSubscriptionIncludes': 'يشمل اشتراكك المجاني:',
      'requestsPerMonth': '{count} طلبات في الشهر',
      'publishUpToRequestsPerMonth': 'نشر حتى {count} طلبات في الشهر',
      'publishOneRequestPerMonth': 'نشر طلب واحد فقط في الشهر',
      'rangeWithBonuses': 'النطاق: {range} كم + مكافآت',
      'range': 'النطاق: {range} كم',
      'exposureUpToKm': 'التعرض حتى {km} كيلومتر من موقعك',
      'seesFreeAndPaidRequests': 'يرى الطلبات المجانية والمدفوعة',
      'seesOnlyFreeRequests': 'يرى الطلبات المجانية فقط',
      'accessToAllRequestTypes': 'الوصول إلى جميع أنواع الطلبات في التطبيق',
      'accessToFreeRequestsOnly': 'الوصول إلى الطلبات المجانية فقط',
      'selectedBusinessAreas': 'مجالات العمل المختارة',
      'yourBusinessAreas': 'مجالات عملك: {areas}',
      'noBusinessAreasSelected': 'لم يتم الاختيار',
      'paymentPerYear': 'الدفع: {amount}₪ في السنة',
      'oneTimePaymentForFullYear': 'دفعة واحدة لسنة كاملة',
      'noPayment': 'بدون دفع',
      'freeSubscriptionAvailable': 'الاشتراك المجاني متاح بدون تكلفة',
      'trialPeriodDays': 'فترة التجربة: {days} يوم',
      'fullAccessToAllFeatures': 'وصول كامل لجميع الميزات مجاناً',
      'yourSubscriptionActiveUntil': 'اشتراكك نشط حتى {date}',
      'unknown': 'غير معروف',
      'yourTrialActiveForDays': 'فترة التجربة الخاصة بك نشطة لمدة {days} أيام أخرى',
      'subscriptionExpiredSwitchToFree': 'انتقل اشتراكك إلى نوع "شخصي مجاني"، قم بالترقية الآن إلى اشتراك "شخصي" أو "تجاري"',
      'afterTrialAutoSwitchToFree': 'بعد فترة التجربة، ستنتقل تلقائياً إلى اشتراك شخصي مجاني. يمكنك الترقية في أي وقت.',
      // Subscription Type Selection Dialog
      'selectSubscriptionType': 'اختيار نوع الاشتراك',
      'chooseYourSubscriptionType': 'اختر نوع اشتراكك:',
      'privateFree': 'شخصي (مجاني)',
      'privateSubscription': 'شخصي (اشتراك)',
      'businessSubscription': 'تجاري (اشتراك)',
      'privateSubscriptionFeatures': '• طلب واحد في الشهر\n• النطاق: 0-3 كم\n• يرى الطلبات المجانية فقط\n• بدون مجالات عمل',
      'privatePaidSubscriptionFeatures': '• 5 طلبات في الشهر\n• النطاق: 0-5 كم\n• يرى الطلبات المجانية فقط\n• بدون مجالات عمل\n• الدفع: 30₪ في السنة',
      'businessSubscriptionFeatures': '• 10 طلبات في الشهر\n• النطاق: 0-8 كم\n• يرى الطلبات المجانية والمدفوعة\n• اختيار مجالات العمل\n• الدفع: 70₪ في السنة',
      // Activate Subscription Dialog
      'activateSubscriptionWithType': 'تفعيل اشتراك {type}',
      'subscriptionTypeWithType': 'اشتراك {type}',
      'perYear': '₪{price} في السنة',
      'businessAreas': 'مجالات العمل: {areas}',
      'howToPay': 'كيفية الدفع:',
      'paymentInstructions': '1. اختر طريقة الدفع: BIT (PayMe) أو بطاقة ائتمان (PayMe)\n2. ادفع المبلغ (₪{price}) - سيتم تفعيل الاشتراك تلقائياً\n3. إذا كانت هناك مشكلة، اتصل بالدعم',
      'payViaPayMe': 'ادفع عبر PayMe (Bit أو بطاقة ائتمان)',
      // Pending Approval Dialog
      'requestPendingApprovalNew': 'طلب قيد الموافقة ⏳',
      'youHaveRequestForSubscription': 'لديك طلب لـ {type} وهو قيد المعالجة.',
      'cannotSendAnotherRequest': 'لا يمكن إرسال طلب آخر حتى يوافق المدير أو يرفض الطلب الحالي.',
      // System Admin Dialog
      'systemAdministrator': 'مدير النظام',
      'adminFullAccessMessage': 'كمدير للنظام، لديك وصول كامل لجميع الوظائف دون الحاجة إلى الدفع.\n\nنوع اشتراكك ثابت: اشتراك تجاري مع الوصول إلى جميع مجالات العمل.',
      // Cash Payment Dialog
      'cashPaymentTitle': 'دفع نقدي',
      'subscriptionDetails': 'تفاصيل الاشتراك:',
      'subscriptionTypeLabel': 'نوع الاشتراك: {type}',
      'priceLabel': 'السعر: ₪{price}',
      'sendPaymentRequestNew': 'إرسال طلب الدفع',
      'completeAllActionsWithinHour': 'يجب تنفيذ جميع الإجراءات خلال ساعة واحدة',
      'granting14DayExtension': 'تمديد 14 يوماً...',
      'extensionGrantedSuccessfully': 'تم منح التمديد لمدة 14 يوماً بنجاح!',
      'errorGrantingExtension': 'خطأ في منح التمديد',
      'shareAppTo5FriendsForTrial': 'شارك التطبيق مع 5 أصدقاء',
      'rateApp5StarsForTrial': 'قيم التطبيق في المتجر بـ 5 نجوم',
      'publishNewRequestForTrial': 'انشر طلباً جديداً',
      'remainingTime': 'الوقت المتبقي',
      'timeExpired': 'انتهى الوقت',
      'shareAppOpened': 'تم فتح مشاركة التطبيق. يرجى المشاركة مع 5 أصدقاء لإكمال المتطلب.',
      'appStoreOpened': 'تم فتح متجر التطبيقات. يرجى التقييم بـ 5 نجوم لإكمال المتطلب.',
      'navigateToNewRequest': 'الانتقال إلى شاشة إنشاء طلب. يرجى نشر طلب لإكمال المتطلب.',
      'notCompleted': 'غير مكتمل',
      'helpUsImproveApp': 'ساعدنا في تحسين التطبيق',
      // Share App Dialog
      'shareAppTitle': 'شارك التطبيق',
      'shareAppForTrialExtension': 'شارك التطبيق لتمديد فترة التجربة',
      'chooseHowToShare': 'اختر كيف تريد مشاركة التطبيق:',
      'sendToFriendsWhatsApp': 'أرسل للأصدقاء على WhatsApp',
      'sendEmail': 'أرسل بالبريد الإلكتروني',
      'openShareOptions': 'افتح خيارات المشاركة',
      'copyToClipboard': 'نسخ إلى الحافظة',
      'copyTextToShare': 'نسخ نص للمشاركة',
      'generalShare': 'مشاركة عامة',
      'shareToFacebookMessenger': 'مشاركة على Messenger',
      'shareToInstagram': 'شارك على Instagram',
      'openingWhatsApp': 'فتح WhatsApp...',
      'openingWhatsAppWeb': 'فتح WhatsApp Web...',
      'openingMessagesApp': 'فتح تطبيق الرسائل...',
      'openingEmailApp': 'فتح تطبيق البريد الإلكتروني...',
      'openingShareOptions': 'فتح خيارات المشاركة...',
      'textCopiedToClipboard': 'تم نسخ النص إلى الحافظة! شاركه مع الأصدقاء',
      'errorOpeningShare': 'خطأ في فتح المشاركة',
      'errorOpeningShareDialog': 'خطأ في فتح حوار المشاركة',
      'errorCopying': 'خطأ في النسخ',
      'errorOpeningShareOptions': 'خطأ في فتح خيارات المشاركة',
      'copyTextFromClipboard': 'انسخ النص من الحافظة',
      // Rate App Dialog
      'rateAppTitle': 'قيم التطبيق',
      'howWasYourExperience': 'كيف كانت تجربتك؟',
      'yourRatingHelpsUs': 'تقييمك يساعدنا في تحسين التطبيق والوصول إلى المزيد من المستخدمين.',
      'highRatingMoreNeighbors': '⭐ تقييم عالي = المزيد من الجيران = المزيد من المساعدة المتبادلة!',
      'errorOpeningStore': 'خطأ في فتح المتجر',
      'cannotOpenAppStore': 'لا يمكن فتح متجر التطبيقات',
      // Recommend to Friends Dialog
      'recommendToFriendsTitle': 'أوصِ بالأصدقاء',
      'lovedTheAppHelpUsGrow': 'أحببت التطبيق؟ ساعدنا على النمو!',
      'shareWithFriends': '🎯 شارك مع الأصدقاء',
      'rateUs': '⭐ قيمنا',
      'tellAboutYourExperience': '💬 أخبر عن تجربتك',
      'everyRecommendationHelps': 'كل توصية تساعدنا في الوصول إلى المزيد من الجيران الذين يبحثون عن مساعدة متبادلة!',
      // Rewards Dialog
      'rewardsForRecommenders': 'مكافآت للموصين',
      'recommendAppAndGetRewards': 'أوصِ بالتطبيق واحصل على مكافآت!',
      'pointsPerRecommendation': '🎁 10 نقاط - كل توصية',
      'pointsFor5StarRating': '⭐ 5 نقاط - تقييم 5 نجوم',
      'pointsForPositiveReview': '💬 3 نقاط - مراجعة إيجابية',
      'pointsPriorityFeatures': 'النقاط = أولوية في الطلبات + ميزات خاصة!',
      'guestPeriodStarted': 'مرحباً! بدأت فترة الضيف',
      'firstWeekMessage': 'أنت في أسبوعك الأول - يمكنك رؤية جميع الطلبات (مجانية ومدفوعة) من جميع الفئات!',
      'guestModeWithCategories': 'وضع الضيف - مجالات عمل محددة',
      'guestModeNoCategories': 'وضع الضيف - بدون مجالات عمل',
      'helpSent': 'تم إرسال عرض المساعدة!',
      'unhelpConfirmation': 'هل أنت متأكد من أنك تريد إلغاء الاهتمام بهذا الطلب؟',
      'unhelpSent': 'تم إلغاء الاهتمام بالطلب',
      'categoryDataUpdated': 'تم تحديث بيانات الفئات بنجاح',
      'nameDisplayInfo': 'سيظهر الاسم في الطلبات التي تنشئها، وفي خرائط ناشري الطلبات',
      'validPrefixes': 'بادئات صالحة: 050-059 (10 أرقام)، 02,03,04,08,09 (9 أرقام)، 072-079 (10 أرقام)',
      'agreeToDisplayPhone': 'أوافق على عرض رقم هاتفي في الطلبات التي أنشئها، والاتصال بي في حالة تقديم الخدمة',
      // Profile screen texts
      'notConnectedToSystem': 'غير متصل بالنظام',
      'pleaseLoginToSeeProfile': 'يرجى تسجيل الدخول لرؤية ملفك الشخصي',
      'loadingProfile': 'جاري تحميل الملف الشخصي...',
      'errorLoadingProfile': 'خطأ في تحميل الملف الشخصي',
      'userProfileNotFound': 'لم يتم العثور على ملف المستخدم',
      'creatingProfile': 'جاري إنشاء الملف الشخصي...',
      'createProfile': 'إنشاء ملف شخصي',
      'setBusinessFields': 'تعيين مجالات العمل',
      'toReceiveRelevantNotifications': 'لتلقي إشعارات حول الطلبات ذات الصلة، يجب عليك اختيار ما يصل إلى مجالين عمل:',
      'iDoNotProvidePaidServices': 'أنا لا أقدم أي خدمة مقابل الدفع',
      'ifYouSelectThisOption': 'إذا قمت بتحديد هذا الخيار، ستتمكن من رؤية الطلبات المجانية فقط في شاشة الطلبات.',
      'orSelectBusinessAreas': 'أو اختر مجالات العمل:',
      'selectBusinessAreasToReceiveRelevantRequests': 'اختر مجالات العمل لتلقي الطلبات ذات الصلة:',
      'allAds': 'جميع الإعلانات',
      'adsCount': '{count} إعلان',
      'ifYouProvideService': 'إذا كنت تقدم خدمة ما، قم بتعيين مجالات عملك واحصل على الوصول إلى الطلبات المدفوعة.\n\nيمكنك تغيير مجالات عملك في أي وقت في ملفك الشخصي.',
      'later': 'لاحقاً',
      'chooseNow': 'اختر الآن',
      'tutorialsResetSuccess': 'تم إعادة تعيين رسائل الدليل بنجاح',
      'subscriptionTypeChanged': 'تم تغيير نوع الاشتراك إلى {type}',
      'errorChangingSubscriptionType': 'خطأ في تغيير نوع الاشتراك: {error}',
      'permissionsRequired': 'الأذونات مطلوبة',
      'imagePermissionRequired': 'إذن الوصول إلى الصور مطلوب. يرجى الانتقال إلى إعدادات التطبيق وتفعيل الإذن.',
      'openSettings': 'فتح الإعدادات',
      'imagePermissionRequiredTryAgain': 'إذن الوصول إلى الصور مطلوب. يرجى المحاولة مرة أخرى.',
      'chooseAction': 'اختر إجراء',
      'chooseFromGallery': 'اختر من المعرض',
      'deletePhoto': 'حذف الصورة',
      'profileImageUpdatedSuccess': 'تم تحديث صورة الملف الشخصي بنجاح',
      'profileImageDeletedSuccess': 'تم حذف صورة الملف الشخصي بنجاح',
      'errorDeletingProfileImage': 'خطأ في حذف صورة الملف الشخصي',
      'profileCreatedSuccess': 'تم إنشاء الملف الشخصي بنجاح كـ {type}',
      'errorCreatingProfile': 'خطأ في إنشاء الملف الشخصي: {error}',
      'errorCreatingProfileAlt': 'خطأ في إنشاء الملف الشخصي: {error}',
      'checkingLocationPermissions': 'جارٍ التحقق من أذونات الموقع...',
      'locationPermissionsRequired': 'أذونات الموقع مطلوبة لتحديث الموقع. يرجى تفعيل أذونات الموقع في إعدادات الجهاز',
      'locationServicesDisabled': 'خدمات الموقع معطلة. يرجى تفعيلها في إعدادات الجهاز',
      'locationServiceDisabledTitle': 'خدمات الموقع معطلة',
      'locationServiceDisabledMessage': 'خدمات الموقع في جهازك معطلة. خدمات الموقع ضرورية للتطبيق من أجل:\n\n• عرض الطلبات ذات الصلة في منطقتك\n• تمكينك من رؤية الطلبات على الخريطة\n• تصفية الطلبات حسب الموقع ونطاق التعرض\n• تلقي إشعارات حول طلبات جديدة في منطقتك\n• عرض موقعك على خرائط ناشري الطلبات\n\nإذا كان لديك موقع ثابت في ملفك الشخصي، فسيستمر في العمل حتى عند تعطيل خدمات الموقع.\n\nيرجى تفعيل خدمات الموقع في إعدادات الجهاز.',
      'enableLocationServiceTitle': 'تفعيل خدمات الموقع على الهاتف',
      'enableLocationServiceMessage': 'لاستخدام التصفية حسب الموقع المحمول، يجب عليك تفعيل خدمات الموقع على هاتفك.\n\nخدمات الموقع ضرورية من أجل:\n• الحصول على موقعك الحالي\n• تحديث الموقع تلقائياً\n• تصفية الطلبات حسب الموقع ونطاق التعرض\n• تلقي إشعارات حول طلبات جديدة في منطقتك',
      'enableLocationService': 'تفعيل خدمات الموقع',
      'gettingCurrentLocation': 'جارٍ الحصول على الموقع الحالي...',
      'savingLocationAndRadius': 'جارٍ حفظ الموقع ونطاق التعرض...',
      'fixedLocationAndRadiusUpdated': 'تم تحديث الموقع الثابت ونطاق التعرض بنجاح!',
      'noLocationSelected': 'لم يتم اختيار موقع',
      'deletingFixedLocation': 'حذف الموقع الثابت',
      'deleteFixedLocationQuestion': 'هل أنت متأكد من أنك تريد حذف الموقع الثابت?\n\nبعد الحذف، ستظهر في الخرائط فقط عندما تكون خدمة الموقع نشطة على هاتفك.',
      'deletingLocation': 'جارٍ حذف الموقع...',
      'fixedLocationDeletedSuccess': 'تم حذف الموقع الثابت بنجاح!',
      'errorDeletingLocation': 'خطأ في حذف الموقع: {error}',
      'shareApp': 'مشاركة التطبيق',
      'rateApp': 'تقييم التطبيق',
      'recommendToFriends': 'أوصِ بالأصدقاء',
      'rewards': 'المكافآت',
      'resetTutorialMessages': 'إعادة تعيين رسائل الدليل',
      'debugSwitchToFree': '🔧 التبديل إلى مجاني خاص',
      'debugSwitchToPersonal': '🔧 التبديل إلى اشتراك خاص',
      'debugSwitchToBusiness': '🔧 التبديل إلى اشتراك تجاري',
      'debugSwitchToGuest': '🔧 التبديل إلى ضيف',
      'contact': 'اتصل بنا',
      'deleteAccount': 'حذف الحساب',
      'update': 'تحديث',
      'firstNameLastName': 'الاسم الأول والعائلة/الشركة/المؤسسة/اللقب',
      'enterFirstNameLastName': 'أدخل الاسم الأول والعائلة/الشركة/المؤسسة/اللقب',
      'clickUpdateToChangeName': 'انقر على "تحديث" لتغيير الاسم. سيتم حفظ الاسم تلقائياً',
      'allBusinessFields': 'جميع مجالات العمل',
      'businessFields': 'مجالات العمل',
      'edit': 'تعديل',
      'noBusinessFieldsDefined': 'لم يتم تحديد مجالات العمل',
      'toReceiveNotifications': 'لتلقي إشعارات حول الطلبات ذات الصلة، يجب عليك اختيار ما يصل إلى مجالين للعمل:',
      'ifYouCheckThisOption': 'إذا قمت بتحديد هذا الخيار، يمكنك رؤية الطلبات المجانية فقط في شاشة الطلبات.',
      'monthlyRequests': 'الطلبات الشهرية',
      'publishedRequestsThisMonth': 'تم نشر {count} طلبات هذا الشهر (بدون حد)',
      'remainingRequestsThisMonth': 'لديك {count} طلبات متبقية للنشر هذا الشهر',
      'reachedMonthlyRequestLimit': 'لقد وصلت إلى حد الطلبات الشهرية',
      'wantMoreUpgradeSubscription': 'تريد المزيد؟ قم بترقية الاشتراك',
      'fixedLocation': 'الموقع الثابت',
      'updateLocationAndRadius': 'تحديث الموقع والنطاق',
      'adminCanUpdateLocation': 'المدير - يمكن تحديث الموقع مثل أي مستخدم آخر',
      'fixedLocationDefined': 'تم تحديد الموقع الثابت',
      'villageNotDefined': 'لم يتم تحديد القرية',
      'youWillAppearInRange': '✅ ستظهر في نطاق الطلبات المنشورة التي تناسب مجال عملك، حتى لو لم تكن خدمة الموقع نشطة على هاتفك',
      'deleteLocation': 'حذف الموقع',
      'noFixedLocationDefined': 'لم يتم تحديد موقع ثابت ونطاق تعرض',
      'asServiceProvider': 'كمزود خدمة، تحديد موقع ثابت ونطاق التعرض أمر ضروري:',
      'locationBenefits': '• ستتلقى إشعارات حول الطلبات ذات الصلة بمجال عملك\n• ستظهر في خرائط ناشري الطلبات ويمكنهم الاتصال بك\n• ستستمر خدمة الموقع الثابت في خدمتك حتى عندما تكون خدمة الموقع معطلة على هاتفك',
      'systemManagement': 'إدارة النظام',
      'manageInquiries': 'إدارة الاستفسارات',
      'manageGuests': 'إدارة الضيوف',
      'additionalInfo': 'معلومات إضافية',
      'joinDate': 'تاريخ الانضمام',
      'helpUsGrow': 'ساعدنا على النمو',
      'recommendAppToFriends': 'أوصِ بالتطبيق للأصدقاء واحصل على مكافآت!',
      'approved': '✅ معتمد',
      'subscriptionPendingApproval': '{type} قيد الموافقة',
      'waitingForAdminApproval': '⏳ في انتظار موافقة المدير',
      'rejected': 'مرفوض',
      'upgradeRequestRejected': '❌ تم رفض طلب الترقية',
      'privateFreeStatus': 'مجاني خاص',
      'freeAccessToFreeRequests': '🆓 الوصول إلى الطلبات المجانية',
      'errorLoadingData': 'خطأ في تحميل البيانات: {error}',
      'wazeNotInstalled': 'Waze غير مثبت على الجهاز',
      'errorOpeningWaze': 'خطأ في فتح Waze',
      'requestApprovalPending': 'طلب قيد الموافقة ⏳',
      'upgradeSubscriptionTitle': 'ترقية الاشتراك 🚀',
      'chooseSubscriptionType': 'اختر نوع الاشتراك:',
      'upgradeToBusiness': 'ترقية إلى اشتراك تجاري:',
      'noUpgradeOptionsAvailable': 'لا توجد خيارات ترقية متاحة',
      'privateFreeType': 'خاص (مجاني)',
      'privateFreeDescription': '• 1 طلب في الشهر\n• النطاق: 0-3 كم\n• يرى فقط الطلبات المجانية\n• بدون مجالات عمل',
      'upgrade': 'ترقية',
      'deleteAccountTitle': 'حذف الحساب',
      'deleteAccountConfirm': 'هل أنت متأكد من أنك تريد حذف حسابك؟',
      'thisActionWillDeletePermanently': 'سيحذف هذا الإجراء بشكل دائم:',
      'yourLoginCredentials': 'بيانات تسجيل الدخول الخاصة بك',
      'yourPersonalInfo': 'المعلومات الشخصية في الملف الشخصي',
      'allYourPublishedRequests': 'جميع الطلبات التي نشرتها',
      'allYourInterestedRequests': 'جميع الطلبات التي اهتممت بها',
      'allYourChats': 'جميع محادثاتك',
      'allYourMessages': 'جميع الرسائل التي أرسلتها واستلمتها',
      'allYourImages': 'جميع الصور والملفات',
      'allYourData': 'جميع البيانات والسجل',
      'thisActionCannotBeUndone': 'هذا الإجراء لا يمكن التراجع عنه!',
      'passwordConfirmation': 'تأكيد كلمة المرور',
      'passwordConfirmationMessage': 'لحذف الحساب، يرجى إدخال كلمة المرور الخاصة بك للتأكيد:',
      'passwordRequired': 'يرجى إدخال كلمة المرور',
      'thisActionWillDeleteAccountPermanently': 'سيحذف هذا الإجراء الحساب بشكل دائم!',
      'deletingAccount': 'جارٍ حذف الحساب...',
      'noUserFound': 'لم يتم العثور على مستخدم متصل',
      'accountDeletedSuccess': 'تم حذف الحساب بنجاح',
      'deletingAccountProgress': 'جارٍ حذف الحساب...',
      'deleteUser': 'حذف المستخدم',
      'googleUserDeleteTitle': 'حذف المستخدم',
      'loggedInWithGoogle': 'قمت بتسجيل الدخول عبر Google',
      'clickConfirmToDeletePermanently': 'انقر "تأكيد" لحذف الحساب بشكل دائم.\nهذا الإجراء لا يمكن التراجع عنه!',
      'contactScreenTitle': 'إنشاء اتصال',
      'contactScreenSubtitle': 'هل لديك أسئلة؟ شيء غير واضح؟ سنكون سعداء لسماعك',
      'contactOperatorInfo': 'يتم تشغيل تطبيق "حارتي" بواسطة "أكستريم تكنولوجيا" – شركة مسجلة قانونياً في إسرائيل. الدعم متاح أيضاً لطلبات الخصوصية وحذف الحساب.',
      'contactName': 'الاسم',
      'contactNameHint': 'أدخل اسمك',
      'contactNameRequired': 'يرجى إدخال اسمك',
      'contactEmail': 'البريد الإلكتروني',
      'contactEmailHint': 'أدخل عنوان بريدك الإلكتروني',
      'contactEmailRequired': 'يرجى إدخال عنوان البريد الإلكتروني',
      'contactEmailInvalid': 'يرجى إدخال عنوان بريد إلكتروني صالح',
      'contactMessage': 'الرسالة',
      'contactMessageHint': 'نص حر',
      'contactMessageRequired': 'يرجى إدخال رسالتك',
      'contactMessageTooShort': 'يرجى إدخال رسالة أكثر تفصيلاً (10 أحرف على الأقل)',
      'contactSend': 'إرسال',
      'contactSuccess': 'تم إرسال الاستفسار بنجاح! سنعود إليك قريباً',
      'contactError': 'خطأ في إرسال الاستفسار: {error}',
      'errorLoadingRating': 'خطأ في تحميل التقييم',
      'noRatingAvailable': 'لا يوجد تقييم متاح',
      'trialPeriodInfo': 'معلومات عن فترة التجربة الخاصة بك',
      'chatClosed': 'تم إغلاق المحادثة - لا يمكن إرسال الرسائل',
      'messageLimitReached': 'وصلت إلى حد 50 رسالة - لا يمكن إرسال المزيد من الرسائل',
      'messagesRemaining': 'تحذير: بقي {count} رسائل فقط',
      'loginMethod': 'طريقة تسجيل الدخول: {method}',
      'saveLoginCredentials': 'حفظ بيانات تسجيل الدخول',
      // הודעות נוספות מ-home_screen
      'confirmCancelInterest': 'تأكيد إلغاء الاهتمام',
      'requestLabel': 'طلب',
      'categoryLabel': 'مجال',
      'typeLabel': 'نوع',
      'paidType': 'مدفوع',
      'freeType': 'مجاني',
      'editBusinessCategories': 'تعديل مجالات العمل',
      'actionConfirmation': 'تأكيد الإجراء',
      'noNotificationsSelected': 'اخترت عدم تلقي إشعارات حول الطلبات الجديدة. هل تريد المتابعة؟',
      'no': 'لا',
      'yes': 'نعم',
      'errorGeneral': 'خطأ: {error}',
      'seeMoreSelectFields': 'أنت ترى الطلبات المدفوعة فقط من مجالات العمل التي اخترتها. لرؤية المزيد من الطلبات، اختر مجالات عمل إضافية في الملف الشخصي.',
      'trialPeriodEnded': 'انتهت فترة التجربة',
      'afterUpdateCanContact': 'بعد تحديث الملف الشخصي، يمكنك التواصل مع الناشرين من خلال التفاصيل المعروضة في الطلب.',
      'businessFieldsNotMatch': 'مجالات العمل غير متطابقة',
      'requestFromCategory': 'هذا الطلب من مجال "{category}" ولا يطابق مجالات عملك.',
      'updateBusinessFieldsHint': 'إذا كنت تريد الاتصال بمنشئ الطلب، يجب عليك تحديث مجالات عملك في الملف الشخصي لتطابق فئة الطلب.',
      'updateBusinessFields': 'تعديل مجالات العمل',
      'updateBusinessFieldsTitle': 'تحديث مجالات العمل',
      'cancelInterest': 'إلغاء الاهتمام',
      'confirm': 'تأكيد',
      // הודעות נוספות
      'afterCancelNoChat': 'بعد الإلغاء، لن تتمكن من رؤية المحادثة مع منشئ الطلب.',
      'yesCancelInterest': 'نعم، إلغاء الاهتمام',
      'requestFromField': 'هذا الطلب في مجال "{category}".',
      'updateFieldsToContact': 'إذا كنت تقدم خدمات في هذا المجال، يجب عليك أولاً تحديث مجالات العمل في ملفك الشخصي ثم يمكنك الاتصال بمنشئ الطلب.',
      'confirmAction': 'تأكيد الإجراء',
      'selectedNoNotifications': 'اخترت عدم تلقي إشعارات حول الطلبات الجديدة. هل تريد المتابعة؟',
      'notificationPermissionRequiredForFilter': 'يجب عليك الموافقة على تلقي الإشعارات لتلقي إشعارات حول طلبات جديدة.\n\nإذا لم توافق، فلن تتلقى إشعارات حول طلبات جديدة.',
      'continue': 'متابعة',
      'loadingRequestsError': 'خطأ في تحميل الطلبات',
      // טקסטים נוספים ממסך הבית
      'requestsFromAdvertisers': 'حارتي الذكية',
      'allRequests': 'جميع الطلبات',
      'serviceProviders': 'مقدمو الخدمات',
      'advancedFilter': 'تصفية الطلبات',
      'goToAllRequests': 'انتقل إلى جميع الطلبات',
      'filterSaved': 'تم حفظ التصفية',
      'saveFilter': 'احفظ التصفية',
      'savedFilter': 'تصفية محفوظة',
      'savedFilterFound': 'تم العثور على تصفية محفوظة من المرة السابقة. هل تريد استعادتها؟',
      'allTypes': 'جميع الأنواع',
      'allSubCategories': 'جميع الفئات الفرعية',
      // טקסטים ממסך סינון בקשות
      'urgency': 'الأولوية',
      'normal': 'عادي',
      'within24Hours': 'خلال 24 ساعة',
      'within24HoursAndNow': 'خلال 24 ساعة وأيضاً الآن',
      'requestRange': 'نطاق طلباتك',
      'km': 'كم',
      'filterByFixedLocation': 'فلترة الطلبات حسب موقعي الثابت ونطاق التعرض الذي حددته في ملفي الشخصي',
      'mustDefineFixedLocation': 'يجب عليك تحديد موقع ثابت ونطاق تعرض في الملف الشخصي أولاً',
      'filterByMobileLocation': 'فلترة الطلبات حسب موقعي المحمول ونطاق التعرض الخاص بي (أثناء الحركة)',
      'selectRange': 'اختر النطاق',
      'setLocationAndRange': 'انقر لاختيار موقع ونطاق تعرض إضافيين',
      'kmFromSelectedLocation': '{distance} كم من الموقع المحدد على الخريطة',
      'kmFromMobileLocation': '{distance} كم من الموقع المحمول',
      'kmFromFixedLocation': '{distance} كم من الموقع الثابت',
      'receiveNotificationsForNewRequests': 'تلقي إشعارات حول طلبات جديدة متطابقة مع المواقع والنطاق الذي حددته',
      'noPaidServicesMessage': 'لقد حددت أنك لا تقدم خدمات مدفوعة - يمكنك رؤية الطلبات المجانية فقط',
      'showToProvidersOutsideRange': 'حسب الموقع الذي اخترته، طلبك موجود في منطقة {region}، هل أنت مهتم بأن يظهر طلبك لدى جميع مقدمي الخدمة من مجال {category} في منطقة {region}؟',
      'yesAllProvidersInRegion': 'نعم، جميع مقدمي الخدمة في منطقة {region}',
      'noOnlyInRange': 'لا، فقط في النطاق الذي حددته',
      'showToAllUsersOrProviders': 'هل أنت مهتم بأن يظهر هذا الطلب لجميع مقدمي الخدمة من جميع المجالات في التطبيق أم فقط لمقدمي الخدمة من مجال {category} الذي اخترته؟',
      'yesToAllUsers': 'نعم لجميع مقدمي الخدمة من جميع المجالات',
      'onlyToProvidersInCategory': 'فقط لمقدمي الخدمة من مجال {category}',
      'northRegion': 'شمال',
      'centerRegion': 'وسط',
      'southRegion': 'جنوب',
      'mainCategory': 'الفئة الرئيسية',
      'subCategory': 'الفئة الفرعية',
      // טקסטים ממסך בקשה חדשה
      'selectCategory': 'اختيار الفئة',
      'pleaseSelectCategoryFirst': 'يرجى اختيار المجال أولاً',
      'title': 'عنوان الطلب',
      'enterTitle': 'يرجى إدخال العنوان',
      'description': 'الوصف',
      'enterDescription': 'يرجى إدخال الوصف',
      'urgencyLevel': 'مستوى الأولوية',
      'normalUrgency': 'عادي',
      'within24HoursUrgency': 'خلال 24 ساعة',
      'nowUrgency': 'الآن',
      'imagesForRequest': 'صور للطلب',
      'youCanAddImages': 'يمكنك إضافة صور تساعد على فهم الطلب بشكل أفضل',
      'limit5Images': 'حد 5 صور',
      'selectImages': 'اختر الصور',
      'takePhoto': 'التقاط صورة',
      'selectedImagesCount': 'تم اختيار {count} صور',
      'enterFullPrefixAndNumber': 'أدخل البادئة والرقم الكامل',
      'invalidPhoneNumber': 'رقم الهاتف غير صحيح',
      'invalidPrefix': 'البادئة غير صالحة',
      'freeRequestsDescription': 'الطلبات المجانية: يمكن لجميع أنواع المستخدمين المساعدة (بدون قيود على الفئة)',
      'paidRequestsDescription': 'الطلبات المدفوعة: يمكن للمستخدمين ذوي الفئات المناسبة فقط المساعدة',
      'permissionRequiredImages': 'مطلوب إذن الوصول للصور',
      'permissionRequiredCamera': 'مطلوب إذن الوصول للكاميرا',
      'errorSelectingImages': 'خطأ في اختيار الصور',
      'errorTakingPhoto': 'خطأ في التقاط الصورة',
      'errorUploadingImages': 'خطأ في رفع الصور',
      'imageAddedSuccessfully': 'تمت إضافة الصورة بنجاح',
      'cannotAddMoreThan5Images': 'لا يمكن إضافة أكثر من 5 صور',
      'alreadyHas5Images': 'يوجد بالفعل 5 صور. احذف الصور لإضافة صور جديدة.',
      'addedImagesCount': 'تمت إضافة {count} صور',
      'multiplePhotoCapture': 'التقاط صور متعددة',
      'clickOkToCapture': 'اضغط "موافق" للتقاط صورة أخرى',
      'shareNow': 'شارك الآن',
      'pleaseSelectCategory': 'يرجى اختيار فئة للطلب',
      'pleaseSelectLocation': 'يرجى اختيار موقع للطلب',
      'creatingRequest': 'جارٍ إنشاء الطلب...',
      'requestLimits': 'قيود الطلبات الخاصة بك',
      'maxRequestsPerMonth': 'الحد الأقصى للطلبات شهرياً: {max}',
      'maxSearchRange': 'نطاق البحث الأقصى: {radius} كم',
      'newRequestTutorialTitle': 'إنشاء طلب جديد',
      'newRequestTutorialMessage': 'هنا يمكنك إنشاء طلب جديد والحصول على المساعدة من المجتمع. اكتب وصفاً واضحاً، اختر فئة، حدد موقعاً ونطاق التعرض (حسب نوع المستخدم الخاص بك)، ونشر الطلب.',
      'writeRequestDescription': 'كتابة وصف الطلب',
      'selectAppropriateCategory': 'اختيار فئة مناسبة',
      'selectLocationAndExposure': 'اختيار الموقع ونطاق التعرض',
      'setPriceFreeOrPaid': 'تحديد السعر (مجاني أو مدفوع)',
      'publishRequest': 'نشر الطلب',
      'locationInfoTitle': 'معلومات حول اختيار الموقع',
      'howToSelectLocation': 'كيفية اختيار موقع صحيح:',
      'selectLocationInstructions': '📍 اختر موقعاً دقيقاً قدر الإمكان\n🎯 سيحدد النطاق عدد الأشخاص الذين سيرون الطلب\n📱 استخدم الخريطة لاختيار الموقع الدقيق',
      'locationSelectionTips': 'نصائح لاختيار الموقع:',
      'locationSelectionTipsDetails': '🏠 اختر العنوان الدقيق\n🚗 إذا كان في الشارع، اختر الجانب الصحيح\n🏢 إذا كان في مبنى، اختر المدخل الرئيسي\n📍 استخدم البحث عن العنوان للدقة القصوى\n📏 الحد الأدنى للنطاق هو 0.1 كم',
      
      // Tutorial Center - Categories
      'tutorialCategoryHome': 'الشاشة الرئيسية',
      'tutorialCategoryRequests': 'الطلبات',
      'tutorialCategoryChat': 'الدردشة',
      'tutorialCategoryProfile': 'الملف الشخصي',
      'tutorialTutorialsAvailable': '{count} دروس متاحة',
      
      // Tutorial Center - Home Screen
      'tutorialHomeBasicsTitle': 'محتوى الشاشة الرئيسية',
      'tutorialHomeBasicsDescription': 'تعلم كيفية التنقل في الشاشة الرئيسية واستخدام الوظائف الأساسية',
      'tutorialHomeBasicsContent': '''أساسيات الشاشة الرئيسية

ما ستجده في الشاشة الرئيسية:
• قائمة الطلبات - جميع الطلبات المتاحة في المجتمع
• البحث - ابحث عن الطلبات باستخدام الكلمات المفتاحية
• التصفية - صفّ الطلبات حسب الفئة والموقع
• طلبات قيد المعالجة - الطلبات التي نشرتها أو تقدمت إليها

كيفية الاستخدام:
1. لعرض طلب - اضغط على طلب من القائمة
2. للبحث - استخدم شريط البحث العلوي
3. للتصفية - اضغط على زر "تصفية الطلبات"
4. لطلبات قيد المعالجة - اضغط على "طلبات قيد المعالجة"''',
      
      'tutorialHomeSearchTitle': 'البحث والتصفية',
      'tutorialHomeSearchDescription': 'كيفية العثور على طلبات محددة بسرعة',
      'tutorialHomeSearchContent': '''البحث والتصفية

البحث:
• الكلمات المفتاحية - أدخل كلمات ذات صلة
• البحث في الوقت الفعلي - النتائج تتحدث أثناء الكتابة
• البحث في جميع الحقول - الاسم، الوصف، الفئة

تصفية الطلبات:
• نوع الطلب - مجاني أو مدفوع
• الفئات - اختر مجالات عمل محددة
• الاستعجال - عادي، عاجل (24 ساعة)، عاجل جداً (الآن)
• الموقع والنطاق - ابحث بالقرب من مكان معين (موقع محمول أو ثابت)
• نطاق التعرض - حدد نطاق بالكيلومترات

نطاقات التعرض في التصفية:
النطاق الأقصى في التصفية يعتمد على نوع المستخدم الخاص بك:
• الضيف: حتى 5 كم
• شخصي مجاني: حتى 3 كم
• شخصي مشترك: حتى 5 كم
• تجاري مشترك: حتى 8 كم

ملاحظة: النطاقات ثابتة ولا تتغير حسب التوصيات أو التقييمات.

نصائح:
• استخدم كلمات مفتاحية قصيرة وواضحة
• جرب عمليات بحث مختلفة لنفس الطلب
• اختر نطاق تعرض يناسب مكانك
• احفظ التصفيات المفضلة''',
      
      // Tutorial Center - Requests
      'tutorialCreateRequestTitle': 'إنشاء طلب جديد',
      'tutorialCreateRequestDescription': 'كيفية إنشاء طلب للمساعدة أو الخدمة',
      'tutorialCreateRequestContent': '''إنشاء طلب جديد

خطوات إنشاء طلب:
1. اضغط على + - في الزاوية اليمنى السفلية
2. اختر فئة - مجال العمل المناسب
3. اكتب وصفاً - اشرح ما تحتاجه
4. حدد السعر - إذا كان مناسباً (مجاني أو مدفوع)
5. اختر الموقع - أين أنت
6. حدد نطاق التعرض - كم كيلومتر من موقعك (حسب نوع المستخدم الخاص بك)
7. انشر - أرسل الطلب إلى المجتمع

نطاقات التعرض حسب نوع المستخدم:
• الضيف: حتى 5 كم
• شخصي مجاني: حتى 3 كم
• شخصي مشترك: حتى 5 كم
• تجاري مشترك: حتى 8 كم

ملاحظة: النطاقات ثابتة ولا تتغير حسب التوصيات أو التقييمات.

نصائح للكتابة الجيدة:
• وصف واضح - اشرح بالضبط ما تحتاجه
• تفاصيل مهمة - الوقت، المكان، الاستعجال
• صورة - أضف صورة إذا كانت تساعد في الشرح
• سعر عادل - اقترح سعراً معقولاً أو اختر "مجاني"
• نطاق التعرض - اختر نطاقاً يناسب موقعك ونوع الطلب

القيود حسب نوع المستخدم:
• شخصي مجاني: طلب واحد في الشهر
• شخصي مشترك: 5 طلبات في الشهر
• تجاري مشترك: 10 طلبات في الشهر

مثال جيد:
"أحتاج مساعدة في نقل الأثاث من شقة إلى شقة في القدس.
هناك 3 خزائن، طاولتان وأسرّة.
مستعد للدفع 200-300 شيكل.
الموعد: نهاية الأسبوع القادم."''',
      
      'tutorialManageRequestsTitle': 'إدارة الطلبات',
      'tutorialManageRequestsDescription': 'كيفية إدارة طلباتك',
      'tutorialManageRequestsContent': '''إدارة الطلبات

الطلبات التي نشرتها:
• عرض الطلبات - انظر من تقدم إليك
• تعديل طلب - حدّث التفاصيل أو السعر
• إغلاق طلب - عند تلقي المساعدة
• حذف طلب - إذا لم يعد مناسباً

طلبات قيد المعالجة (التي تقدمت إليها):
• متابعة الحالة - انظر إذا تم قبولك
• الدردشة مع الناشر - اتصال مباشر
• إلغاء الطلب - إذا غيرت رأيك

نصائح للإدارة:
• حدّث الحالة - حدّد عند اكتمال الطلب
• تواصل في الدردشة - اسأل أسئلة قبل الالتزام
• تحقق من الملفات الشخصية - انظر تقييمات مقدمي الخدمة
• كن مهذباً - رد في الوقت المناسب وباحترام''',
      
      // Tutorial Center - Chat
      'tutorialChatBasicsTitle': 'محتوى الدردشة',
      'tutorialChatBasicsDescription': 'كيفية استخدام نظام الدردشة',
      'tutorialChatBasicsContent': '''أساسيات الدردشة

كيفية الدخول إلى الدردشة:
1. من طلب نشرته - اضغط على "دردشة" بجانب الطلب
2. من طلب تقدمت إليه - اضغط على "دردشة" في الطلب
3. من شاشة "طلبات قيد المعالجة" - اضغط على زر الدردشة

وظائف الدردشة:
• إرسال الرسائل - نص ورسائل صوتية
• تعديل الرسائل - اضغط مطولاً على رسالة أرسلتها
• حذف الرسائل - اضغط مطولاً واختر "حذف"
• إغلاق الدردشة - إذا لم تعد تريد التواصل

علامات القراءة:
• علامة واحدة - تم إرسال الرسالة
• علامتان - تم قراءة الرسالة من قبل المستلم
• علامة متوهجة - تم قراءة الرسالة مؤخراً

قواعد السلوك:
• كن مهذباً - استخدم لغة مناسبة
• رد في الوقت المناسب - لا تترك رسائل بدون رد
• كن واضحاً - اشرح بالضبط ما تحتاجه
• احافظ على الخصوصية - لا تنقل معلومات شخصية''',
      
      'tutorialChatAdvancedTitle': 'وظائف متقدمة',
      'tutorialChatAdvancedDescription': 'وظائف متقدمة للدردشة',
      'tutorialChatAdvancedContent': '''وظائف متقدمة

تعديل الرسائل:
1. اضغط مطولاً على رسالة أرسلتها
2. اختر "تعديل" من القائمة
3. عدّل النص واحفظ
4. ستُعلّم الرسالة كـ"معدّلة"

حذف الرسائل:
1. اضغط مطولاً على رسالة أرسلتها
2. اختر "حذف" من القائمة
3. أكد الحذف4. ستُحذف الرسالة نهائياً

إغلاق الدردشة:
• متى تُغلق - عندما لا تريد التواصل بعد الآن
• كيف تُغلق - القائمة (3 نقاط) > "إغلاق الدردشة"
• إعادة الفتح - يمكن إعادة فتح دردشة مغلقة
• رسالة النظام - سيتم إرسال رسالة عن إغلاق الدردشة

تنظيف الدردشة:
• حذف السجل - القائمة > "نظف الدردشة"
• التأثير - يحذف جميع الرسائل
• لا يمكن الاسترجاع - عملية نهائية''',
      
      // Tutorial Center - Profile
      'tutorialProfileSetupTitle': 'إعداد الملف الشخصي',
      'tutorialProfileSetupDescription': 'كيفية إعداد ملفك الشخصي',
      'tutorialProfileSetupContent': '''إعداد الملف الشخصي

المعلومات الأساسية:
• الاسم - اسمك (إلزامي)
• البريد الإلكتروني - عنوان البريد الإلكتروني (إلزامي)
• الصورة - صورة الملف الشخصي (اختياري)
• الموقع - أين أنت (إلزامي)
• نطاق التعرض - كم كيلومتر من موقعك (حسب نوع المستخدم)

نطاقات التعرض في الملف الشخصي:
• الضيف: حتى 5 كم
• شخصي مجاني: حتى 3 كم
• شخصي مشترك: حتى 5 كم
• تجاري مشترك: حتى 8 كم

ملاحظة: إعداد موقع ثابت ونطاق تعرض مسموح فقط للمستخدمين: الضيف، تجاري مشترك.

معلومات تجارية (للمشتركين التجاريين):
• مجالات العمل - اختر عدد مجالات العمل التي تريدها (تجاري مشترك فقط)
• الوصف - اشرح خدماتك
• الأسعار - قائمة أسعار عامة
• التوفر - متى تكون متاحاً

إعدادات الخصوصية:
• رقم الهاتف - إذا كنت تريد عرضه
• عرض الهاتف - الموافقة على العرض على الخريطة (للمشتركين التجاريين فقط)
• إعدادات الإشعارات - أي إشعارات تتلقى

تمديد فترة التجربة (مستخدمو الضيف):
إذا كنت مستخدم ضيف، يمكنك تمديد فترة التجربة لمدة أسبوعين من خلال:
1. مشاركة التطبيق مع 5 أصدقاء (WhatsApp، SMS، Email)
2. تقييم التطبيق في المتجر 5 نجوم
3. نشر طلب جديد في أي مجال تريده

يجب تنفيذ جميع الإجراءات خلال ساعة واحدة من بداية العملية.

نصائح لملف شخصي جيد:
• صورة احترافية - صورة واضحة وممتعة
• وصف مفصل - اشرح ما تقدمه
• معلومات صحيحة - لا تكتب أشياء غير صحيحة
• تحديث منتظم - حدّث المعلومات عند التغيير
• موقع دقيق - حدّث الموقع للحصول على عروض ذات صلة''',
      
      'tutorialSubscriptionTitle': 'الاشتراكات والمدفوعات',
      'tutorialSubscriptionDescription': 'كيفية إدارة الاشتراك والمدفوعات',
      'tutorialSubscriptionContent': '''الاشتراكات والمدفوعات

أنواع المستخدمين والاشتراكات:
• الضيف - وصول أساسي بدون دفع
• شخصي مجاني - وصول أساسي بدون دفع
• شخصي مشترك - وظائف متقدمة (30₪ سنوياً)
• تجاري مشترك - نشر الخدمات (70₪ سنوياً)

ما هو متضمن في كل نوع:

الضيف:
• نطاق التعرض: 5 كم
• عرض الطلبات المجانية
• التقدم للطلبات (محدود)
• دردشة أساسية
• إمكانية تمديد فترة التجربة بإجراءات خاصة

شخصي مجاني:
• نطاق التعرض: 3 كم
• عرض الطلبات المجانية
• التقدم للطلبات (طلب واحد في الشهر)
• دردشة أساسية

شخصي مشترك (30₪ سنوياً):
• نطاق التعرض: 5 كم
• كل ما في الشخصي المجاني +
• نشر الطلبات (5 طلبات في الشهر)
• عرض فقط الطلبات المجانية
• بدون مجالات عمل

تجاري مشترك (70₪ سنوياً):
• نطاق التعرض: 8 كم
• كل ما في الشخصي المشترك +
• نشر الطلبات (10 طلبات في الشهر)
• عرض الطلبات المجانية والمدفوعة
• اختيار مجالات العمل (بدون قيود)
• الظهور على خريطة مقدمي الخدمة
• تقييمات مفصلة

ملاحظات مهمة:
• نطاقات التعرض الثابتة - كل نوع مستخدم يحصل على نطاق أقصى ثابت
• لا توجد مكافآت - النطاقات لا تتغير حسب التوصيات أو التقييمات
• فترة التجربة للضيوف - يمكن لمستخدمي الضيف تمديد فترة التجربة بإجراءات خاصة
• الدفع السنوي - تُدفع الاشتراكات مرة في السنة

المدفوعات:
• وسائل الدفع - BIT (PayMe)، بطاقة ائتمان (PayMe)
• الدفع السنوي - لمرة واحدة في السنة
• التفعيل التلقائي - يتم تفعيل الاشتراك تلقائياً بعد الدفع
• الدعم - اتصل بالدعم إذا كانت هناك مشكلة''',
      
      // Tutorial Center - General
      'tutorialMarkedAsRead': 'تم تعليم الدرس كمقروء',
      'tutorialClose': 'إغلاق',
      'tutorialRead': 'قرأت',
      'selectMainCategoryThenSub': 'اختر الفئة الرئيسية ثم الفئة الفرعية',
      'selectSubCategoriesUpTo': 'اختر الفئات الفرعية (حتى {max} من جميع الفئات):',
      'clearSelection': 'مسح الاختيار',
      'prefix': 'البادئة',
      'phoneNumberLabel': 'رقم الهاتف',
      'selectLocation': 'اختر الموقع',
      'selectDeadlineOptional': 'اختر تاريخ انتهاء الطلب (اختياري)',
      'price': 'السعر',
      'optional': 'اختياري',
      'willingToPay': 'مستعد للدفع',
      'howMuchWillingToPay': '(اختياري) كم أنت مستعد للدفع؟',
      'upToOneMonth': 'حتى شهر من اليوم',
      // טקסטים ממסך בחירת מיקום
      'selectLocationTitle': 'اختيار الموقع',
      'currentLocation': 'الموقع الحالي',
      'gettingLocation': 'جاري الحصول على الموقع...',
      'exposureCircle': 'دائرة التعرض',
      'kilometers': 'كيلومترات',
      'dragSliderToChange': 'اسحب المنزلق لتغيير حجم دائرة التعرض',
      'maxRangeWithBonuses': 'النطاق الأقصى: {radius} كم (بما في ذلك المكافآت)',
      'notificationsWillBeSent': 'سيتم إرسال الإشعارات فقط للمستخدمين الذين يكون موقع التصفية الخاص بهم داخل إسرائيل وفي النطاق',
      'selectedLocation': 'الموقع المحدد',
      'selectedLocationLabel': 'الموقع المحدد:',
      // טקסטים ממסך בקשות שלי
      'statusOpen': 'مفتوح',
      'statusCompleted': 'تم معالجة الطلب',
      'statusCancelled': 'ملغي',
      'statusInProgress': 'قيد المعالجة',
      'mapOfRelevantHelpers': 'خريطة مقدمي الخدمات ذات الصلة',
      'helpersInRange': 'هناك {count} مقدمي خدمات مناسبين ضمن نطاق {radius} كم',
      'updatesEvery30Seconds': 'يتم التحديث كل 10 ثواني',
      'yourRequestLocation': 'موقع طلبك',
      'subscribedHelpers': 'مقدمو الخدمات المشتركون',
      'chatWith': 'محادثة مع {name}',
      'chatClosedWith': 'محادثة مغلقة مع {name}',
      'markAsCompleted': 'ضع علامة كتم التعامل معه',
      'cancelCompleted': 'فتح الطلب من جديد',
      'mapAvailableOnly': 'الخريطة متاحة فقط للطلبات المدفوعة',
      'goToSeeSubscribedHelpers': 'انتقل لرؤية مقدمي الخدمات المشتركين في المنطقة',
      'rangeKm': 'النطاق: {radius} كم',
      'helpers': 'المساعدون',
      'helpersCount': 'المساعدون: {count}',
      'likes': 'الإعجابات',
      'likesCount': 'الإعجابات: {count}',
      'deadlineLabel': 'تاريخ انتهاء الطلب',
      'deadlineExpired': 'تاريخ انتهاء الطلب: منتهي الصلاحية',
      'deadlineDate': 'تاريخ انتهاء الطلب: {date}',
      'helpersWhoShowedInterest': 'المساعدون الذين أبدوا اهتماماً:',
      'noHelpersAvailable': 'لا يوجد مساعدون متاحون',
      // טקסטים ממסך בית
      'requestWithoutPhone': 'طلب بدون رقم هاتف',
      'deadlineDateHome': 'تاريخ انتهاء الطلب: {date}',
      'interestedCallers': '{count} متصلين معنيين',
      'publishedBy': 'نشر بواسطة: {name}',
      'publishedByUser': 'نشر بواسطة: مستخدم',
      'iAmInterested': 'أنا معني',
      'iAmNotInterested': 'أنا لست معنياً',
      'clickIAmInterestedToShowPhone': 'اضغط "أنا معني" لعرض رقم الهاتف',
      // טקסטים נוספים ממסך פניות שלי
      'chatButton': 'محادثة',
      'chatClosedButton': 'محادثة مغلقة',
      'request': 'طلب',
      'helloIAm': 'مرحباً! أنا {name}{badge}',
      'newInField': 'من مجال {category}',
      'interestedInHelping': 'أنا مهتم بمساعدتك في طلبك. كيف يمكنني المساعدة؟',
      'canSendUpTo50Messages': 'يمكن إرسال ما يصل إلى 50 رسالة في هذه المحادثة. الرسائل النظامية لا تُحسب ضمن الحد.',
      // Chat screen messages
      'loadingMessages': 'جاري تحميل الرسائل...',
      'errorLoadingMessages': 'خطأ: {error}',
      'messageDeleted': 'تم حذف الرسالة',
      'messageDeletedSuccessfully': 'تم حذف الرسالة بنجاح',
      'errorDeletingMessage': 'خطأ في حذف الرسالة',
      'chatClosedCannotSend': 'تم إغلاق المحادثة - لا يمكن إرسال الرسائل',
      'closeChat': 'إغلاق المحادثة',
      'closeChatTitle': 'إغلاق المحادثة',
      'closeChatMessage': 'هل أنت متأكد من أنك تريد إغلاق المحادثة؟ بعد الإغلاق لن تتمكن من إرسال رسائل إضافية.',
      'reopenChat': 'إعادة فتح المحادثة',
      'chatClosedBy': 'تم إغلاق المحادثة بواسطة {name}. لا يمكن إرسال رسائل إضافية.',
      'chatClosedStatus': 'تم إغلاق المحادثة',
      'chatClosedSuccessfully': 'تم إغلاق المحادثة بنجاح',
      'chatReopened': 'تم إعادة فتح المحادثة',
      'chatReopenedBy': 'تم إعادة فتح المحادثة بواسطة {name}.',
      'errorClosingChat': 'خطأ في إغلاق المحادثة',
      // Splash screen
      'initializing': 'جاري التهيئة...',
      'ready': 'جاهز!',
      'errorInitialization': 'خطأ في التهيئة: {error}',
      'strongNeighborhoodInAction': 'حارة قوية وذكية',
      // Voice messages
      'recording': 'جاري التسجيل...',
      'errorLoadingVoiceMessage': 'خطأ في تحميل الرسالة الصوتية: {error}',
      // Trial extension
      'guestPeriodExtendedTwoWeeks': 'تم تمديد فترة الضيف لمدة أسبوعين! 🎉',
      'thankYouForActions': 'شكراً على الإجراءات التي قمت بها. تم تمديد فترة الضيف لمدة 14 يوماً إضافية.',
      // My Requests Screen
      'fullScreenMap': 'خريطة - شاشة كاملة',
      'fixedLocationClickForDetails': 'موقع ثابت - انقر للحصول على التفاصيل الكاملة',
      'mobileLocationClickForDetails': 'موقع متنقل - انقر للحصول على التفاصيل الكاملة',
      'overallRating': 'التقييم العام: {rating}',
      'ratings': 'التقييمات:',
      'reliabilityLabel': 'الموثوقية',
      'availabilityLabel': 'التوفر',
      'attitudeLabel': 'السلوك',
      'fairPriceLabel': 'السعر العادل',
      'navigateToServiceProvider': 'انتقل إلى موقع مقدم الخدمة',
      'phone': 'الهاتف: {phone}',
      'cannotCallNumber': 'لا يمكن الاتصال بالرقم: {phone}',
      'errorCalling': 'خطأ في الاتصال: {error}',
      'loadingRequests': 'جاري تحميل الطلبات...',
      'errorLoading': 'خطأ: {error}',
      'openFullScreen': 'افتح الشاشة الكاملة',
      'refreshMap': 'تحديث الخريطة',
      'minimalRatings': 'التقييمات الدنيا:',
      'generalRating': 'عام: {rating}+',
      'reliabilityRating': 'الموثوقية: {rating}+',
      'availabilityRating': 'التوفر: {rating}+',
      'attitudeRating': 'السلوك: {rating}+',
      'priceRating': 'السعر: {rating}+',
      'helper': 'مساعد',
      'chatReopenedCanSend': 'تم إعادة فتح الدردشة - يمكن إرسال الرسائل',
      'requestReopenedChatsReopened': 'تم إعادة فتح الطلب والدردشات',
      'deleteRequestTitle': 'حذف الطلب',
      'deleteRequestConfirm': 'هل أنت متأكد من أنك تريد حذف هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.',
      'requestDeletedSuccess': 'تم حذف الطلب بنجاح',
      'errorDeletingRequest': 'خطأ في حذف الطلب: {error}',
      'deletedImagesFromStorage': 'تم حذف {count} صورة من التخزين',
      'errorDeletingImages': 'خطأ في حذف الصور: {error}',
      'errorOpeningChat': 'خطأ في فتح الدردشة: {error}',
      // Home Screen
      'businessNoSubscription': 'تجاري بدون اشتراك',
      'admin': 'مدير',
      'rangeInfo': 'معلومات عن نطاقك',
      'currentRange': 'النطاق الحالي: {radius} كم',
      'subscriptionType': 'نوع الاشتراك: {type}',
      'baseRange': 'النطاق الأساسي: {radius} كم',
      'bonuses': 'المكافآت: +{bonus} كم',
      'bonusDetails': 'تفاصيل المكافآت:',
      'howToImproveRange': 'كيفية تحسين النطاق:',
      'recommendAppBonus': '🎉 أوصِ بالتطبيق للأصدقاء (+0.2 كم لكل توصية)',
      'getHighRatingsBonus': '⭐ احصل على تقييمات عالية (+0.5-1.5 كم)',
      'subscriptionRequired': 'اشتراك مطلوب',
      'subscriptionRequiredMessage': 'لمشاهدة الطلبات المدفوعة، يرجى تفعيل اشتراكك',
      'businessFieldsRequired': 'مجالات العمل مطلوبة',
      'businessFieldsRequiredMessage': 'لمشاهدة الطلبات المدفوعة، يرجى اختيار مجالات العمل في الملف الشخصي',
      'categoryRestriction': 'تقييد الفئة',
      'categoryRestrictionMessage': 'مجال العمل "{category}" الذي اخترته ليس من مجالات عملك. إذا كنت تريد رؤية الطلبات المدفوعة في هذه الفئة، قم بتحديث مجالات عملك في الملف الشخصي.',
      'reachedEndOfList': 'وصلت إلى نهاية القائمة',
      'noMoreRequestsAvailable': 'لا توجد طلبات متاحة أخرى',
      // Profile Screen
      'completeYourProfile': 'أكمل ملفك الشخصي',
      'completeProfileMessage': 'للحصول على مساعدة أفضل، يُنصح بإكمال التفاصيل في ملفك الشخصي: صورة، وصف قصير، موقع ونطاق التعرض. النطاق الأقصى يعتمد على نوع المستخدم الخاص بك.',
      'whatYouCanDo': 'ما يمكنك فعله:',
      'uploadProfilePicture': 'تحميل صورة الملف الشخصي',
      'updatePersonalDetails': 'تحديث التفاصيل الشخصية',
      'updateLocationAndExposureRange': 'تحديث الموقع ونطاق التعرض',
      'selectSubscriptionTypeIfRelevant': 'اختيار نوع الاشتراك (إن كان ذا صلة)',
      'errorUploadingImage': 'خطأ في تحميل الصورة',
      'noPermissionToUpload': 'لا يوجد إذن لتحميل الصور. يرجى الاتصال بمدير النظام.',
      'networkError': 'خطأ في الشبكة. يرجى التحقق من الاتصال بالإنترنت.',
      'errorStoringImage': 'خطأ في تخزين الصورة. يرجى المحاولة مرة أخرى.',
      'user': 'مستخدم',
      'errorUpdatingLocation': 'خطأ في تحديث الموقع',
      'errorLocationPermissions': 'خطأ في أذونات الموقع. يرجى التحقق من الإعدادات',
      'errorNetworkLocation': 'خطأ في الشبكة. يرجى التحقق من الاتصال بالإنترنت',
      'timeoutError': 'انتهت المهلة. يرجى المحاولة مرة أخرى',
      'deleteFixedLocationTitle': 'حذف الموقع الثابت',
      'deleteFixedLocationMessage': 'هل أنت متأكد من أنك تريد حذف الموقع الثابت?\n\nبعد الحذف، ستظهر في الخرائط فقط عندما تكون خدمة الموقع نشطة على هاتفك.',
      'selectUpToTwoFields': 'للحصول على إشعارات حول الطلبات ذات الصلة، يجب عليك اختيار ما يصل إلى مجالين للعمل:',
      'onlyFreeRequestsMessage': 'إذا قمت بتحديد هذا الخيار، ستتمكن من رؤية الطلبات المجانية فقط في شاشة الطلبات.',
      // Payment request messages
      'paymentRequestSentSuccessfully': 'تم إرسال طلب الدفع بنجاح، سنتحقق من طلبك قريباً!',
      'errorSendingPaymentRequest': 'خطأ في إرسال طلب الدفع. يرجى المحاولة مرة أخرى لاحقاً.',
      'accountDeletedSuccessfully': 'تم حذف الحساب بنجاح',
      'errorLoggingOutMessage': 'خطأ في تسجيل الخروج: {error}',
      'systemAdminCannotChangeSubscription': 'لا يمكن لمدير النظام تغيير نوع الاشتراك',
      'pendingRequestExists': 'لديك طلب قيد الانتظار للموافقة. لا يمكن إرسال طلب إضافي.',
      'providerFilterSaved': 'تم حفظ فلتر مقدمي الخدمة',
      'errorDeletingUsers': 'خطأ في حذف المستخدمين: {error}',
      'requestsDeletedSuccessfully': 'تم حذف {count} طلبات بنجاح',
      'errorDeletingRequests': 'خطأ في حذف الطلبات: {error}',
      'documentsDeletedSuccessfully': 'تم حذف {count} مستندات من المجموعات بنجاح.{errors}',
      'errorDeletingCollections': 'خطأ في حذف المجموعات: {error}',
      'systemAdmin': 'مدير النظام - وصول كامل لجميع الوظائف (اشتراك تجاري)',
      'manageUsers': 'إدارة المستخدمين',
      'requestStatistics': 'إحصائيات الطلبات',
      'deleteAllUsers': 'حذف جميع المستخدمين',
      'deleteAllRequests': 'حذف جميع الطلبات',
      'deleteAllCollections': 'حذف جميع المجموعات',
      'subscription': 'اشتراك',
      'privateSubscriptionType': 'اشتراك شخصي',
      'businessSubscriptionType': 'اشتراك تجاري',
      'rejectionReason': 'السبب: {reason}',
      'remainingRequests': 'تبقى لك فقط {count} طلبات!',
      'wantMoreUpgrade': 'تريد المزيد؟ قم بالترقية',
      'guest': 'ضيف',
      // Share Service
      'interestingRequestInApp': '🎯 طلب مثير للاهتمام في "حارتي"!',
      'locationNotSpecified': 'الموقع غير محدد',
      'wantToHelpDownloadApp': '💡 تريد المساعدة؟ قم بتنزيل التطبيق "حارتي" واتصل مباشرة!',
      // App Sharing Service
      'appDescription': '"حارتي" - التطبيق الذي يربط بين الجيران للمساعدة المتبادلة الحقيقية',
      'yourRangeIncreased': 'نطاقك زاد!',
      'chooseHowToShareApp': 'اختر كيف تريد مشاركة التطبيق:',
      'sendToWhatsApp': 'أرسل للأصدقاء على WhatsApp',
      'shareOnMessenger': 'أرسل على Messenger',
      'shareOnInstagram': 'شارك على Instagram',
      // Chat screen additional
      'communicationWithServiceProvider': 'التواصل مع مقدم الخدمة',
      'communicationWithServiceProviderMessage': 'هنا يمكنك التواصل مع مقدم الخدمة، وطرح الأسئلة وتنسيق التفاصيل.',
      'messageOptions': 'خيارات الرسالة',
      'whatDoYouWantToDoWithMessage': 'ماذا تريد أن تفعل بالرسالة؟',
      'editMessage': 'تعديل الرسالة',
      'typeNewMessage': 'اكتب الرسالة الجديدة...',
      'messageEditedSuccessfully': 'تم تعديل الرسالة بنجاح',
      'errorEditingMessage': 'خطأ في تعديل الرسالة: {error}',
      'deleteMessageTitle': 'حذف الرسالة',
      'deleteMessageConfirm': 'هل أنت متأكد من أنك تريد حذف الرسالة؟',
      'deleteChat': 'حذف الدردشة',
      'errorSendingVoiceMessage': 'خطأ في إرسال رسالة صوتية: {error}',
      'reached50MessageLimit': 'وصلت إلى حد 50 رسالة - لا يمكن إرسال المزيد من الرسائل',
      'warningMessagesRemaining': 'تحذير: تبقى {count} رسائل فقط',
      'errorSendingMessage': 'خطأ في إرسال الرسالة: {error}',
      'deleteChatTitle': 'حذف الدردشة',
      'deleteChatConfirm': 'هل أنت متأكد من أنك تريد حذف الدردشة؟ لا يمكن التراجع عن هذا الإجراء.',
      'chatDeletedSuccessfully': 'تم حذف الدردشة بنجاح',
      'errorDeletingChat': 'خطأ في حذف الدردشة: {error}',
      'cannotReopenChatDeletedByRequester': 'لا يمكن إعادة فتح الدردشة - تم حذف الدردشة من قبل طالب الخدمة',
      'cannotReopenChatDeletedByProvider': 'لا يمكن إعادة فتح الدردشة - تم حذف الدردشة من قبل مقدم الخدمة',
      'deleteMyMessagesConfirm': 'هل أنت متأكد من أنك تريد حذف رسائلك؟\nسيستمر المستخدم الآخر في رؤية رسائله.',
      'myMessagesDeletedSuccessfully': 'تم حذف رسائلك بنجاح',
      'errorDeletingMyMessages': 'خطأ في حذف الرسائل: {error}',
      // Network aware widget
      'connectionRestored': 'تم استعادة الاتصال!',
      'stillNoConnection': 'لا يزال لا يوجد اتصال',
      'processing': 'جارٍ المعالجة...',
      'noInternetConnection': 'لا يوجد اتصال بالإنترنت',
      // Tutorial dialog
      'dontShowAgain': 'لا تعرض مرة أخرى',
      // Edit request screen
      'imageAccessPermissionRequired': 'مطلوب إذن الوصول إلى الصور',
      'cameraAccessPermissionRequired': 'مطلوب إذن الوصول إلى الكاميرا',
      'imagesDeletedFromStorage': 'تم حذف {count} صورة من التخزين',
      'pleaseEnterTitle': 'الرجاء إدخال العنوان',
      'pleaseEnterDescription': 'الرجاء إدخال الوصف',
      'userNotLoggedIn': 'المستخدم غير متصل',
      'pleaseSelectLocationForRequest': 'الرجاء اختيار موقع للطلب',
      'errorUpdatingRequest': 'خطأ في التحديث: {error}',
      'deleteImages': 'حذف الصور',
      'deleteAllImagesConfirm': 'هل أنت متأكد من أنك تريد حذف جميع الصور؟ سيتم حذف الصور أيضًا من التخزين.',
      'deleteAll': 'حذف الكل',
      'allImagesDeletedSuccessfully': 'تم حذف جميع الصور بنجاح',
      'updatingRequest': 'جارٍ تحديث الطلب...',
      'selectMainCategoryThenSubcategory': 'اختر المجال الرئيسي ثم المجال الفرعي:',
      'imagesSelected': 'تم اختيار {count} صورة',
      'clickToSelectLocation': 'انقر لاختيار الموقع',
      'deadlineDateSelected': 'تاريخ الاستحقاق: {day}/{month}/{year}',
      'urgencyTags': 'علامات الاستعجال',
      'selectTagsForRequest': 'اختر العلامات المناسبة لطلبك:',
      'minRatingForHelpers': 'الحد الأدنى لتقييم المساعدين',
      'allRatings': 'جميع التقييمات',
      'customTag': 'علامة مخصصة',
      'writeCustomTag': 'اكتب علامة قصيرة خاصة بك',
      'deleteImage': 'حذف الصورة',
      'deleteImageConfirm': 'هل أنت متأكد من أنك تريد حذف الصورة؟',
      'imageDeletedSuccessfully': 'تم حذف الصورة بنجاح',
      'errorDeletingImage': 'خطأ في حذف الصورة: {error}',
      'imageRemovedFromList': 'تمت إزالة الصورة من القائمة',
      // Service providers count dialog
      'noServiceProvidersInCategory': 'لا يوجد مقدمي خدمات في هذا المجال بعد',
      'serviceProvidersInCategory': 'عدد مقدمي الخدمات في هذا المجال',
      'noServiceProvidersInCategoryMessage': 'لا يوجد مقدمي خدمات من المجال الذي اخترته بعد.',
      'theFieldYouSelected': 'المجال الذي اخترته',
      'confirmMinimalRadius': 'تأكيد النطاق الأدنى',
      'minimalRadiusWarning': 'النطاق الذي اخترته هو 0.1 كم فقط. هذا نطاق صغير جداً سيحد من تعرض طلبك. هل أنت متأكد من أنك تريد المتابعة بهذا النطاق؟',
      'allRequestsFromCategory': 'جميع الطلبات من مجال {category}',
      'serviceProvidersInCategoryMessage': 'تم العثور على {count} مقدم خدمات متاحين في هذا المجال.',
      'continueCreatingRequestMessage': 'تابع إنشاء الطلب - سيتم إضافة مقدمي خدمات من هذا المجال في المستقبل.',
      'helpGrowCommunity': 'ساعدنا في توسيع المجتمع!',
      'shareAppToGrowProviders': 'شارك التطبيق مع الأصدقاء والزملاء حتى يتمكن المزيد من مقدمي الخدمات من الانضمام.',
      // Home screen additional
      'removeRequestConfirm': 'هل أنت متأكد من أنك تريد إزالة الطلب من شاشة "{screen}"? لن يتم حذف الطلب، سيتم إزالته من القائمة فقط.',
      'requestRemoved': 'تم إزالة الطلب من شاشة "{screen}"',
      'errorRemovingRequest': 'خطأ في إزالة الطلب: {error}',
      'interestCancelled': 'ألغيت اهتمامك بالطلب',
      'cannotCallThisNumber': 'لا يمكن الاتصال بهذا الرقم',
      'errorCreatingChat': 'خطأ في إنشاء الدردشة: {error}',
      'savedFilterRestored': 'تمت استعادة المرشح المحفوظ بنجاح',
      'errorRestoringFilter': 'خطأ في استعادة المرشح: {error}',
      'goToProfileToActivateSubscription': 'يرجى الانتقال إلى شاشة الملف الشخصي من خلال القائمة السفلية لتفعيل الاشتراك',
      'selectRequestRange': 'اختيار نطاق الطلبات',
      'selectLocationAndRangeOnMap': 'اختر الموقع والنطاق على الخريطة',
      'newNotification': 'إشعار جديد!',
      'setFixedLocationInProfile': 'تعيين موقع ثابت في الملف الشخصي',
      'clearFilter': 'مسح المرشح',
      'changeFilter': 'تغيير المرشح',
      'filter': 'فلترة واستقبل الإشعارات',
      'filterServiceProviders': 'فلترة مقدمي الخدمة',
      'loginWithoutVerification': 'تسجيل الدخول بدون التحقق',
      'refresh': 'تحديث',
      'addedLike': 'تمت إضافة إعجاب! ❤️',
      'removedLike': 'تمت إزالة الإعجاب',
      'filterOptions': 'خيارات التصفية',
      'saveFilterForNextTime': 'احفظ المرشح للمرة القادمة',
      // Profile screen additional
      'deleteFixedLocation': 'حذف الموقع الثابت',
      'requestPendingApproval': 'طلب قيد الموافقة ⏳',
      'privateSubscriptionPrice': 'اشتراك شخصي - 30₪/سنة',
      'businessSubscriptionPrice': 'اشتراك تجاري - 70₪/سنة',
      'upgradeToBusinessSubscription': 'ترقية إلى اشتراك تجاري:',
      // Share service
      'interestingRequestInShchunati': '🎯 طلب مثير للاهتمام في "حارتي"!',
      // App sharing service
      'shchunatiAppDescription': '"حارتي" - التطبيق الذي يربط بين الجيران للمساعدة المتبادلة الحقيقية',
      'yourRangeGrew': 'نطاقك نمى!',
      'sendToMessenger': 'أرسل على Messenger',
      // תגיות דחיפות
      'tagSuddenLeak': '❗ تسرب مفاجئ',
      'tagPowerOutage': '⚡ انقطاع التيار الكهربائي',
      'tagLockedOut': '🔒 عالق خارج المنزل',
      'tagUrgentBeforeShabbat': '🔧 إصلاح عاجل قبل السبت',
      'tagCarStuck': '🚨 سيارة عالقة على الطريق',
      'tagJumpStart': '🔋 بدء التشغيل / كابلات',
      'tagQuickParkingRepair': '🧰 إصلاح سريع في موقف السيارات',
      'tagMovingToday': '🧳 مساعدة في الانتقال اليوم',
      'tagUrgentBabysitter': '🍼 جليسة أطفال عاجلة',
      'tagExamTomorrow': '📚 درس قبل امتحان غداً',
      'tagSickChild': '🧸 مساعدة مع طفل مريض',
      'tagZoomLessonNow': '👩‍🏫 درس على Zoom الآن',
      'tagUrgentDocument': '📄 وثيقة عاجلة',
      'tagMeetingToday': '🤝 اجتماع اليوم',
      'tagPresentationTomorrow': '📊 عرض تقديمي غداً',
      'tagUrgentTranslation': '🌐 ترجمة عاجلة',
      'tagWeddingToday': '💒 زفاف اليوم',
      'tagUrgentGift': '🎁 هدية عاجلة',
      'tagEventTomorrow': '🎉 حدث غداً',
      'tagUrgentCraftRepair': '🔧 إصلاح حرفي عاجل',
      'tagUrgentAppointment': '🏥 موعد عاجل',
      'tagEmergencyCare': '🚑 رعاية طوارئ',
      'tagUrgentTherapy': '💆 علاج عاجل',
      'tagHealthEmergency': '⚕️ طوارئ صحية',
      'tagUrgentITSupport': '💻 دعم تقني عاجل',
      'tagSystemDown': '🖥️ النظام لا يعمل',
      'tagUrgentTechRepair': '🔧 إصلاح تقني عاجل',
      'tagDataRecovery': '💾 استعادة البيانات',
      'tagUrgentTutoring': '📖 درس عاجل',
      'tagExamPreparation': '📝 التحضير للامتحان',
      'tagUrgentCourse': '🎓 دورة عاجلة',
      'tagCertificationUrgent': '🏆 شهادة عاجلة',
      'tagPartyToday': '🎊 حفلة اليوم',
      'tagUrgentEntertainment': '🎭 ترفيه عاجل',
      'tagEventSetup': '🎪 إعداد حدث',
      'tagUrgentPhotography': '📸 تصوير عاجل',
      'tagUrgentGardenCare': '🌱 رعاية حديقة عاجلة',
      'tagTreeEmergency': '🌳 طوارئ شجرة',
      'tagUrgentCleaning': '🧹 تنظيف عاجل',
      'tagPestControl': '🐛 مكافحة الآفات',
      'tagUrgentCatering': '🍽️ خدمات طعام عاجلة',
      'tagPartyFood': '🍕 طعام للحفلة',
      'tagUrgentDelivery': '🚚 توصيل عاجل',
      'tagSpecialDiet': '🥗 نظام غذائي خاص',
      'tagUrgentTraining': '💪 تدريب عاجل',
      'tagCompetitionPrep': '🏆 التحضير للمسابقة',
      'tagInjuryRecovery': '🩹 التعافي من الإصابة',
      'tagUrgentCoaching': '🏃 تدريب عاجل',
      'tagEventToday': '🎉 حدث اليوم',
      'tagUrgentBeforeEvent': '💄 عاجل قبل الحدث',
      'tagUrgentBeautyFix': '✨ إصلاح جمالي عاجل',
      'tagUrgentPurchase': '🛒 شراء عاجل',
      'tagUrgentSale': '💰 بيع عاجل',
      'tagEventShopping': '🎁 تسوق للحدث اليوم',
      'tagUrgentProduct': '📦 منتج عاجل',
      'tagUrgentDeliveryToday': '📦 توصيل عاجل اليوم',
      'tagUrgentMoving': '🚚 نقل عاجل',
      'tagUrgentRoadRepair': '🔧 إصلاح عاجل على الطريق',
      'tagUrgentTowing': '🚛 سحب عاجل',
      'tagUrgentPostRenovation': '🧹 تنظيف عاجل بعد التجديد',
      'tagUrgentConsultation': '💼 استشارة عاجلة',
      'tagUrgentMeeting': '🤝 اجتماع عاجل',
      'tagUrgentElderlyHelp': '👴 مساعدة عاجلة للمسنين',
      'tagUrgentVolunteering': '❤️ تطوع عاجل',
      'tagUrgentPetCare': '🐾 رعاية عاجلة للحيوانات الأليفة',
    },
    'en': {
      'appTitle': 'My Neighborhood',
      'hello': 'Hello',
      'helloName': 'Hello, {name}',
      'connected': 'Connected',
      'notConnected': 'Not Connected',
      'disconnected': 'Disconnected',
      'welcomeBack': 'Welcome back',
      'welcome': 'Welcome to your smart neighborhood',
      'welcomeSubtitle': 'register as a guest for 3 months free and get full access to all services',
      'joinCommunity': 'Join our community',
      'fullName': 'Full Name',
      'email': 'Email',
      'password': 'Password',
      'emailAndPassword': 'Email and Password',
      'yourAccount': 'Your Account',
      'continueWithGoogle': 'Continue with Google',
      'loginWithShchunati': 'Login with Neighborhood',
      'continueWithoutRegistration': 'Continue without Registration',
      'pleaseRegisterFirst': 'You must register first to perform this action',
      'or': 'or',
      'byContinuingYouAgree': 'By continuing to use the app, you agree to:',
      'termsOfService': 'Terms of Service',
      'privacyPolicy': 'Privacy Policy',
      'termsButton': 'Terms of Service',
      'privacyButton': 'Privacy Policy',
      'termsAndPrivacyButton': 'Terms of Use and Privacy Policy',
      'copyright': '© 2025 Shchunati. All rights reserved.',
      'aboutButton': 'About the App',
      'aboutTitle': 'About Shchunati App',
      'aboutAppName': 'Shchunati',
      'aboutDescription': 'Shchunati app is a digital platform connecting service seekers with service providers in the local community. The app allows you to post help requests, offer services, communicate with neighbors, and manage transactions safely and conveniently.\n\nThe "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel. The app operates as a mediator only and does not interfere with transactions or services between users.',
      'aboutVersion': 'Version',
      'aboutSupport': 'Support',
      'aboutSupportDescription': 'For questions, issues, or requests, please contact support',
      'aboutSupportEmail': 'support@shchunati.com',
      'aboutSupportSubject': 'Question/Request - Shchunati App',
      'aboutClickToContact': 'Click to contact',
      'aboutLegalTitle': 'Legal Documents',
      'aboutFooter': '© 2025 Shchunati. All rights reserved.',
      'newRegistration': 'New Registration',
      'forgotPassword': 'Forgot Password',
      'pleaseEnterEmail': 'Please enter email address',
      'verifyEmailBelongsToYou': 'Make sure the email belongs to you! If you enter someone else\'s email, they will receive the password reset link.',
      'sendLink': 'Send Link',
      'passwordResetLinkSentTo': 'Password reset link sent to ',
      'applyingLanguage': 'Applying language...',
      'userType': 'User Type',
      'personal': 'Personal',
      'business': 'Business',
      'limitedAccess': 'Limited Access',
      'fullAccess': 'Full Access',
      'register': 'Register',
      'login': 'Login',
      'alreadyHaveAccount': 'Already have an account? Login',
      'noAccount': 'Don\'t have an account? Register',
      'home': 'Home',
      'notifications': 'Notifications',
      'chat': 'Chat',
      'profile': 'Profile',
      'myRequests': 'My Requests in Progress',
      'myRequestsMenu': 'My Requests', // לתפריט התחתון
      'openRequestsForTreatment': 'Open Requests for Treatment',
      'newRequest': 'New Request',
      'logout': 'Logout',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'hebrew': 'Hebrew',
      'arabic': 'Arabic',
      'english': 'English',
      'theme': 'Theme',
      'lightTheme': 'Light',
      'darkTheme': 'Dark',
      'systemTheme': 'System',
      'goldTheme': 'Gold',
      'searchHint': 'Search requests...',
      'searchProvidersHint': 'Search businesses and freelancers...',
      'location': 'Location',
      'nearMe': 'Near me',
      'wholeVillage': 'Whole village',
      'city': 'Whole city',
      'category': 'Category',
      'all': 'All',
      'maintenance': 'Maintenance',
      'education': 'Education',
      'transport': 'Transport',
      'shopping': 'Shopping',
      'urgent': 'Urgent',
      'canHelp': 'I can help',
      'requestTitleExample': 'Need faucet repair',
      'requestDescriptionExample': 'Kitchen faucet is leaking, need plumber',
      'requestTitle2': 'Math lesson',
      'requestDescription2': 'Looking for private math tutor for 10th grade',
      'requestTitle3': 'Small transport',
      'requestDescription3': 'Need help transporting small furniture',
      'enterName': 'Please enter full name',
      'enterEmail': 'Please enter email',
      'invalidEmail': 'Invalid email',
      'enterPassword': 'Please enter password',
      'weakPassword': 'Password too weak',
             'signUpSuccess': 'Registered successfully! Now login with your details',
             'loginSuccess': 'Logged in successfully!',
             'ok': 'OK',
             'noResults': 'No results found for',
             'noRequests': 'No requests available',
             'save': 'Save',
             'requestTitle': 'Request Title',
             'requestDescription': 'Request Description',
             'images': 'Images',
             'addImages': 'Add Images',
             'clear': 'Clear',
      'sendMessage': 'Send Message',
      'noMessages': 'No Messages',
      'you': 'You',
      'otherUser': 'Other User',
      'phoneNumber': 'Phone Number',
      'enterPhoneNumber': 'Enter phone number (optional)',
      'clearChat': 'Clear Chat',
      'clearChatConfirm': 'Are you sure you want to delete all messages in the chat?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'chatCleared': 'Chat cleared successfully',
      'open': 'Open',
      'inProgress': 'In Progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'free': 'Free',
      'paid': 'Paid',
      'deadline': 'Deadline',
      'selectDeadline': 'Select Deadline',
      'selectDeadlineOptional': 'Select deadline (optional)',
      'price': 'Price',
      'optional': 'Optional',
      'willingToPay': 'Willing to pay',
      'howMuchWillingToPay': '(Optional) How much are you willing to pay?',
      'targetAudience': 'Target Audience',
      'distance': 'Distance',
      'village': 'Village',
      'maxDistance': 'Max Distance (km)',
      'selectVillage': 'Select Village',
      'selectCategories': 'Select Categories',
      'requestType': 'Request Type',
      'selectRequestType': 'Select Request Type',
      'selectTargetAudience': 'Select Target Audience',
      'allCategories': 'All Categories',
      'expired': 'Expired',
      'editRequest': 'Edit Request',
      'deleteRequest': 'Delete Request',
      'confirmDelete': 'Are you sure you want to delete this request?',
      'requestDeleted': 'Request deleted successfully',
      'requestUpdated': 'Request updated successfully',
      'newMessage': 'New Message',
      'unreadMessages': 'Unread Messages',
      'publishAllTypes': 'Publish all types of requests',
      'respondFreeOnly': 'Respond only to free requests',
      'respondFreeAndPaid': 'Respond to free and paid requests according to your business field',
      'businessCategories': 'Business Categories',
      'selectBusinessCategories': 'Select Business Categories',
      'availability': 'Availability',
      'availabilityDescription': 'Your work days and hours',
      'availableAllWeek': 'Available all week',
      'editAvailability': 'Edit Availability',
      'selectDaysAndHours': 'Select Days and Hours',
      'day': 'Day',
      'startTime': 'Start Time',
      'endTime': 'End Time',
      'selectTime': 'Select Time',
      'availabilityUpdated': 'Availability updated successfully',
      'errorUpdatingAvailability': 'Error updating availability',
      'noAvailabilityDefined': 'No availability defined',
      'daySunday': 'Sunday',
      'dayMonday': 'Monday',
      'dayTuesday': 'Tuesday',
      'dayWednesday': 'Wednesday',
      'dayThursday': 'Thursday',
      'dayFriday': 'Friday',
      'daySaturday': 'Saturday',
      'subscriptionPayment': 'Subscription Payment',
      'payWithBit': 'Pay with Bit',
      'annualSubscription': 'Annual Subscription - 10 NIS',
      'subscriptionDescription': 'Access to paid requests according to your business fields',
      'activateSubscription': 'Activate Subscription',
      'subscriptionStatus': 'Subscription Status',
      'active': 'Active',
      'inactive': 'Inactive',
      'expiryDate': 'Expiry Date',
      // Error messages
      'emailNotRegistered': 'This email is not registered in the system',
      'wrongPassword': 'The password is incorrect',
      'emailAlreadyRegistered': 'This email is already registered in the system',
      'userAlreadyRegistered': 'This user is already registered in the system',
      'userAlreadyRegisteredPleaseLogin': 'This user is already registered in the system. Please login with your email and password',
      'emailOrPasswordWrong': 'The email or password is incorrect',
      'loginError': 'Login error',
      'retry': 'Try again',
      'registrationError': 'Registration error',
      // Success messages
      'loggedInSuccessfully': 'Logged in successfully!',
      'registeredSuccessfully': 'Registered successfully! Now login with your details',
      'googleLoginSuccess': 'Successfully logged in with Google!',
      // Additional messages
      'userGuide': 'User Guide',
      'managePayments': 'Manage Cash Payments',
      'payCash': 'Pay in Cash',
      'cashPayment': 'Cash Payment',
      'sendPaymentRequest': 'Send Payment Request',
      'manageCashPayments': 'Manage Cash Payments',
      'logoutTitle': 'Logout',
      'logoutMessage': 'Are you sure you want to logout?',
      'logoutButton': 'Logout',
      'errorLoggingOut': 'Error logging out: {error}',
      'monthlyLimitReached': 'Monthly Request Limit Reached',
      'monthlyLimitMessage': 'You have reached your monthly request limit ({count} requests).',
      'youCan': 'You can:',
      'waitForNextMonth': 'Wait for next month starting on {date}',
      'upgradeSubscription': 'Upgrade subscription to get more monthly requests',
      'upgradeSubscriptionInProfile': 'Upgrade Subscription in Profile',
      // Additional messages
      'welcomeMessage': 'Welcome!',
      'welcomeToApp': 'Welcome to "Neighborhood" app!',
      // Subscription Details Dialogs
      'yourBusinessSubscriptionDetails': 'Your Business Subscription Details',
      'yourPersonalSubscriptionDetails': 'Your Personal Subscription Details',
      'yourGuestSubscriptionDetails': 'Your Guest Subscription Details',
      'yourFreeSubscription': 'Your Free Subscription',
      'yourBusinessSubscriptionIncludes': 'Your business subscription includes:',
      'yourPersonalSubscriptionIncludes': 'Your personal subscription includes:',
      'yourTrialPeriodIncludes': 'Your trial period includes:',
      'yourFreeSubscriptionIncludes': 'Your free subscription includes:',
      'requestsPerMonth': '{count} requests per month',
      'publishUpToRequestsPerMonth': 'Publish up to {count} requests per month',
      'publishOneRequestPerMonth': 'Publish one request only per month',
      'rangeWithBonuses': 'Range: {range} km + bonuses',
      'range': 'Range: {range} km',
      'exposureUpToKm': 'Exposure up to {km} kilometers from your location',
      'seesFreeAndPaidRequests': 'Sees free and paid requests',
      'seesOnlyFreeRequests': 'Sees only free requests',
      'accessToAllRequestTypes': 'Access to all types of requests in the app',
      'accessToFreeRequestsOnly': 'Access to free requests only',
      'selectedBusinessAreas': 'Selected business areas',
      'yourBusinessAreas': 'Your business areas: {areas}',
      'noBusinessAreasSelected': 'Not selected',
      'paymentPerYear': 'Payment: {amount}₪ per year',
      'oneTimePaymentForFullYear': 'One-time payment for a full year',
      'noPayment': 'No payment',
      'freeSubscriptionAvailable': 'Free subscription available at no cost',
      'trialPeriodDays': 'Trial period: {days} days',
      'fullAccessToAllFeatures': 'Full access to all features for free',
      'yourSubscriptionActiveUntil': 'Your subscription is active until {date}',
      'unknown': 'Unknown',
      'yourTrialActiveForDays': 'Your trial period is active for {days} more days',
      'subscriptionExpiredSwitchToFree': 'Your subscription has switched to "Free Private" type, upgrade now to "Personal Subscription" or "Business"',
      'afterTrialAutoSwitchToFree': 'After the trial period, you will automatically switch to a free private subscription. You can upgrade at any time.',
      // Subscription Type Selection Dialog
      'selectSubscriptionType': 'Subscription Type Selection',
      'chooseYourSubscriptionType': 'Choose your subscription type:',
      'privateFree': 'Private (Free)',
      'privateSubscription': 'Private (Subscription)',
      'businessSubscription': 'Business (Subscription)',
      'privateSubscriptionFeatures': '• 1 request per month\n• Range: 0-3 km\n• Sees only free requests\n• No business areas',
      'privatePaidSubscriptionFeatures': '• 5 requests per month\n• Range: 0-5 km\n• Sees only free requests\n• No business areas\n• Payment: 30₪ per year',
      'businessSubscriptionFeatures': '• 10 requests per month\n• Range: 0-8 km\n• Sees free and paid requests\n• Selection of business areas\n• Payment: 70₪ per year',
      // Activate Subscription Dialog
      'activateSubscriptionWithType': 'Activate {type} Subscription',
      'subscriptionTypeWithType': '{type} Subscription',
      'perYear': '₪{price} per year',
      'businessAreas': 'Business areas: {areas}',
      'howToPay': 'How to pay:',
      'paymentInstructions': '1. Choose payment method: BIT (PayMe) or credit card (PayMe)\n2. Pay the amount (₪{price}) - the subscription will be activated automatically\n3. If there is a problem, contact support',
      'payViaPayMe': 'Pay via PayMe (Bit or credit card)',
      // Pending Approval Dialog
      'requestPendingApprovalNew': 'Request Pending Approval ⏳',
      'youHaveRequestForSubscription': 'You have a request for {type} and it is being processed.',
      'cannotSendAnotherRequest': 'Cannot send another request until the administrator approves or rejects the current request.',
      // System Admin Dialog
      'systemAdministrator': 'System Administrator',
      'adminFullAccessMessage': 'As a system administrator, you have full access to all functions without payment.\n\nYour subscription type is fixed: Business subscription with access to all business areas.',
      // Cash Payment Dialog
      'cashPaymentTitle': 'Cash Payment',
      'subscriptionDetails': 'Subscription Details:',
      'subscriptionTypeLabel': 'Subscription Type: {type}',
      'priceLabel': 'Price: ₪{price}',
      'sendPaymentRequestNew': 'Send Payment Request',
      'fillAllFields': 'Please fill in all fields',
      'rememberMe': 'Remember me',
      'saveCredentialsQuestion': 'Would you like to save your login credentials?',
      'saveCredentialsInfo': 'If you choose yes, you can login automatically next time',
      'saveCredentialsText': 'Save my login credentials',
      'autoLoginText': 'I want to login automatically next time',
      'noThanks': 'No, thanks',
      'requestsFromNeighborhood': 'Requests from neighborhood',
      'allNotificationsInNeighborhood': 'All notifications in my neighborhood',
      'manageNotifications': 'Manage all notifications',
      'notificationOptions': 'Various options for receiving notifications about new requests',
      // Texts from notifications screen
      'userNotConnected': 'User not connected',
      'clearAllNotifications': 'Clear all notifications',
      'markAllAsRead': 'Mark all as read',
      'notificationsBlocked': 'Notifications blocked - Please enable notification permissions in phone settings',
      'enableNotifications': 'Enable Notifications',
      'error': 'Error',
      'errorMessage': 'Error: {error}',
      'noNewNotifications': 'No new notifications',
      'notificationInfo': 'When someone responds to your requests or offers help,\nyou will receive a notification here',
      'openRequest': 'Open Request',
      'errorUpdatingNotification': 'Error updating notification: {error}',
      'allNotificationsMarkedAsRead': 'All notifications marked as read',
      'errorUpdatingNotifications': 'Error updating notifications: {error}',
      'clearAllNotificationsTitle': 'Clear all notifications',
      'clearAllNotificationsMessage': 'Are you sure you want to delete all notifications? This action cannot be undone.',
      'clearAll': 'Clear All',
      'allNotificationsDeletedSuccessfully': 'All notifications deleted successfully',
      'errorDeletingNotifications': 'Error deleting notifications: {error}',
      'deleteNotification': 'Delete Notification',
      'deleteNotificationMessage': 'Are you sure you want to delete the notification "{title}"?',
      'notificationDeletedSuccessfully': 'Notification deleted successfully',
      'errorDeletingNotification': 'Error deleting notification: {error}',
      'now': 'Now',
      'minutesAgo': '{count} minutes ago',
      'hoursAgo': '{count} hours ago',
      'daysAgo': '{count} days ago',
      // Additional messages
      'understood': 'Understood',
      'openTutorial': 'Open Tutorial',
      // Terms and Privacy
      'termsAndPrivacyTitle': 'Terms of Service and Privacy Policy',
      'welcomeToTermsScreen': 'Welcome to our app',
      'agreeAndContinue': 'Agree and Continue',
      'doNotAgree': 'Do Not Agree',
      'importantNote': 'Important to Know',
      'termsMayBeUpdated': 'The Terms of Service and Privacy Policy may be updated from time to time.\nYou can find the most current version in the app.',
      'byContinuingYouConfirm': 'By continuing to use the app, you confirm that you have read and understood the Terms of Service and Privacy Policy, and you agree to them.',
      'mustAcceptTerms': 'Important: You must accept the Terms of Service and Privacy Policy to continue using the app.',
      // Terms of Service
      'termsOfServiceIntro': 'Welcome to the "Shchunati" app. Use of the app is subject to the following terms. Please read them carefully:\n\nThe "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company").',
      'termsSection1': 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company"). Use of the app is conditional upon acceptance of these Terms of Service.',
      'termsSection2': 'The app is intended for users over the age of 18 only. The company reserves the right to request proof of age at any stage.',
      'termsSection3': 'The app is intended for mutual assistance between neighbors - connecting those seeking help with those providing help in the local community.',
      'termsSection4': 'The user undertakes to provide only true and accurate information, including location details and contact details.',
      'termsSection5': 'The app is a marketplace platform connecting service seekers with service providers. The app allows users to post free and paid help requests, and offer professional and commercial services in exchange for payment. Commercial and professional use of the app is permitted within the framework of these Terms of Service. The company operates as a mediator only and is not responsible for the quality of services, the reliability of users, any damages, fraud, disputes, or financial losses.',
      'termsSection6': 'Users are solely responsible for the content they publish and for any interaction with other users.',
      'termsSection7': 'Neighborhood is only a mediator and is not responsible for the quality of services, the reliability of users or any damages.',
      'termsSection8': 'The user undertakes to report any inappropriate, offensive or dangerous behavior immediately to support or the relevant authorities.',
      'termsSection10': 'The company reserves the right to stop the service, block users or remove content at any time.',
      'termsSection11': 'The user is responsible for maintaining their login password and securing their personal information.',
      'termsSection12': 'Any dispute will be resolved according to Israeli law and in accordance with the laws of the State of Israel.',
      // Mutual Help and Safety
      'mutualHelpAndSafety': 'Mutual Help and Safety',
      'mutualHelpSection1': 'The app is a marketplace platform connecting people. You choose for yourself who to communicate with, who to offer services to, or who to receive services from, and any such interaction is at your sole responsibility. Ratings and user feedback can help build trust, but they do not constitute a guarantee of quality, reliability, or safety. The company is not responsible for any damage, misconduct, fraud, or poor service quality.',
      'mutualHelpSection2': 'There is no legal obligation to provide service, but it is recommended to fulfill commitments made to others.',
      'mutualHelpSection3': 'The rating and review system must be true and accurate. False or offensive ratings will lead to user blocking.',
      'mutualHelpSection4': 'In case of suspicion of danger, inappropriate behavior or exploitation, report immediately to support or the relevant authorities.',
      'mutualHelpSection5': 'We reserve the right to block users who violate the rules or behave inappropriately.',
      'mutualHelpSection6': 'Payments between users are their exclusive responsibility. Neighborhood is not responsible for payments or transactions between users.',
      'mutualHelpSection8': 'In case of a problem or dispute, we recommend trying to resolve the issue peacefully before contacting support.',
      // Privacy Policy
      'privacyPolicyIntro': 'This Privacy Policy describes how we collect, use and protect your personal information in the "Shchunati" app:\n\nThe "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company").',
      'privacySection1': 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company"). We respect user privacy and are committed to protecting your personal information.',
      'privacySection2': 'Personal information is collected to provide services, including geographic location to connect neighbors, contact details and information about help requests.',
      'privacySection3': 'We will not sell or share your personal information with third parties without explicit consent, except in cases required by law.',
      'privacySection4': 'Information is stored on secure and encrypted servers. Geographic location is stored encrypted and is not transferred to third parties.',
      'privacySection5': 'You have full control over who sees your information. You can set different privacy levels for different requests.',
      'privacySection6': 'The user may request to access, correct or delete their personal information at any time.',
      'privacySection7': 'We use cookies and similar technologies to improve user experience and analyze app usage.',
      'privacySection8': 'The app uses Google Firebase services (Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging) for security, data storage, and notification services. Information is transferred to Firebase servers protected by advanced encryption and under Google\'s privacy policy.',
      'privacySection9': 'The app requires access to your geographic location to connect you with nearby neighbors. Location is stored encrypted and used only to display relevant help requests. You can revoke location access at any time in device settings.',
      'privacySection10': 'The app requires access to your microphone to create voice messages. Recordings are stored on encrypted Firebase servers and used only for communication between users. You can revoke microphone access at any time in device settings.',
      'privacySection11': 'The app requires access to your camera and gallery to upload images for help requests. Images are stored on encrypted Firebase Storage servers and used only to display help requests. You can revoke camera/gallery access at any time in device settings.',
      'privacySection12': 'We take reasonable security measures to protect your information from unauthorized access, use or disclosure.',
      'privacySection13': 'In case of a security breach or information disclosure, we will report it as soon as possible and take appropriate measures.',
      'privacySection14': 'We are committed to updating users about any changes to the Privacy Policy through the app or other means.',
      'privacySection15': 'The app may contain links to third-party websites or services. We are not responsible for their privacy policy.',
      'tutorialHint': 'To learn how to use the app, click on the tutorial icon (📚) in the top menu.',
      // Profile Screen
      'extendTrialPeriod': 'Extend Trial Period',
      'extendTrialPeriodByTwoWeeks': 'Extend Trial Period by Two Weeks',
      'youAreInWeek': 'You are in week',
      'youAreInFirstWeekMessage': 'You are in your first week! You can see all requests (free and paid) from all categories.',
      'yourRating': 'Your Rating',
      'noRatingsYet': 'You have not received ratings yet',
      'detailedRatings': 'Detailed Ratings',
      'reliability': 'Reliability',
      'attitude': 'Attitude',
      'fairPrice': 'Fair Price',
      'editDisplayName': 'Edit Display Name',
      'editPhoneNumber': 'Edit Phone Number',
      'afterSavingNameWillUpdate': 'After saving, the name will be updated everywhere in the app',
      'phonePrefix': 'Prefix',
      'enterNumberWithoutPrefix': 'Enter the number without the prefix',
      'select': 'Select',
      'forExample': 'For example',
      // My Requests Screen
      'noRequestsInMyRequests': 'No requests',
      'createNewRequestToStart': 'Create a new request to get started',
      // In Progress Requests Screen
      'noInterestedRequests': 'You have no requests in progress',
      'clickInterestedOnRequests': 'Click "I\'m interested" on requests that interest you in "All Requests"',
      'howItWorks': 'How does it work?',
      'howItWorksSteps': '1. Go to "All Requests"\n2. Click "I\'m interested" on requests that interest you\n3. Requests will appear here in "My Requests in Progress"',
      // Category Selection
      'selectMainCategoryThen': 'Select main category then',
      'selectMainCategoryThenUpTo': 'Select main category then up to',
      'subCategories': 'sub categories',
      // Buttons
      'close': 'Close',
      'startProcess': 'Start Process',
      'maybeLater': 'Maybe Later',
      'rateNow': 'Rate Now',
      'startEarning': 'Start Earning',
      // Trial Extension Dialog
      'toExtendTrialPeriod': 'To extend your trial period by two weeks, you need to perform the following actions:',
      'shareAppTo5Friends': 'Share the app to 5 friends (WhatsApp, SMS, Email)',
      'rateApp5Stars': 'Rate the app 5 stars in the store',
      'publishNewRequest': 'Publish a new request in any field you want',
      'serviceRequiresAppointment': 'Service requires appointment',
      'serviceRequiresAppointmentHint': 'If the service requires scheduling an appointment, select this option',
      'canReceiveByDelivery': 'Can it be received by delivery?',
      'canReceiveByDeliveryHint': 'Can the service be received via couriers?',
      'publishAd': 'Publish Ad',
      'completeAllActionsWithinHour': 'All actions must be completed within one hour',
      'granting14DayExtension': 'Granting 14-day extension...',
      'extensionGrantedSuccessfully': '14-day extension granted successfully!',
      'errorGrantingExtension': 'Error granting extension',
      'shareAppTo5FriendsForTrial': 'Share the app to 5 friends',
      'rateApp5StarsForTrial': 'Rate the app 5 stars in the store',
      'publishNewRequestForTrial': 'Publish a new request',
      'newRequestTutorialTitle': 'Create new request',
      'newRequestTutorialMessage': 'Here you can create a new request and get help from the community. Write a clear description, select a category, set location and exposure range (according to your user type), and publish the request.',
      'writeRequestDescription': 'Write request description',
      'selectAppropriateCategory': 'Select appropriate category',
      'selectLocationAndExposure': 'Select location and exposure range',
      'setPriceFreeOrPaid': 'Set price (free or paid)',
      'publishRequest': 'Publish request',
      'locationInfoTitle': 'Location selection information',
      'howToSelectLocation': 'How to select the right location:',
      'selectLocationInstructions': '📍 Select as precise a location as possible\n🎯 The range will determine how many people see the request\n📱 Use the map to select the precise location',
      'locationSelectionTips': 'Location selection tips:',
      'locationSelectionTipsDetails': '🏠 Select the exact address\n🚗 If it\'s on a street, select the correct side\n🏢 If it\'s in a building, select the main entrance\n📍 Use address search for maximum accuracy\n📏 The minimum range is 0.1 km',
      'remainingTime': 'Remaining time',
      'timeExpired': 'Time expired',
      'shareAppOpened': 'App sharing opened. Please share with 5 friends to complete the requirement.',
      'appStoreOpened': 'App store opened. Please rate 5 stars to complete the requirement.',
      'navigateToNewRequest': 'Navigating to new request screen. Please publish a request to complete the requirement.',
      'notCompleted': 'Not completed',
      'helpUsImproveApp': 'Help us improve the app',
      // Share App Dialog
      'shareAppTitle': 'Share App',
      'shareAppForTrialExtension': 'Share App for Trial Extension',
      'chooseHowToShare': 'Choose how you want to share the app:',
      'sendToFriendsWhatsApp': 'Send to friends on WhatsApp',
      'sendEmail': 'Send email',
      'openShareOptions': 'Open share options',
      'copyToClipboard': 'Copy to clipboard',
      'copyTextToShare': 'Copy text to share',
      'generalShare': 'General share',
      'shareToFacebookMessenger': 'Share on Messenger',
      'shareToInstagram': 'Share on Instagram',
      'openingWhatsApp': 'Opening WhatsApp...',
      'openingWhatsAppWeb': 'Opening WhatsApp Web...',
      'openingMessagesApp': 'Opening messages app...',
      'openingEmailApp': 'Opening email app...',
      'openingShareOptions': 'Opening share options...',
      'textCopiedToClipboard': 'Text copied to clipboard! Share it with friends',
      'errorOpeningShare': 'Error opening share',
      'errorOpeningShareDialog': 'Error opening share dialog',
      'errorCopying': 'Error copying',
      'errorOpeningShareOptions': 'Error opening share options',
      'copyTextFromClipboard': 'Copy text from clipboard',
      // Rate App Dialog
      'rateAppTitle': 'Rate App',
      'howWasYourExperience': 'How was your experience?',
      'yourRatingHelpsUs': 'Your rating helps us improve the app and reach more users.',
      'highRatingMoreNeighbors': '⭐ High rating = more neighbors = more mutual help!',
      'errorOpeningStore': 'Error opening store',
      'cannotOpenAppStore': 'Cannot open app store',
      // Recommend to Friends Dialog
      'recommendToFriendsTitle': 'Recommend to Friends',
      'lovedTheAppHelpUsGrow': 'Loved the app? Help us grow!',
      'shareWithFriends': '🎯 Share with friends',
      'rateUs': '⭐ Rate us',
      'tellAboutYourExperience': '💬 Tell about your experience',
      'everyRecommendationHelps': 'Every recommendation helps us reach more neighbors looking for mutual help!',
      // Rewards Dialog
      'rewardsForRecommenders': 'Rewards for Recommenders',
      'recommendAppAndGetRewards': 'Recommend the app and get rewards!',
      'pointsPerRecommendation': '🎁 10 points - each recommendation',
      'pointsFor5StarRating': '⭐ 5 points - 5 star rating',
      'pointsForPositiveReview': '💬 3 points - positive review',
      'pointsPriorityFeatures': 'Points = priority in requests + special features!',
      'guestPeriodStarted': 'Welcome! Guest period started',
      'firstWeekMessage': 'You are in your first week - you can see all requests (free and paid) from all categories!',
      'guestModeWithCategories': 'Guest mode - defined business fields',
      'guestModeNoCategories': 'Guest mode - no business fields',
      'helpSent': 'Help offer sent!',
      'unhelpConfirmation': 'Are you sure you want to cancel your interest in this request?',
      'unhelpSent': 'Interest in request cancelled',
      'categoryDataUpdated': 'Category data updated successfully',
      'nameDisplayInfo': 'The name will appear in requests you create, and in the maps of request publishers',
      'validPrefixes': 'Valid prefixes: 050-059 (10 digits), 02,03,04,08,09 (9 digits), 072-079 (10 digits)',
      'agreeToDisplayPhone': 'I agree to display my phone number in requests I create, and to be contacted if I provide services',
      // Home screen additional
      'removeRequestConfirm': 'Are you sure you want to remove the request from "{screen}" screen? The request will not be deleted, only removed from the list.',
      'requestRemoved': 'Request removed from "{screen}" screen',
      'errorRemovingRequest': 'Error removing request: {error}',
      'interestCancelled': 'You cancelled your interest in the request',
      'cannotCallThisNumber': 'Cannot call this number',
      'errorCreatingChat': 'Error creating chat: {error}',
      'savedFilterRestored': 'Saved filter restored successfully',
      'errorRestoringFilter': 'Error restoring filter: {error}',
      'goToProfileToActivateSubscription': 'Please go to the profile screen through the bottom menu to activate subscription',
      'selectRequestRange': 'Select request range',
      'selectLocationAndRangeOnMap': 'Select location and range on map',
      'newNotification': 'New notification!',
      'setFixedLocationInProfile': 'Set fixed location in profile',
      'clearFilter': 'Clear filter',
      'changeFilter': 'Change filter',
      'filter': 'Filter and receive notifications',
      'filterServiceProviders': 'Filter service providers',
      'loginWithoutVerification': 'Login without verification',
      'refresh': 'Refresh',
      'addedLike': 'Added like! ❤️',
      'removedLike': 'Removed like',
      'filterOptions': 'Filter options',
      'saveFilterForNextTime': 'Save filter for next time',
      // Profile screen additional
      'deleteFixedLocation': 'Delete fixed location',
      'requestPendingApproval': 'Request pending approval ⏳',
      'upgradeSubscriptionTitle': 'Upgrade subscription 🚀',
      'privateSubscriptionPrice': 'Personal subscription - 30₪/year',
      'businessSubscriptionPrice': 'Business subscription - 70₪/year',
      'upgradeToBusinessSubscription': 'Upgrade to business subscription:',
      // Share service
      'interestingRequestInShchunati': '🎯 Interesting request in "Shchunati"!',
      // App sharing service
      'shchunatiAppDescription': '"Shchunati" - The app that connects neighbors for real mutual help',
      'yourRangeGrew': 'Your range grew!',
      'sendToMessenger': 'Send on Messenger',
      // Profile screen texts
      'notConnectedToSystem': 'Not connected to system',
      'pleaseLoginToSeeProfile': 'Please login to see your profile',
      'loadingProfile': 'Loading profile...',
      'errorLoadingProfile': 'Error loading profile',
      'userProfileNotFound': 'User profile not found',
      'creatingProfile': 'Creating profile...',
      'createProfile': 'Create profile',
      'setBusinessFields': 'Set business fields',
      'ifYouProvideService': 'If you provide any service, set your business fields and get access to paid requests.\n\nYou can change your business fields at any time in your profile.',
      'later': 'Later',
      'chooseNow': 'Choose now',
      'tutorialsResetSuccess': 'Tutorial messages reset successfully',
      'subscriptionTypeChanged': 'Subscription type changed to {type}',
      'errorChangingSubscriptionType': 'Error changing subscription type: {error}',
      'permissionsRequired': 'Permissions required',
      'imagePermissionRequired': 'Image access permission is required. Please go to app settings and enable the permission.',
      'openSettings': 'Open settings',
      'imagePermissionRequiredTryAgain': 'Image access permission is required. Please try again.',
      'chooseAction': 'Choose action',
      'chooseFromGallery': 'Choose from gallery',
      'deletePhoto': 'Delete photo',
      'profileImageUpdatedSuccess': 'Profile image updated successfully',
      'profileImageDeletedSuccess': 'Profile image deleted successfully',
      'errorDeletingProfileImage': 'Error deleting profile image',
      'profileCreatedSuccess': 'Profile created successfully as {type}',
      'errorCreatingProfile': 'Error creating profile: {error}',
      'errorCreatingProfileAlt': 'Error creating profile: {error}',
      'checkingLocationPermissions': 'Checking location permissions...',
      'locationPermissionsRequired': 'Location permissions are required to update location. Please enable location permissions in device settings',
      'locationServicesDisabled': 'Location services are disabled. Please enable them in device settings',
      'locationServiceDisabledTitle': 'Location Service Disabled',
      'locationServiceDisabledMessage': 'Location service on your device is disabled. Location service is essential for the app to:\n\n• Show you relevant requests in your area\n• Allow you to see requests on the map\n• Filter requests by location and exposure range\n• Receive notifications about new requests in your area\n• Display your location on request publishers\' maps\n\nIf you have a fixed location in your profile, it will continue to work even when location service is disabled.\n\nPlease enable location service in device settings.',
      'enableLocationServiceTitle': 'Enable Location Services on Phone',
      'enableLocationServiceMessage': 'To use filtering by mobile location, you need to enable location services on your phone.\n\nLocation services are essential to:\n• Get your current location\n• Update location automatically\n• Filter requests by location and exposure range\n• Receive notifications about new requests in your area',
      'enableLocationService': 'Enable Location Services',
      'gettingCurrentLocation': 'Getting current location...',
      'savingLocationAndRadius': 'Saving location and exposure radius...',
      'fixedLocationAndRadiusUpdated': 'Fixed location and exposure radius updated successfully!',
      'noLocationSelected': 'No location selected',
      'deletingFixedLocation': 'Deleting fixed location',
      'deleteFixedLocationQuestion': 'Are you sure you want to delete the fixed location?\n\nAfter deletion, you will appear on maps only when location service is active on your phone.',
      'deletingLocation': 'Deleting location...',
      'fixedLocationDeletedSuccess': 'Fixed location deleted successfully!',
      'errorDeletingLocation': 'Error deleting location: {error}',
      'shareApp': 'Share app',
      'rateApp': 'Rate app',
      'recommendToFriends': 'Recommend to friends',
      'rewards': 'Rewards',
      'resetTutorialMessages': 'Reset tutorial messages',
      'debugSwitchToFree': '🔧 Switch to free private',
      'debugSwitchToPersonal': '🔧 Switch to personal subscription',
      'debugSwitchToBusiness': '🔧 Switch to business subscription',
      'debugSwitchToGuest': '🔧 Switch to guest',
      'contact': 'Contact',
      'deleteAccount': 'Delete account',
      'update': 'Update',
      'firstNameLastName': 'First name and last name/company/business/nickname',
      'enterFirstNameLastName': 'Enter first name and last name/company/business/nickname',
      'clickUpdateToChangeName': 'Click "Update" to change the name. The name will be saved automatically',
      'allBusinessFields': 'All business fields',
      'businessFields': 'Business fields',
      'edit': 'Edit',
      'noBusinessFieldsDefined': 'No business fields defined',
      'toReceiveNotifications': 'To receive notifications about relevant requests, you must select up to two business fields:',
      'iDoNotProvidePaidServices': 'I do not provide any service for payment',
      'ifYouCheckThisOption': 'If you check this option, you can see only free requests in the requests screen.',
      'allAds': 'All Ads',
      'adsCount': '{count} ads',
      'monthlyRequests': 'Monthly requests',
      'publishedRequestsThisMonth': 'Published {count} requests this month (no limit)',
      'remainingRequestsThisMonth': 'You have {count} requests remaining to publish this month',
      'reachedMonthlyRequestLimit': 'Reached monthly request limit',
      'wantMoreUpgradeSubscription': 'Want more? Upgrade subscription',
      'invalidPrefix': 'Invalid prefix',
      'fixedLocation': 'Fixed location',
      'updateLocationAndRadius': 'Update location and radius',
      'adminCanUpdateLocation': 'Admin - can update location like any other user',
      'fixedLocationDefined': 'Fixed location defined',
      'villageNotDefined': 'Village not defined',
      'youWillAppearInRange': '✅ You will appear in the range of published requests that match your business field, even if location service is not active on your phone',
      'deleteLocation': 'Delete location',
      'noFixedLocationDefined': 'No fixed location and exposure radius defined',
      'asServiceProvider': 'As a service provider, setting a fixed location and exposure radius is essential:',
      'locationBenefits': '• You will receive notifications about requests relevant to your business field\n• You will appear on maps of request publishers and they can contact you\n• Fixed location service will continue to serve you even when location service is disabled on your phone',
      'systemManagement': 'System management',
      'manageInquiries': 'Manage inquiries',
      'manageGuests': 'Manage guests',
      'additionalInfo': 'Additional info',
      'joinDate': 'Join date',
      'helpUsGrow': 'Help us grow',
      'recommendAppToFriends': 'Recommend the app to friends and get rewards!',
      'approved': '✅ Approved',
      'subscriptionPendingApproval': '{type} pending approval',
      'waitingForAdminApproval': '⏳ Waiting for admin approval',
      'rejected': 'Rejected',
      'upgradeRequestRejected': '❌ Upgrade request rejected',
      'privateFreeStatus': 'Private free',
      'freeAccessToFreeRequests': '🆓 Access to free requests',
      'errorLoadingData': 'Error loading data: {error}',
      'wazeNotInstalled': 'Waze is not installed on this device',
      'errorOpeningWaze': 'Error opening Waze',
      'requestApprovalPending': 'Request pending approval ⏳',
      'chooseSubscriptionType': 'Choose subscription type:',
      'upgradeToBusiness': 'Upgrade to business subscription:',
      'noUpgradeOptionsAvailable': 'No upgrade options available',
      'privateFreeType': 'Private (free)',
      'privateFreeDescription': '• 1 request per month\n• Range: 0-3 km\n• See only free requests\n• No business fields',
      'upgrade': 'Upgrade',
      'deleteAccountTitle': 'Delete account',
      'deleteAccountConfirm': 'Are you sure you want to delete your account?',
      'thisActionWillDeletePermanently': 'This action will delete permanently:',
      'yourLoginCredentials': 'Your login credentials',
      'yourPersonalInfo': 'Your personal information in profile',
      'allYourPublishedRequests': 'All your published requests',
      'allYourInterestedRequests': 'All requests you were interested in',
      'allYourChats': 'All your chats',
      'allYourMessages': 'All messages you sent and received',
      'allYourImages': 'All images and files',
      'allYourData': 'All data and history',
      'thisActionCannotBeUndone': 'This action cannot be undone!',
      'passwordConfirmation': 'Password confirmation',
      'passwordConfirmationMessage': 'To delete the account, please enter your password for confirmation:',
      'passwordRequired': 'Please enter your password',
      'thisActionWillDeleteAccountPermanently': 'This action will delete the account permanently!',
      'deletingAccount': 'Deleting account...',
      'noUserFound': 'No connected user found',
      'accountDeletedSuccess': 'Account deleted successfully',
      'deletingAccountProgress': 'Deleting account...',
      'deleteUser': 'Delete user',
      'googleUserDeleteTitle': 'Delete user',
      'loggedInWithGoogle': 'Logged in with Google',
      'clickConfirmToDeletePermanently': 'Click "Confirm" to delete the account permanently.\nThis action cannot be undone!',
      'contactScreenTitle': 'Contact Us',
      'contactScreenSubtitle': 'Have questions? Something unclear? We\'d love to hear from you',
      'contactOperatorInfo': 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel. Support is also available for privacy requests and account deletion.',
      'contactName': 'Name',
      'contactNameHint': 'Enter your name',
      'contactNameRequired': 'Please enter your name',
      'contactEmail': 'Email',
      'contactEmailHint': 'Enter your email address',
      'contactEmailRequired': 'Please enter your email address',
      'contactEmailInvalid': 'Please enter a valid email address',
      'contactMessage': 'Message',
      'contactMessageHint': 'Free text',
      'contactMessageRequired': 'Please enter your message',
      'contactMessageTooShort': 'Please enter a more detailed message (at least 10 characters)',
      'contactSend': 'Send',
      'contactSuccess': 'Inquiry sent successfully! We will get back to you soon',
      'contactError': 'Error sending inquiry: {error}',
      'errorLoadingRating': 'Error loading rating',
      'noRatingAvailable': 'No rating available',
      'trialPeriodInfo': 'Information about your trial period',
      'chatClosed': 'Chat closed - cannot send messages',
      'messageLimitReached': 'Reached 50 message limit - cannot send more messages',
      'messagesRemaining': 'Warning: Only {count} messages remaining',
      'loginMethod': 'Login method: {method}',
      'saveLoginCredentials': 'Save login credentials',
      // Additional messages from home_screen
      'confirmCancelInterest': 'Confirm Cancel Interest',
      'requestLabel': 'Request',
      'categoryLabel': 'Category',
      'typeLabel': 'Type',
      'paidType': 'Paid',
      'freeType': 'Free',
      'editBusinessCategories': 'Edit Business Categories',
      'actionConfirmation': 'Action Confirmation',
      'noNotificationsSelected': 'You chose not to receive notifications about new requests. Continue?',
      'no': 'No',
      'yes': 'Yes',
      'showToProvidersOutsideRange': 'According to the location you selected, your request is in the {region} region, are you interested in your request appearing to all service providers in the {category} field from the {region} region?',
      'yesAllProvidersInRegion': 'Yes, all service providers in the {region} region',
      'noOnlyInRange': 'No, only in the range I defined',
      'showToAllUsersOrProviders': 'Are you interested in this request appearing to all service providers from all fields in the app or only to service providers in the {category} field you selected?',
      'yesToAllUsers': 'Yes, to all service providers from all fields',
      'onlyToProvidersInCategory': 'Only to service providers in the {category} field',
      'northRegion': 'North',
      'centerRegion': 'Center',
      'southRegion': 'South',
      'errorGeneral': 'Error: {error}',
      'seeMoreSelectFields': 'You see paid requests only from the business fields you selected. To see more requests, select additional business fields in your profile.',
      
      // Tutorial Center - Categories
      'tutorialCategoryHome': 'Home Screen',
      'tutorialCategoryRequests': 'Requests',
      'tutorialCategoryChat': 'Chat',
      'tutorialCategoryProfile': 'Profile',
      'tutorialTutorialsAvailable': '{count} tutorials available',
      
      // Tutorial Center - Home Screen
      'tutorialHomeBasicsTitle': 'Home Screen Basics',
      'tutorialHomeBasicsDescription': 'Learn how to navigate the home screen and use basic functions',
      'tutorialHomeBasicsContent': '''Home Screen Basics

What you'll find on the home screen:
• Request list - All available requests in the community
• Search - Search requests by keywords
• Filter - Filter requests by category and location
• My Requests in Progress - Requests you published or applied to

How to use:
1. To view a request - Click on a request from the list
2. To search - Use the top search bar
3. To filter - Click on "Filter Requests" button
4. For my requests in progress - Click on "My Requests in Progress"''',
      
      'tutorialHomeSearchTitle': 'Search and Filter',
      'tutorialHomeSearchDescription': 'How to find specific requests quickly',
      'tutorialHomeSearchContent': '''Search and Filter

Search:
• Keywords - Enter relevant words
• Real-time search - Results update as you type
• Search all fields - Name, description, category

Filter requests:
• Request type - Free or paid
• Categories - Select specific business fields
• Urgency - Normal, urgent (24 hours), very urgent (now)
• Location and range - Search near a specific place (mobile or fixed location)
• Exposure range - Set range in kilometers

Exposure ranges in filter:
The maximum range in filter depends on your user type:
• Guest: Up to 5 km
• Personal free: Up to 3 km
• Personal subscription: Up to 5 km
• Business subscription: Up to 8 km

Note: Ranges are fixed and do not change based on recommendations or ratings.

Tips:
• Use short and clear keywords
• Try different searches for the same request
• Choose an exposure range that fits your location
• Save favorite filters''',
      
      // Tutorial Center - Requests
      'tutorialCreateRequestTitle': 'Create New Request',
      'tutorialCreateRequestDescription': 'How to create a request for help or service',
      'tutorialCreateRequestContent': '''Create New Request

Steps to create a request:
1. Click on + - In the bottom right corner
2. Select category - Appropriate business field
3. Write description - Explain what you need
4. Set price - If relevant (free or paid)
5. Select location - Where you are
6. Set exposure range - How many km from your location (according to your user type)
7. Publish - Send the request to the community

Exposure ranges by user type:
• Guest: Up to 5 km
• Personal free: Up to 3 km
• Personal subscription: Up to 5 km
• Business subscription: Up to 8 km

Note: Ranges are fixed and do not change based on recommendations or ratings.

Tips for good writing:
• Clear description - Explain exactly what you need
• Important details - Time, place, urgency
• Image - Add an image if it helps explain
• Fair price - Suggest a reasonable price or choose "free"
• Exposure range - Choose a range that fits your location and request type

Limits by user type:
• Personal free: 1 request per month
• Personal subscription: 5 requests per month
• Business subscription: 10 requests per month

Good example:
"Need help moving furniture from apartment to apartment in Jerusalem.
There are 3 closets, 2 tables and beds.
Ready to pay 200-300 shekels.
Deadline: Next weekend."''',
      
      'tutorialManageRequestsTitle': 'Manage Requests',
      'tutorialManageRequestsDescription': 'How to manage your requests',
      'tutorialManageRequestsContent': '''Manage Requests

Requests you published:
• View applications - See who applied to you
• Edit request - Update details or price
• Close request - When help was received
• Delete request - If no longer relevant

My Requests in Progress (you applied to):
• Track status - See if you were accepted
• Chat with publisher - Direct communication
• Cancel application - If you changed your mind

Management tips:
• Update status - Mark when request is completed
• Communicate in chat - Ask questions before committing
• Check profiles - See service provider ratings
• Be polite - Respond on time and respectfully''',
      
      // Tutorial Center - Chat
      'tutorialChatBasicsTitle': 'Chat Basics',
      'tutorialChatBasicsDescription': 'How to use the chat system',
      'tutorialChatBasicsContent': '''Chat Basics

How to enter chat:
1. From a request you published - Click on "Chat" next to application
2. From a request you applied to - Click on "Chat" in the request
3. From "My Requests in Progress" screen - Click on chat button

Chat functions:
• Send messages - Text and voice messages
• Edit messages - Long press on a message you sent
• Delete messages - Long press and select "Delete"
• Close chat - If you don't want to communicate anymore

Read indicators:
• One check - Message sent
• Two checks - Message read by recipient
• Glowing check - Message read recently

Behavior rules:
• Be polite - Use appropriate language
• Respond on time - Don't leave messages unanswered
• Be clear - Explain exactly what you need
• Maintain privacy - Don't share personal information''',
      
      'tutorialChatAdvancedTitle': 'Advanced Functions',
      'tutorialChatAdvancedDescription': 'Advanced chat functions',
      'tutorialChatAdvancedContent': '''Advanced Functions

Edit messages:
1. Long press on a message you sent
2. Select "Edit" from menu
3. Edit the text and save
4. Message will be marked as "Edited"

Delete messages:
1. Long press on a message you sent
2. Select "Delete" from menu
3. Confirm deletion4. Message will be deleted permanently

Close chat:
• When to close - When you don't want to communicate anymore
• How to close - Menu (3 dots) > "Close Chat"
• Reopen - Can reopen a closed chat
• System message - A message will be sent about chat closure

Clear chat:
• Delete history - Menu > "Clear Chat"
• Effect - Deletes all messages
• Cannot be recovered - Final action''',
      
      // Tutorial Center - Profile
      'tutorialProfileSetupTitle': 'Profile Setup',
      'tutorialProfileSetupDescription': 'How to set up your profile',
      'tutorialProfileSetupContent': '''Profile Setup

Basic information:
• Name - Your name (required)
• Email - Email address (required)
• Photo - Profile picture (optional)
• Location - Where you are (required)
• Exposure range - How many km from your location (according to user type)

Exposure ranges in profile:
• Guest: Up to 5 km
• Personal free: Up to 3 km
• Personal subscription: Up to 5 km
• Business subscription: Up to 8 km

Note: Setting fixed location and exposure range is allowed only for users: Guest, Business subscription.

Business information (for business subscribers):
• Business fields - Select as many business fields as you want (Business subscription only)
• Description - Explain your services
• Prices - General price list
• Availability - When you're available

Privacy settings:
• Phone number - If you want it displayed
• Display phone - Consent to display on map (Business subscribers only)
• Notification settings - Which notifications to receive

Trial period extension (Guest users):
If you are a guest user, you can extend the trial period by two weeks by:
1. Sharing the app with 5 friends (WhatsApp, SMS, Email)
2. Rating the app in the store 5 stars
3. Publishing a new request in any field you want

All actions must be completed within one hour of starting the process.

Tips for a good profile:
• Professional photo - Clear and pleasant photo
• Detailed description - Explain what you offer
• Accurate information - Don't write incorrect things
• Regular updates - Update information when it changes
• Accurate location - Update location to receive relevant offers''',
      
      'tutorialSubscriptionTitle': 'Subscriptions and Payments',
      'tutorialSubscriptionDescription': 'How to manage subscription and payments',
      'tutorialSubscriptionContent': '''Subscriptions and Payments

User types and subscriptions:
• Guest - Basic access without payment
• Personal free - Basic access without payment
• Personal subscription - Advanced functions (30₪ per year)
• Business subscription - Service publishing (70₪ per year)

What's included in each type:

Guest:
• Exposure range: 5 km
• View free requests
• Apply to requests (limited)
• Basic chat
• Option to extend trial period with special actions

Personal free:
• Exposure range: 3 km
• View free requests
• Apply to requests (1 request per month)
• Basic chat

Personal subscription (30₪ per year):
• Exposure range: 5 km
• Everything in Personal free +
• Publish requests (5 requests per month)
• View only free requests
• No business fields

Business subscription (70₪ per year):
• Exposure range: 8 km
• Everything in Personal subscription +
• Publish requests (10 requests per month)
• View free and paid requests
• Select business fields (no limit)
• Appearance on service provider map
• Detailed ratings

Important notes:
• Fixed exposure ranges - Each user type gets a fixed maximum range
• No bonuses - Ranges do not change based on recommendations or ratings
• Trial period for guests - Guest users can extend trial period with special actions
• Annual payment - Subscriptions are paid once per year

Payments:
• Payment methods - BIT (PayMe), Credit card (PayMe)
• Annual payment - One-time per year
• Automatic activation - Subscription is activated automatically after payment
• Support - Contact support if there's a problem''',
      
      // Tutorial Center - General
      'tutorialMarkedAsRead': 'Tutorial marked as read',
      'tutorialClose': 'Close',
      'tutorialRead': 'I read',
      'trialPeriodEnded': 'Trial Period Ended',
      'selectBusinessFieldsInProfile': 'To see paid requests, select business fields in your profile.',
      'afterUpdateCanContact': 'After updating your profile, you can contact the publishers through the details shown in the request.',
      // Additional messages from home_screen
      'businessFieldsNotMatch': 'Business fields do not match',
      'requestFromCategory': 'This request is from the field "{category}" and does not match your business fields.',
      'updateBusinessFieldsHint': 'If you want to contact the request creator, you must update your business fields in your profile to match the request category.',
      'updateBusinessFields': 'Edit Business Categories',
      'updateBusinessFieldsTitle': 'Update Business Categories',
      'cancelInterest': 'Cancel Interest',
      'confirm': 'Confirm',
      'afterCancelNoChat': 'After cancellation, you will not be able to see the chat with the request creator.',
      'yesCancelInterest': 'Yes, Cancel Interest',
      'requestFromField': 'This request is in the field "{category}".',
      'updateFieldsToContact': 'If you provide services in this field, you must first update business fields in your profile, then you can contact the request creator.',
      'confirmAction': 'Action Confirmation',
      'selectedNoNotifications': 'You chose not to receive notifications about new requests. Continue?',
      'notificationPermissionRequiredForFilter': 'You must approve receiving notifications to receive notifications for new requests.\n\nIf you do not approve, you will not receive notifications for new requests.',
      'continue': 'Continue',
      'loadingRequestsError': 'Error loading requests',
      // Additional texts from home screen
      'requestsFromAdvertisers': 'My Smart Neighborhood',
      'allRequests': 'All Requests',
      'serviceProviders': 'Service Providers',
      'advancedFilter': 'Request Filter',
      'goToAllRequests': 'Go to All Requests',
      'filterSaved': 'Filter Saved',
      'saveFilter': 'Save Filter',
      'savedFilter': 'Saved Filter',
      'savedFilterFound': 'A saved filter was found from the last time. Would you like to restore it?',
      'allTypes': 'All Types',
      'allSubCategories': 'All Sub-Categories',
      // Status texts from my requests screen
      'statusOpen': 'Open',
      'statusCompleted': 'Completed',
      'statusCancelled': 'Cancelled',
      'statusInProgress': 'In Progress',
      // Chat screen messages
      'helloIAm': 'Hello! I am {name}{badge}',
      'newInField': 'from field {category}',
      'interestedInHelping': 'Interested in helping you with your request. How can I help?',
      'canSendUpTo50Messages': 'You can send up to 50 messages in this chat. System messages are not counted in the limit.',
      'loadingMessages': 'Loading messages...',
      'errorLoadingMessages': 'Error: {error}',
      'messageDeleted': 'Message deleted',
      'messageDeletedSuccessfully': 'Message deleted successfully',
      'errorDeletingMessage': 'Error deleting message',
      'chatClosedCannotSend': 'Chat closed - cannot send messages',
      'closeChat': 'Close Chat',
      'closeChatTitle': 'Close Chat',
      'closeChatMessage': 'Are you sure you want to close the chat? After closing, you will not be able to send additional messages.',
      'reopenChat': 'Reopen Chat',
      'chatClosedBy': 'Chat closed by {name}. Cannot send additional messages.',
      'chatClosedStatus': 'Chat closed',
      'chatClosedSuccessfully': 'Chat closed successfully',
      'chatReopened': 'Chat reopened',
      'chatReopenedBy': 'Chat reopened by {name}.',
      'errorClosingChat': 'Error closing chat',
      // Splash screen
      'initializing': 'Initializing...',
      'ready': 'Ready!',
      'errorInitialization': 'Initialization error: {error}',
      'strongNeighborhoodInAction': 'Strong neighborhood in action',
      // Voice messages
      'recording': 'Recording...',
      'errorLoadingVoiceMessage': 'Error loading voice message: {error}',
      // Trial extension
      'guestPeriodExtendedTwoWeeks': 'Your guest period has been extended by two weeks! 🎉',
      'thankYouForActions': 'Thank you for the actions you took. Your guest period has been extended by 14 days.',
      // My Requests Screen
      'fullScreenMap': 'Map - Full Screen',
      'fixedLocationClickForDetails': 'Fixed location - Click for full details',
      'mobileLocationClickForDetails': 'Mobile location - Click for full details',
      'overallRating': 'Overall rating: {rating}',
      'ratings': 'Ratings:',
      'reliabilityLabel': 'Reliability',
      'availabilityLabel': 'Availability',
      'attitudeLabel': 'Attitude',
      'fairPriceLabel': 'Fair price',
      'navigateToServiceProvider': 'Navigate to service provider location',
      'phone': 'Phone: {phone}',
      'cannotCallNumber': 'Cannot call number: {phone}',
      'errorCalling': 'Error calling: {error}',
      'loadingRequests': 'Loading requests...',
      'errorLoading': 'Error: {error}',
      'openFullScreen': 'Open full screen',
      'refreshMap': 'Refresh map',
      'minimalRatings': 'Minimal ratings:',
      'generalRating': 'General: {rating}+',
      'reliabilityRating': 'Reliability: {rating}+',
      'availabilityRating': 'Availability: {rating}+',
      'attitudeRating': 'Attitude: {rating}+',
      'priceRating': 'Price: {rating}+',
      'helper': 'Helper',
      'chatReopenedCanSend': 'Chat reopened - can send messages',
      'requestReopenedChatsReopened': 'Request reopened and chats reopened',
      'deleteRequestTitle': 'Delete request',
      'deleteRequestConfirm': 'Are you sure you want to delete this request? This action cannot be undone.',
      'requestDeletedSuccess': 'Request deleted successfully',
      'errorDeletingRequest': 'Error deleting request: {error}',
      'deletedImagesFromStorage': 'Deleted {count} images from Storage',
      'errorDeletingImages': 'Error deleting images: {error}',
      'errorOpeningChat': 'Error opening chat: {error}',
      // Home Screen
      'businessNoSubscription': 'Business no subscription',
      'admin': 'Admin',
      'rangeInfo': 'Information about your range',
      'currentRange': 'Your current range: {radius} km',
      'subscriptionType': 'Subscription type: {type}',
      'baseRange': 'Base range: {radius} km',
      'bonuses': 'Bonuses: +{bonus} km',
      'bonusDetails': 'Bonus details:',
      'howToImproveRange': 'How to improve range:',
      'recommendAppBonus': '🎉 Recommend the app to friends (+0.2 km per recommendation)',
      'getHighRatingsBonus': '⭐ Get high ratings (+0.5-1.5 km)',
      'subscriptionRequired': 'Subscription required',
      'subscriptionRequiredMessage': 'To see paid requests, please activate your subscription',
      'businessFieldsRequired': 'Business fields required',
      'businessFieldsRequiredMessage': 'To see paid requests, please select business fields in profile',
      'categoryRestriction': 'Category restriction',
      'categoryRestrictionMessage': 'The business field "{category}" you selected is not one of your business fields. If you want to see paid requests in this category, update your business fields in your profile.',
      'reachedEndOfList': 'Reached end of list',
      'noMoreRequestsAvailable': 'No more requests available',
      // Profile Screen
      'completeYourProfile': 'Complete your profile',
      'completeProfileMessage': 'To get better help, it is recommended to complete the details in your profile: photo, short description, location and exposure range. The maximum range depends on your user type.',
      'whatYouCanDo': 'What you can do:',
      'uploadProfilePicture': 'Upload profile picture',
      'updatePersonalDetails': 'Update personal details',
      'updateLocationAndExposureRange': 'Update location and exposure range',
      'selectSubscriptionTypeIfRelevant': 'Select subscription type (if relevant)',
      'errorUploadingImage': 'Error uploading image',
      'noPermissionToUpload': 'No permission to upload images. Please contact the system administrator.',
      'networkError': 'Network error. Please check your internet connection.',
      'errorStoringImage': 'Error storing image. Please try again.',
      'user': 'User',
      'errorUpdatingLocation': 'Error updating location',
      'errorLocationPermissions': 'Error with location permissions. Please check settings',
      'errorNetworkLocation': 'Network error. Please check your internet connection',
      'timeoutError': 'Timeout. Please try again',
      'deleteFixedLocationTitle': 'Delete fixed location',
      'deleteFixedLocationMessage': 'Are you sure you want to delete the fixed location?\n\nAfter deletion, you will appear on maps only when location service is active on your phone.',
      'selectUpToTwoFields': 'To receive notifications about relevant requests, you must select up to two business fields:',
      'onlyFreeRequestsMessage': 'If you check this option, you will only be able to see free requests on the requests screen.',
      // Payment request messages
      'paymentRequestSentSuccessfully': 'Payment request sent successfully, we will check your request soon!',
      'errorSendingPaymentRequest': 'Error sending payment request. Please try again later.',
      'accountDeletedSuccessfully': 'Account deleted successfully',
      'errorLoggingOutMessage': 'Error logging out: {error}',
      'systemAdminCannotChangeSubscription': 'System administrator cannot change subscription type',
      'pendingRequestExists': 'You have a pending approval request. Cannot send another request.',
      'providerFilterSaved': 'Service provider filter saved',
      'errorDeletingUsers': 'Error deleting users: {error}',
      'requestsDeletedSuccessfully': 'Deleted {count} requests successfully',
      'errorDeletingRequests': 'Error deleting requests: {error}',
      'documentsDeletedSuccessfully': 'Deleted {count} documents from collections successfully.{errors}',
      'errorDeletingCollections': 'Error deleting collections: {error}',
      'systemAdmin': 'System administrator - Full access to all functions (Business subscription)',
      'manageUsers': 'Manage users',
      'requestStatistics': 'Request statistics',
      'deleteAllUsers': 'Delete all users',
      'deleteAllRequests': 'Delete all requests',
      'deleteAllCollections': 'Delete all collections',
      'subscription': 'Subscription',
      'privateSubscriptionType': 'Private subscription',
      'businessSubscriptionType': 'Business subscription',
      'rejectionReason': 'Reason: {reason}',
      'remainingRequests': 'You only have {count} requests left!',
      'wantMoreUpgrade': 'Want more? Upgrade subscription',
      'guest': 'Guest',
      // Share Service
      'interestingRequestInApp': '🎯 Interesting request in "Shchunati"!',
      'locationNotSpecified': 'Location not specified',
      'wantToHelpDownloadApp': '💡 Want to help? Download the "Shchunati" app and contact directly!',
      // App Sharing Service
      'appDescription': '"Shchunati" - The app that connects neighbors for real mutual help',
      'yourRangeIncreased': 'Your range has increased!',
      'chooseHowToShareApp': 'Choose how you want to share the app:',
      'sendToWhatsApp': 'Send to friends on WhatsApp',
      'shareOnMessenger': 'Send on Messenger',
      'shareOnInstagram': 'Share on Instagram',
      // Chat screen additional
      'communicationWithServiceProvider': 'Communication with service provider',
      'communicationWithServiceProviderMessage': 'Here you can communicate with the service provider, ask questions and coordinate details.',
      'messageOptions': 'Message options',
      'whatDoYouWantToDoWithMessage': 'What do you want to do with the message?',
      'editMessage': 'Edit message',
      'typeNewMessage': 'Type the new message...',
      'messageEditedSuccessfully': 'Message edited successfully',
      'errorEditingMessage': 'Error editing message: {error}',
      'deleteMessageTitle': 'Delete message',
      'deleteMessageConfirm': 'Are you sure you want to delete the message?',
      'deleteChat': 'Delete chat',
      'errorSendingVoiceMessage': 'Error sending voice message: {error}',
      'reached50MessageLimit': 'Reached 50 message limit - cannot send more messages',
      'warningMessagesRemaining': 'Warning: Only {count} messages remaining',
      'errorSendingMessage': 'Error sending message: {error}',
      'deleteChatTitle': 'Delete chat',
      'deleteChatConfirm': 'Are you sure you want to delete the chat? This action cannot be undone.',
      'chatDeletedSuccessfully': 'Chat deleted successfully',
      'errorDeletingChat': 'Error deleting chat: {error}',
      'cannotReopenChatDeletedByRequester': 'Cannot reopen chat - chat was deleted by the requester',
      'cannotReopenChatDeletedByProvider': 'Cannot reopen chat - chat was deleted by the service provider',
      'deleteMyMessagesConfirm': 'Are you sure you want to delete your messages?\nThe other user will continue to see their messages.',
      'myMessagesDeletedSuccessfully': 'Your messages deleted successfully',
      'errorDeletingMyMessages': 'Error deleting messages: {error}',
      // Network aware widget
      'connectionRestored': 'Connection restored!',
      'stillNoConnection': 'Still no connection',
      'processing': 'Processing...',
      'noInternetConnection': 'No internet connection',
      // Tutorial dialog
      'dontShowAgain': 'Don\'t show again',
      // Urgency tags
      'tagSuddenLeak': '❗ Sudden leak',
      'tagPowerOutage': '⚡ Power outage',
      'tagLockedOut': '🔒 Locked out',
      'tagUrgentBeforeShabbat': '🔧 Urgent repair before Shabbat',
      'tagCarStuck': '🚨 Car stuck on road',
      'tagJumpStart': '🔋 Jump start / Cables',
      'tagQuickParkingRepair': '🧰 Quick parking repair',
      'tagMovingToday': '🧳 Moving help today',
      'tagUrgentBabysitter': '🍼 Urgent babysitter',
      'tagExamTomorrow': '📚 Lesson before exam tomorrow',
      'tagSickChild': '🧸 Help with sick child',
      'tagZoomLessonNow': '👩‍🏫 Zoom lesson now',
      'tagUrgentDocument': '📄 Urgent document',
      'tagMeetingToday': '🤝 Meeting today',
      'tagPresentationTomorrow': '📊 Presentation tomorrow',
      'tagUrgentTranslation': '🌐 Urgent translation',
      'tagWeddingToday': '💒 Wedding today',
      'tagUrgentGift': '🎁 Urgent gift',
      'tagEventTomorrow': '🎉 Event tomorrow',
      'tagUrgentCraftRepair': '🔧 Urgent craft repair',
      'tagUrgentAppointment': '🏥 Urgent appointment',
      'tagEmergencyCare': '🚑 Emergency care',
      'tagUrgentTherapy': '💆 Urgent therapy',
      'tagHealthEmergency': '⚕️ Health emergency',
      'tagUrgentITSupport': '💻 Urgent IT support',
      'tagSystemDown': '🖥️ System down',
      'tagUrgentTechRepair': '🔧 Urgent tech repair',
      'tagDataRecovery': '💾 Data recovery',
      'tagUrgentTutoring': '📖 Urgent tutoring',
      'tagExamPreparation': '📝 Exam preparation',
      'tagUrgentCourse': '🎓 Urgent course',
      'tagCertificationUrgent': '🏆 Urgent certification',
      'tagPartyToday': '🎊 Party today',
      'tagUrgentEntertainment': '🎭 Urgent entertainment',
      'tagEventSetup': '🎪 Event setup',
      'tagUrgentPhotography': '📸 Urgent photography',
      'tagUrgentGardenCare': '🌱 Urgent garden care',
      'tagTreeEmergency': '🌳 Tree emergency',
      'tagUrgentCleaning': '🧹 Urgent cleaning',
      'tagPestControl': '🐛 Pest control',
      'tagUrgentCatering': '🍽️ Urgent catering',
      'tagPartyFood': '🍕 Party food',
      'tagUrgentDelivery': '🚚 Urgent delivery',
      'tagSpecialDiet': '🥗 Special diet',
      'tagUrgentTraining': '💪 Urgent training',
      'tagCompetitionPrep': '🏆 Competition preparation',
      'tagInjuryRecovery': '🩹 Injury recovery',
      'tagUrgentCoaching': '🏃 Urgent coaching',
      'tagEventToday': '🎉 Event today',
      'tagUrgentBeforeEvent': '💄 Urgent before event',
      'tagUrgentBeautyFix': '✨ Urgent beauty fix',
      'tagUrgentPurchase': '🛒 Urgent purchase',
      'tagUrgentSale': '💰 Urgent sale',
      'tagEventShopping': '🎁 Shopping for event today',
      'tagUrgentProduct': '📦 Urgent product',
      'tagUrgentDeliveryToday': '📦 Urgent delivery today',
      'tagUrgentMoving': '🚚 Urgent moving',
      'tagUrgentRoadRepair': '🔧 Urgent road repair',
      'tagUrgentTowing': '🚛 Urgent towing',
      'tagUrgentPostRenovation': '🧹 Urgent post-renovation cleaning',
      'tagUrgentConsultation': '💼 Urgent consultation',
      'tagUrgentMeeting': '🤝 Urgent meeting',
      'tagUrgentElderlyHelp': '👴 Urgent elderly help',
      'tagUrgentVolunteering': '❤️ Urgent volunteering',
      'tagUrgentPetCare': '🐾 Urgent pet care',
      // Service providers count dialog
      'noServiceProvidersInCategory': 'No service providers in this category yet',
      'serviceProvidersInCategory': 'Number of service providers in this category: {count}',
      'noServiceProvidersInCategoryMessage': 'There are no service providers from the category you selected yet.',
      'theFieldYouSelected': 'the field you selected',
      'confirmMinimalRadius': 'Confirm Minimal Radius',
      'minimalRadiusWarning': 'The range you selected is only 0.1 km. This is a very small range that will limit the exposure of your request. Are you sure you want to continue with this range?',
      'allRequestsFromCategory': 'All requests from {category} field',
      'serviceProvidersInCategoryMessage': 'Found {count} available service providers in this category.',
      'continueCreatingRequestMessage': 'Continue creating the request - service providers from this category will be added in the future.',
      'helpGrowCommunity': 'Help us grow the community!',
      'shareAppToGrowProviders': 'Share the app with friends and colleagues so more service providers can join.',
      // New request screen
      'selectCategory': 'Select category',
      'pleaseSelectCategoryFirst': 'Please select a category first',
      'title': 'Title',
    },
  };

  String get appTitle => _safeGet('appTitle', fallback: 'Neighborhood');
  String get hello => _safeGet('hello', fallback: 'Hello');
  String helloName(String name) {
    final template = _safeGet('helloName', fallback: 'Hello, {name}');
    return template.replaceAll('{name}', name);
  }
  String get connected => _safeGet('connected', fallback: 'Connected');
  String get notConnected => _safeGet('notConnected', fallback: 'Not Connected');
  String get disconnected => _safeGet('disconnected', fallback: 'Disconnected');
  String get welcomeBack => _safeGet('welcomeBack', fallback: 'Welcome back');
  String get welcome => _safeGet('welcome', fallback: 'Welcome');
  String get welcomeSubtitle => _safeGet('welcomeSubtitle', fallback: 'Welcome, register as a guest for 3 months free and get full access to all services');
  String get joinCommunity => _safeGet('joinCommunity', fallback: 'Join our community');
  String get continueWithGoogle => _safeGet('continueWithGoogle', fallback: 'Continue with Google');
  String get loginWithShchunati => _safeGet('loginWithShchunati', fallback: 'Login with Neighborhood');
  String get continueWithoutRegistration => _safeGet('continueWithoutRegistration', fallback: 'Continue without Registration');
  String get pleaseRegisterFirst => _safeGet('pleaseRegisterFirst', fallback: 'You must register first to perform this action');
  String get or => _safeGet('or', fallback: 'or');
  String get byContinuingYouAgree => _safeGet('byContinuingYouAgree', fallback: 'By continuing to use the app, you agree to:');
  String get termsOfService => _safeGet('termsOfService', fallback: 'Terms of Service');
  String get privacyPolicy => _safeGet('privacyPolicy', fallback: 'Privacy Policy');
  String get termsButton => _safeGet('termsButton', fallback: 'Terms of Service');
  String get privacyButton => _safeGet('privacyButton', fallback: 'Privacy Policy');
  String get termsAndPrivacyButton => _safeGet('termsAndPrivacyButton', fallback: 'Terms of Use and Privacy Policy');
  String get copyright => _safeGet('copyright', fallback: '© 2025 Shchunati. All rights reserved.');
  String get aboutButton => _safeGet('aboutButton', fallback: 'About the App');
  String get aboutTitle => _safeGet('aboutTitle', fallback: 'About Shchunati App');
  String get aboutAppName => _safeGet('aboutAppName', fallback: 'Shchunati');
  String get aboutDescription => _safeGet('aboutDescription', fallback: 'Shchunati app is a digital platform connecting service seekers with service providers in the local community. The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel. The app operates as a mediator only and does not interfere with transactions or services between users.');
  String get aboutVersion => _safeGet('aboutVersion', fallback: 'Version');
  String get aboutSupport => _safeGet('aboutSupport', fallback: 'Support');
  String get aboutSupportDescription => _safeGet('aboutSupportDescription', fallback: 'For questions, issues, or requests, please contact support');
  String get aboutSupportEmail => _safeGet('aboutSupportEmail', fallback: 'support@shchunati.com');
  String get aboutSupportSubject => _safeGet('aboutSupportSubject', fallback: 'Question/Request - Shchunati App');
  String get aboutClickToContact => _safeGet('aboutClickToContact', fallback: 'Click to contact');
  String get aboutLegalTitle => _safeGet('aboutLegalTitle', fallback: 'Legal Documents');
  String get aboutFooter => _safeGet('aboutFooter', fallback: '© 2025 Shchunati. All rights reserved.');
  String get newRegistration => _safeGet('newRegistration', fallback: 'New Registration');
  String get forgotPassword => _safeGet('forgotPassword', fallback: 'Forgot Password');
  String get pleaseEnterEmail => _safeGet('pleaseEnterEmail', fallback: 'Please enter email address');
  String get verifyEmailBelongsToYou => _safeGet('verifyEmailBelongsToYou', fallback: 'Make sure the email belongs to you! If you enter someone else\'s email, they will receive the password reset link.');
  String get sendLink => _safeGet('sendLink', fallback: 'Send Link');
  String passwordResetLinkSentTo(String email) {
    final template = _safeGet('passwordResetLinkSentTo', fallback: 'Password reset link sent to ');
    return template + email;
  }
  String get applyingLanguage => _safeGet('applyingLanguage', fallback: 'Applying language...');
  String get fullName => _safeGet('fullName', fallback: 'Full Name');
  String get email => _safeGet('email', fallback: 'Email');
  String get password => _safeGet('password', fallback: 'Password');
  String get emailAndPassword => _safeGet('emailAndPassword', fallback: 'Email and Password');
  String get yourAccount => _safeGet('yourAccount', fallback: 'Your Account');
  String get userType => _safeGet('userType', fallback: 'User Type');
  String get personal => _safeGet('personal', fallback: 'Personal');
  String get business => _safeGet('business', fallback: 'Business');
  String get limitedAccess => _safeGet('limitedAccess', fallback: 'Limited Access');
  String get fullAccess => _safeGet('fullAccess', fallback: 'Full Access');
  String get register => _safeGet('register', fallback: 'Register');
  String get login => _safeGet('login', fallback: 'Login');
  String get alreadyHaveAccount => _safeGet('alreadyHaveAccount', fallback: 'Already have an account? Login');
  String get noAccount => _safeGet('noAccount', fallback: 'Don\'t have an account? Register');
  String get home => _safeGet('home', fallback: 'Home');
  String get notifications => _safeGet('notifications', fallback: 'Notifications');
  String get chat => _safeGet('chat', fallback: 'Chat');
  String get profile => _safeGet('profile', fallback: 'Profile');
  String get myRequests => _safeGet('myRequests', fallback: 'My Requests in Progress');
  String get myRequestsMenu => _safeGet('myRequestsMenu', fallback: 'My Requests');
  String get serviceProviders => _safeGet('serviceProviders', fallback: 'Service Providers');
  String get openRequestsForTreatment => _safeGet('openRequestsForTreatment', fallback: 'Open Requests for Treatment');
  String get newRequest => _safeGet('newRequest', fallback: 'New Request');
  String get logout => _safeGet('logout', fallback: 'Logout');
  String get language => _safeGet('language', fallback: 'Language');
  String get selectLanguage => _safeGet('selectLanguage', fallback: 'Select Language');
  String get hebrew => _safeGet('hebrew', fallback: 'Hebrew');
  String get arabic => _safeGet('arabic', fallback: 'Arabic');
  String get english => _safeGet('english', fallback: 'English');
  String get theme => _safeGet('theme', fallback: 'Theme');
  String get lightTheme => _safeGet('lightTheme', fallback: 'Light');
  String get darkTheme => _safeGet('darkTheme', fallback: 'Dark');
  String get systemTheme => _safeGet('systemTheme', fallback: 'System');
  String get goldTheme => _safeGet('goldTheme', fallback: 'Gold');
  String get searchHint => _safeGet('searchHint', fallback: 'Search requests...');
  String get searchProvidersHint => _safeGet('searchProvidersHint', fallback: 'Search businesses and freelancers...');
  String get location => _safeGet('location', fallback: 'Location');
  String get nearMe => _safeGet('nearMe', fallback: 'Near me');
  String get wholeVillage => _safeGet('wholeVillage', fallback: 'Whole village');
  String get city => _safeGet('city', fallback: 'Whole city');
  String get category => _safeGet('category', fallback: 'Category');
  String get all => _safeGet('all', fallback: 'All');
  String get maintenance => _safeGet('maintenance', fallback: 'Maintenance');
  String get education => _safeGet('education', fallback: 'Education');
  String get transport => _safeGet('transport', fallback: 'Transport');
  String get shopping => _safeGet('shopping', fallback: 'Shopping');
  String get urgent => _safeGet('urgent', fallback: 'Urgent');
  String get canHelp => _safeGet('canHelp', fallback: 'I can help');
  String get requestTitleExample => _safeGet('requestTitleExample', fallback: 'Need faucet repair');
  String get requestDescriptionExample => _safeGet('requestDescriptionExample', fallback: 'Kitchen faucet is leaking, need plumber');
  String get requestTitle2 => _safeGet('requestTitle2', fallback: 'Math lesson');
  String get requestDescription2 => _safeGet('requestDescription2', fallback: 'Looking for private math tutor for 10th grade');
  String get requestTitle3 => _safeGet('requestTitle3', fallback: 'Small transport');
  String get requestDescription3 => _safeGet('requestDescription3', fallback: 'Need help transporting small furniture');
  String get enterName => _safeGet('enterName', fallback: 'Please enter full name');
  String get enterEmail => _safeGet('enterEmail', fallback: 'Please enter email');
  String get invalidEmail => _safeGet('invalidEmail', fallback: 'Invalid email');
  String get enterPassword => _safeGet('enterPassword', fallback: 'Please enter password');
  String get weakPassword => _safeGet('weakPassword', fallback: 'Password too weak');
  String get signUpSuccess => _safeGet('signUpSuccess', fallback: 'Registered successfully! Now login with your details');
  String get loginSuccess => _safeGet('loginSuccess', fallback: 'Logged in successfully!');
  String get error => _safeGet('error', fallback: 'Error');
         String get ok => _safeGet('ok', fallback: 'OK');
         String get noResults => _safeGet('noResults', fallback: 'No results found for');
         String get noRequests => _safeGet('noRequests', fallback: 'No requests available');
         String get save => _safeGet('save', fallback: 'Save');
         String get enterTitle => _safeGet('enterTitle', fallback: 'Please enter title');
         String get enterDescription => _safeGet('enterDescription', fallback: 'Please enter description');
         String get images => _safeGet('images', fallback: 'Images');
         String get addImages => _safeGet('addImages', fallback: 'Add Images');
         String get clear => _safeGet('clear', fallback: 'Clear');
         String get requestTitle => _safeGet('requestTitle', fallback: 'Request Title');
         String get requestDescription => _safeGet('requestDescription', fallback: 'Request Description');
         String get sendMessage => _safeGet('sendMessage', fallback: 'Send Message');
         String get noMessages => _safeGet('noMessages', fallback: 'No Messages');
         String get you => _safeGet('you', fallback: 'You');
         String get otherUser => _safeGet('otherUser', fallback: 'Other User');
         String get phoneNumber => _safeGet('phoneNumber', fallback: 'Phone Number');
         String get enterPhoneNumber => _safeGet('enterPhoneNumber', fallback: 'Enter phone number (optional)');
         String get clearChat => _safeGet('clearChat', fallback: 'Clear Chat');
         String get clearChatConfirm => _safeGet('clearChatConfirm', fallback: 'Are you sure you want to delete all messages in the chat?');
         String get cancel => _safeGet('cancel', fallback: 'Cancel');
         String get delete => _safeGet('delete', fallback: 'Delete');
         String get chatCleared => _safeGet('chatCleared', fallback: 'Chat cleared successfully');
         String get open => _safeGet('open', fallback: 'Open');
         String get inProgress => _safeGet('inProgress', fallback: 'In Progress');
         String get completed => _safeGet('completed', fallback: 'Completed');
         String get cancelled => _safeGet('cancelled', fallback: 'Cancelled');
         String get free => _safeGet('free', fallback: 'Free');
         String get paid => _safeGet('paid', fallback: 'Paid');
         String get deadline => _safeGet('deadline', fallback: 'Deadline');
         String get selectDeadline => _safeGet('selectDeadline', fallback: 'Select Deadline');
         String get targetAudience => _safeGet('targetAudience', fallback: 'Target Audience');
         String get distance => _safeGet('distance', fallback: 'Distance');
         String get maxDistance => _safeGet('maxDistance', fallback: 'Max Distance (km)');
         String get selectVillage => _safeGet('selectVillage', fallback: 'Select Village');
         String get selectCategories => _safeGet('selectCategories', fallback: 'Select Categories');
         String get requestType => _safeGet('requestType', fallback: 'Request Type');
         String get selectRequestType => _safeGet('selectRequestType', fallback: 'Select Request Type');
         String get selectTargetAudience => _safeGet('selectTargetAudience', fallback: 'Select Target Audience');
         String get allCategories => _safeGet('allCategories', fallback: 'All Categories');
         String get expired => _safeGet('expired', fallback: 'Expired');
         String get editRequest => _safeGet('editRequest', fallback: 'Edit Request');
         String get deleteRequest => _safeGet('deleteRequest', fallback: 'Delete Request');
         String get confirmDelete => _safeGet('confirmDelete', fallback: 'Are you sure you want to delete this request?');
         String get requestDeleted => _safeGet('requestDeleted', fallback: 'Request deleted successfully');
         String get requestUpdated => _safeGet('requestUpdated', fallback: 'Request updated successfully');
         String get newMessage => _safeGet('newMessage', fallback: 'New Message');
         String get unreadMessages => _safeGet('unreadMessages', fallback: 'Unread Messages');
  String get publishAllTypes => _safeGet('publishAllTypes', fallback: 'Publish all types of requests');
  String get respondFreeOnly => _safeGet('respondFreeOnly', fallback: 'Respond only to free requests');
  String get respondFreeAndPaid => _safeGet('respondFreeAndPaid', fallback: 'Respond to free and paid requests according to your business field');
  String get businessCategories => _safeGet('businessCategories', fallback: 'Business Categories');
  String get selectBusinessCategories => _safeGet('selectBusinessCategories', fallback: 'Select Business Categories');
  String get availability => _safeGet('availability', fallback: 'Availability');
  String get availabilityDescription => _safeGet('availabilityDescription', fallback: 'Your work days and hours');
  String get availableAllWeek => _safeGet('availableAllWeek', fallback: 'Available all week');
  String get editAvailability => _safeGet('editAvailability', fallback: 'Edit Availability');
  String get selectDaysAndHours => _safeGet('selectDaysAndHours', fallback: 'Select Days and Hours');
  String get day => _safeGet('day', fallback: 'Day');
  String get startTime => _safeGet('startTime', fallback: 'Start Time');
  String get endTime => _safeGet('endTime', fallback: 'End Time');
  String get selectTime => _safeGet('selectTime', fallback: 'Select Time');
  String get availabilityUpdated => _safeGet('availabilityUpdated', fallback: 'Availability updated successfully');
  String get errorUpdatingAvailability => _safeGet('errorUpdatingAvailability', fallback: 'Error updating availability');
  String get noAvailabilityDefined => _safeGet('noAvailabilityDefined', fallback: 'No availability defined');
  String get daySunday => _safeGet('daySunday', fallback: 'Sunday');
  String get dayMonday => _safeGet('dayMonday', fallback: 'Monday');
  String get dayTuesday => _safeGet('dayTuesday', fallback: 'Tuesday');
  String get dayWednesday => _safeGet('dayWednesday', fallback: 'Wednesday');
  String get dayThursday => _safeGet('dayThursday', fallback: 'Thursday');
  String get dayFriday => _safeGet('dayFriday', fallback: 'Friday');
  String get daySaturday => _safeGet('daySaturday', fallback: 'Saturday');
  String get subscriptionPayment => _safeGet('subscriptionPayment', fallback: 'Subscription Payment');
  String get payWithBit => _safeGet('payWithBit', fallback: 'Pay with Bit');
  String get annualSubscription => _safeGet('annualSubscription', fallback: 'Annual Subscription - 10 NIS');
  String get subscriptionDescription => _safeGet('subscriptionDescription', fallback: 'Access to paid requests according to your business fields');
  String get activateSubscription => _safeGet('activateSubscription', fallback: 'Activate Subscription');
  String get subscriptionStatus => _safeGet('subscriptionStatus', fallback: 'Subscription Status');
  String get active => _safeGet('active', fallback: 'Active');
  String get inactive => _safeGet('inactive', fallback: 'Inactive');
  String get expiryDate => _safeGet('expiryDate', fallback: 'Expiry Date');
  // Error messages
  String get emailNotRegistered => _safeGet('emailNotRegistered', fallback: 'This email is not registered in the system');
  String get wrongPassword => _safeGet('wrongPassword', fallback: 'The password is incorrect');
  String get emailAlreadyRegistered => _safeGet('emailAlreadyRegistered', fallback: 'This email is already registered in the system');
  String get userAlreadyRegistered => _safeGet('userAlreadyRegistered', fallback: 'This user is already registered in the system');
  String get userAlreadyRegisteredPleaseLogin => _safeGet('userAlreadyRegisteredPleaseLogin', fallback: 'This user is already registered in the system. Please login with your email and password');
  String get emailOrPasswordWrong => _safeGet('emailOrPasswordWrong', fallback: 'The email or password is incorrect');
  String get loginError => _safeGet('loginError', fallback: 'Login error');
  String get retry => _safeGet('retry', fallback: 'Try again');
  String get registrationError => _safeGet('registrationError', fallback: 'Registration error');
  // Success messages
  String get loggedInSuccessfully => _safeGet('loggedInSuccessfully', fallback: 'Logged in successfully!');
  String get registeredSuccessfully => _safeGet('registeredSuccessfully', fallback: 'Registered successfully! Now login with your details');
  String get googleLoginSuccess => _safeGet('googleLoginSuccess', fallback: 'Successfully logged in with Google!');
  // Additional getters
  String get userGuide => _safeGet('userGuide', fallback: 'User Guide');
  String get managePayments => _safeGet('managePayments', fallback: 'Manage Cash Payments');
  String get payCash => _safeGet('payCash', fallback: 'Pay in Cash');
  String get cashPayment => _safeGet('cashPayment', fallback: 'Cash Payment');
  String get sendPaymentRequest => _safeGet('sendPaymentRequest', fallback: 'Send Payment Request');
  String get manageCashPayments => _safeGet('manageCashPayments', fallback: 'Manage Cash Payments');
  String get logoutTitle => _safeGet('logoutTitle', fallback: 'Logout');
  String get logoutMessage => _safeGet('logoutMessage', fallback: 'Are you sure you want to logout?');
  String get logoutButton => _safeGet('logoutButton', fallback: 'Logout');
  String errorLoggingOut(String error) {
    final template = _safeGet('errorLoggingOut', fallback: 'Error logging out: {error}');
    return template.replaceAll('{error}', error);
  }
  String errorLoggingOutMessage(String error) {
    final template = _safeGet('errorLoggingOutMessage', fallback: 'Error logging out: {error}');
    return template.replaceAll('{error}', error);
  }
  String get paymentRequestSentSuccessfully => _safeGet('paymentRequestSentSuccessfully', fallback: 'Payment request sent successfully, we will check your request soon!');
  String get errorSendingPaymentRequest => _safeGet('errorSendingPaymentRequest', fallback: 'Error sending payment request. Please try again later.');
  String get accountDeletedSuccessfully => _safeGet('accountDeletedSuccessfully', fallback: 'Account deleted successfully');
  String get systemAdminCannotChangeSubscription => _safeGet('systemAdminCannotChangeSubscription', fallback: 'System administrator cannot change subscription type');
  String get pendingRequestExists => _safeGet('pendingRequestExists', fallback: 'You have a pending approval request. Cannot send another request.');
  String get providerFilterSaved => _safeGet('providerFilterSaved', fallback: 'Service provider filter saved');
  String errorDeletingUsers(String error) {
    final template = _safeGet('errorDeletingUsers', fallback: 'Error deleting users: {error}');
    return template.replaceAll('{error}', error);
  }
  String requestsDeletedSuccessfully(int count) {
    final template = _safeGet('requestsDeletedSuccessfully', fallback: 'Deleted {count} requests successfully');
    return template.replaceAll('{count}', count.toString());
  }
  String errorDeletingRequests(String error) {
    final template = _safeGet('errorDeletingRequests', fallback: 'Error deleting requests: {error}');
    return template.replaceAll('{error}', error);
  }
  String documentsDeletedSuccessfully(int count, String errors) {
    final template = _safeGet('documentsDeletedSuccessfully', fallback: 'Deleted {count} documents from collections successfully.{errors}');
    return template.replaceAll('{count}', count.toString()).replaceAll('{errors}', errors);
  }
  String errorDeletingCollections(String error) {
    final template = _safeGet('errorDeletingCollections', fallback: 'Error deleting collections: {error}');
    return template.replaceAll('{error}', error);
  }
  String get monthlyLimitReached => _safeGet('monthlyLimitReached', fallback: 'Monthly Request Limit Reached');
  String monthlyLimitMessage(int count) {
    final template = _safeGet('monthlyLimitMessage', fallback: 'You have reached your monthly request limit ({count} requests).');
    return template.replaceAll('{count}', count.toString());
  }
  String get youCan => _safeGet('youCan', fallback: 'You can:');
  String waitForNextMonth(String date) {
    final template = _safeGet('waitForNextMonth', fallback: 'Wait for next month starting on {date}');
    return template.replaceAll('{date}', date);
  }
  String get upgradeSubscription => _safeGet('upgradeSubscription', fallback: 'Upgrade subscription to get more monthly requests');
  String get upgradeSubscriptionInProfile => _safeGet('upgradeSubscriptionInProfile', fallback: 'Upgrade Subscription in Profile');
  // Additional messages
  String get welcomeMessage => _safeGet('welcomeMessage', fallback: 'Welcome!');
  String get welcomeToApp => _safeGet('welcomeToApp', fallback: 'Welcome to "Neighborhood" app!');
  String get fillAllFields => _safeGet('fillAllFields', fallback: 'Please fill in all fields');
  String get rememberMe => _safeGet('rememberMe', fallback: 'Remember me');
  String get saveCredentialsQuestion => _safeGet('saveCredentialsQuestion', fallback: 'Would you like to save your login credentials?');
  String get saveCredentialsInfo => _safeGet('saveCredentialsInfo', fallback: 'If you choose yes, you can login automatically next time');
  String get saveCredentialsText => _safeGet('saveCredentialsText', fallback: 'Save my login credentials');
  String get autoLoginText => _safeGet('autoLoginText', fallback: 'I want to login automatically next time');
  String get noThanks => _safeGet('noThanks', fallback: 'No, thanks');
  String get requestsFromNeighborhood => _safeGet('requestsFromNeighborhood', fallback: 'Requests from neighborhood');
  String get allNotificationsInNeighborhood => _safeGet('allNotificationsInNeighborhood', fallback: 'All notifications in my neighborhood');
  String get manageNotifications => _safeGet('manageNotifications', fallback: 'Manage all notifications');
  String get notificationOptions => _safeGet('notificationOptions', fallback: 'Various options for receiving notifications about new requests');
  // Getters for manage notifications screen
  String errorLoadingPreferences(String error) {
    final template = _safeGet('errorLoadingPreferences', fallback: 'Error loading preferences: {error}');
    return template.replaceAll('{error}', error);
  }
  String get requestLocationInRangeFixed => _safeGet('requestLocationInRangeFixed', fallback: 'When the request location is within my exposure range and my fixed location');
  String get requestLocationInRangeMobile => _safeGet('requestLocationInRangeMobile', fallback: 'When the request location is within my exposure range and my mobile location');
  String get requestLocationInRangeFixedOrMobile => _safeGet('requestLocationInRangeFixedOrMobile', fallback: 'When the request location is within my exposure range and my fixed or mobile location');
  String get notInterestedInPaidRequestNotifications => _safeGet('notInterestedInPaidRequestNotifications', fallback: 'Not interested in receiving notifications about new paid requests');
  String get subscriptionNotifications => _safeGet('subscriptionNotifications', fallback: 'Subscription Notifications');
  String get whenSubscriptionExpires => _safeGet('whenSubscriptionExpires', fallback: 'When my subscription period expires');
  String get subscriptionReminderBeforeExpiry => _safeGet('subscriptionReminderBeforeExpiry', fallback: 'Reminder before subscription period ends (one week before)');
  String get guestPeriodExtensionTwoWeeks => _safeGet('guestPeriodExtensionTwoWeeks', fallback: 'Guest period extension for two weeks free');
  String get subscriptionUpgrade => _safeGet('subscriptionUpgrade', fallback: 'Subscription Upgrade');
  String get requestStatusNotifications => _safeGet('requestStatusNotifications', fallback: 'Request Status and Data Notifications');
  String get interestInRequest => _safeGet('interestInRequest', fallback: 'Interest/No Interest in Request');
  String get newChatMessages => _safeGet('newChatMessages', fallback: 'New Chat Messages');
  String get serviceCompletionAndRating => _safeGet('serviceCompletionAndRating', fallback: 'Service Completion and Rating');
  String get radiusExpansionShareRating => _safeGet('radiusExpansionShareRating', fallback: 'Radius Expansion (Share/Rating)');
  // Getters for notifications screen
  String get userNotConnected => _safeGet('userNotConnected', fallback: 'User not connected');
  String get clearAllNotifications => _safeGet('clearAllNotifications', fallback: 'Clear all notifications');
  String get markAllAsRead => _safeGet('markAllAsRead', fallback: 'Mark all as read');
  String get notificationsBlocked => _safeGet('notificationsBlocked', fallback: 'Notifications blocked - Please enable notification permissions in phone settings');
  String get enableNotifications => _safeGet('enableNotifications', fallback: 'Enable Notifications');
  String errorMessage(String error) {
    final template = _safeGet('errorMessage', fallback: 'Error: {error}');
    return template.replaceAll('{error}', error);
  }
  String get noNewNotifications => _safeGet('noNewNotifications', fallback: 'No new notifications');
  String get notificationInfo => _safeGet('notificationInfo', fallback: 'When someone responds to your requests or offers help,\nyou will receive a notification here');
  String get openRequest => _safeGet('openRequest', fallback: 'Open Request');
  String errorUpdatingNotification(String error) {
    final template = _safeGet('errorUpdatingNotification', fallback: 'Error updating notification: {error}');
    return template.replaceAll('{error}', error);
  }
  String get allNotificationsMarkedAsRead => _safeGet('allNotificationsMarkedAsRead', fallback: 'All notifications marked as read');
  String errorUpdatingNotifications(String error) {
    final template = _safeGet('errorUpdatingNotifications', fallback: 'Error updating notifications: {error}');
    return template.replaceAll('{error}', error);
  }
  String get clearAllNotificationsTitle => _safeGet('clearAllNotificationsTitle', fallback: 'Clear all notifications');
  String get clearAllNotificationsMessage => _safeGet('clearAllNotificationsMessage', fallback: 'Are you sure you want to delete all notifications? This action cannot be undone.');
  String get clearAll => _safeGet('clearAll', fallback: 'Clear All');
  String get allNotificationsDeletedSuccessfully => _safeGet('allNotificationsDeletedSuccessfully', fallback: 'All notifications deleted successfully');
  String errorDeletingNotifications(String error) {
    final template = _safeGet('errorDeletingNotifications', fallback: 'Error deleting notifications: {error}');
    return template.replaceAll('{error}', error);
  }
  String get deleteNotification => _safeGet('deleteNotification', fallback: 'Delete Notification');
  String deleteNotificationMessage(String title) {
    final template = _safeGet('deleteNotificationMessage', fallback: 'Are you sure you want to delete the notification "{title}"?');
    return template.replaceAll('{title}', title);
  }
  String get notificationDeletedSuccessfully => _safeGet('notificationDeletedSuccessfully', fallback: 'Notification deleted successfully');
  String errorDeletingNotification(String error) {
    final template = _safeGet('errorDeletingNotification', fallback: 'Error deleting notification: {error}');
    return template.replaceAll('{error}', error);
  }
  String get now => _safeGet('now', fallback: 'Now');
  String minutesAgo(int count) {
    final template = _safeGet('minutesAgo', fallback: '{count} minutes ago');
    return template.replaceAll('{count}', count.toString());
  }
  String hoursAgo(int count) {
    final template = _safeGet('hoursAgo', fallback: '{count} hours ago');
    return template.replaceAll('{count}', count.toString());
  }
  String daysAgo(int count) {
    final template = _safeGet('daysAgo', fallback: '{count} days ago');
    return template.replaceAll('{count}', count.toString());
  }
  // Additional messages
  String get understood => _safeGet('understood', fallback: 'Understood');
  String get openTutorial => _safeGet('openTutorial', fallback: 'Open Tutorial');
  // Terms and Privacy
  String get termsAndPrivacyTitle => _safeGet('termsAndPrivacyTitle', fallback: 'Terms of Service and Privacy Policy');
  String get welcomeToTermsScreen => _safeGet('welcomeToTermsScreen', fallback: 'Welcome to our app');
  String get agreeAndContinue => _safeGet('agreeAndContinue', fallback: 'Agree and Continue');
  String get doNotAgree => _safeGet('doNotAgree', fallback: 'Do Not Agree');
  String get importantNote => _safeGet('importantNote', fallback: 'Important to Know');
  String get termsMayBeUpdated => _safeGet('termsMayBeUpdated', fallback: 'The Terms of Service and Privacy Policy may be updated from time to time.\nYou can find the most current version in the app.');
  String get byContinuingYouConfirm => _safeGet('byContinuingYouConfirm', fallback: 'By continuing to use the app, you confirm that you have read and understood the Terms of Service and Privacy Policy, and you agree to them.');
  String get mustAcceptTerms => _safeGet('mustAcceptTerms', fallback: 'Important: You must accept the Terms of Service and Privacy Policy to continue using the app.');
  // Terms of Service
  String get termsOfServiceIntro => _safeGet('termsOfServiceIntro', fallback: 'Welcome to the "Shchunati" app. Use of the app is subject to the following terms. Please read them carefully:\n\nThe "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company").');
  String get termsSection1 => _safeGet('termsSection1', fallback: 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company"). Use of the app is conditional upon acceptance of these Terms of Service.');
  String get termsSection2 => _safeGet('termsSection2', fallback: 'The app is intended for users over the age of 18 only. The company reserves the right to request proof of age at any stage.');
  String get termsSection3 => _safeGet('termsSection3', fallback: 'The app is intended for mutual assistance between neighbors - connecting those seeking help with those providing help in the local community.');
  String get termsSection4 => _safeGet('termsSection4', fallback: 'The user undertakes to provide only true and accurate information, including location details and contact details.');
  String get termsSection5 => _safeGet('termsSection5', fallback: 'The app is a marketplace platform connecting service seekers with service providers. The app allows users to post free and paid help requests, and offer professional and commercial services in exchange for payment. Commercial and professional use of the app is permitted within the framework of these Terms of Service. The company operates as a mediator only and is not responsible for the quality of services, the reliability of users, any damages, fraud, disputes, or financial losses.');
  String get termsSection6 => _safeGet('termsSection6', fallback: 'Users are solely responsible for the content they publish and for any interaction with other users.');
  String get termsSection7 => _safeGet('termsSection7', fallback: 'Neighborhood is only a mediator and is not responsible for the quality of services, the reliability of users or any damages.');
  String get termsSection8 => _safeGet('termsSection8', fallback: 'The user undertakes to report any inappropriate, offensive or dangerous behavior immediately to support or the relevant authorities.');
  String get termsSection10 => _safeGet('termsSection10', fallback: 'The company reserves the right to stop the service, block users or remove content at any time.');
  String get termsSection11 => _safeGet('termsSection11', fallback: 'The user is responsible for maintaining their login password and securing their personal information.');
  String get termsSection12 => _safeGet('termsSection12', fallback: 'Any dispute will be resolved according to Israeli law and in accordance with the laws of the State of Israel.');
  // Mutual Help and Safety
  String get mutualHelpAndSafety => _safeGet('mutualHelpAndSafety', fallback: 'Mutual Help and Safety');
  String get mutualHelpSection1 => _safeGet('mutualHelpSection1', fallback: 'The app is a marketplace platform connecting people. You choose for yourself who to communicate with, who to offer services to, or who to receive services from, and any such interaction is at your sole responsibility. Ratings and user feedback can help build trust, but they do not constitute a guarantee of quality, reliability, or safety. The company is not responsible for any damage, misconduct, fraud, or poor service quality.');
  String get mutualHelpSection2 => _safeGet('mutualHelpSection2', fallback: 'There is no legal obligation to provide service, but it is recommended to fulfill commitments made to others.');
  String get mutualHelpSection3 => _safeGet('mutualHelpSection3', fallback: 'The rating and review system must be true and accurate. False or offensive ratings will lead to user blocking.');
  String get mutualHelpSection4 => _safeGet('mutualHelpSection4', fallback: 'In case of suspicion of danger, inappropriate behavior or exploitation, report immediately to support or the relevant authorities.');
  String get mutualHelpSection5 => _safeGet('mutualHelpSection5', fallback: 'We reserve the right to block users who violate the rules or behave inappropriately.');
  String get mutualHelpSection6 => _safeGet('mutualHelpSection6', fallback: 'Payments between users are their exclusive responsibility. Neighborhood is not responsible for payments or transactions between users.');
  String get mutualHelpSection8 => _safeGet('mutualHelpSection8', fallback: 'In case of a problem or dispute, we recommend trying to resolve the issue peacefully before contacting support.');
  // Privacy Policy
  String get privacyPolicyIntro => _safeGet('privacyPolicyIntro', fallback: 'This Privacy Policy describes how we collect, use and protect your personal information in the "Shchunati" app:\n\nThe "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company").');
  String get privacySection1 => _safeGet('privacySection1', fallback: 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel (hereinafter: "the Company"). We respect user privacy and are committed to protecting your personal information.');
  String get privacySection2 => _safeGet('privacySection2', fallback: 'Personal information is collected to provide services, including geographic location to connect neighbors, contact details and information about help requests.');
  String get privacySection3 => _safeGet('privacySection3', fallback: 'We will not sell or share your personal information with third parties without explicit consent, except in cases required by law.');
  String get privacySection4 => _safeGet('privacySection4', fallback: 'Information is stored on secure and encrypted servers. Geographic location is stored encrypted and is not transferred to third parties.');
  String get privacySection5 => _safeGet('privacySection5', fallback: 'You have full control over who sees your information. You can set different privacy levels for different requests.');
  String get privacySection6 => _safeGet('privacySection6', fallback: 'The user may request to access, correct or delete their personal information at any time.');
  String get privacySection7 => _safeGet('privacySection7', fallback: 'We use cookies and similar technologies to improve user experience and analyze app usage.');
  String get privacySection8 => _safeGet('privacySection8', fallback: 'The app uses Google Firebase services (Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging) for security, data storage, and notification services. Information is transferred to Firebase servers protected by advanced encryption and under Google\'s privacy policy.');
  String get privacySection9 => _safeGet('privacySection9', fallback: 'The app requires access to your geographic location to connect you with nearby neighbors. Location is stored encrypted and used only to display relevant help requests. You can revoke location access at any time in device settings.');
  String get privacySection10 => _safeGet('privacySection10', fallback: 'The app requires access to your microphone to create voice messages. Recordings are stored on encrypted Firebase servers and used only for communication between users. You can revoke microphone access at any time in device settings.');
  String get privacySection11 => _safeGet('privacySection11', fallback: 'The app requires access to your camera and gallery to upload images for help requests. Images are stored on encrypted Firebase Storage servers and used only to display help requests. You can revoke camera/gallery access at any time in device settings.');
  String get privacySection12 => _safeGet('privacySection12', fallback: 'We take reasonable security measures to protect your information from unauthorized access, use or disclosure.');
  String get privacySection13 => _safeGet('privacySection13', fallback: 'In case of a security breach or information disclosure, we will report it as soon as possible and take appropriate measures.');
  String get privacySection14 => _safeGet('privacySection14', fallback: 'We are committed to updating users about any changes to the Privacy Policy through the app or other means.');
  String get privacySection15 => _safeGet('privacySection15', fallback: 'The app may contain links to third-party websites or services. We are not responsible for their privacy policy.');
  String get tutorialHint => _safeGet('tutorialHint', fallback: 'To learn how to use the app, click on the tutorial icon (📚) in the top menu.');
  // Profile Screen
  String get extendTrialPeriod => _safeGet('extendTrialPeriod', fallback: 'Extend Trial Period');
  String get extendTrialPeriodByTwoWeeks => _safeGet('extendTrialPeriodByTwoWeeks', fallback: 'Extend Trial Period by Two Weeks');
  String get youAreInWeek => _safeGet('youAreInWeek', fallback: 'You are in week');
  String get youAreInFirstWeekMessage => _safeGet('youAreInFirstWeekMessage', fallback: 'You are in your first week! You can see all requests (free and paid) from all categories.');
  String get yourRating => _safeGet('yourRating', fallback: 'Your Rating');
  String get noRatingsYet => _safeGet('noRatingsYet', fallback: 'You have not received ratings yet');
  String get detailedRatings => _safeGet('detailedRatings', fallback: 'Detailed Ratings');
  String basedOnRatings(int count) => count == 1 
    ? _safeGet('basedOnRating', fallback: 'Based on {count} rating').replaceAll('{count}', count.toString())
    : _safeGet('basedOnRatings', fallback: 'Based on {count} ratings').replaceAll('{count}', count.toString());
  String get reliability => _safeGet('reliability', fallback: 'Reliability');
  String get attitude => _safeGet('attitude', fallback: 'Attitude');
  String get editDisplayName => _safeGet('editDisplayName', fallback: 'Edit Display Name');
  String get editPhoneNumber => _safeGet('editPhoneNumber', fallback: 'Edit Phone Number');
  String get afterSavingNameWillUpdate => _safeGet('afterSavingNameWillUpdate', fallback: 'After saving, the name will be updated everywhere in the app');
  String get phonePrefix => _safeGet('phonePrefix', fallback: 'Prefix');
  String get enterNumberWithoutPrefix => _safeGet('enterNumberWithoutPrefix', fallback: 'Enter the number without the prefix');
  String get select => _safeGet('select', fallback: 'Select');
  String get forExample => _safeGet('forExample', fallback: 'For example');
  // My Requests Screen
  String get noRequestsInMyRequests => _safeGet('noRequestsInMyRequests', fallback: 'No requests');
  String get createNewRequestToStart => _safeGet('createNewRequestToStart', fallback: 'Create a new request to get started');
  // In Progress Requests Screen
  String get noInterestedRequests => _safeGet('noInterestedRequests', fallback: 'You have no interested requests');
  String get clickInterestedOnRequests => _safeGet('clickInterestedOnRequests', fallback: 'Click "I\'m interested" on requests that interest you in "All Requests"');
  String get howItWorks => _safeGet('howItWorks', fallback: 'How does it work?');
  String get howItWorksSteps => _safeGet('howItWorksSteps', fallback: '1. Go to "All Requests"\n2. Click "I\'m interested" on requests that interest you\n3. Requests will appear here in "My Requests in Progress"');
  String get fairPrice => _safeGet('fairPrice', fallback: 'Fair Price');
  // Category Selection
  String get selectMainCategoryThen => _safeGet('selectMainCategoryThen', fallback: 'Select main category then');
  String get selectMainCategoryThenUpTo => _safeGet('selectMainCategoryThenUpTo', fallback: 'Select main category then up to');
  String get subCategories => _safeGet('subCategories', fallback: 'sub categories');
  // Buttons
  String get close => _safeGet('close', fallback: 'Close');
  String get startProcess => _safeGet('startProcess', fallback: 'Start Process');
  String get maybeLater => _safeGet('maybeLater', fallback: 'Maybe Later');
  String get rateNow => _safeGet('rateNow', fallback: 'Rate Now');
  String get startEarning => _safeGet('startEarning', fallback: 'Start Earning');
  // Trial Extension Dialog
  String get toExtendTrialPeriod => _safeGet('toExtendTrialPeriod', fallback: 'To extend your trial period by two weeks, you need to perform the following actions:');
  String get shareAppTo5Friends => _safeGet('shareAppTo5Friends', fallback: 'Share the app to 5 friends (WhatsApp, SMS, Email)');
  String get rateApp5Stars => _safeGet('rateApp5Stars', fallback: 'Rate the app 5 stars in the store');
  String get publishNewRequest => _safeGet('publishNewRequest', fallback: 'Publish a new request in any field you want');
  String get serviceRequiresAppointment => _safeGet('serviceRequiresAppointment', fallback: 'Service requires appointment');
  String get serviceRequiresAppointmentHint => _safeGet('serviceRequiresAppointmentHint', fallback: 'If the service requires scheduling an appointment, select this option');
  String get canReceiveByDelivery => _safeGet('canReceiveByDelivery', fallback: 'Can it be received by delivery?');
  String get canReceiveByDeliveryHint => _safeGet('canReceiveByDeliveryHint', fallback: 'Can the service be received via couriers?');
  String get publishAd => _safeGet('publishAd', fallback: 'Publish Ad');
  // Subscription Details Dialogs
  String get yourBusinessSubscriptionDetails => _safeGet('yourBusinessSubscriptionDetails', fallback: 'Your Business Subscription Details');
  String get yourPersonalSubscriptionDetails => _safeGet('yourPersonalSubscriptionDetails', fallback: 'Your Personal Subscription Details');
  String get yourGuestSubscriptionDetails => _safeGet('yourGuestSubscriptionDetails', fallback: 'Your Guest Subscription Details');
  String get yourBusinessSubscriptionIncludes => _safeGet('yourBusinessSubscriptionIncludes', fallback: 'Your business subscription includes:');
  String get yourPersonalSubscriptionIncludes => _safeGet('yourPersonalSubscriptionIncludes', fallback: 'Your personal subscription includes:');
  String get yourTrialPeriodIncludes => _safeGet('yourTrialPeriodIncludes', fallback: 'Your trial period includes:');
  String get yourFreeSubscriptionIncludes => _safeGet('yourFreeSubscriptionIncludes', fallback: 'Your free subscription includes:');
  String requestsPerMonth(int count) => _safeGet('requestsPerMonth', fallback: '{count} requests per month').replaceAll('{count}', count.toString());
  String publishUpToRequestsPerMonth(int count) => _safeGet('publishUpToRequestsPerMonth', fallback: 'Publish up to {count} requests per month').replaceAll('{count}', count.toString());
  String get publishOneRequestPerMonth => _safeGet('publishOneRequestPerMonth', fallback: 'Publish one request only per month');
  String rangeWithBonuses(String range) => _safeGet('rangeWithBonuses', fallback: 'Range: {range} km + bonuses').replaceAll('{range}', range);
  String exposureUpToKm(int km) => _safeGet('exposureUpToKm', fallback: 'Exposure up to {km} kilometers from your location').replaceAll('{km}', km.toString());
  String get seesFreeAndPaidRequests => _safeGet('seesFreeAndPaidRequests', fallback: 'Sees free and paid requests');
  String get seesOnlyFreeRequests => _safeGet('seesOnlyFreeRequests', fallback: 'Sees only free requests');
  String get accessToAllRequestTypes => _safeGet('accessToAllRequestTypes', fallback: 'Access to all types of requests in the app');
  String get accessToFreeRequestsOnly => _safeGet('accessToFreeRequestsOnly', fallback: 'Access to free requests only');
  String get selectedBusinessAreas => _safeGet('selectedBusinessAreas', fallback: 'Selected business areas');
  String yourBusinessAreas(String areas) => _safeGet('yourBusinessAreas', fallback: 'Your business areas: {areas}').replaceAll('{areas}', areas);
  String get noBusinessAreasSelected => _safeGet('noBusinessAreasSelected', fallback: 'Not selected');
  String paymentPerYear(int amount) => _safeGet('paymentPerYear', fallback: 'Payment: {amount}₪ per year').replaceAll('{amount}', amount.toString());
  String get oneTimePaymentForFullYear => _safeGet('oneTimePaymentForFullYear', fallback: 'One-time payment for a full year');
  String get noPayment => _safeGet('noPayment', fallback: 'No payment');
  String get freeSubscriptionAvailable => _safeGet('freeSubscriptionAvailable', fallback: 'Free subscription available at no cost');
  String trialPeriodDays(int days) => _safeGet('trialPeriodDays', fallback: 'Trial period: {days} days').replaceAll('{days}', days.toString());
  String get fullAccessToAllFeatures => _safeGet('fullAccessToAllFeatures', fallback: 'Full access to all features for free');
  String yourSubscriptionActiveUntil(String date) => _safeGet('yourSubscriptionActiveUntil', fallback: 'Your subscription is active until {date}').replaceAll('{date}', date);
  String yourTrialActiveForDays(int days) => _safeGet('yourTrialActiveForDays', fallback: 'Your trial period is active for {days} more days').replaceAll('{days}', days.toString());
  String get subscriptionExpiredSwitchToFree => _safeGet('subscriptionExpiredSwitchToFree', fallback: 'Your subscription has switched to "Free Private" type, upgrade now to "Personal Subscription" or "Business"');
  String get afterTrialAutoSwitchToFree => _safeGet('afterTrialAutoSwitchToFree', fallback: 'After the trial period, you will automatically switch to a free private subscription. You can upgrade at any time.');
  // Subscription Type Selection Dialog
  String get selectSubscriptionType => _safeGet('selectSubscriptionType', fallback: 'Subscription Type Selection');
  String get chooseYourSubscriptionType => _safeGet('chooseYourSubscriptionType', fallback: 'Choose your subscription type:');
  String get privateSubscriptionFeatures => _safeGet('privateSubscriptionFeatures', fallback: '• 1 request per month\n• Range: 0-3 km\n• Sees only free requests\n• No business areas');
  String get privatePaidSubscriptionFeatures => _safeGet('privatePaidSubscriptionFeatures', fallback: '• 5 requests per month\n• Range: 0-5 km\n• Sees only free requests\n• No business areas\n• Payment: 30₪ per year');
  String get businessSubscriptionFeatures => _safeGet('businessSubscriptionFeatures', fallback: '• 10 requests per month\n• Range: 0-8 km\n• Sees free and paid requests\n• Selection of business areas\n• Payment: 70₪ per year');
  // Activate Subscription Dialog
  String activateSubscriptionWithType(String type) => _safeGet('activateSubscriptionWithType', fallback: 'Activate {type} Subscription').replaceAll('{type}', type);
  String subscriptionTypeWithType(String type) => _safeGet('subscriptionTypeWithType', fallback: '{type} Subscription').replaceAll('{type}', type);
  String perYear(int price) => _safeGet('perYear', fallback: '₪{price} per year').replaceAll('{price}', price.toString());
  String businessAreas(String areas) => _safeGet('businessAreas', fallback: 'Business areas: {areas}').replaceAll('{areas}', areas);
  String get howToPay => _safeGet('howToPay', fallback: 'How to pay:');
  String paymentInstructions(int price) => _safeGet('paymentInstructions', fallback: '1. Choose payment method: BIT (PayMe) or credit card (PayMe)\n2. Pay the amount (₪{price}) - the subscription will be activated automatically\n3. If there is a problem, contact support').replaceAll('{price}', price.toString());
  String get payViaPayMe => _safeGet('payViaPayMe', fallback: 'Pay via PayMe (Bit or credit card)');
  // Pending Approval Dialog
  String get requestPendingApprovalNew => _safeGet('requestPendingApprovalNew', fallback: 'Request Pending Approval ⏳');
  String youHaveRequestForSubscription(String type) => _safeGet('youHaveRequestForSubscription', fallback: 'You have a request for {type} and it is being processed.').replaceAll('{type}', type);
  String get cannotSendAnotherRequest => _safeGet('cannotSendAnotherRequest', fallback: 'Cannot send another request until the administrator approves or rejects the current request.');
  // System Admin Dialog
  String get systemAdministrator => _safeGet('systemAdministrator', fallback: 'System Administrator');
  String get adminFullAccessMessage => _safeGet('adminFullAccessMessage', fallback: 'As a system administrator, you have full access to all functions without payment.\n\nYour subscription type is fixed: Business subscription with access to all business areas.');
  // Cash Payment Dialog
  String get cashPaymentTitle => _safeGet('cashPaymentTitle', fallback: 'Cash Payment');
  String get subscriptionDetails => _safeGet('subscriptionDetails', fallback: 'Subscription Details:');
  String subscriptionTypeLabel(String type) => _safeGet('subscriptionTypeLabel', fallback: 'Subscription Type: {type}').replaceAll('{type}', type);
  String priceLabel(int price) => _safeGet('priceLabel', fallback: 'Price: ₪{price}').replaceAll('{price}', price.toString());
  String get sendPaymentRequestNew => _safeGet('sendPaymentRequestNew', fallback: 'Send Payment Request');
  String get completeAllActionsWithinHour => _safeGet('completeAllActionsWithinHour', fallback: 'All actions must be completed within one hour');
  String get granting14DayExtension => _safeGet('granting14DayExtension', fallback: 'Granting 14-day extension...');
  String get extensionGrantedSuccessfully => _safeGet('extensionGrantedSuccessfully', fallback: '14-day extension granted successfully!');
  String get errorGrantingExtension => _safeGet('errorGrantingExtension', fallback: 'Error granting extension');
  String get shareAppTo5FriendsForTrial => _safeGet('shareAppTo5FriendsForTrial', fallback: 'Share the app to 5 friends');
  String get rateApp5StarsForTrial => _safeGet('rateApp5StarsForTrial', fallback: 'Rate the app 5 stars in the store');
  String get publishNewRequestForTrial => _safeGet('publishNewRequestForTrial', fallback: 'Publish a new request');
  String get remainingTime => _safeGet('remainingTime', fallback: 'Remaining time');
  String get timeExpired => _safeGet('timeExpired', fallback: 'Time expired');
  String get shareAppOpened => _safeGet('shareAppOpened', fallback: 'App sharing opened. Please share with 5 friends to complete the requirement.');
  String get appStoreOpened => _safeGet('appStoreOpened', fallback: 'App store opened. Please rate 5 stars to complete the requirement.');
  String get navigateToNewRequest => _safeGet('navigateToNewRequest', fallback: 'Navigating to new request screen. Please publish a request to complete the requirement.');
  String get notCompleted => _safeGet('notCompleted', fallback: 'Not completed');
  String get helpUsImproveApp => _safeGet('helpUsImproveApp', fallback: 'Help us improve the app');
  // Share App Dialog
  String get shareAppTitle => _safeGet('shareAppTitle', fallback: 'Share App');
  String get shareAppForTrialExtension => _safeGet('shareAppForTrialExtension', fallback: 'Share App for Trial Extension');
  String get chooseHowToShare => _safeGet('chooseHowToShare', fallback: 'Choose how you want to share the app:');
  String get sendToFriendsWhatsApp => _safeGet('sendToFriendsWhatsApp', fallback: 'Send to friends on WhatsApp');
  String get sendEmail => _safeGet('sendEmail', fallback: 'Send email');
  String get openShareOptions => _safeGet('openShareOptions', fallback: 'Open share options');
  String get copyToClipboard => _safeGet('copyToClipboard', fallback: 'Copy to clipboard');
  String get copyTextToShare => _safeGet('copyTextToShare', fallback: 'Copy text to share');
  String get generalShare => _safeGet('generalShare', fallback: 'General share');
  String get shareToFacebookMessenger => _safeGet('shareToFacebookMessenger', fallback: 'Share on Messenger');
  String get shareToInstagram => _safeGet('shareToInstagram', fallback: 'Share on Instagram');
  String get openingWhatsApp => _safeGet('openingWhatsApp', fallback: 'Opening WhatsApp...');
  String get openingWhatsAppWeb => _safeGet('openingWhatsAppWeb', fallback: 'Opening WhatsApp Web...');
  String get openingMessagesApp => _safeGet('openingMessagesApp', fallback: 'Opening messages app...');
  String get openingEmailApp => _safeGet('openingEmailApp', fallback: 'Opening email app...');
  String get openingShareOptions => _safeGet('openingShareOptions', fallback: 'Opening share options...');
  String get textCopiedToClipboard => _safeGet('textCopiedToClipboard', fallback: 'Text copied to clipboard! Share it with friends');
  String get errorOpeningShare => _safeGet('errorOpeningShare', fallback: 'Error opening share');
  String get errorOpeningShareDialog => _safeGet('errorOpeningShareDialog', fallback: 'Error opening share dialog');
  String get errorCopying => _safeGet('errorCopying', fallback: 'Error copying');
  String get errorOpeningShareOptions => _safeGet('errorOpeningShareOptions', fallback: 'Error opening share options');
  String get copyTextFromClipboard => _safeGet('copyTextFromClipboard', fallback: 'Copy text from clipboard');
  // Rate App Dialog
  String get rateAppTitle => _safeGet('rateAppTitle', fallback: 'Rate App');
  String get howWasYourExperience => _safeGet('howWasYourExperience', fallback: 'How was your experience?');
  String get yourRatingHelpsUs => _safeGet('yourRatingHelpsUs', fallback: 'Your rating helps us improve the app and reach more users.');
  String get highRatingMoreNeighbors => _safeGet('highRatingMoreNeighbors', fallback: '⭐ High rating = more neighbors = more mutual help!');
  String get errorOpeningStore => _safeGet('errorOpeningStore', fallback: 'Error opening store');
  String get cannotOpenAppStore => _safeGet('cannotOpenAppStore', fallback: 'Cannot open app store');
  // Recommend to Friends Dialog
  String get recommendToFriendsTitle => _safeGet('recommendToFriendsTitle', fallback: 'Recommend to Friends');
  String get lovedTheAppHelpUsGrow => _safeGet('lovedTheAppHelpUsGrow', fallback: 'Loved the app? Help us grow!');
  String get shareWithFriends => _safeGet('shareWithFriends', fallback: '🎯 Share with friends');
  String get rateUs => _safeGet('rateUs', fallback: '⭐ Rate us');
  String get tellAboutYourExperience => _safeGet('tellAboutYourExperience', fallback: '💬 Tell about your experience');
  String get everyRecommendationHelps => _safeGet('everyRecommendationHelps', fallback: 'Every recommendation helps us reach more neighbors looking for mutual help!');
  // Rewards Dialog
  String get rewardsForRecommenders => _safeGet('rewardsForRecommenders', fallback: 'Rewards for Recommenders');
  String get recommendAppAndGetRewards => _safeGet('recommendAppAndGetRewards', fallback: 'Recommend the app and get rewards!');
  String get pointsPerRecommendation => _safeGet('pointsPerRecommendation', fallback: '🎁 10 points - each recommendation');
  String get pointsFor5StarRating => _safeGet('pointsFor5StarRating', fallback: '⭐ 5 points - 5 star rating');
  String get pointsForPositiveReview => _safeGet('pointsForPositiveReview', fallback: '💬 3 points - positive review');
  String get pointsPriorityFeatures => _safeGet('pointsPriorityFeatures', fallback: 'Points = priority in requests + special features!');
  String get guestPeriodStarted => _safeGet('guestPeriodStarted', fallback: 'Welcome! Guest period started');
  String get firstWeekMessage => _safeGet('firstWeekMessage', fallback: 'You are in your first week - you can see all requests (free and paid) from all categories!');
  String get guestModeWithCategories => _safeGet('guestModeWithCategories', fallback: 'Guest mode - defined business fields');
  String get guestModeNoCategories => _safeGet('guestModeNoCategories', fallback: 'Guest mode - no business fields');
  String get helpSent => _safeGet('helpSent', fallback: 'Help offer sent!');
  String get unhelpConfirmation => _safeGet('unhelpConfirmation', fallback: 'Are you sure you want to cancel your interest in this request?');
  String get unhelpSent => _safeGet('unhelpSent', fallback: 'Interest in request cancelled');
  String get categoryDataUpdated => _safeGet('categoryDataUpdated', fallback: 'Category data updated successfully');
  String get nameDisplayInfo => _safeGet('nameDisplayInfo', fallback: 'The name will appear in requests you create, and in the maps of request publishers');
  String get validPrefixes => _safeGet('validPrefixes', fallback: 'Valid prefixes: 050-059 (10 digits), 02,03,04,08,09 (9 digits), 072-079 (10 digits)');
  String get agreeToDisplayPhone => _safeGet('agreeToDisplayPhone', fallback: 'Agree to display my phone number in requests I create, so they can contact me');
  String get chatClosed => _safeGet('chatClosed', fallback: 'Chat closed - cannot send messages');
  String get messageLimitReached => _safeGet('messageLimitReached', fallback: 'Reached 50 message limit - cannot send more messages');
  String messagesRemaining(int count) {
    final template = _safeGet('messagesRemaining', fallback: 'Warning: Only {count} messages remaining');
    return template.replaceAll('{count}', count.toString());
  }
  String loginMethod(String method) {
    final template = _safeGet('loginMethod', fallback: 'Login method: {method}');
    return template.replaceAll('{method}', method);
  }
  String get saveLoginCredentials => _safeGet('saveLoginCredentials', fallback: 'Save login credentials');
  // Additional messages from home_screen
  String get confirmCancelInterest => _safeGet('confirmCancelInterest', fallback: 'Confirm Cancel Interest');
  String get requestLabel => _safeGet('requestLabel', fallback: 'Request');
  String get categoryLabel => _safeGet('categoryLabel', fallback: 'Category');
  String get typeLabel => _safeGet('typeLabel', fallback: 'Type');
  String get paidType => _safeGet('paidType', fallback: 'Paid');
  String get freeType => _safeGet('freeType', fallback: 'Free');
  String get editBusinessCategories => _safeGet('editBusinessCategories', fallback: 'Edit Business Categories');
  String get actionConfirmation => _safeGet('actionConfirmation', fallback: 'Action Confirmation');
  String get noNotificationsSelected => _safeGet('noNotificationsSelected', fallback: 'You chose not to receive notifications about new requests. Continue?');
  String get no => _safeGet('no', fallback: 'No');
  String get yes => _safeGet('yes', fallback: 'Yes');
  String errorGeneral(String error) {
    final template = _safeGet('errorGeneral', fallback: 'Error: {error}');
    return template.replaceAll('{error}', error);
  }
  String get seeMoreSelectFields => _safeGet('seeMoreSelectFields', fallback: 'You see paid requests only from the business fields you selected. To see more requests, select additional business fields in your profile.');
  String get trialPeriodEnded => _safeGet('trialPeriodEnded', fallback: 'Trial Period Ended');
  String get selectBusinessFieldsInProfile => _safeGet('selectBusinessFieldsInProfile', fallback: 'To see paid requests, select business fields in your profile.');
  String get afterUpdateCanContact => _safeGet('afterUpdateCanContact', fallback: 'After updating your profile, you can contact the publishers through the details shown in the request.');
  String get businessFieldsNotMatch => _safeGet('businessFieldsNotMatch', fallback: 'Business fields do not match');
  String requestFromCategory(String category) {
    final template = _safeGet('requestFromCategory', fallback: 'This request is from the field "{category}" and does not match your business fields.');
    return template.replaceAll('{category}', category);
  }
  String get updateBusinessFieldsHint => _safeGet('updateBusinessFieldsHint', fallback: 'If you want to contact the request creator, you must update your business fields in your profile to match the request category.');
  String get updateBusinessFields => _safeGet('updateBusinessFields', fallback: 'Edit Business Categories');
  String get updateBusinessFieldsTitle => _safeGet('updateBusinessFieldsTitle', fallback: 'Update Business Categories');
  String get cancelInterest => _safeGet('cancelInterest', fallback: 'Cancel Interest');
  String get confirm => _safeGet('confirm', fallback: 'Confirm');
  // Additional messages
  String get afterCancelNoChat => _safeGet('afterCancelNoChat', fallback: 'After cancellation, you will not be able to see the chat with the request creator.');
  String get yesCancelInterest => _safeGet('yesCancelInterest', fallback: 'Yes, Cancel Interest');
  String requestFromField(String category) {
    final template = _safeGet('requestFromField', fallback: 'This request is in the field "{category}".');
    return template.replaceAll('{category}', category);
  }
  String get updateFieldsToContact => _safeGet('updateFieldsToContact', fallback: 'If you provide services in this field, you must first update business fields in your profile, then you can contact the request creator.');
  String get confirmAction => _safeGet('confirmAction', fallback: 'Action Confirmation');
  String get selectedNoNotifications => _safeGet('selectedNoNotifications', fallback: 'You chose not to receive notifications about new requests. Continue?');
  String get notificationPermissionRequiredForFilter => _safeGet('notificationPermissionRequiredForFilter', fallback: 'You must approve receiving notifications to receive notifications for new requests.\n\nIf you do not approve, you will not receive notifications for new requests.');
  String get continueText => _safeGet('continue', fallback: 'Continue');
  String get loadingRequestsError => _safeGet('loadingRequestsError', fallback: 'Error loading requests');
  // Additional getters from home screen
  String get requestsFromAdvertisers => _safeGet('requestsFromAdvertisers', fallback: 'My Smart Neighborhood');
  String get allRequests => _safeGet('allRequests', fallback: 'All Requests');
  String get advancedFilter => _safeGet('advancedFilter', fallback: 'Advanced Filter');
  String get goToAllRequests => _safeGet('goToAllRequests', fallback: 'Go to All Requests');
  String get filterSaved => _safeGet('filterSaved', fallback: 'Filter Saved');
  String get saveFilter => _safeGet('saveFilter', fallback: 'Save Filter');
  String get savedFilter => _safeGet('savedFilter', fallback: 'Saved Filter');
  String get savedFilterFound => _safeGet('savedFilterFound', fallback: 'A saved filter was found from the last time. Would you like to restore it?');
  String get allTypes => _safeGet('allTypes', fallback: 'All Types');
  String get allSubCategories => _safeGet('allSubCategories', fallback: 'All Sub-Categories');
  // Additional getters from request filter screen
  String get urgency => _safeGet('urgency', fallback: 'Urgency');
  String get normal => _safeGet('normal', fallback: 'Normal');
  String get within24Hours => _safeGet('within24Hours', fallback: 'Within 24 hours');
  String get nowUrgency => _safeGet('nowUrgency', fallback: 'Now');
  String get within24HoursAndNow => _safeGet('within24HoursAndNow', fallback: 'Within 24 hours and also now');
  String get requestRange => _safeGet('requestRange', fallback: 'Your request range');
  String get km => _safeGet('km', fallback: 'km');
  String get filterByFixedLocation => _safeGet('filterByFixedLocation', fallback: 'Filter requests by fixed location and exposure range');
  String get mustDefineFixedLocation => _safeGet('mustDefineFixedLocation', fallback: 'You must define a fixed location and exposure range in profile first');
  String get filterByMobileLocation => _safeGet('filterByMobileLocation', fallback: 'Filter requests by mobile location and exposure range (while moving)');
  String get selectRange => _safeGet('selectRange', fallback: 'Select range');
  String get setLocationAndRange => _safeGet('setLocationAndRange', fallback: 'Click to select additional location and exposure range');
  String kmFromSelectedLocation(String distance) {
    final template = _safeGet('kmFromSelectedLocation', fallback: '{distance} km from selected location');
    return template.replaceAll('{distance}', distance);
  }
  String kmFromMobileLocation(String distance) {
    final template = _safeGet('kmFromMobileLocation', fallback: '{distance} km from mobile location');
    return template.replaceAll('{distance}', distance);
  }
  String kmFromFixedLocation(String distance) {
    final template = _safeGet('kmFromFixedLocation', fallback: '{distance} km from fixed location');
    return template.replaceAll('{distance}', distance);
  }
  String get receiveNotificationsForNewRequests => _safeGet('receiveNotificationsForNewRequests', fallback: 'Receive notifications for new matching requests');
  String get noPaidServicesMessage => _safeGet('noPaidServicesMessage', fallback: 'You have set that you do not provide paid services - you can only see free requests');
  String showToProvidersOutsideRange(String region, String category) {
    final template = _safeGet('showToProvidersOutsideRange', fallback: 'According to the location you selected, your request is in the {region} region, are you interested in your request appearing to all service providers in the {category} field from the {region} region?');
    return template.replaceAll('{region}', region).replaceAll('{category}', category);
  }
  
  String yesAllProvidersInRegion(String region) {
    final template = _safeGet('yesAllProvidersInRegion', fallback: 'Yes, all service providers in the {region} region');
    return template.replaceAll('{region}', region);
  }
  
  String get noOnlyInRange => _safeGet('noOnlyInRange', fallback: 'No, only in the range I defined');
  String showToAllUsersOrProviders(String category) {
    final template = _safeGet('showToAllUsersOrProviders', fallback: 'Are you interested in this request appearing to all users in the app or only to service providers in the {category} field you selected?');
    return template.replaceAll('{category}', category);
  }
  String get yesToAllUsers => _safeGet('yesToAllUsers', fallback: 'Yes to all users');
  String onlyToProvidersInCategory(String category) {
    final template = _safeGet('onlyToProvidersInCategory', fallback: 'Only to service providers in the {category} field');
    return template.replaceAll('{category}', category);
  }
  String get northRegion => _safeGet('northRegion', fallback: 'North');
  String get centerRegion => _safeGet('centerRegion', fallback: 'Center');
  String get southRegion => _safeGet('southRegion', fallback: 'South');
  String get mainCategory => _safeGet('mainCategory', fallback: 'Main category');
  String get subCategory => _safeGet('subCategory', fallback: 'Sub category');
  // Additional getters for new request screen
  String get selectCategory => _safeGet('selectCategory', fallback: 'Select category');
  String get pleaseSelectCategoryFirst => _safeGet('pleaseSelectCategoryFirst', fallback: 'Please select a category first');
  String get title => _safeGet('title', fallback: 'Title');
  String get description => _safeGet('description', fallback: 'Description');
  String get urgencyLevel => _safeGet('urgencyLevel', fallback: 'Urgency level');
  String get normalUrgency => _safeGet('normalUrgency', fallback: 'Normal');
  String get within24HoursUrgency => _safeGet('within24HoursUrgency', fallback: 'Within 24 hours');
  String get imagesForRequest => _safeGet('imagesForRequest', fallback: 'Images for request');
  String get youCanAddImages => _safeGet('youCanAddImages', fallback: 'You can add images to help understand the request better');
  String get limit5Images => _safeGet('limit5Images', fallback: 'Limit: 5 images');
  String get selectImages => _safeGet('selectImages', fallback: 'Select images');
  String get takePhoto => _safeGet('takePhoto', fallback: 'Take photo');
  String selectedImagesCount(int count) {
    final template = _safeGet('selectedImagesCount', fallback: 'Selected {count} images');
    return template.replaceAll('{count}', count.toString());
  }
  String get enterFullPrefixAndNumber => _safeGet('enterFullPrefixAndNumber', fallback: 'Enter full prefix and number');
  String get invalidPhoneNumber => _safeGet('invalidPhoneNumber', fallback: 'Invalid phone number');
  String get invalidPrefix => _safeGet('invalidPrefix', fallback: 'Invalid prefix');
  String get freeRequestsDescription => _safeGet('freeRequestsDescription', fallback: 'Free requests: all user types can help (no category restriction)');
  String get paidRequestsDescription => _safeGet('paidRequestsDescription', fallback: 'Paid requests: only users with matching categories can help');
  String get permissionRequiredImages => _safeGet('permissionRequiredImages', fallback: 'Permission required to access images');
  String get permissionRequiredCamera => _safeGet('permissionRequiredCamera', fallback: 'Permission required to access camera');
  String get errorSelectingImages => _safeGet('errorSelectingImages', fallback: 'Error selecting images');
  String get errorTakingPhoto => _safeGet('errorTakingPhoto', fallback: 'Error taking photo');
  String get errorUploadingImages => _safeGet('errorUploadingImages', fallback: 'Error uploading images');
  String get imageAddedSuccessfully => _safeGet('imageAddedSuccessfully', fallback: 'Image added successfully');
  String get cannotAddMoreThan5Images => _safeGet('cannotAddMoreThan5Images', fallback: 'Cannot add more than 5 images');
  String get alreadyHas5Images => _safeGet('alreadyHas5Images', fallback: 'Already has 5 images. Delete images to add new ones.');
  String addedImagesCount(int count) {
    final template = _safeGet('addedImagesCount', fallback: 'Added {count} images');
    return template.replaceAll('{count}', count.toString());
  }
  String get multiplePhotoCapture => _safeGet('multiplePhotoCapture', fallback: 'Multiple photo capture');
  String get clickOkToCapture => _safeGet('clickOkToCapture', fallback: 'Click "OK" to capture another photo');
  String get shareNow => _safeGet('shareNow', fallback: 'Share now');
  String get pleaseSelectCategory => _safeGet('pleaseSelectCategory', fallback: 'Please select a category for the request');
  String get pleaseSelectLocation => _safeGet('pleaseSelectLocation', fallback: 'Please select a location for the request');
  String get creatingRequest => _safeGet('creatingRequest', fallback: 'Creating request...');
  String get requestLimits => _safeGet('requestLimits', fallback: 'Your request limits');
  String maxRequestsPerMonth(int max) {
    final template = _safeGet('maxRequestsPerMonth', fallback: 'Maximum requests per month: {max}');
    return template.replaceAll('{max}', max.toString());
  }
  String maxSearchRange(String radius) {
    final template = _safeGet('maxSearchRange', fallback: 'Maximum search range: {radius} km');
    return template.replaceAll('{radius}', radius);
  }
  String get newRequestTutorialTitle => _safeGet('newRequestTutorialTitle', fallback: 'Create new request');
  String get newRequestTutorialMessage => _safeGet('newRequestTutorialMessage', fallback: 'Here you can create a new request and get help from the community. Write a clear description, select a category, set location and exposure range (according to your user type), and publish the request.');
  String get writeRequestDescription => _safeGet('writeRequestDescription', fallback: 'Write request description');
  String get selectAppropriateCategory => _safeGet('selectAppropriateCategory', fallback: 'Select appropriate category');
  String get selectLocationAndExposure => _safeGet('selectLocationAndExposure', fallback: 'Select location and exposure range');
  String get setPriceFreeOrPaid => _safeGet('setPriceFreeOrPaid', fallback: 'Set price (free or paid)');
  String get publishRequest => _safeGet('publishRequest', fallback: 'Publish request');
  String get locationInfoTitle => _safeGet('locationInfoTitle', fallback: 'Location selection information');
  String get howToSelectLocation => _safeGet('howToSelectLocation', fallback: 'How to select the right location:');
  String get selectLocationInstructions => _safeGet('selectLocationInstructions', fallback: '📍 Select as precise a location as possible\n🎯 The range will determine how many people see the request\n📱 Use the map to select the precise location');
  String get locationSelectionTips => _safeGet('locationSelectionTips', fallback: 'Location selection tips:');
  String get locationSelectionTipsDetails => _safeGet('locationSelectionTipsDetails', fallback: '🏠 Select the exact address\n🚗 If it\'s on a street, select the correct side\n🏢 If it\'s in a building, select the main entrance\n📍 Use address search for maximum accuracy\n📏 The minimum range is 0.1 km');
  
  // Tutorial Center - Categories
  String get tutorialCategoryHome => _safeGet('tutorialCategoryHome', fallback: 'Home Screen');
  String get tutorialCategoryRequests => _safeGet('tutorialCategoryRequests', fallback: 'Requests');
  String get tutorialCategoryChat => _safeGet('tutorialCategoryChat', fallback: 'Chat');
  String get tutorialCategoryProfile => _safeGet('tutorialCategoryProfile', fallback: 'Profile');
  String tutorialsAvailable(int count) {
    final template = _safeGet('tutorialTutorialsAvailable', fallback: '{count} tutorials available');
    return template.replaceAll('{count}', count.toString());
  }
  
  // Tutorial Center - Home Screen
  String get tutorialHomeBasicsTitle => _safeGet('tutorialHomeBasicsTitle', fallback: 'Home Screen Basics');
  String get tutorialHomeBasicsDescription => _safeGet('tutorialHomeBasicsDescription', fallback: 'Learn how to navigate the home screen and use basic functions');
  String get tutorialHomeBasicsContent => _safeGet('tutorialHomeBasicsContent', fallback: '');
  
  String get tutorialHomeSearchTitle => _safeGet('tutorialHomeSearchTitle', fallback: 'Search and Filter');
  String get tutorialHomeSearchDescription => _safeGet('tutorialHomeSearchDescription', fallback: 'How to find specific requests quickly');
  String get tutorialHomeSearchContent => _safeGet('tutorialHomeSearchContent', fallback: '');
  
  // Tutorial Center - Requests
  String get tutorialCreateRequestTitle => _safeGet('tutorialCreateRequestTitle', fallback: 'Create New Request');
  String get tutorialCreateRequestDescription => _safeGet('tutorialCreateRequestDescription', fallback: 'How to create a request for help or service');
  String get tutorialCreateRequestContent => _safeGet('tutorialCreateRequestContent', fallback: '');
  
  String get tutorialManageRequestsTitle => _safeGet('tutorialManageRequestsTitle', fallback: 'Manage Requests');
  String get tutorialManageRequestsDescription => _safeGet('tutorialManageRequestsDescription', fallback: 'How to manage your requests');
  String get tutorialManageRequestsContent => _safeGet('tutorialManageRequestsContent', fallback: '');
  
  // Tutorial Center - Chat
  String get tutorialChatBasicsTitle => _safeGet('tutorialChatBasicsTitle', fallback: 'Chat Basics');
  String get tutorialChatBasicsDescription => _safeGet('tutorialChatBasicsDescription', fallback: 'How to use the chat system');
  String get tutorialChatBasicsContent => _safeGet('tutorialChatBasicsContent', fallback: '');
  
  String get tutorialChatAdvancedTitle => _safeGet('tutorialChatAdvancedTitle', fallback: 'Advanced Functions');
  String get tutorialChatAdvancedDescription => _safeGet('tutorialChatAdvancedDescription', fallback: 'Advanced chat functions');
  String get tutorialChatAdvancedContent => _safeGet('tutorialChatAdvancedContent', fallback: '');
  
  // Tutorial Center - Profile
  String get tutorialProfileSetupTitle => _safeGet('tutorialProfileSetupTitle', fallback: 'Profile Setup');
  String get tutorialProfileSetupDescription => _safeGet('tutorialProfileSetupDescription', fallback: 'How to set up your profile');
  String get tutorialProfileSetupContent => _safeGet('tutorialProfileSetupContent', fallback: '');
  
  String get tutorialSubscriptionTitle => _safeGet('tutorialSubscriptionTitle', fallback: 'Subscriptions and Payments');
  String get tutorialSubscriptionDescription => _safeGet('tutorialSubscriptionDescription', fallback: 'How to manage subscription and payments');
  String get tutorialSubscriptionContent => _safeGet('tutorialSubscriptionContent', fallback: '');
  
  // Tutorial Center - General
  String get tutorialMarkedAsRead => _safeGet('tutorialMarkedAsRead', fallback: 'Tutorial marked as read');
  String get tutorialClose => _safeGet('tutorialClose', fallback: 'Close');
  String get tutorialRead => _safeGet('tutorialRead', fallback: 'I read');
  String get selectMainCategoryThenSub => _safeGet('selectMainCategoryThenSub', fallback: 'Select main category then sub category');
  String selectSubCategoriesUpTo(int max) {
    final template = _safeGet('selectSubCategoriesUpTo', fallback: 'Select sub categories (up to {max} from all categories):');
    return template.replaceAll('{max}', max.toString());
  }
  String get clearSelection => _safeGet('clearSelection', fallback: 'Clear selection');
  String get prefix => _safeGet('prefix', fallback: 'Prefix');
  String get phoneNumberLabel => _safeGet('phoneNumberLabel', fallback: 'Phone number');
  String get selectLocation => _safeGet('selectLocation', fallback: 'Select location');
  String get selectDeadlineOptional => _safeGet('selectDeadlineOptional', fallback: 'Select deadline (optional)');
  String get price => _safeGet('price', fallback: 'Price');
  String get optional => _safeGet('optional', fallback: 'Optional');
  String get willingToPay => _safeGet('willingToPay', fallback: 'Willing to pay');
  String get howMuchWillingToPay => _safeGet('howMuchWillingToPay', fallback: '(Optional) How much are you willing to pay?');
  String get upToOneMonth => _safeGet('upToOneMonth', fallback: 'Up to one month from today');
  // Additional getters for location picker screen
  String get selectLocationTitle => _safeGet('selectLocationTitle', fallback: 'Select location');
  String get currentLocation => _safeGet('currentLocation', fallback: 'Current location');
  String get gettingLocation => _safeGet('gettingLocation', fallback: 'Getting location...');
  String get exposureCircle => _safeGet('exposureCircle', fallback: 'Exposure circle');
  String get kilometers => _safeGet('kilometers', fallback: 'Kilometers');
  String get dragSliderToChange => _safeGet('dragSliderToChange', fallback: 'Drag slider to change exposure circle size');
  String maxRangeWithBonuses(String radius) {
    final template = _safeGet('maxRangeWithBonuses', fallback: 'Maximum range: {radius} km (including bonuses)');
    return template.replaceAll('{radius}', radius);
  }
  String get notificationsWillBeSent => _safeGet('notificationsWillBeSent', fallback: 'Notifications will be sent only to users whose filter location is within Israel and in range');
  String get selectedLocation => _safeGet('selectedLocation', fallback: 'Selected location');
  String get selectedLocationLabel => _safeGet('selectedLocationLabel', fallback: 'Selected location:');
  // Additional getters for my requests screen
  String get statusOpen => _safeGet('statusOpen', fallback: 'Open');
  String get statusCompleted => _safeGet('statusCompleted', fallback: 'Completed');
  String get statusCancelled => _safeGet('statusCancelled', fallback: 'Cancelled');
  String get statusInProgress => _safeGet('statusInProgress', fallback: 'In Progress');
  String get mapOfRelevantHelpers => _safeGet('mapOfRelevantHelpers', fallback: 'Map of relevant helpers');
  String helpersInRange(int count, String radius) {
    final template = _safeGet('helpersInRange', fallback: 'There are {count} helpers in range of {radius} km');
    return template.replaceAll('{count}', count.toString()).replaceAll('{radius}', radius);
  }
  String get updatesEvery30Seconds => _safeGet('updatesEvery30Seconds', fallback: 'Updates every 10 seconds');
  String get yourRequestLocation => _safeGet('yourRequestLocation', fallback: 'Your request location');
  String get subscribedHelpers => _safeGet('subscribedHelpers', fallback: 'Subscribed helpers');
  String get range => _safeGet('range', fallback: 'Range');
  String chatWith(String name) {
    final template = _safeGet('chatWith', fallback: 'Chat with {name}');
    return template.replaceAll('{name}', name);
  }
  String chatClosedWith(String name) {
    final template = _safeGet('chatClosedWith', fallback: 'Chat closed with {name}');
    return template.replaceAll('{name}', name);
  }
  String get markAsCompleted => _safeGet('markAsCompleted', fallback: 'Mark as completed');
  String get cancelCompleted => _safeGet('cancelCompleted', fallback: 'Cancel completed');
  String get mapAvailableOnly => _safeGet('mapAvailableOnly', fallback: 'Map available only');
  String get goToSeeSubscribedHelpers => _safeGet('goToSeeSubscribedHelpers', fallback: 'Go to see subscribed helpers');
  String rangeKm(String radius) {
    final template = _safeGet('rangeKm', fallback: 'Range: {radius} km');
    return template.replaceAll('{radius}', radius);
  }
  // Additional getters for helpers and likes
  String get helpers => _safeGet('helpers', fallback: 'Helpers');
  String helpersCount(int count) {
    final template = _safeGet('helpersCount', fallback: 'Helpers: {count}');
    return template.replaceAll('{count}', count.toString());
  }
  String get likes => _safeGet('likes', fallback: 'Likes');
  String likesCount(int count) {
    final template = _safeGet('likesCount', fallback: 'Likes: {count}');
    return template.replaceAll('{count}', count.toString());
  }
  String get deadlineLabel => _safeGet('deadlineLabel', fallback: 'Deadline');
  String get deadlineExpired => _safeGet('deadlineExpired', fallback: 'Deadline: Expired');
  String deadlineDate(String date) {
    final template = _safeGet('deadlineDate', fallback: 'Deadline: {date}');
    return template.replaceAll('{date}', date);
  }
  String get helpersWhoShowedInterest => _safeGet('helpersWhoShowedInterest', fallback: 'Helpers who showed interest:');
  String get noHelpersAvailable => _safeGet('noHelpersAvailable', fallback: 'No helpers available');
  // Additional getters for home screen
  String get requestWithoutPhone => _safeGet('requestWithoutPhone', fallback: 'Request without phone number');
  String deadlineDateHome(String date) {
    final template = _safeGet('deadlineDateHome', fallback: 'Deadline: {date}');
    return template.replaceAll('{date}', date);
  }
  String interestedCallers(int count) {
    final template = _safeGet('interestedCallers', fallback: '{count} interested callers');
    return template.replaceAll('{count}', count.toString());
  }
  String publishedBy(String name) {
    final template = _safeGet('publishedBy', fallback: 'Published by: {name}');
    return template.replaceAll('{name}', name);
  }
  String get publishedByUser => _safeGet('publishedByUser', fallback: 'Published by: User');
  String get iAmInterested => _safeGet('iAmInterested', fallback: 'I am interested');
  String get iAmNotInterested => _safeGet('iAmNotInterested', fallback: 'I am not interested');
  String get clickIAmInterestedToShowPhone => _safeGet('clickIAmInterestedToShowPhone', fallback: 'Click "I am interested" to show phone number');
  // Additional getters for my requests screen
  String get chatButton => _safeGet('chatButton', fallback: 'Chat');
  String get chatClosedButton => _safeGet('chatClosedButton', fallback: 'Chat closed');
  String get request => _safeGet('request', fallback: 'Request');
  String helloIAm(String name, String badge) {
    final template = _safeGet('helloIAm', fallback: 'Hello! I am {name}{badge}');
    return template.replaceAll('{name}', name).replaceAll('{badge}', badge);
  }
  String newInField(String category) {
    final template = _safeGet('newInField', fallback: '(New in field {category})');
    return template.replaceAll('{category}', category);
  }
  String get interestedInHelping => _safeGet('interestedInHelping', fallback: 'Interested in helping you with your request. How can I help?');
  String get canSendUpTo50Messages => _safeGet('canSendUpTo50Messages', fallback: 'You can send up to 50 messages in this chat. System messages are not counted in the limit.');
  // Additional getters
  String get errorLoadingData => _safeGet('errorLoadingData', fallback: 'Error loading data');
  String get tryAgain => _safeGet('tryAgain', fallback: 'Try Again');
  String get wazeNotInstalled => _safeGet('wazeNotInstalled', fallback: 'Waze is not installed on this device');
  String get errorOpeningWaze => _safeGet('errorOpeningWaze', fallback: 'Error opening Waze');
  // Chat screen getters
  String get loadingMessages => _safeGet('loadingMessages', fallback: 'Loading messages...');
  String errorLoadingMessages(String error) {
    final template = _safeGet('errorLoadingMessages', fallback: 'Error: {error}');
    return template.replaceAll('{error}', error);
  }
  String get messageDeleted => _safeGet('messageDeleted', fallback: 'Message deleted');
  String get messageDeletedSuccessfully => _safeGet('messageDeletedSuccessfully', fallback: 'Message deleted successfully');
  String get errorDeletingMessage => _safeGet('errorDeletingMessage', fallback: 'Error deleting message');
  String get chatClosedCannotSend => _safeGet('chatClosedCannotSend', fallback: 'Chat closed - cannot send messages');
  String get closeChat => _safeGet('closeChat', fallback: 'Close Chat');
  String get closeChatTitle => _safeGet('closeChatTitle', fallback: 'Close Chat');
  String get closeChatMessage => _safeGet('closeChatMessage', fallback: 'Are you sure you want to close the chat? After closing, you will not be able to send additional messages.');
  String get reopenChat => _safeGet('reopenChat', fallback: 'Reopen Chat');
  String chatClosedBy(String name) {
    final template = _safeGet('chatClosedBy', fallback: 'Chat closed by {name}. Cannot send additional messages.');
    return template.replaceAll('{name}', name);
  }
  String get chatClosedStatus => _safeGet('chatClosedStatus', fallback: 'Chat closed');
  String get chatClosedSuccessfully => _safeGet('chatClosedSuccessfully', fallback: 'Chat closed successfully');
  String get chatReopened => _safeGet('chatReopened', fallback: 'Chat reopened');
  String chatReopenedBy(String name) {
    final template = _safeGet('chatReopenedBy', fallback: 'Chat reopened by {name}.');
    return template.replaceAll('{name}', name);
  }
  String get errorClosingChat => _safeGet('errorClosingChat', fallback: 'Error closing chat');
  
  // Splash screen getters
  String get initializing => _safeGet('initializing', fallback: 'Initializing...');
  String get ready => _safeGet('ready', fallback: 'Ready!');
  String errorInitialization(String error) {
    final template = _safeGet('errorInitialization', fallback: 'Initialization error: {error}');
    return template.replaceAll('{error}', error);
  }
  String get strongNeighborhoodInAction => _safeGet('strongNeighborhoodInAction', fallback: 'Strong neighborhood in action');
  
  // Voice messages getters
  String get recording => _safeGet('recording', fallback: 'Recording...');
  String errorLoadingVoiceMessage(String error) {
    final template = _safeGet('errorLoadingVoiceMessage', fallback: 'Error loading voice message: {error}');
    return template.replaceAll('{error}', error);
  }
  
  // Trial extension getters
  String get guestPeriodExtendedTwoWeeks => _safeGet('guestPeriodExtendedTwoWeeks', fallback: 'Your guest period has been extended by two weeks! 🎉');
  String get thankYouForActions => _safeGet('thankYouForActions', fallback: 'Thank you for the actions you took. Your guest period has been extended by 14 days.');
  
  // Home screen additional getters
  String removeRequestConfirm(String screen) {
    final template = _safeGet('removeRequestConfirm', fallback: 'Are you sure you want to remove the request from "{screen}" screen? The request will not be deleted, only removed from the list.');
    return template.replaceAll('{screen}', screen);
  }
  String requestRemoved(String screen) {
    final template = _safeGet('requestRemoved', fallback: 'Request removed from "{screen}" screen');
    return template.replaceAll('{screen}', screen);
  }
  String errorRemovingRequest(String error) {
    final template = _safeGet('errorRemovingRequest', fallback: 'Error removing request: {error}');
    return template.replaceAll('{error}', error);
  }
  String get interestCancelled => _safeGet('interestCancelled', fallback: 'You cancelled your interest in the request');
  String get cannotCallThisNumber => _safeGet('cannotCallThisNumber', fallback: 'Cannot call this number');
  String errorCreatingChat(String error) {
    final template = _safeGet('errorCreatingChat', fallback: 'Error creating chat: {error}');
    return template.replaceAll('{error}', error);
  }
  String get savedFilterRestored => _safeGet('savedFilterRestored', fallback: 'Saved filter restored successfully');
  String errorRestoringFilter(String error) {
    final template = _safeGet('errorRestoringFilter', fallback: 'Error restoring filter: {error}');
    return template.replaceAll('{error}', error);
  }
  String get goToProfileToActivateSubscription => _safeGet('goToProfileToActivateSubscription', fallback: 'Please go to the profile screen through the bottom menu to activate subscription');
  String get selectRequestRange => _safeGet('selectRequestRange', fallback: 'Select request range');
  String get selectLocationAndRangeOnMap => _safeGet('selectLocationAndRangeOnMap', fallback: 'Select location and range on map');
  String get newNotification => _safeGet('newNotification', fallback: 'New notification!');
  String get setFixedLocationInProfile => _safeGet('setFixedLocationInProfile', fallback: 'Set fixed location in profile');
  String get clearFilter => _safeGet('clearFilter', fallback: 'Clear filter');
  String get changeFilter => _safeGet('changeFilter', fallback: 'Change filter');
  String get filter => _safeGet('filter', fallback: 'Filter and receive notifications');
  String get filterServiceProviders => _safeGet('filterServiceProviders', fallback: 'Filter service providers');
  String get loginWithoutVerification => _safeGet('loginWithoutVerification', fallback: 'Login without verification');
  String get refresh => _safeGet('refresh', fallback: 'Refresh');
  String get addedLike => _safeGet('addedLike', fallback: 'Added like! ❤️');
  String get removedLike => _safeGet('removedLike', fallback: 'Removed like');
  String get filterOptions => _safeGet('filterOptions', fallback: 'Filter options');
  String get saveFilterForNextTime => _safeGet('saveFilterForNextTime', fallback: 'Save filter for next time');
  
  // Profile screen additional getters
  String get deleteFixedLocation => _safeGet('deleteFixedLocation', fallback: 'Delete fixed location');
  String get requestPendingApproval => _safeGet('requestPendingApproval', fallback: 'Request pending approval ⏳');
  String get upgradeSubscriptionTitle => _safeGet('upgradeSubscriptionTitle', fallback: 'Upgrade subscription 🚀');
  String get privateSubscriptionPrice => _safeGet('privateSubscriptionPrice', fallback: 'Personal subscription - 30₪/year');
  String get businessSubscriptionPrice => _safeGet('businessSubscriptionPrice', fallback: 'Business subscription - 70₪/year');
  String get upgradeToBusinessSubscription => _safeGet('upgradeToBusinessSubscription', fallback: 'Upgrade to business subscription:');
  
  // Share service getters
  String get interestingRequestInShchunati => _safeGet('interestingRequestInShchunati', fallback: '🎯 Interesting request in "Shchunati"!');
  
  // App sharing service getters
  String get shchunatiAppDescription => _safeGet('shchunatiAppDescription', fallback: '"Shchunati" - The app that connects neighbors for real mutual help');
  String get yourRangeGrew => _safeGet('yourRangeGrew', fallback: 'Your range grew!');
  String get sendToMessenger => _safeGet('sendToMessenger', fallback: 'Send on Messenger');
  
  // Chat screen additional getters
  String get communicationWithServiceProvider => _safeGet('communicationWithServiceProvider', fallback: 'Communication with service provider');
  String get communicationWithServiceProviderMessage => _safeGet('communicationWithServiceProviderMessage', fallback: 'Here you can communicate with the service provider, ask questions and coordinate details.');
  String get messageOptions => _safeGet('messageOptions', fallback: 'Message options');
  String get whatDoYouWantToDoWithMessage => _safeGet('whatDoYouWantToDoWithMessage', fallback: 'What do you want to do with the message?');
  String get editMessage => _safeGet('editMessage', fallback: 'Edit message');
  String get typeNewMessage => _safeGet('typeNewMessage', fallback: 'Type the new message...');
  String get messageEditedSuccessfully => _safeGet('messageEditedSuccessfully', fallback: 'Message edited successfully');
  String errorEditingMessage(String error) {
    final template = _safeGet('errorEditingMessage', fallback: 'Error editing message: {error}');
    return template.replaceAll('{error}', error);
  }
  String get deleteMessageTitle => _safeGet('deleteMessageTitle', fallback: 'Delete message');
  String get deleteMessageConfirm => _safeGet('deleteMessageConfirm', fallback: 'Are you sure you want to delete the message?');
  String get deleteChat => _safeGet('deleteChat', fallback: 'Delete chat');
  String errorSendingVoiceMessage(String error) {
    final template = _safeGet('errorSendingVoiceMessage', fallback: 'Error sending voice message: {error}');
    return template.replaceAll('{error}', error);
  }
  String get reached50MessageLimit => _safeGet('reached50MessageLimit', fallback: 'Reached 50 message limit - cannot send more messages');
  String warningMessagesRemaining(int count) {
    final template = _safeGet('warningMessagesRemaining', fallback: 'Warning: Only {count} messages remaining');
    return template.replaceAll('{count}', count.toString());
  }
  String errorSendingMessage(String error) {
    final template = _safeGet('errorSendingMessage', fallback: 'Error sending message: {error}');
    return template.replaceAll('{error}', error);
  }
  String get deleteChatTitle => _safeGet('deleteChatTitle', fallback: 'Delete chat');
  String get deleteChatConfirm => _safeGet('deleteChatConfirm', fallback: 'Are you sure you want to delete the chat? This action cannot be undone.');
  String get chatDeletedSuccessfully => _safeGet('chatDeletedSuccessfully', fallback: 'Chat deleted successfully');
  String errorDeletingChat(String error) {
    final template = _safeGet('errorDeletingChat', fallback: 'Error deleting chat: {error}');
    return template.replaceAll('{error}', error);
  }
  String get cannotReopenChatDeletedByRequester => _safeGet('cannotReopenChatDeletedByRequester', fallback: 'Cannot reopen chat - chat was deleted by the requester');
  String get cannotReopenChatDeletedByProvider => _safeGet('cannotReopenChatDeletedByProvider', fallback: 'Cannot reopen chat - chat was deleted by the service provider');
  String get deleteMyMessagesConfirm => _safeGet('deleteMyMessagesConfirm', fallback: 'Are you sure you want to delete your messages?\nThe other user will continue to see their messages.');
  String get myMessagesDeletedSuccessfully => _safeGet('myMessagesDeletedSuccessfully', fallback: 'Your messages deleted successfully');
  String errorDeletingMyMessages(String error) {
    final template = _safeGet('errorDeletingMyMessages', fallback: 'Error deleting messages: {error}');
    return template.replaceAll('{error}', error);
  }
  
  // Network aware widget getters
  String get connectionRestored => _safeGet('connectionRestored', fallback: 'Connection restored!');
  String get stillNoConnection => _safeGet('stillNoConnection', fallback: 'Still no connection');
  String get processing => _safeGet('processing', fallback: 'Processing...');
  String get noInternetConnection => _safeGet('noInternetConnection', fallback: 'No internet connection');
  
  // Tutorial dialog getters
  String get dontShowAgain => _safeGet('dontShowAgain', fallback: 'Don\'t show again');
  
  // Edit request screen getters
  String get imageAccessPermissionRequired => _safeGet('imageAccessPermissionRequired', fallback: 'Image access permission required');
  String get cameraAccessPermissionRequired => _safeGet('cameraAccessPermissionRequired', fallback: 'Camera access permission required');
  String imagesDeletedFromStorage(int count) {
    final template = _safeGet('imagesDeletedFromStorage', fallback: '{count} images deleted from Storage');
    return template.replaceAll('{count}', count.toString());
  }
  String get pleaseEnterTitle => _safeGet('pleaseEnterTitle', fallback: 'Please enter title');
  String get pleaseEnterDescription => _safeGet('pleaseEnterDescription', fallback: 'Please enter description');
  String get userNotLoggedIn => _safeGet('userNotLoggedIn', fallback: 'User not logged in');
  String get pleaseSelectLocationForRequest => _safeGet('pleaseSelectLocationForRequest', fallback: 'Please select location for request');
  String errorUpdatingRequest(String error) {
    final template = _safeGet('errorUpdatingRequest', fallback: 'Error updating: {error}');
    return template.replaceAll('{error}', error);
  }
  String get deleteImages => _safeGet('deleteImages', fallback: 'Delete images');
  String get deleteAllImagesConfirm => _safeGet('deleteAllImagesConfirm', fallback: 'Are you sure you want to delete all images? Images will also be deleted from Storage.');
  String get deleteAll => _safeGet('deleteAll', fallback: 'Delete all');
  String get allImagesDeletedSuccessfully => _safeGet('allImagesDeletedSuccessfully', fallback: 'All images deleted successfully');
  String get updatingRequest => _safeGet('updatingRequest', fallback: 'Updating request...');
  String get selectMainCategoryThenSubcategory => _safeGet('selectMainCategoryThenSubcategory', fallback: 'Select main field then sub field:');
  String imagesSelected(int count) {
    final template = _safeGet('imagesSelected', fallback: '{count} images selected');
    return template.replaceAll('{count}', count.toString());
  }
  String get clickToSelectLocation => _safeGet('clickToSelectLocation', fallback: 'Click to select location');
  String deadlineDateSelected(int day, int month, int year) {
    final template = _safeGet('deadlineDateSelected', fallback: 'Deadline date: {day}/{month}/{year}');
    return template.replaceAll('{day}', day.toString()).replaceAll('{month}', month.toString()).replaceAll('{year}', year.toString());
  }
  String get urgencyTags => _safeGet('urgencyTags', fallback: 'Urgency tags');
  String get selectTagsForRequest => _safeGet('selectTagsForRequest', fallback: 'Select tags suitable for your request:');
  String get minRatingForHelpers => _safeGet('minRatingForHelpers', fallback: 'Minimum rating for helpers');
  String get allRatings => _safeGet('allRatings', fallback: 'All ratings');
  
  // Service providers count dialog getters
  String get noServiceProvidersInCategory => _safeGet('noServiceProvidersInCategory', fallback: 'No service providers in this category yet');
  String serviceProvidersInCategory(int count) {
    final template = _safeGet('serviceProvidersInCategory', fallback: 'Number of service providers in this category: {count}');
    return template.replaceAll('{count}', count.toString());
  }
  String get noServiceProvidersInCategoryMessage => _safeGet('noServiceProvidersInCategoryMessage', fallback: 'There are no service providers from the category you selected yet.');
  String get theFieldYouSelected => _safeGet('theFieldYouSelected', fallback: 'the field you selected');
  String get confirmMinimalRadius => _safeGet('confirmMinimalRadius', fallback: 'Confirm Minimal Radius');
  String get minimalRadiusWarning => _safeGet('minimalRadiusWarning', fallback: 'The range you selected is only 0.1 km. This is a very small range that will limit the exposure of your request. Are you sure you want to continue with this range?');
  String allRequestsFromCategory(String category) {
    final template = _safeGet('allRequestsFromCategory', fallback: 'All requests from {category} field');
    return template.replaceAll('{category}', category);
  }
  String serviceProvidersInCategoryMessage(int count) {
    final template = _safeGet('serviceProvidersInCategoryMessage', fallback: 'Found {count} available service providers in this category.');
    return template.replaceAll('{count}', count.toString());
  }
  String get continueCreatingRequestMessage => _safeGet('continueCreatingRequestMessage', fallback: 'Continue creating the request - service providers from this category will be added in the future.');
  String get helpGrowCommunity => _safeGet('helpGrowCommunity', fallback: 'Help us grow the community!');
  String get shareAppToGrowProviders => _safeGet('shareAppToGrowProviders', fallback: 'Share the app with friends and colleagues so more service providers can join.');
  String get customTag => _safeGet('customTag', fallback: 'Custom tag');
  String get writeCustomTag => _safeGet('writeCustomTag', fallback: 'Write a short tag of your own');
  String get deleteImage => _safeGet('deleteImage', fallback: 'Delete image');
  String get deleteImageConfirm => _safeGet('deleteImageConfirm', fallback: 'Are you sure you want to delete the image?');
  String get imageDeletedSuccessfully => _safeGet('imageDeletedSuccessfully', fallback: 'Image deleted successfully');
  String errorDeletingImage(String error) {
    final template = _safeGet('errorDeletingImage', fallback: 'Error deleting image: {error}');
    return template.replaceAll('{error}', error);
  }
  String get imageRemovedFromList => _safeGet('imageRemovedFromList', fallback: 'Image removed from list');
  
  // My Requests Screen getters
  String get fullScreenMap => _safeGet('fullScreenMap', fallback: 'Map - Full Screen');
  String get fixedLocationClickForDetails => _safeGet('fixedLocationClickForDetails', fallback: 'Fixed location - Click for full details');
  String get mobileLocationClickForDetails => _safeGet('mobileLocationClickForDetails', fallback: 'Mobile location - Click for full details');
  String overallRating(String rating) {
    final template = _safeGet('overallRating', fallback: 'Overall rating: {rating}');
    return template.replaceAll('{rating}', rating);
  }
  String get ratings => _safeGet('ratings', fallback: 'Ratings:');
  String get reliabilityLabel => _safeGet('reliabilityLabel', fallback: 'Reliability');
  String get availabilityLabel => _safeGet('availabilityLabel', fallback: 'Availability');
  String get attitudeLabel => _safeGet('attitudeLabel', fallback: 'Attitude');
  String get fairPriceLabel => _safeGet('fairPriceLabel', fallback: 'Fair price');
  String get navigateToServiceProvider => _safeGet('navigateToServiceProvider', fallback: 'Navigate to service provider location');
  String phone(String phoneNumber) {
    final template = _safeGet('phone', fallback: 'Phone: {phone}');
    return template.replaceAll('{phone}', phoneNumber);
  }
  String cannotCallNumber(String phoneNumber) {
    final template = _safeGet('cannotCallNumber', fallback: 'Cannot call number: {phone}');
    return template.replaceAll('{phone}', phoneNumber);
  }
  String errorCalling(String error) {
    final template = _safeGet('errorCalling', fallback: 'Error calling: {error}');
    return template.replaceAll('{error}', error);
  }
  String get loadingRequests => _safeGet('loadingRequests', fallback: 'Loading requests...');
  String errorLoading(String error) {
    final template = _safeGet('errorLoading', fallback: 'Error: {error}');
    return template.replaceAll('{error}', error);
  }
  String get openFullScreen => _safeGet('openFullScreen', fallback: 'Open full screen');
  String get refreshMap => _safeGet('refreshMap', fallback: 'Refresh map');
  String get minimalRatings => _safeGet('minimalRatings', fallback: 'Minimal ratings:');
  String generalRating(String rating) {
    final template = _safeGet('generalRating', fallback: 'General: {rating}+');
    return template.replaceAll('{rating}', rating);
  }
  String reliabilityRating(String rating) {
    final template = _safeGet('reliabilityRating', fallback: 'Reliability: {rating}+');
    return template.replaceAll('{rating}', rating);
  }
  String availabilityRating(String rating) {
    final template = _safeGet('availabilityRating', fallback: 'Availability: {rating}+');
    return template.replaceAll('{rating}', rating);
  }
  String attitudeRating(String rating) {
    final template = _safeGet('attitudeRating', fallback: 'Attitude: {rating}+');
    return template.replaceAll('{rating}', rating);
  }
  String priceRating(String rating) {
    final template = _safeGet('priceRating', fallback: 'Price: {rating}+');
    return template.replaceAll('{rating}', rating);
  }
  String get helper => _safeGet('helper', fallback: 'Helper');
  String get chatReopenedCanSend => _safeGet('chatReopenedCanSend', fallback: 'Chat reopened - can send messages');
  String get requestReopenedChatsReopened => _safeGet('requestReopenedChatsReopened', fallback: 'Request reopened and chats reopened');
  String get deleteRequestTitle => _safeGet('deleteRequestTitle', fallback: 'Delete request');
  String get deleteRequestConfirm => _safeGet('deleteRequestConfirm', fallback: 'Are you sure you want to delete this request? This action cannot be undone.');
  String get requestDeletedSuccess => _safeGet('requestDeletedSuccess', fallback: 'Request deleted successfully');
  String errorDeletingRequest(String error) {
    final template = _safeGet('errorDeletingRequest', fallback: 'Error deleting request: {error}');
    return template.replaceAll('{error}', error);
  }
  String deletedImagesFromStorage(int count) {
    final template = _safeGet('deletedImagesFromStorage', fallback: 'Deleted {count} images from Storage');
    return template.replaceAll('{count}', count.toString());
  }
  String errorDeletingImages(String error) {
    final template = _safeGet('errorDeletingImages', fallback: 'Error deleting images: {error}');
    return template.replaceAll('{error}', error);
  }
  String errorOpeningChat(String error) {
    final template = _safeGet('errorOpeningChat', fallback: 'Error opening chat: {error}');
    return template.replaceAll('{error}', error);
  }
  
  // Home Screen getters
  String get privateFree => _safeGet('privateFree', fallback: 'Private free');
  String get privateSubscription => _safeGet('privateSubscription', fallback: 'Private subscription');
  String get businessSubscription => _safeGet('businessSubscription', fallback: 'Business subscription');
  String get businessNoSubscription => _safeGet('businessNoSubscription', fallback: 'Business no subscription');
  String get admin => _safeGet('admin', fallback: 'Admin');
  String get rangeInfo => _safeGet('rangeInfo', fallback: 'Information about your range');
  String currentRange(String radius) {
    final template = _safeGet('currentRange', fallback: 'Your current range: {radius} km');
    return template.replaceAll('{radius}', radius);
  }
  String subscriptionType(String type) {
    final template = _safeGet('subscriptionType', fallback: 'Subscription type: {type}');
    return template.replaceAll('{type}', type);
  }
  String baseRange(String radius) {
    final template = _safeGet('baseRange', fallback: 'Base range: {radius} km');
    return template.replaceAll('{radius}', radius);
  }
  String bonuses(String bonus) {
    final template = _safeGet('bonuses', fallback: 'Bonuses: +{bonus} km');
    return template.replaceAll('{bonus}', bonus);
  }
  String get bonusDetails => _safeGet('bonusDetails', fallback: 'Bonus details:');
  String get howToImproveRange => _safeGet('howToImproveRange', fallback: 'How to improve range:');
  String get recommendAppBonus => _safeGet('recommendAppBonus', fallback: '🎉 Recommend the app to friends (+0.2 km per recommendation)');
  String get getHighRatingsBonus => _safeGet('getHighRatingsBonus', fallback: '⭐ Get high ratings (+0.5-1.5 km)');
  String get subscriptionRequired => _safeGet('subscriptionRequired', fallback: 'Subscription required');
  String get subscriptionRequiredMessage => _safeGet('subscriptionRequiredMessage', fallback: 'To see paid requests, please activate your subscription');
  String get businessFieldsRequired => _safeGet('businessFieldsRequired', fallback: 'Business fields required');
  String get businessFieldsRequiredMessage => _safeGet('businessFieldsRequiredMessage', fallback: 'To see paid requests, please select business fields in profile');
  String get updateProfile => _safeGet('updateProfile', fallback: 'Update profile');
  String get categoryRestriction => _safeGet('categoryRestriction', fallback: 'Category restriction');
  String categoryRestrictionMessage(String category) {
    final template = _safeGet('categoryRestrictionMessage', fallback: 'The business field "{category}" you selected is not one of your business fields. If you want to see paid requests in this category, update your business fields in your profile.');
    return template.replaceAll('{category}', category);
  }
  String get reachedEndOfList => _safeGet('reachedEndOfList', fallback: 'Reached end of list');
  String get noMoreRequestsAvailable => _safeGet('noMoreRequestsAvailable', fallback: 'No more requests available');
  
  // Profile Screen getters
  String get completeYourProfile => _safeGet('completeYourProfile', fallback: 'Complete your profile');
  String get completeProfileMessage => _safeGet('completeProfileMessage', fallback: 'To get better help, it is recommended to complete the details in your profile: photo, short description, location and exposure range. The maximum range depends on your user type.');
  String get whatYouCanDo => _safeGet('whatYouCanDo', fallback: 'What you can do:');
  String get uploadProfilePicture => _safeGet('uploadProfilePicture', fallback: 'Upload profile picture');
  String get updatePersonalDetails => _safeGet('updatePersonalDetails', fallback: 'Update personal details');
  String get updateLocationAndExposureRange => _safeGet('updateLocationAndExposureRange', fallback: 'Update location and exposure range');
  String get selectSubscriptionTypeIfRelevant => _safeGet('selectSubscriptionTypeIfRelevant', fallback: 'Select subscription type (if relevant)');
  String get errorUploadingImage => _safeGet('errorUploadingImage', fallback: 'Error uploading image');
  String get noPermissionToUpload => _safeGet('noPermissionToUpload', fallback: 'No permission to upload images. Please contact the system administrator.');
  String get networkError => _safeGet('networkError', fallback: 'Network error. Please check your internet connection.');
  String get errorStoringImage => _safeGet('errorStoringImage', fallback: 'Error storing image. Please try again.');
  String get user => _safeGet('user', fallback: 'User');
  String get errorUpdatingLocation => _safeGet('errorUpdatingLocation', fallback: 'Error updating location');
  String get errorLocationPermissions => _safeGet('errorLocationPermissions', fallback: 'Error with location permissions. Please check settings');
  String get errorNetworkLocation => _safeGet('errorNetworkLocation', fallback: 'Network error. Please check your internet connection');
  String get timeoutError => _safeGet('timeoutError', fallback: 'Timeout. Please try again');
  String get deleteFixedLocationTitle => _safeGet('deleteFixedLocationTitle', fallback: 'Delete fixed location');
  String get deleteFixedLocationMessage => _safeGet('deleteFixedLocationMessage', fallback: 'Are you sure you want to delete the fixed location?\n\nAfter deletion, you will appear on maps only when location service is active on your phone.');
  String get setBusinessFields => _safeGet('setBusinessFields', fallback: 'Set business fields');
  String get selectUpToTwoFields => _safeGet('selectUpToTwoFields', fallback: 'To receive notifications about relevant requests, you must select up to two business fields:');
  String get iDoNotProvidePaidServices => _safeGet('iDoNotProvidePaidServices', fallback: 'I do not provide any service for payment');
  String get onlyFreeRequestsMessage => _safeGet('onlyFreeRequestsMessage', fallback: 'If you check this option, you will only be able to see free requests on the requests screen.');
  String get toReceiveRelevantNotifications => _safeGet('toReceiveRelevantNotifications', fallback: 'To receive notifications about relevant requests, you must choose up to two business areas:');
  String get ifYouSelectThisOption => _safeGet('ifYouSelectThisOption', fallback: 'If you select this option, you will only be able to see free requests on the requests screen.');
  String get orSelectBusinessAreas => _safeGet('orSelectBusinessAreas', fallback: 'Or select business areas:');
  String get selectBusinessAreasToReceiveRelevantRequests => _safeGet('selectBusinessAreasToReceiveRelevantRequests', fallback: 'Select business areas to receive relevant requests:');
  String get allAds => _safeGet('allAds', fallback: 'All Ads');
  String adsCount(int count) => _safeGet('adsCount', fallback: '{count} ads').replaceAll('{count}', count.toString());
  String get systemAdmin => _safeGet('systemAdmin', fallback: 'System administrator - Full access to all functions (Business subscription)');
  String get manageUsers => _safeGet('manageUsers', fallback: 'Manage users');
  String get requestStatistics => _safeGet('requestStatistics', fallback: 'Request statistics');
  String get deleteAllUsers => _safeGet('deleteAllUsers', fallback: 'Delete all users');
  String get deleteAllRequests => _safeGet('deleteAllRequests', fallback: 'Delete all requests');
  String get deleteAllCollections => _safeGet('deleteAllCollections', fallback: 'Delete all collections');
  String get subscription => _safeGet('subscription', fallback: 'Subscription');
  String get privateSubscriptionType => _safeGet('privateSubscriptionType', fallback: 'Private subscription');
  String get businessSubscriptionType => _safeGet('businessSubscriptionType', fallback: 'Business subscription');
  String rejectionReason(String reason) {
    final template = _safeGet('rejectionReason', fallback: 'Reason: {reason}');
    return template.replaceAll('{reason}', reason);
  }
  String get privateFreeType => _safeGet('privateFreeType', fallback: 'Private free');
  String remainingRequests(int count) {
    final template = _safeGet('remainingRequests', fallback: 'You only have {count} requests left!');
    return template.replaceAll('{count}', count.toString());
  }
  String get wantMoreUpgrade => _safeGet('wantMoreUpgrade', fallback: 'Want more? Upgrade subscription');
  String get guest => _safeGet('guest', fallback: 'Guest');
  String get unknown => _safeGet('unknown', fallback: 'Unknown');
  
  // Share Service getters
  String get interestingRequestInApp => _safeGet('interestingRequestInApp', fallback: '🎯 Interesting request in "Shchunati"!');
  String get locationNotSpecified => _safeGet('locationNotSpecified', fallback: 'Location not specified');
  String get wantToHelpDownloadApp => _safeGet('wantToHelpDownloadApp', fallback: '💡 Want to help? Download the "Shchunati" app and contact directly!');
  
  // App Sharing Service getters
  String get appDescription => _safeGet('appDescription', fallback: '"Shchunati" - The app that connects neighbors for real mutual help');
  String get yourRangeIncreased => _safeGet('yourRangeIncreased', fallback: 'Your range has increased!');
  String get chooseHowToShareApp => _safeGet('chooseHowToShareApp', fallback: 'Choose how you want to share the app:');
  String get sendToWhatsApp => _safeGet('sendToWhatsApp', fallback: 'Send to friends on WhatsApp');
  String get shareOnMessenger => _safeGet('shareOnMessenger', fallback: 'Send on Messenger');
  String get shareOnInstagram => _safeGet('shareOnInstagram', fallback: 'Share on Instagram');
  
  // Profile screen getters
  String get notConnectedToSystem => _safeGet('notConnectedToSystem', fallback: 'Not connected to system');
  String get pleaseLoginToSeeProfile => _safeGet('pleaseLoginToSeeProfile', fallback: 'Please login to see your profile');
  String get loadingProfile => _safeGet('loadingProfile', fallback: 'Loading profile...');
  String get errorLoadingProfile => _safeGet('errorLoadingProfile', fallback: 'Error loading profile');
  String get userProfileNotFound => _safeGet('userProfileNotFound', fallback: 'User profile not found');
  String get creatingProfile => _safeGet('creatingProfile', fallback: 'Creating profile...');
  String get createProfile => _safeGet('createProfile', fallback: 'Create profile');
  String get ifYouProvideService => _safeGet('ifYouProvideService', fallback: 'If you provide any service, set your business fields and get access to paid requests.\n\nYou can change your business fields at any time in your profile.');
  String get later => _safeGet('later', fallback: 'Later');
  String get chooseNow => _safeGet('chooseNow', fallback: 'Choose now');
  String get tutorialsResetSuccess => _safeGet('tutorialsResetSuccess', fallback: 'Tutorial messages reset successfully');
  String subscriptionTypeChanged(String type) {
    final template = _safeGet('subscriptionTypeChanged', fallback: 'Subscription type changed to {type}');
    return template.replaceAll('{type}', type);
  }
  String errorChangingSubscriptionType(String error) {
    final template = _safeGet('errorChangingSubscriptionType', fallback: 'Error changing subscription type: {error}');
    return template.replaceAll('{error}', error);
  }
  String get permissionsRequired => _safeGet('permissionsRequired', fallback: 'Permissions required');
  String get imagePermissionRequired => _safeGet('imagePermissionRequired', fallback: 'Image access permission is required. Please go to app settings and enable the permission.');
  String get openSettings => _safeGet('openSettings', fallback: 'Open settings');
  String get imagePermissionRequiredTryAgain => _safeGet('imagePermissionRequiredTryAgain', fallback: 'Image access permission is required. Please try again.');
  String get chooseAction => _safeGet('chooseAction', fallback: 'Choose action');
  String get chooseFromGallery => _safeGet('chooseFromGallery', fallback: 'Choose from gallery');
  String get deletePhoto => _safeGet('deletePhoto', fallback: 'Delete photo');
  String get profileImageUpdatedSuccess => _safeGet('profileImageUpdatedSuccess', fallback: 'Profile image updated successfully');
  String get profileImageDeletedSuccess => _safeGet('profileImageDeletedSuccess', fallback: 'Profile image deleted successfully');
  String get errorDeletingProfileImage => _safeGet('errorDeletingProfileImage', fallback: 'Error deleting profile image');
  String profileCreatedSuccess(String type) {
    final template = _safeGet('profileCreatedSuccess', fallback: 'Profile created successfully as {type}');
    return template.replaceAll('{type}', type);
  }
  String errorCreatingProfile(String error) {
    final template = _safeGet('errorCreatingProfile', fallback: 'Error creating profile: {error}');
    return template.replaceAll('{error}', error);
  }
  String errorCreatingProfileAlt(String error) {
    final template = _safeGet('errorCreatingProfileAlt', fallback: 'Error creating profile: {error}');
    return template.replaceAll('{error}', error);
  }
  String get checkingLocationPermissions => _safeGet('checkingLocationPermissions', fallback: 'Checking location permissions...');
  String get locationPermissionsRequired => _safeGet('locationPermissionsRequired', fallback: 'Location permissions are required to update location. Please enable location permissions in device settings');
  String get locationServicesDisabled => _safeGet('locationServicesDisabled', fallback: 'Location services are disabled. Please enable them in device settings');
  String get locationServiceDisabledTitle => _safeGet('locationServiceDisabledTitle', fallback: 'Location Service Disabled');
  String get locationServiceDisabledMessage => _safeGet('locationServiceDisabledMessage', fallback: 'Location service on your device is disabled. Location service is essential for the app.');
  String get enableLocationServiceTitle => _safeGet('enableLocationServiceTitle', fallback: 'Enable Location Services on Phone');
  String get enableLocationServiceMessage => _safeGet('enableLocationServiceMessage', fallback: 'To use filtering by mobile location, you need to enable location services on your phone.');
  String get enableLocationService => _safeGet('enableLocationService', fallback: 'Enable Location Services');
  String get gettingCurrentLocation => _safeGet('gettingCurrentLocation', fallback: 'Getting current location...');
  String get savingLocationAndRadius => _safeGet('savingLocationAndRadius', fallback: 'Saving location and exposure radius...');
  String get fixedLocationAndRadiusUpdated => _safeGet('fixedLocationAndRadiusUpdated', fallback: 'Fixed location and exposure radius updated successfully!');
  String get noLocationSelected => _safeGet('noLocationSelected', fallback: 'No location selected');
  String get deletingFixedLocation => _safeGet('deletingFixedLocation', fallback: 'Deleting fixed location');
  String get deleteFixedLocationQuestion => _safeGet('deleteFixedLocationQuestion', fallback: 'Are you sure you want to delete the fixed location?\n\nAfter deletion, you will appear on maps only when location service is active on your phone.');
  String get deletingLocation => _safeGet('deletingLocation', fallback: 'Deleting location...');
  String get fixedLocationDeletedSuccess => _safeGet('fixedLocationDeletedSuccess', fallback: 'Fixed location deleted successfully!');
  String errorDeletingLocation(String error) {
    final template = _safeGet('errorDeletingLocation', fallback: 'Error deleting location: {error}');
    return template.replaceAll('{error}', error);
  }
  String get shareApp => _safeGet('shareApp', fallback: 'Share app');
  String get rateApp => _safeGet('rateApp', fallback: 'Rate app');
  String get recommendToFriends => _safeGet('recommendToFriends', fallback: 'Recommend to friends');
  String get rewards => _safeGet('rewards', fallback: 'Rewards');
  String get resetTutorialMessages => _safeGet('resetTutorialMessages', fallback: 'Reset tutorial messages');
  String get debugSwitchToFree => _safeGet('debugSwitchToFree', fallback: '🔧 Switch to free private');
  String get debugSwitchToPersonal => _safeGet('debugSwitchToPersonal', fallback: '🔧 Switch to personal subscription');
  String get debugSwitchToBusiness => _safeGet('debugSwitchToBusiness', fallback: '🔧 Switch to business subscription');
  String get debugSwitchToGuest => _safeGet('debugSwitchToGuest', fallback: '🔧 Switch to guest');
  String get contact => _safeGet('contact', fallback: 'Contact');
  String get deleteAccount => _safeGet('deleteAccount', fallback: 'Delete account');
  String get update => _safeGet('update', fallback: 'Update');
  String get firstNameLastName => _safeGet('firstNameLastName', fallback: 'First name and last name/company/business/nickname');
  String get enterFirstNameLastName => _safeGet('enterFirstNameLastName', fallback: 'Enter first name and last name/company/business/nickname');
  String get clickUpdateToChangeName => _safeGet('clickUpdateToChangeName', fallback: 'Click "Update" to change the name. The name will be saved automatically');
  String get allBusinessFields => _safeGet('allBusinessFields', fallback: 'All business fields');
  String get businessFields => _safeGet('businessFields', fallback: 'Business fields');
  String get edit => _safeGet('edit', fallback: 'Edit');
  String get noBusinessFieldsDefined => _safeGet('noBusinessFieldsDefined', fallback: 'No business fields defined');
  String get toReceiveNotifications => _safeGet('toReceiveNotifications', fallback: 'To receive notifications about relevant requests, you must select up to two business fields:');
  String get ifYouCheckThisOption => _safeGet('ifYouCheckThisOption', fallback: 'If you check this option, you can see only free requests in the requests screen.');
  String get monthlyRequests => _safeGet('monthlyRequests', fallback: 'Monthly requests');
  String publishedRequestsThisMonth(int count) {
    final template = _safeGet('publishedRequestsThisMonth', fallback: 'Published {count} requests this month (no limit)');
    return template.replaceAll('{count}', count.toString());
  }
  String remainingRequestsThisMonth(int count) {
    final template = _safeGet('remainingRequestsThisMonth', fallback: 'You have {count} requests remaining to publish this month');
    return template.replaceAll('{count}', count.toString());
  }
  String get reachedMonthlyRequestLimit => _safeGet('reachedMonthlyRequestLimit', fallback: 'Reached monthly request limit');
  String get wantMoreUpgradeSubscription => _safeGet('wantMoreUpgradeSubscription', fallback: 'Want more? Upgrade subscription');
  String get fixedLocation => _safeGet('fixedLocation', fallback: 'Fixed location');
  String get updateLocationAndRadius => _safeGet('updateLocationAndRadius', fallback: 'Update location and radius');
  String get adminCanUpdateLocation => _safeGet('adminCanUpdateLocation', fallback: 'Admin - can update location like any other user');
  String get fixedLocationDefined => _safeGet('fixedLocationDefined', fallback: 'Fixed location defined');
  String get villageNotDefined => _safeGet('villageNotDefined', fallback: 'Village not defined');
  String get youWillAppearInRange => _safeGet('youWillAppearInRange', fallback: '✅ You will appear in the range of published requests that match your business field, even if location service is not active on your phone');
  String get deleteLocation => _safeGet('deleteLocation', fallback: 'Delete location');
  String get noFixedLocationDefined => _safeGet('noFixedLocationDefined', fallback: 'No fixed location and exposure radius defined');
  String get asServiceProvider => _safeGet('asServiceProvider', fallback: 'As a service provider, setting a fixed location and exposure radius is essential:');
  String get locationBenefits => _safeGet('locationBenefits', fallback: '• You will receive notifications about requests relevant to your business field\n• You will appear on maps of request publishers and they can contact you\n• Fixed location service will continue to serve you even when location service is disabled on your phone');
  String get systemManagement => _safeGet('systemManagement', fallback: 'System management');
  String get manageInquiries => _safeGet('manageInquiries', fallback: 'Manage inquiries');
  String get manageGuests => _safeGet('manageGuests', fallback: 'Manage guests');
  String get additionalInfo => _safeGet('additionalInfo', fallback: 'Additional info');
  String get joinDate => _safeGet('joinDate', fallback: 'Join date');
  String get helpUsGrow => _safeGet('helpUsGrow', fallback: 'Help us grow');
  String get recommendAppToFriends => _safeGet('recommendAppToFriends', fallback: 'Recommend the app to friends and get rewards!');
  String get approved => _safeGet('approved', fallback: '✅ Approved');
  String subscriptionPendingApproval(String type) {
    final template = _safeGet('subscriptionPendingApproval', fallback: '{type} pending approval');
    return template.replaceAll('{type}', type);
  }
  String get waitingForAdminApproval => _safeGet('waitingForAdminApproval', fallback: '⏳ Waiting for admin approval');
  String get upgradeRequestRejected => _safeGet('upgradeRequestRejected', fallback: '❌ Upgrade request rejected');
  String get privateFreeStatus => _safeGet('privateFreeStatus', fallback: 'Private free');
  String get freeAccessToFreeRequests => _safeGet('freeAccessToFreeRequests', fallback: '🆓 Access to free requests');
  String get requestApprovalPending => _safeGet('requestApprovalPending', fallback: 'Request pending approval ⏳');
  String get chooseSubscriptionType => _safeGet('chooseSubscriptionType', fallback: 'Choose subscription type:');
  String get upgradeToBusiness => _safeGet('upgradeToBusiness', fallback: 'Upgrade to business subscription:');
  String get noUpgradeOptionsAvailable => _safeGet('noUpgradeOptionsAvailable', fallback: 'No upgrade options available');
  String get privateFreeDescription => _safeGet('privateFreeDescription', fallback: '• 1 request per month\n• Range: 0-3 km\n• See only free requests\n• No business fields');
  String get yourFreeSubscription => _safeGet('yourFreeSubscription', fallback: 'Your free subscription');
  String get upgrade => _safeGet('upgrade', fallback: 'Upgrade');
  String get deleteAccountTitle => _safeGet('deleteAccountTitle', fallback: 'Delete account');
  String get deleteAccountConfirm => _safeGet('deleteAccountConfirm', fallback: 'Are you sure you want to delete your account?');
  String get thisActionWillDeletePermanently => _safeGet('thisActionWillDeletePermanently', fallback: 'This action will delete permanently:');
  String get yourLoginCredentials => _safeGet('yourLoginCredentials', fallback: 'Your login credentials');
  String get yourPersonalInfo => _safeGet('yourPersonalInfo', fallback: 'Your personal information in profile');
  String get allYourPublishedRequests => _safeGet('allYourPublishedRequests', fallback: 'All your published requests');
  String get allYourInterestedRequests => _safeGet('allYourInterestedRequests', fallback: 'All requests you were interested in');
  String get allYourChats => _safeGet('allYourChats', fallback: 'All your chats');
  String get allYourMessages => _safeGet('allYourMessages', fallback: 'All messages you sent and received');
  String get allYourImages => _safeGet('allYourImages', fallback: 'All images and files');
  String get allYourData => _safeGet('allYourData', fallback: 'All data and history');
  String get thisActionCannotBeUndone => _safeGet('thisActionCannotBeUndone', fallback: 'This action cannot be undone!');
  String get passwordConfirmation => _safeGet('passwordConfirmation', fallback: 'Password confirmation');
  String get passwordConfirmationMessage => _safeGet('passwordConfirmationMessage', fallback: 'To delete the account, please enter your password for confirmation:');
  String get passwordRequired => _safeGet('passwordRequired', fallback: 'Please enter your password');
  String get thisActionWillDeleteAccountPermanently => _safeGet('thisActionWillDeleteAccountPermanently', fallback: 'This action will delete the account permanently!');
  String get deletingAccount => _safeGet('deletingAccount', fallback: 'Deleting account...');
  String get noUserFound => _safeGet('noUserFound', fallback: 'No connected user found');
  String get accountDeletedSuccess => _safeGet('accountDeletedSuccess', fallback: 'Account deleted successfully');
  String get deletingAccountProgress => _safeGet('deletingAccountProgress', fallback: 'Deleting account...');
  String get deleteUser => _safeGet('deleteUser', fallback: 'Delete user');
  String get googleUserDeleteTitle => _safeGet('googleUserDeleteTitle', fallback: 'Delete user');
  String get loggedInWithGoogle => _safeGet('loggedInWithGoogle', fallback: 'Logged in with Google');
  String get clickConfirmToDeletePermanently => _safeGet('clickConfirmToDeletePermanently', fallback: 'Click "Confirm" to delete the account permanently.\nThis action cannot be undone!');
  String get contactScreenTitle => _safeGet('contactScreenTitle', fallback: 'Contact Us');
  String get contactScreenSubtitle => _safeGet('contactScreenSubtitle', fallback: 'Have questions? Something unclear? We\'d love to hear from you');
  String get contactOperatorInfo => _safeGet('contactOperatorInfo', fallback: 'The "Shchunati" app is operated by "Extreme Technologies" – a legally registered business in Israel. Support is also available for privacy requests and account deletion.');
  String get contactName => _safeGet('contactName', fallback: 'Name');
  String get contactNameHint => _safeGet('contactNameHint', fallback: 'Enter your name');
  String get contactNameRequired => _safeGet('contactNameRequired', fallback: 'Please enter your name');
  String get contactEmail => _safeGet('contactEmail', fallback: 'Email');
  String get contactEmailHint => _safeGet('contactEmailHint', fallback: 'Enter your email address');
  String get contactEmailRequired => _safeGet('contactEmailRequired', fallback: 'Please enter your email address');
  String get contactEmailInvalid => _safeGet('contactEmailInvalid', fallback: 'Please enter a valid email address');
  String get contactMessage => _safeGet('contactMessage', fallback: 'Message');
  String get contactMessageHint => _safeGet('contactMessageHint', fallback: 'Free text');
  String get contactMessageRequired => _safeGet('contactMessageRequired', fallback: 'Please enter your message');
  String get contactMessageTooShort => _safeGet('contactMessageTooShort', fallback: 'Please enter a more detailed message (at least 10 characters)');
  String get contactSend => _safeGet('contactSend', fallback: 'Send');
  String get contactSuccess => _safeGet('contactSuccess', fallback: 'Inquiry sent successfully! We will get back to you soon');
  String contactError(String error) {
    final template = _safeGet('contactError', fallback: 'Error sending inquiry: {error}');
    return template.replaceAll('{error}', error);
  }
  String get errorLoadingRating => _safeGet('errorLoadingRating', fallback: 'Error loading rating');
  String get noRatingAvailable => _safeGet('noRatingAvailable', fallback: 'No rating available');
  String get trialPeriodInfo => _safeGet('trialPeriodInfo', fallback: 'Information about your trial period');

         // Check if current locale is RTL
         bool get isRTL => locale.languageCode == 'he' || locale.languageCode == 'ar';

  // Get localized day name
  String getDayName(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.sunday:
        return daySunday;
      case DayOfWeek.monday:
        return dayMonday;
      case DayOfWeek.tuesday:
        return dayTuesday;
      case DayOfWeek.wednesday:
        return dayWednesday;
      case DayOfWeek.thursday:
        return dayThursday;
      case DayOfWeek.friday:
        return dayFriday;
      case DayOfWeek.saturday:
        return daySaturday;
    }
  }

  // Urgency tag getters
  String get tagSuddenLeak => _safeGet('tagSuddenLeak', fallback: '❗ Sudden leak');
  String get tagPowerOutage => _safeGet('tagPowerOutage', fallback: '⚡ Power outage');
  String get tagLockedOut => _safeGet('tagLockedOut', fallback: '🔒 Locked out');
  String get tagUrgentBeforeShabbat => _safeGet('tagUrgentBeforeShabbat', fallback: '🔧 Urgent repair before Shabbat');
  String get tagCarStuck => _safeGet('tagCarStuck', fallback: '🚨 Car stuck on road');
  String get tagJumpStart => _safeGet('tagJumpStart', fallback: '🔋 Jump start / Cables');
  String get tagQuickParkingRepair => _safeGet('tagQuickParkingRepair', fallback: '🧰 Quick parking repair');
  String get tagMovingToday => _safeGet('tagMovingToday', fallback: '🧳 Moving help today');
  String get tagUrgentBabysitter => _safeGet('tagUrgentBabysitter', fallback: '🍼 Urgent babysitter');
  String get tagExamTomorrow => _safeGet('tagExamTomorrow', fallback: '📚 Lesson before exam tomorrow');
  String get tagSickChild => _safeGet('tagSickChild', fallback: '🧸 Help with sick child');
  String get tagZoomLessonNow => _safeGet('tagZoomLessonNow', fallback: '👩‍🏫 Zoom lesson now');
  String get tagUrgentDocument => _safeGet('tagUrgentDocument', fallback: '📄 Urgent document');
  String get tagMeetingToday => _safeGet('tagMeetingToday', fallback: '🤝 Meeting today');
  String get tagPresentationTomorrow => _safeGet('tagPresentationTomorrow', fallback: '📊 Presentation tomorrow');
  String get tagUrgentTranslation => _safeGet('tagUrgentTranslation', fallback: '🌐 Urgent translation');
  String get tagWeddingToday => _safeGet('tagWeddingToday', fallback: '💒 Wedding today');
  String get tagUrgentGift => _safeGet('tagUrgentGift', fallback: '🎁 Urgent gift');
  String get tagEventTomorrow => _safeGet('tagEventTomorrow', fallback: '🎉 Event tomorrow');
  String get tagUrgentCraftRepair => _safeGet('tagUrgentCraftRepair', fallback: '🔧 Urgent craft repair');
  String get tagUrgentAppointment => _safeGet('tagUrgentAppointment', fallback: '🏥 Urgent appointment');
  String get tagEmergencyCare => _safeGet('tagEmergencyCare', fallback: '🚑 Emergency care');
  String get tagUrgentTherapy => _safeGet('tagUrgentTherapy', fallback: '💆 Urgent therapy');
  String get tagHealthEmergency => _safeGet('tagHealthEmergency', fallback: '⚕️ Health emergency');
  String get tagUrgentITSupport => _safeGet('tagUrgentITSupport', fallback: '💻 Urgent IT support');
  String get tagSystemDown => _safeGet('tagSystemDown', fallback: '🖥️ System down');
  String get tagUrgentTechRepair => _safeGet('tagUrgentTechRepair', fallback: '🔧 Urgent tech repair');
  String get tagDataRecovery => _safeGet('tagDataRecovery', fallback: '💾 Data recovery');
  String get tagUrgentTutoring => _safeGet('tagUrgentTutoring', fallback: '📖 Urgent tutoring');
  String get tagExamPreparation => _safeGet('tagExamPreparation', fallback: '📝 Exam preparation');
  String get tagUrgentCourse => _safeGet('tagUrgentCourse', fallback: '🎓 Urgent course');
  String get tagCertificationUrgent => _safeGet('tagCertificationUrgent', fallback: '🏆 Urgent certification');
  String get tagPartyToday => _safeGet('tagPartyToday', fallback: '🎊 Party today');
  String get tagUrgentEntertainment => _safeGet('tagUrgentEntertainment', fallback: '🎭 Urgent entertainment');
  String get tagEventSetup => _safeGet('tagEventSetup', fallback: '🎪 Event setup');
  String get tagUrgentPhotography => _safeGet('tagUrgentPhotography', fallback: '📸 Urgent photography');
  String get tagUrgentGardenCare => _safeGet('tagUrgentGardenCare', fallback: '🌱 Urgent garden care');
  String get tagTreeEmergency => _safeGet('tagTreeEmergency', fallback: '🌳 Tree emergency');
  String get tagUrgentCleaning => _safeGet('tagUrgentCleaning', fallback: '🧹 Urgent cleaning');
  String get tagPestControl => _safeGet('tagPestControl', fallback: '🐛 Pest control');
  String get tagUrgentCatering => _safeGet('tagUrgentCatering', fallback: '🍽️ Urgent catering');
  String get tagPartyFood => _safeGet('tagPartyFood', fallback: '🍕 Party food');
  String get tagUrgentDelivery => _safeGet('tagUrgentDelivery', fallback: '🚚 Urgent delivery');
  String get tagSpecialDiet => _safeGet('tagSpecialDiet', fallback: '🥗 Special diet');
  String get tagUrgentTraining => _safeGet('tagUrgentTraining', fallback: '💪 Urgent training');
  String get tagCompetitionPrep => _safeGet('tagCompetitionPrep', fallback: '🏆 Competition preparation');
  String get tagInjuryRecovery => _safeGet('tagInjuryRecovery', fallback: '🩹 Injury recovery');
  String get tagUrgentCoaching => _safeGet('tagUrgentCoaching', fallback: '🏃 Urgent coaching');
  String get tagEventToday => _safeGet('tagEventToday', fallback: '🎉 Event today');
  String get tagUrgentBeforeEvent => _safeGet('tagUrgentBeforeEvent', fallback: '💄 Urgent before event');
  String get tagUrgentBeautyFix => _safeGet('tagUrgentBeautyFix', fallback: '✨ Urgent beauty fix');
  String get tagUrgentPurchase => _safeGet('tagUrgentPurchase', fallback: '🛒 Urgent purchase');
  String get tagUrgentSale => _safeGet('tagUrgentSale', fallback: '💰 Urgent sale');
  String get tagEventShopping => _safeGet('tagEventShopping', fallback: '🎁 Shopping for event today');
  String get tagUrgentProduct => _safeGet('tagUrgentProduct', fallback: '📦 Urgent product');
  String get tagUrgentDeliveryToday => _safeGet('tagUrgentDeliveryToday', fallback: '📦 Urgent delivery today');
  String get tagUrgentMoving => _safeGet('tagUrgentMoving', fallback: '🚚 Urgent moving');
  String get tagUrgentRoadRepair => _safeGet('tagUrgentRoadRepair', fallback: '🔧 Urgent road repair');
  String get tagUrgentTowing => _safeGet('tagUrgentTowing', fallback: '🚛 Urgent towing');
  String get tagUrgentPostRenovation => _safeGet('tagUrgentPostRenovation', fallback: '🧹 Urgent post-renovation cleaning');
  String get tagUrgentConsultation => _safeGet('tagUrgentConsultation', fallback: '💼 Urgent consultation');
  String get tagUrgentMeeting => _safeGet('tagUrgentMeeting', fallback: '🤝 Urgent meeting');
  String get tagUrgentElderlyHelp => _safeGet('tagUrgentElderlyHelp', fallback: '👴 Urgent elderly help');
  String get tagUrgentVolunteering => _safeGet('tagUrgentVolunteering', fallback: '❤️ Urgent volunteering');
  String get tagUrgentPetCare => _safeGet('tagUrgentPetCare', fallback: '🐾 Urgent pet care');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['he', 'ar', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
