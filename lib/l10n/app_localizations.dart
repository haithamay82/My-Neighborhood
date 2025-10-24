import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
      'welcomeBack': 'ברוך הבא חזור',
      'joinCommunity': 'הצטרף לקהילה שלנו',
      'fullName': 'שם מלא',
      'email': 'אימייל',
      'password': 'סיסמה',
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
      'myRequests': 'בקשות שלי',
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
      'searchHint': 'חיפוש בקשות...',
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
             'error': 'שגיאה',
             'ok': 'אישור',
             'noResults': 'לא נמצאו תוצאות עבור',
             'noRequests': 'אין בקשות זמינות',
             'save': 'שמור',
             'requestTitle': 'כותרת הבקשה',
             'requestDescription': 'תיאור הבקשה',
             'enterTitle': 'אנא הכנס כותרת',
             'enterDescription': 'אנא הכנס תיאור',
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
      'subscriptionPayment': 'תשלום מנוי',
      'payWithBit': 'שלם עם ביט',
      'annualSubscription': 'מנוי שנתי - 10 ש״ח',
      'subscriptionDescription': 'גישה לבקשות בתשלום לפי תחומי העיסוק שלך',
      'activateSubscription': 'הפעל מנוי',
      'subscriptionStatus': 'סטטוס מנוי',
      'active': 'פעיל',
      'inactive': 'לא פעיל',
      'expiryDate': 'תאריך פג תוקף',
    },
    'ar': {
      'appTitle': 'حيي',
      'hello': 'مرحباً',
      'welcomeBack': 'مرحباً بعودتك',
      'joinCommunity': 'انضم إلى مجتمعنا',
      'fullName': 'الاسم الكامل',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
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
      'myRequests': 'طلباتي',
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
      'searchHint': 'البحث في الطلبات...',
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
             'error': 'خطأ',
             'ok': 'موافق',
             'noResults': 'لم يتم العثور على نتائج لـ',
             'noRequests': 'لا توجد طلبات متاحة',
             'save': 'حفظ',
             'requestTitle': 'عنوان الطلب',
             'requestDescription': 'وصف الطلب',
             'enterTitle': 'يرجى إدخال العنوان',
             'enterDescription': 'يرجى إدخال الوصف',
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
      'deadline': 'تاريخ الهدف',
      'selectDeadline': 'اختر تاريخ الهدف',
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
      'subscriptionPayment': 'دفع الاشتراك',
      'payWithBit': 'ادفع مع بت',
      'annualSubscription': 'اشتراك سنوي - 10 شيكل',
      'subscriptionDescription': 'الوصول للطلبات المدفوعة حسب مجالات عملك',
      'activateSubscription': 'تفعيل الاشتراك',
      'subscriptionStatus': 'حالة الاشتراك',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'expiryDate': 'تاريخ انتهاء الصلاحية',
    },
    'en': {
      'appTitle': 'Neighborhood',
      'hello': 'Hello',
      'welcomeBack': 'Welcome back',
      'joinCommunity': 'Join our community',
      'fullName': 'Full Name',
      'email': 'Email',
      'password': 'Password',
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
      'myRequests': 'My Requests',
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
      'searchHint': 'Search requests...',
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
             'error': 'Error',
             'ok': 'OK',
             'noResults': 'No results found for',
             'noRequests': 'No requests available',
             'save': 'Save',
             'requestTitle': 'Request Title',
             'requestDescription': 'Request Description',
             'enterTitle': 'Please enter title',
             'enterDescription': 'Please enter description',
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
      'subscriptionPayment': 'Subscription Payment',
      'payWithBit': 'Pay with Bit',
      'annualSubscription': 'Annual Subscription - 10 NIS',
      'subscriptionDescription': 'Access to paid requests according to your business fields',
      'activateSubscription': 'Activate Subscription',
      'subscriptionStatus': 'Subscription Status',
      'active': 'Active',
      'inactive': 'Inactive',
      'expiryDate': 'Expiry Date',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  String get hello => _localizedValues[locale.languageCode]!['hello']!;
  String get welcomeBack => _localizedValues[locale.languageCode]!['welcomeBack']!;
  String get joinCommunity => _localizedValues[locale.languageCode]!['joinCommunity']!;
  String get fullName => _localizedValues[locale.languageCode]!['fullName']!;
  String get email => _localizedValues[locale.languageCode]!['email']!;
  String get password => _localizedValues[locale.languageCode]!['password']!;
  String get userType => _localizedValues[locale.languageCode]!['userType']!;
  String get personal => _localizedValues[locale.languageCode]!['personal']!;
  String get business => _localizedValues[locale.languageCode]!['business']!;
  String get limitedAccess => _localizedValues[locale.languageCode]!['limitedAccess']!;
  String get fullAccess => _localizedValues[locale.languageCode]!['fullAccess']!;
  String get register => _localizedValues[locale.languageCode]!['register']!;
  String get login => _localizedValues[locale.languageCode]!['login']!;
  String get alreadyHaveAccount => _localizedValues[locale.languageCode]!['alreadyHaveAccount']!;
  String get noAccount => _localizedValues[locale.languageCode]!['noAccount']!;
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get notifications => _localizedValues[locale.languageCode]!['notifications']!;
  String get chat => _localizedValues[locale.languageCode]!['chat']!;
  String get profile => _localizedValues[locale.languageCode]!['profile']!;
  String get myRequests => _localizedValues[locale.languageCode]!['myRequests']!;
  String get newRequest => _localizedValues[locale.languageCode]!['newRequest']!;
  String get logout => _localizedValues[locale.languageCode]!['logout']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get selectLanguage => _localizedValues[locale.languageCode]!['selectLanguage']!;
  String get hebrew => _localizedValues[locale.languageCode]!['hebrew']!;
  String get arabic => _localizedValues[locale.languageCode]!['arabic']!;
  String get english => _localizedValues[locale.languageCode]!['english']!;
  String get theme => _localizedValues[locale.languageCode]!['theme']!;
  String get lightTheme => _localizedValues[locale.languageCode]!['lightTheme']!;
  String get darkTheme => _localizedValues[locale.languageCode]!['darkTheme']!;
  String get systemTheme => _localizedValues[locale.languageCode]!['systemTheme']!;
  String get searchHint => _localizedValues[locale.languageCode]!['searchHint']!;
  String get location => _localizedValues[locale.languageCode]!['location']!;
  String get nearMe => _localizedValues[locale.languageCode]!['nearMe']!;
  String get wholeVillage => _localizedValues[locale.languageCode]!['wholeVillage']!;
  String get city => _localizedValues[locale.languageCode]!['city']!;
  String get category => _localizedValues[locale.languageCode]!['category']!;
  String get all => _localizedValues[locale.languageCode]!['all']!;
  String get maintenance => _localizedValues[locale.languageCode]!['maintenance']!;
  String get education => _localizedValues[locale.languageCode]!['education']!;
  String get transport => _localizedValues[locale.languageCode]!['transport']!;
  String get shopping => _localizedValues[locale.languageCode]!['shopping']!;
  String get urgent => _localizedValues[locale.languageCode]!['urgent']!;
  String get canHelp => _localizedValues[locale.languageCode]!['canHelp']!;
  String get requestTitleExample => _localizedValues[locale.languageCode]!['requestTitleExample']!;
  String get requestDescriptionExample => _localizedValues[locale.languageCode]!['requestDescriptionExample']!;
  String get requestTitle2 => _localizedValues[locale.languageCode]!['requestTitle2']!;
  String get requestDescription2 => _localizedValues[locale.languageCode]!['requestDescription2']!;
  String get requestTitle3 => _localizedValues[locale.languageCode]!['requestTitle3']!;
  String get requestDescription3 => _localizedValues[locale.languageCode]!['requestDescription3']!;
  String get enterName => _localizedValues[locale.languageCode]!['enterName']!;
  String get enterEmail => _localizedValues[locale.languageCode]!['enterEmail']!;
  String get invalidEmail => _localizedValues[locale.languageCode]!['invalidEmail']!;
  String get enterPassword => _localizedValues[locale.languageCode]!['enterPassword']!;
  String get weakPassword => _localizedValues[locale.languageCode]!['weakPassword']!;
  String get signUpSuccess => _localizedValues[locale.languageCode]!['signUpSuccess']!;
  String get loginSuccess => _localizedValues[locale.languageCode]!['loginSuccess']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
         String get ok => _localizedValues[locale.languageCode]!['ok']!;
         String get noResults => _localizedValues[locale.languageCode]!['noResults']!;
         String get noRequests => _localizedValues[locale.languageCode]!['noRequests']!;
         String get save => _localizedValues[locale.languageCode]!['save']!;
         String get enterTitle => _localizedValues[locale.languageCode]!['enterTitle']!;
         String get enterDescription => _localizedValues[locale.languageCode]!['enterDescription']!;
         String get images => _localizedValues[locale.languageCode]!['images']!;
         String get addImages => _localizedValues[locale.languageCode]!['addImages']!;
         String get clear => _localizedValues[locale.languageCode]!['clear']!;
         String get requestTitle => _localizedValues[locale.languageCode]!['requestTitle']!;
         String get requestDescription => _localizedValues[locale.languageCode]!['requestDescription']!;
         String get sendMessage => _localizedValues[locale.languageCode]!['sendMessage']!;
         String get noMessages => _localizedValues[locale.languageCode]!['noMessages']!;
         String get you => _localizedValues[locale.languageCode]!['you']!;
         String get otherUser => _localizedValues[locale.languageCode]!['otherUser']!;
         String get phoneNumber => _localizedValues[locale.languageCode]!['phoneNumber']!;
         String get enterPhoneNumber => _localizedValues[locale.languageCode]!['enterPhoneNumber']!;
         String get clearChat => _localizedValues[locale.languageCode]!['clearChat']!;
         String get clearChatConfirm => _localizedValues[locale.languageCode]!['clearChatConfirm']!;
         String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
         String get delete => _localizedValues[locale.languageCode]!['delete']!;
         String get chatCleared => _localizedValues[locale.languageCode]!['chatCleared']!;
         String get open => _localizedValues[locale.languageCode]!['open']!;
         String get inProgress => _localizedValues[locale.languageCode]!['inProgress']!;
         String get completed => _localizedValues[locale.languageCode]!['completed']!;
         String get cancelled => _localizedValues[locale.languageCode]!['cancelled']!;
         String get free => _localizedValues[locale.languageCode]!['free']!;
         String get paid => _localizedValues[locale.languageCode]!['paid']!;
         String get deadline => _localizedValues[locale.languageCode]!['deadline']!;
         String get selectDeadline => _localizedValues[locale.languageCode]!['selectDeadline']!;
         String get targetAudience => _localizedValues[locale.languageCode]!['targetAudience']!;
         String get distance => _localizedValues[locale.languageCode]!['distance']!;
         String get maxDistance => _localizedValues[locale.languageCode]!['maxDistance']!;
         String get selectVillage => _localizedValues[locale.languageCode]!['selectVillage']!;
         String get selectCategories => _localizedValues[locale.languageCode]!['selectCategories']!;
         String get requestType => _localizedValues[locale.languageCode]!['requestType']!;
         String get selectRequestType => _localizedValues[locale.languageCode]!['selectRequestType']!;
         String get selectTargetAudience => _localizedValues[locale.languageCode]!['selectTargetAudience']!;
         String get allCategories => _localizedValues[locale.languageCode]!['allCategories']!;
         String get expired => _localizedValues[locale.languageCode]!['expired']!;
         String get editRequest => _localizedValues[locale.languageCode]!['editRequest']!;
         String get deleteRequest => _localizedValues[locale.languageCode]!['deleteRequest']!;
         String get confirmDelete => _localizedValues[locale.languageCode]!['confirmDelete']!;
         String get requestDeleted => _localizedValues[locale.languageCode]!['requestDeleted']!;
         String get requestUpdated => _localizedValues[locale.languageCode]!['requestUpdated']!;
         String get newMessage => _localizedValues[locale.languageCode]!['newMessage']!;
         String get unreadMessages => _localizedValues[locale.languageCode]!['unreadMessages']!;
  String get publishAllTypes => _localizedValues[locale.languageCode]!['publishAllTypes']!;
  String get respondFreeOnly => _localizedValues[locale.languageCode]!['respondFreeOnly']!;
  String get respondFreeAndPaid => _localizedValues[locale.languageCode]!['respondFreeAndPaid']!;
  String get businessCategories => _localizedValues[locale.languageCode]!['businessCategories']!;
  String get selectBusinessCategories => _localizedValues[locale.languageCode]!['selectBusinessCategories']!;
  String get subscriptionPayment => _localizedValues[locale.languageCode]!['subscriptionPayment']!;
  String get payWithBit => _localizedValues[locale.languageCode]!['payWithBit']!;
  String get annualSubscription => _localizedValues[locale.languageCode]!['annualSubscription']!;
  String get subscriptionDescription => _localizedValues[locale.languageCode]!['subscriptionDescription']!;
  String get activateSubscription => _localizedValues[locale.languageCode]!['activateSubscription']!;
  String get subscriptionStatus => _localizedValues[locale.languageCode]!['subscriptionStatus']!;
  String get active => _localizedValues[locale.languageCode]!['active']!;
  String get inactive => _localizedValues[locale.languageCode]!['inactive']!;
  String get expiryDate => _localizedValues[locale.languageCode]!['expiryDate']!;

         // Check if current locale is RTL
         bool get isRTL => locale.languageCode == 'he' || locale.languageCode == 'ar';
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
