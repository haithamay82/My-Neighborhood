import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'dart:html' as html show window;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_messaging_background.dart';
import 'services/push_notification_service.dart';
import 'services/hive_cache_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/yoki_style_auth_screen.dart';
import 'screens/tutorial_center_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/my_requests_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'services/admin_auth_service.dart';
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/app_state_service.dart';
import 'services/audio_service.dart';
import 'services/auto_login_service.dart';
import 'services/tiktok_auth_service.dart';
import 'services/monthly_requests_tracker.dart';
import 'services/request_reminder_service.dart';
import 'services/background_location_service.dart';
import 'services/location_service.dart';
import 'package:geolocator/geolocator.dart';
// Guest trial expiry check moved to Cloud Functions
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'firebase_options.dart';
import 'widgets/background_icons_widget.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // אתחול Firebase
  // על iOS, Firebase כבר מאותחל ב-AppDelegate.swift, אז לא צריך לאתחל שוב
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  } else if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
    // על iOS, FirebaseApp.configure() נקרא ב-AppDelegate.swift
    // על Web, צריך לאתחל
    if (kIsWeb) {
      final webOptions = DefaultFirebaseOptions.currentPlatform;
      debugPrint('🌐 Initializing Firebase for Web');
      debugPrint('   App ID: ${webOptions.appId}');
      debugPrint('   Project ID: ${webOptions.projectId}');
      debugPrint('   Auth Domain: ${webOptions.authDomain}');
      await Firebase.initializeApp(
        options: webOptions,
      );
      debugPrint('✅ Firebase initialized for Web successfully');
      
      // 🔥 טיפול ב-Google Sign-In redirect לפני ש-Flutter router מתחיל
      // זה חשוב כי Firebase Auth צריך לעבד את ה-redirect לפני ש-Flutter router משנה את ה-URL
      try {
        debugPrint('🔍 Checking for Google Sign-In redirect BEFORE Flutter router...');
        
        // קריאה ל-JavaScript כדי לקבל את ה-URL המלא לפני ש-Flutter router משנה אותו
        if (kIsWeb) {
          try {
            // קריאה ל-window.location כדי לקבל את ה-URL המלא
            final currentUrl = html.window.location.href;
            final currentPath = html.window.location.pathname;
            final currentQuery = html.window.location.search;
            final currentHash = html.window.location.hash;
            
            debugPrint('   Current URL (from window.location): $currentUrl');
            debugPrint('   Current path: $currentPath');
            debugPrint('   Current query: $currentQuery');
            debugPrint('   Current hash: $currentHash');
            
            // בדיקה אם זה Firebase Auth redirect handler
            final isAuthHandler = currentPath == '/__/auth/handler';
            debugPrint('   Is /__/auth/handler: $isAuthHandler');
            
            // ניסיון לפרסר את ה-URL המלא
            final fullUrl = Uri.parse(currentUrl);
            debugPrint('   Parsed URL query: ${fullUrl.query}');
            debugPrint('   Parsed URL query params: ${fullUrl.queryParameters}');
            
            // בדיקה אם יש query parameters של redirect
            final hasRedirectParams = fullUrl.queryParameters.containsKey('__firebase_request_key__') ||
                fullUrl.queryParameters.containsKey('apiKey') ||
                fullUrl.queryParameters.containsKey('mode') ||
                fullUrl.queryParameters.containsKey('oobCode') ||
                (currentQuery?.contains('__firebase_request_key__') ?? false) ||
                (currentQuery?.contains('apiKey') ?? false) ||
                isAuthHandler; // גם אם זה /__/auth/handler, ננסה לעבד את ה-redirect
            
            debugPrint('   Has redirect params: $hasRedirectParams');
            
            // גם אם אין query parameters גלויים, ננסה לקרוא את getRedirectResult
            // כי Firebase Auth יכול לעבד את ה-redirect גם בלי query parameters גלויים
            // זה חשוב במיוחד אם זה /__/auth/handler
            debugPrint('   Attempting getRedirectResult...');
            await Future.delayed(const Duration(milliseconds: 2000)); // המתנה ארוכה יותר
            
            final redirectResult = await FirebaseAuth.instance.getRedirectResult();
            debugPrint('   Redirect result: hasUser=${redirectResult.user != null}, hasCredential=${redirectResult.credential != null}');
            debugPrint('   Redirect result additionalUserInfo: ${redirectResult.additionalUserInfo != null}');
            
            if (redirectResult.user != null) {
              debugPrint('✅ Google Sign-In redirect processed successfully: ${redirectResult.user!.email}');
              debugPrint('   User ID: ${redirectResult.user!.uid}');
              debugPrint('   Email verified: ${redirectResult.user!.emailVerified}');
            } else if (redirectResult.credential != null) {
              debugPrint('⚠️ Redirect has credential but no user - signing in with credential...');
              try {
                final userCredential = await FirebaseAuth.instance.signInWithCredential(redirectResult.credential!);
                if (userCredential.user != null) {
                  debugPrint('✅ Signed in with credential successfully: ${userCredential.user!.email}');
                  debugPrint('   User ID: ${userCredential.user!.uid}');
                }
              } catch (credError) {
                debugPrint('❌ Error signing in with credential: $credError');
                debugPrint('   Error type: ${credError.runtimeType}');
                debugPrint('   Error details: ${credError.toString()}');
              }
            } else {
              debugPrint('ℹ️ No redirect result found');
              // בדיקה נוספת של currentUser - אולי Firebase Auth כבר עיבד את ה-redirect
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                debugPrint('✅ Found current user (Firebase Auth may have processed redirect): ${currentUser.email}');
                debugPrint('   User ID: ${currentUser.uid}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error checking redirect in main: $e');
            debugPrint('   Error type: ${e.runtimeType}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error in redirect check: $e');
      }
    }
    // על iOS, Firebase כבר מאותחל - רק נבדוק שהוא זמין
    try {
      if (Firebase.apps.isEmpty && defaultTargetPlatform == TargetPlatform.iOS) {
        // אם Firebase לא מאותחל (לא אמור לקרות), נאתחל אותו
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Firebase initialization check: $e');
    }
  }
  
  // Firestore offline persistence is enabled by default on mobile
  // No need to explicitly enable it - it's automatic
  debugPrint('✅ Firestore offline persistence is enabled by default');
  
  // Initialize Hive cache for offline support
  if (!kIsWeb) {
    try {
      await HiveCacheService.init();
      debugPrint('✅ Hive cache initialized');
    } catch (e) {
      debugPrint('⚠️ Could not initialize Hive cache: $e');
    }
  }
  
  // רישום background message handler (לא עובד ב-web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  
  // הערה: הגדרת כיוון מסך תתבצע ב-CommunityApp לפי סוג המכשיר (טאבלט או סמארטפון)
  // לא נגדיר כאן כדי שההגדרה תתבצע רק אחרי שיש context
  
  // הצגת מסך Splash מיד - האתחולים יקרו במסך ה-Splash
  runApp(
    const ProviderScope(
      child: CommunityApp(),
    ),
  );
}

// Enum מותאם אישית לערכות
enum AppTheme {
  system,
  light,
  dark,
  gold,
}

class CommunityApp extends StatefulWidget {
  const CommunityApp({super.key});

  @override
  State<CommunityApp> createState() => _CommunityAppState();
}

class _CommunityAppState extends State<CommunityApp> {
  final ValueNotifier<Locale> _localeNotifier = ValueNotifier(const Locale('he'));
  AppTheme _appTheme = AppTheme.light; // ברירת מחדל בהיר
  bool _localeLoaded = false; // דגל שמציין אם השפה נטענה

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // טעינת השפה והערכת הנושא לפני שב-build רץ
    await _loadLocale();
    await _loadThemeMode();
    // הגדרת כיוון מסך לפי סוג המכשיר (טאבלט או סמארטפון)
    await _setOrientationForDevice();
    // השפה נטענה, אפשר להמשיך
    if (mounted) {
      setState(() {
        _localeLoaded = true;
      });
    }
    // שאר האתחולים (לא חוסמים)
    // הערה: בקשות הרשאות התראות ומיקום מועברות למסך התחברות
    _setupDeepLinkHandling();
  }

  /// בדיקה אם המכשיר הוא טאבלט (לפי גודל המסך או device_info)
  Future<bool> _isTablet() async {
    if (kIsWeb) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iPad או iPad Pro
        return iosInfo.model.toLowerCase().contains('ipad');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        // בדיקה לפי גודל המסך - אם shortestSide >= 600dp זה טאבלט
        // או לפי device type
        final size = MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).size;
        final shortestSide = size.shortestSide;
        return shortestSide >= 600 || androidInfo.device.toString().toLowerCase().contains('tablet');
      }
    } catch (e) {
      debugPrint('⚠️ Error detecting tablet: $e');
      // fallback - בדיקה לפי גודל המסך
      try {
        final size = MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).size;
        final shortestSide = size.shortestSide;
        return shortestSide >= 600;
      } catch (e2) {
        debugPrint('⚠️ Error in fallback tablet detection: $e2');
      }
    }
    
    return false;
  }

  /// הגדרת כיוון מסך לפי סוג המכשיר
  Future<void> _setOrientationForDevice() async {
    if (kIsWeb) return;
    
    final isTablet = await _isTablet();
    
    if (isTablet) {
      // טאבלט - מאפשר כל הכיוונים
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      debugPrint('📱 Tablet detected - All orientations enabled');
    } else {
      // סמארטפון - אנכי בלבד
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      debugPrint('📱 Phone detected - Portrait only');
    }
  }
  
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('selected_language');
      
      // אם אין שפה שמורה, זו הפעם הראשונה - נשתמש בעברית כברירת מחדל
      // הדיאלוג בחירת שפה יוצג ב-Splash Screen
      final finalLanguageCode = languageCode ?? 'he';
      final locale = Locale(finalLanguageCode);
      debugPrint('🌐 Loading locale from SharedPreferences: $finalLanguageCode');
      debugPrint('🔍 All SharedPreferences keys: ${prefs.getKeys()}');
      debugPrint('🔍 Current selected_language value: $languageCode');
      if (mounted) {
        _localeNotifier.value = locale;
        debugPrint('✅ Locale loaded and set to: $finalLanguageCode');
      }
    } catch (e) {
      debugPrint('❌ Error loading locale: $e');
      // במקרה של שגיאה, נשתמש בברירת המחדל
      if (mounted) {
        final defaultLocale = const Locale('he');
        _localeNotifier.value = defaultLocale;
      }
    }
  }
  
  Future<void> _saveLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('selected_language', locale.languageCode);
      debugPrint('💾 Saved locale to SharedPreferences: ${locale.languageCode} (result: $saved)');
      // וידוא שהשמירה הצליחה - קריאה נוספת
      final savedLanguage = prefs.getString('selected_language');
      debugPrint('✅ Verified saved locale: $savedLanguage');
      if (savedLanguage != locale.languageCode) {
        debugPrint('⚠️ WARNING: Saved language ($savedLanguage) does not match requested (${locale.languageCode})');
      }
    } catch (e) {
      debugPrint('❌ Error saving locale: $e');
    }
  }
  
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme') ?? 1; // 0 = system, 1 = light, 2 = dark, 3 = gold (ברירת מחדל: light)
    setState(() {
      _appTheme = AppTheme.values[themeIndex.clamp(0, AppTheme.values.length - 1)];
    });
  }
  
  Future<void> _saveThemeMode(AppTheme appTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', appTheme.index);
    setState(() {
      _appTheme = appTheme;
    });
  }
  
  // פונקציה שמחזירה ThemeMode בהתאם ל-AppTheme (למקרה של system)
  ThemeMode _getThemeMode() {
    if (_appTheme == AppTheme.system) {
      return ThemeMode.system;
    } else if (_appTheme == AppTheme.light) {
      return ThemeMode.light;
    } else {
      // dark או gold - נשתמש ב-darkTheme
      return ThemeMode.dark;
    }
  }
  
  // פונקציה שמחזירה ThemeData לערכה GOLD
  ThemeData _getGoldTheme() {
    // עיצוב יוקרתי עם צבעי זהב/שחור
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFFFD700), // זהב
      onPrimary: Color(0xFF000000), // שחור על זהב
      primaryContainer: Color(0xFFFFA000), // זהב כהה (רקע לכפתורים)
      onPrimaryContainer: Color(0xFF000000), // טקסט על רקע זהב כהה
      secondary: Color(0xFFFFC107), // זהב בהיר
      onSecondary: Color(0xFF000000), // שחור על זהב
      secondaryContainer: Color(0xFFFFA000), // זהב כהה
      onSecondaryContainer: Color(0xFF000000), // טקסט על רקע זהב כהה
      tertiary: Color(0xFFFFC107), // זהב בהיר (לשימוש כללי)
      onTertiary: Color(0xFF000000), // שחור על זהב
      tertiaryContainer: Color(0xFF2A1A00), // רקע למידע חיובי (זהב כהה עם שקיפות)
      onTertiaryContainer: Color(0xFFFFC107), // טקסט על רקע מידע חיובי
      error: Color(0xFFE57373), // אדום רך
      onError: Colors.white,
      errorContainer: Color(0xFF3A1A1A), // רקע לשגיאות (אדום כהה עם שקיפות)
      onErrorContainer: Colors.white, // טקסט על רקע שגיאות
      surface: Color(0xFF000000), // שחור
      onSurface: Color(0xFFFFD700), // זהב על שחור
      onSurfaceVariant: Color(0xFFFFC107), // זהב בהיר
      surfaceContainer: Color(0xFF1A1A1A), // שחור בהיר
      surfaceContainerHigh: Color(0xFF2A2A2A), // אפור כהה
      surfaceContainerHighest: Color(0xFF3A3A3A), // אפור בינוני
      outline: Color(0xFFFFD700), // גבול זהב
      outlineVariant: Color(0xFFFFC107), // גבול זהב בהיר
      shadow: Color(0xFF000000), // צל
      scrim: Color(0xFF000000), // רקע מעל
    );
    
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // עיצוב משופר לכפתורים
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700), // זהב
          foregroundColor: const Color(0xFF000000), // שחור
          elevation: 4,
          shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // עיצוב לכפתורי טקסט
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFD700),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      // עיצוב לכפתורי אייקון
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFFFD700),
          backgroundColor: Colors.transparent,
        ),
      ),
      // עיצוב לכפתורי פעולה צפים
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFD700),
        foregroundColor: Color(0xFF000000),
        elevation: 6,
      ),
      // עיצוב משופר לשדות טקסט
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE57373)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      // עיצוב משופר לכרטיסים
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: const Color(0xFF1A1A1A),
      ),
      // עיצוב משופר ל-AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface, // שימוש בצבע מהערכה
        foregroundColor: colorScheme.onSurface, // שימוש בצבע מהערכה
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      // עיצוב משופר ל-BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: Color(0xFFFFD700), // זהב
        unselectedItemColor: Color(0xFF666666), // אפור
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
  
  
  void _setupDeepLinkHandling() {
    // טיפול ב-deep links
    _initUniLinks();
  }
  
  Future<void> _initUniLinks() async {
    try {
      final appLinks = AppLinks();
      
      // בדוק אם האפליקציה נפתחה עם deep link
      final Uri? initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
      
      // האזן ל-deep links חדשים
      appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Deep link initialization error: $e');
    }
  }
  
  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    
    if (uri.scheme == 'shchunati' && uri.host == 'auth') {
      // טיפול ב-callback מ-TikTok
      TikTokAuthService.handleCallback(uri.toString()).then((success) {
        if (success) {
          debugPrint('TikTok authentication successful!');
          // כאן תוכל להוסיף ניווט למסך הבית
        } else {
          debugPrint('TikTok authentication failed');
        }
      });
    } else if (uri.scheme == 'com.example.flutter1' && uri.host == 'email-verified') {
      // טיפול ב-email verification callback
      debugPrint('Email verification callback received');
      // האימייל כבר מאומת - המשתמש יכול להתחבר
    } else if (uri.path.contains('/payment/success') || 
               uri.host == 'payment' ||
               (uri.scheme == 'https' && uri.host.contains('nearme-970f3') && uri.path.contains('/payment/success')) ||
               (uri.scheme == 'shchunati' && uri.host == 'payment')) {
      // טיפול ב-payment success callback מ-PayMe
      debugPrint('✅ Payment success callback received from PayMe: $uri');
      _navigateToProfileAfterPayment();
    }
  }
  
  /// ניווט למסך פרופיל אחרי תשלום מוצלח
  void _navigateToProfileAfterPayment() {
    debugPrint('✅ Payment success - setting flag to open profile');
    
    // בדוק אם המשתמש מחובר
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // שמור סמן שצריך לפתוח פרופיל אחרי תשלום
      AppStateService.setShouldOpenProfileAfterPayment(true);
      
      // ניווט למסך הראשי (אם לא כבר שם)
    if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
        );
    }
    } else {
      debugPrint('⚠️ User not logged in, cannot navigate to profile');
    }
  }
  
  

  @override
  void dispose() {
    _localeNotifier.dispose();
    super.dispose();
  }

  void _changeLocale(Locale locale) async {
    debugPrint('🔄 Changing locale to: ${locale.languageCode}');
    // עדכון ה-state לפני השמירה כדי שהמשתמש יראה את השינוי מיד
    if (mounted) {
      debugPrint('🔄 Setting _localeNotifier.value to: ${locale.languageCode}');
      _localeNotifier.value = locale;
      debugPrint('✅ _localeNotifier.value updated to: ${locale.languageCode}');
    }
    // שמירה ב-SharedPreferences - ללא חסימה של UI
    _saveLocale(locale).then((_) {
      debugPrint('✅ Locale changed and saved successfully to: ${locale.languageCode}');
    }).catchError((e) {
      debugPrint('❌ Error saving locale: $e');
    });
  }
  
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    // טיפול ב-deep links
    if (settings.name != null && settings.name!.startsWith('shchunati://auth/tiktok')) {
      // טיפול ב-callback מ-TikTok
      TikTokAuthService.handleCallback(settings.name!).then((success) {
        if (success && mounted) {
          // אם ההתחברות הצליחה, עבור למסך הבית
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    }
    
    return null; // השתמש ב-routes הרגילים
  }

  @override
  Widget build(BuildContext context) {
    // אם השפה עדיין לא נטענה, הצג loading
    if (!_localeLoaded) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    // שימוש ב-ValueListenableBuilder כדי להגיב לשינויים בשפה
    return ValueListenableBuilder<Locale>(
      valueListenable: _localeNotifier,
      builder: (context, locale, child) {
    return Localizations(
          locale: locale,
      delegates: AppLocalizations.localizationsDelegates,
      child: Builder(
        builder: (context) {
              final l10n = AppLocalizations.of(context);
              // הגדרת כיוון מסך לפי סוג המכשיר (טאבלט או סמארטפון)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _setOrientationForDevice();
              });
          return MaterialApp(
                title: l10n.appTitle,
        debugShowCheckedModeBanner: false,
                locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateRoute: _generateRoute,
        themeMode: _getThemeMode(),
        builder: (context, child) {
          // הגבלת רוחב ל-80% ב-web בלבד עם רקע אייקונים
          if (kIsWeb) {
            return Stack(
              children: [
                // רקע עם אייקונים מפוזרים
                BackgroundIconsWidget(child: const SizedBox.shrink()),
                // התוכן המרכזי
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    constraints: const BoxConstraints(maxWidth: 1200), // מקסימום 1200px
                    child: child,
                  ),
                ),
              ],
            );
          }
          return child!;
        },
        theme: _appTheme == AppTheme.gold ? _getGoldTheme() : ThemeData(
          useMaterial3: true,
          fontFamily: 'Arial',
          brightness: Brightness.light,
          // עיצוב משופר עם צבעים מהלוגו
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF03A9F4), // כחול בהיר מהלוגו
            secondary: Color(0xFFE91E63), // ורוד מהלוגו
            tertiary: Color(0xFFFF9800), // כתום מהלוגו
            surface: Color(0xFFF8F9FA), // רקע לבן
            surfaceContainer: Color(0xFFF0F0F0), // רקע משני
            surfaceContainerHigh: Color(0xFFE8E8E8), // רקע גבוה
            surfaceContainerHighest: Color(0xFFE0E0E0), // רקע הגבוה ביותר
            error: Color(0xFFE57373), // אדום רך
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF424242), // אפור כהה מהלוגו
            onSurfaceVariant: Color(0xFF666666), // אפור בינוני
            onError: Colors.white,
            outline: Color(0xFFCCCCCC), // גבול
            outlineVariant: Color(0xFFE0E0E0), // גבול משני
            shadow: Color(0xFF000000), // צל
            scrim: Color(0xFF000000), // רקע מעל
          ),
          // עיצוב משופר לכפתורים
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF03A9F4), // כחול מהלוגו
              foregroundColor: Colors.white,
              elevation: 4,
                        shadowColor: const Color(0xFF03A9F4).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          // עיצוב לכפתורי טקסט
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF03A9F4),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          // עיצוב לכפתורי אייקון
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF03A9F4),
              backgroundColor: Colors.transparent,
            ),
          ),
          // עיצוב לכפתורי פעולה צפים
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF03A9F4),
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          // עיצוב משופר לשדות טקסט
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE57373)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          // עיצוב משופר לכרטיסים
          cardTheme: CardThemeData(
            elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
          ),
          // עיצוב משופר ל-AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF03A9F4), // כחול מהלוגו
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          // עיצוב משופר ל-BottomNavigationBar
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFF03A9F4), // כחול מהלוגו
            unselectedItemColor: Colors.grey,
            elevation: 8,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        darkTheme: _appTheme == AppTheme.gold ? _getGoldTheme() : ThemeData(
          useMaterial3: true,
          fontFamily: 'Arial',
          brightness: Brightness.dark,
          // עיצוב כהה עם צבעים מהלוגו
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF03A9F4), // כחול בהיר מהלוגו
            secondary: Color(0xFFE91E63), // ורוד מהלוגו
            tertiary: Color(0xFFFF9800), // כתום מהלוגו
            surface: Color(0xFF121212), // רקע כהה
            surfaceContainer: Color(0xFF1E1E1E), // רקע משני
            surfaceContainerHigh: Color(0xFF2A2A2A), // רקע גבוה
            surfaceContainerHighest: Color(0xFF363636), // רקע הגבוה ביותר
            error: Color(0xFFE57373), // אדום רך
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFFE0E0E0), // טקסט בהיר
            onSurfaceVariant: Color(0xFFB0B0B0), // אפור בהיר
            onError: Colors.white,
            outline: Color(0xFF404040), // גבול
            outlineVariant: Color(0xFF2A2A2A), // גבול משני
            shadow: Color(0xFF000000), // צל
            scrim: Color(0xFF000000), // רקע מעל
          ),
          // עיצוב משופר לכפתורים
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF03A9F4), // כחול מהלוגו
              foregroundColor: Colors.white,
              elevation: 4,
                        shadowColor: const Color(0xFF03A9F4).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          // עיצוב לכפתורי טקסט
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF03A9F4),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          // עיצוב לכפתורי אייקון
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF03A9F4),
              backgroundColor: Colors.transparent,
            ),
          ),
          // עיצוב לכפתורי פעולה צפים
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF03A9F4),
            foregroundColor: Colors.white,
            elevation: 6,
          ),
          // עיצוב משופר לשדות טקסט
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade800,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE57373)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          // עיצוב משופר לכרטיסים
          cardTheme: CardThemeData(
            elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.grey.shade800,
          ),
          // עיצוב משופר ל-AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF9C27B0), // סגול יפה למצב כהה
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          // עיצוב משופר ל-BottomNavigationBar
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1E1E1E),
            selectedItemColor: Color(0xFF03A9F4), // כחול מהלוגו
            unselectedItemColor: Colors.white, // לבן במצב כהה
            elevation: 8,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        home: SplashScreen(
          onLanguageSelected: (locale) {
            _changeLocale(locale);
          },
        ),
        routes: {
          '/main': (context) => AuthWrapper(
            onLocaleChange: _changeLocale, 
            localeNotifier: _localeNotifier,
            onThemeChange: _saveThemeMode,
            currentThemeMode: _appTheme,
          ),
          '/auth': (context) => YokiStyleAuthScreen(
            onLoginSuccess: () {
              Navigator.pushReplacementNamed(context, '/main');
            },
          ),
        },
      );
        },
      ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final void Function(Locale) onLocaleChange;
  final ValueNotifier<Locale> localeNotifier;
  final void Function(AppTheme) onThemeChange;
  final AppTheme currentThemeMode;
  const AuthWrapper({
    super.key, 
    required this.onLocaleChange, 
    required this.localeNotifier,
    required this.onThemeChange,
    required this.currentThemeMode,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<User?>? _redirectResultFuture;
  
  @override
  void initState() {
    super.initState();
    // טעינת redirect result פעם אחת ב-initState
    _redirectResultFuture = _getRedirectResult();
  }

  /// קבלת redirect result
  Future<User?> _getRedirectResult() async {
    if (kIsWeb) {
      try {
        debugPrint('🔍 Checking for Google Sign-In redirect result...');
        // הגדלת timeout ל-5 שניות כדי לאפשר זמן ל-redirect result להתעדכן
        final result = await FirebaseAuth.instance
            .getRedirectResult()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⏱️ getRedirectResult timeout - returning null');
                throw TimeoutException('getRedirectResult timeout');
              },
            );
        
        if (result.user != null) {
          debugPrint('✅ Google Sign-In redirect successful: ${result.user!.email}');
          debugPrint('   User ID: ${result.user!.uid}');
          // הודעה תוצג ב-build method דרך ScaffoldMessenger
          return result.user;
        } else {
          debugPrint('ℹ️ No Google Sign-In redirect result (user is null)');
          // בדיקה אם יש user מחובר כבר (למקרה שה-redirect result לא עובד אבל המשתמש כבר מחובר)
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            debugPrint('✅ Found current user already authenticated: ${currentUser.email}');
            return currentUser;
          }
          return null;
        }
      } on TimeoutException {
        debugPrint('⏱️ getRedirectResult timeout - checking current user');
        // גם אחרי timeout, נבדוק אם יש user מחובר
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint('✅ Found current user after timeout: ${currentUser.email}');
          return currentUser;
        }
        return null;
      } catch (e) {
        debugPrint('❌ Google Sign-In redirect error: $e');
        // התעלם משגיאות minified - זה לא קריטי
        if (e.toString().contains('minified')) {
          debugPrint('⚠️ Ignoring minified error - this is a known issue with getRedirectResult');
        }
        // גם אחרי שגיאה, נבדוק אם יש user מחובר
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint('✅ Found current user after error: ${currentUser.email}');
          return currentUser;
        }
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // בדיקה שה-widget עדיין פעיל
        if (!mounted || !context.mounted) {
          return const SizedBox.shrink();
        }
        return FutureBuilder<User?>(
          future: _redirectResultFuture,
          builder: (context, redirectSnapshot) {
            // בדיקה שה-widget עדיין פעיל
            if (!mounted || !context.mounted) {
              return const SizedBox.shrink();
            }
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // בדיקה שה-widget עדיין פעיל
                if (!mounted || !context.mounted) {
                  return const SizedBox.shrink();
                }
                
            // בדיקה נוספת שה-widget עדיין פעיל לפני כל פעולה
            if (!mounted || !context.mounted) {
                  return const SizedBox.shrink();
                }
                
            debugPrint('🔄 AuthWrapper - StreamBuilder update:');
            debugPrint('   - hasError: ${snapshot.hasError}');
            debugPrint('   - connectionState: ${snapshot.connectionState}');
            debugPrint('   - hasData: ${snapshot.hasData}');
            debugPrint('   - user: ${snapshot.data?.uid}');
            debugPrint('   - user email: ${snapshot.data?.email}');
            debugPrint('   - redirectUser: ${redirectSnapshot.data?.uid}');
            debugPrint('   - redirectUser email: ${redirectSnapshot.data?.email}');
            
            // אם יש redirect result, השתמש בו
            if (redirectSnapshot.hasData && redirectSnapshot.data != null) {
              debugPrint('✅ AuthWrapper - Redirect user found, showing MainApp');
              if (!mounted || !context.mounted) return const SizedBox.shrink();
              return MainApp(
                onLocaleChange: widget.onLocaleChange, 
                localeNotifier: widget.localeNotifier,
                onThemeChange: widget.onThemeChange,
                currentThemeMode: widget.currentThemeMode,
              );
            }
            
            if (snapshot.hasError) {
              debugPrint('❌ AuthWrapper - Error in stream, showing YokiStyleAuthScreen');
              if (!mounted || !context.mounted) return const SizedBox.shrink();
              return YokiStyleAuthScreen(
                onLoginSuccess: () {
                  // אחרי התחברות מוצלחת - המעבר יתבצע אוטומטית דרך StreamBuilder
                  debugPrint('✅ AuthWrapper - Login success callback called');
                },
              );
            }

            // אם יש user גם ב-waiting state, נציג את MainApp (למקרה שה-stream לא מתעדכן)
            if (snapshot.hasData && snapshot.data != null) {
              debugPrint('✅ AuthWrapper - User authenticated (even in waiting state), showing MainApp');
              if (!mounted || !context.mounted) return const SizedBox.shrink();
              return MainApp(
                onLocaleChange: widget.onLocaleChange, 
                localeNotifier: widget.localeNotifier,
                onThemeChange: widget.onThemeChange,
                currentThemeMode: widget.currentThemeMode,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint('⏳ AuthWrapper - Waiting for auth state');
              // אם יש redirect result ב-waiting state, נציג את MainApp
              if (redirectSnapshot.hasData && redirectSnapshot.data != null) {
                debugPrint('✅ AuthWrapper - Redirect user found in waiting state, showing MainApp');
                if (!mounted || !context.mounted) return const SizedBox.shrink();
                return MainApp(
                  onLocaleChange: widget.onLocaleChange, 
                  localeNotifier: widget.localeNotifier,
                  onThemeChange: widget.onThemeChange,
                  currentThemeMode: widget.currentThemeMode,
                );
              }
              // בדיקה אם יש user מחובר כבר (למקרה שה-redirect result לא עובד אבל המשתמש כבר מחובר)
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                debugPrint('✅ AuthWrapper - Found current user in waiting state: ${currentUser.email}');
                if (!mounted || !context.mounted) return const SizedBox.shrink();
                return MainApp(
                  onLocaleChange: widget.onLocaleChange, 
                  localeNotifier: widget.localeNotifier,
                  onThemeChange: widget.onThemeChange,
                  currentThemeMode: widget.currentThemeMode,
                );
              }
              debugPrint('⏳ AuthWrapper - Showing loading');
              if (!mounted || !context.mounted) return const SizedBox.shrink();
              // הצג loading - אם זה לוקח יותר מדי זמן, ה-StreamBuilder יתעדכן אוטומטית
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // אם אין user, נציג מסך התחברות
            debugPrint('🔐 AuthWrapper - No user, showing YokiStyleAuthScreen');
            if (!mounted || !context.mounted) return const SizedBox.shrink();
            return YokiStyleAuthScreen(
              onLoginSuccess: () {
                // אחרי התחברות מוצלחת - המעבר יתבצע אוטומטית דרך StreamBuilder
                debugPrint('✅ AuthWrapper - Login success callback called');
                // כפיית עדכון של ה-widget
                if (mounted) {
                  setState(() {});
                }
              },
            );
          },
        );
          },
        );
      },
    );
  }
}

class MainApp extends StatefulWidget {
  final void Function(Locale) onLocaleChange;
  final ValueNotifier<Locale> localeNotifier;
  final void Function(AppTheme) onThemeChange;
  final AppTheme currentThemeMode;
  const MainApp({
    super.key, 
    required this.onLocaleChange, 
    required this.localeNotifier,
    required this.onThemeChange,
    required this.currentThemeMode,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver, AudioMixin {
  int _selectedIndex = 0;
  int _pendingPaymentsCount = 0;
  Timer? _reminderTimer;
  Timer? _locationServiceCheckTimer;
  
  _MainAppState() {
    debugPrint('🚀 MainApp constructor called');
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 MainApp - initState called');
    WidgetsBinding.instance.addObserver(this);
    // אתחול שירות ההתראות
    _initializePushNotifications();
    // וידוא שהמנהל מוגדר כעסקי
    _ensureAdminProfileIfNeeded();
    // האזנה להתראות
    _listenToNotifications();
    // האזנה לבקשות תשלום ממתינות (רק למנהל)
    if (AdminAuthService.isCurrentUserAdmin()) {
      _listenToPendingPayments();
    }
    
    // בדיקה אם צריך לפתוח פרופיל אחרי תשלום
    _checkAndOpenProfileAfterPayment();
    
    // אתחול Timer לבדיקת תזכורות כל דקה
    _startReminderTimer();
    // הפעלת שירות עדכון מיקום ברקע (לא עובד ב-web)
    if (!kIsWeb) {
      BackgroundLocationService.start();
    }
    // ✅ בדיקת שירות המיקום כאשר האפליקציה נפתחת - מיידית
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ✅ בדיקה מיידית (ללא delay) אם context זמין
        if (context.mounted) {
          _checkLocationService(providedContext: context);
        } else {
          // אם context לא זמין, נמתין קצת ונבדוק שוב
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && context.mounted) {
              _checkLocationService(providedContext: context);
            }
          });
        }
      }
    });
    
    // ✅ בדיקה תקופתית של שירות המיקום כל 30 שניות כאשר האפליקציה פתוחה (להצגת דיאלוג אם נדרש)
    // הערה: הדיאלוג יוצג רק פעם אחת בכניסה לאפליקציה (forceShow: true), ולאחר מכן רק אם עברה שעה (forceShow: false)
    _locationServiceCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && context.mounted) {
        _checkLocationService(providedContext: context, forceShow: false);
      }
    });
  }

  /// אתחול שירות ההתראות
  Future<void> _initializePushNotifications() async {
    try {
      await PushNotificationService.initialize();
      debugPrint('✅ Push notification service initialized in MainApp');
    } catch (e) {
      debugPrint('❌ Error initializing push notification service: $e');
    }
  }

  /// בדיקה אם צריך לפתוח פרופיל אחרי תשלום מוצלח
  void _checkAndOpenProfileAfterPayment() {
    // המתן קצת כדי שהמסך ייטען
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && AppStateService.shouldOpenProfileAfterPayment()) {
        debugPrint('✅ Opening profile after payment success');
        
        // עדכן את ה-index למסך פרופיל (index 3)
        setState(() {
          _selectedIndex = 3;
        });
        
        // איפוס הסמן
        AppStateService.clearShouldOpenProfileAfterPayment();
        
        // הצג הודעה שהמנוי התעדכן
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 תשלום אושר! המנוי שלך הופעל בהצלחה'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    });
  }

  /// אתחול Timer לבדיקת תזכורות כל דקה
  void _startReminderTimer() {
    debugPrint('🚀 MainApp: Starting reminder timer (every 1 minute)');
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      debugPrint('🚀 MainApp: Timer triggered - checking reminders');
      _checkRequestReminders();
      // Guest trial expiry check moved to Cloud Functions
    });
    
    // בדיקה ראשונית
    _checkRequestReminders();
    // Guest trial expiry check moved to Cloud Functions
  }

  /// בדיקת בקשות עם עוזרים במשך יותר משבוע
  Future<void> _checkRequestReminders() async {
    try {
      debugPrint('🚀 MainApp: Starting request reminders check...');
      await RequestReminderService.checkAndSendReminderNotifications();
      debugPrint('🚀 MainApp: Request reminders check completed');
    } catch (e) {
      debugPrint('❌ Error checking request reminders: $e');
    }
  }

  /// ✅ בדיקת שירות המיקום והצגת דיאלוג אם מבוטל
  /// forceShow: true = הצג תמיד (בכניסה לאפליקציה), false = הצג רק אם לא הוצג לאחרונה
  Future<void> _checkLocationService({BuildContext? providedContext, bool forceShow = false}) async {
    try {
      // בדיקה ראשונית אם שירות המיקום פעיל (לפני המתנה ל-context)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        debugPrint('📍 Location service is enabled, no need to show dialog');
        return;
      }
      
      debugPrint('📍 Location service is disabled, attempting to show dialog (forceShow: $forceShow)');
      
      // ✅ המתנה מינימלית (100ms) כדי לוודא שה-context מוכן - מיידי ככל האפשר
      await Future.delayed(const Duration(milliseconds: 100));
      
      // ניסיון לקבל context - ננסה מספר פעמים
      BuildContext? context = providedContext;
      
      if (context == null || !context.mounted) {
        // ננסה לקבל context מה-State ישירות
        try {
          if (mounted) {
            context = this.context;
          }
        } catch (e) {
          debugPrint('❌ Error getting context from State: $e');
        }
      }
      
      if (context == null || !context.mounted) {
        // ננסה לקבל context מ-AppStateService - ננסה פחות פעמים עם delay קצר יותר
        for (int i = 0; i < 5; i++) {
          context = AppStateService.currentContext;
          if (context != null && context.mounted) {
            break;
          }
          if (i < 4) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      
      if (context == null || !context.mounted) {
        debugPrint('📍 No active context available for location service check after retries');
        // אם אין context, נציג התראה במקום דיאלוג
        await LocationService.checkAndShowLocationServiceNotification();
        return;
      }
      
      debugPrint('✅ Context available, showing location service dialog');
      
      // בדיקה והצגת דיאלוג אם שירות המיקום מבוטל
      // forceShow = true בכניסה לאפליקציה כדי להציג את הדיאלוג פעם אחת, false בבדיקות תקופתיות
      await LocationService.checkAndShowLocationServiceDialog(context, forceShow: forceShow);
    } catch (e) {
      debugPrint('❌ Error checking location service: $e');
      // אם יש שגיאה, נציג התראה במקום דיאלוג
      try {
        await LocationService.checkAndShowLocationServiceNotification();
      } catch (e2) {
        debugPrint('❌ Error showing location service notification: $e2');
      }
    }
  }

  // Guest trial expiry check moved to Cloud Functions

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    _locationServiceCheckTimer?.cancel();
    // עצירת שירות עדכון מיקום ברקע
    BackgroundLocationService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // כשהאפליקציה עוברת לרקע או נסגרת - ניקוי מצב
        AppStateService.clearUserState();
        // ✅ בדיקת שירות המיקום כאשר האפליקציה עוברת לרקע
        BackgroundLocationService.checkLocationServiceWhenBackground();
        break;
      case AppLifecycleState.resumed:
        // כשהאפליקציה חוזרת לקדמה - בדוק אם שירות המיקום פעיל - מיידית
        // ✅ בדיקה מיידית (ללא delay) אם context זמין - forceShow: true כדי להציג פעם אחת
        if (mounted && context.mounted) {
          _checkLocationService(providedContext: context, forceShow: true);
        } else {
          // אם context לא זמין, נמתין קצת ונבדוק שוב
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && context.mounted) {
              _checkLocationService(providedContext: context, forceShow: true);
            }
          });
        }
        break;
      default:
        break;
    }
  }

  Future<void> _ensureAdminProfileIfNeeded() async {
    if (AdminAuthService.isCurrentUserAdmin()) {
      await AdminAuthService.ensureAdminProfile();
    }
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        _showNotification(data, doc.id);
      }
    });
  }

  Future<void> _showNotification(Map<String, dynamic> data, String notificationId) async {
    try {
      // הצגת התראה מקומית
      await NotificationService.showLocalNotification(
        title: data['title'] ?? 'התראה',
        body: data['message'] ?? '',
      );

      // סימון ההתראה כנקראה
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      debugPrint('Notification shown and marked as read');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }


  void _listenToPendingPayments() {
    FirebaseFirestore.instance
        .collection('payment_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingPaymentsCount = snapshot.docs.length;
        });
      }
    });
  }

  void _clearPendingPaymentsCount() {
    if (mounted) {
      setState(() {
        _pendingPaymentsCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ MainApp - build method called');
    // שמירת context לניווט התראות - רק אם ה-widget עדיין פעיל
    if (mounted) {
    AppStateService.setCurrentContext(context);
    }
    
    return ValueListenableBuilder<Locale>(
      valueListenable: widget.localeNotifier,
      builder: (context, locale, child) {
        final l10n = AppLocalizations(locale);
        
        return Directionality(
          textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.appTitle),
              actions: [
                // אייקון מדריך
                IconButton(
                  icon: const Icon(Icons.school),
                  tooltip: l10n.userGuide,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TutorialCenterScreen(),
                      ),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    if (!mounted) return const SizedBox.shrink();
                    // שמירת l10n ב-closure כדי למנוע בעיות עם deactivated widget
                    final currentL10n = l10n;
                    return PopupMenuButton<Locale>(
                      key: ValueKey('locale_menu_${locale.languageCode}'), // Force rebuild on locale change
                      icon: const Icon(Icons.language),
                      tooltip: currentL10n.selectLanguage,
                      onSelected: (locale) {
                        if (mounted) {
                          widget.onLocaleChange(locale);
                        }
                      },
                      itemBuilder: (context) {
                        // Guard: בדיקה אם ה-context עדיין valid
                        if (!mounted) return [];
                        // יצירת l10n חדש-context כדי לוודא שהוא עדכני
                        final builderL10n = AppLocalizations.of(context);
                        return [
                        PopupMenuItem(
                          value: const Locale('he'),
                            child: Text(builderL10n.hebrew),
                        ),
                        PopupMenuItem(
                          value: const Locale('ar'),
                            child: Text(builderL10n.arabic),
                        ),
                        PopupMenuItem(
                          value: const Locale('en'),
                            child: Text(builderL10n.english),
                        ),
                        ];
                      },
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    if (!mounted) return const SizedBox.shrink();
                    // שמירת l10n ב-closure כדי למנוע בעיות עם deactivated widget
                    final currentL10n = l10n;
                    final currentThemeMode = widget.currentThemeMode;
                    return PopupMenuButton<AppTheme>(
                      key: ValueKey('theme_menu_${locale.languageCode}'), // Force rebuild on locale change
                      icon: const Icon(Icons.palette),
                      tooltip: currentL10n.theme,
                      onSelected: (appTheme) {
                        if (mounted) {
                          widget.onThemeChange(appTheme);
                        }
                      },
                      itemBuilder: (context) {
                        // Guard: בדיקה אם ה-context עדיין valid
                        if (!mounted) return [];
                        // יצירת l10n חדש-context כדי לוודא שהוא עדכני
                        final builderL10n = AppLocalizations.of(context);
                        return [
                        PopupMenuItem(
                          value: AppTheme.system,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_auto,
                                  color: currentThemeMode == AppTheme.system 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                                Text(builderL10n.systemTheme),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: AppTheme.light,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_high,
                                  color: currentThemeMode == AppTheme.light 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                                Text(builderL10n.lightTheme),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: AppTheme.dark,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_2,
                                  color: currentThemeMode == AppTheme.dark 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                                Text(builderL10n.darkTheme),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: AppTheme.gold,
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                  color: currentThemeMode == AppTheme.gold 
                                    ? const Color(0xFFFFD700) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                                Text(builderL10n.goldTheme),
                            ],
                          ),
                        ),
                        ];
                      },
                    );
                  },
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  tooltip: l10n.logout,
                ),
              ],
            ),
            body: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseAuth.instance.currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                return IndexedStack(
              index: _selectedIndex,
              children: [
                const HomeScreen(),
                const MyRequestsScreen(),
                const MyOrdersScreen(),
                const NotificationsScreen(),
                const ProfileScreen(),
                if (AdminAuthService.isCurrentUserAdmin()) const AdminPaymentsScreen(),
              ],
                );
              },
            ),
            bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseAuth.instance.currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                return BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() => _selectedIndex = index);
                // איפוס ספירת תשלומים ממתינים כאשר המנהל נכנס למסך ניהול תשלומים
                    final adminIndex = AdminAuthService.isCurrentUserAdmin() ? 5 : 4;
                    if (AdminAuthService.isCurrentUserAdmin() && index == adminIndex) {
                  _clearPendingPaymentsCount();
                }
              },
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.assignment),
                  label: l10n.myRequestsMenu,
                    ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.shopping_cart),
                  label: 'הזמנות שלי',
                    ),
                BottomNavigationBarItem(
                  icon: StreamBuilder<int>(
                    stream: FirebaseAuth.instance.currentUser != null 
                        ? NotificationService.getUnreadCount(FirebaseAuth.instance.currentUser!.uid)
                        : Stream.value(0),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          const Icon(Icons.notifications),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  label: l10n.notifications,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person),
                  label: l10n.profile,
                ),
                if (AdminAuthService.isCurrentUserAdmin())
                  BottomNavigationBarItem(
                    icon: Stack(
                      children: [
                        const Icon(Icons.admin_panel_settings),
                        if (_pendingPaymentsCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$_pendingPaymentsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: l10n.managePayments,
                  ),
              ],
                );
              },
            ),
            floatingActionButton: _selectedIndex == 0 // הצג רק במסך הבית (אינדקס 0)
                ? StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // כפתור "בקשה חדשה"
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                      color: const Color(0xFFFFD700), // צהוב זהב
                      border: Border.all(
                                color: const Color(0xFF2196F3),
                                width: 3,
                      ),
                    ),
                    child: FloatingActionButton(
                              heroTag: "new_request",
                      onPressed: () {
                        debugPrint('🔍 FloatingActionButton pressed!');
                        _showNewRequestDialog();
                      },
                              backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                              elevation: 0,
                      child: const Icon(
                                Icons.add_rounded,
                        size: 28,
                      ),
                    ),
                          ),
                        ],
                  );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  void _logout() async {
    // הוספת צליל לכפתור התנתקות
    await AudioService().playSound(AudioEvent.buttonClick);
    
    // Guard context usage after async gap
    if (!mounted) return;
    
    // הצגת דיאלוג אישור התנתקות
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.logoutTitle),
          content: Text(dialogL10n.logoutMessage),
          actions: [
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                if (context.mounted) {
                Navigator.of(context).pop(false);
                }
              },
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                if (context.mounted) {
                Navigator.of(context).pop(true);
                }
              },
              child: Text(
                dialogL10n.logoutButton,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    // אם המשתמש אישר את ההתנתקות
    if (shouldLogout == true) {
      try {
        // שימוש ב-AutoLoginService להתנתקות מלאה
        await AutoLoginService.logout();
        
        // Guard context usage after async gap
        if (!mounted) return;
        
        // חזרה למסך התחברות
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      } catch (e) {
        // Guard context usage after async gap
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoggingOut(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNewRequestDialog() async {
    // הוספת צליל לכפתור +
    await AudioService().playSound(AudioEvent.buttonClick);
    
    debugPrint('🔍 _showNewRequestDialog: Starting monthly request limit check');
    
    // בדיקה אם המשתמש הוא אורח זמני
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final isTemporaryGuest = userData['isTemporaryGuest'] ?? false;
          
          if (isTemporaryGuest) {
            debugPrint('🔍 _showNewRequestDialog: Temporary guest detected, blocking request creation');
            if (!mounted) return;
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.pleaseRegisterFirst),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('🔍 _showNewRequestDialog: Error checking temporary guest status: $e');
      }
    }
    
    // בדיקת מגבלת בקשות חודשיות
    final canCreateRequest = await _checkMonthlyRequestLimit();
    debugPrint('🔍 _showNewRequestDialog: canCreateRequest = $canCreateRequest');
    
    // Guard context usage after async gap
    if (!mounted) return;
    
    if (!canCreateRequest) {
      debugPrint('🔍 _showNewRequestDialog: Cannot create request, showing limit dialog');
      return; // הדיאלוג כבר הוצג
    }
    
    debugPrint('🔍 _showNewRequestDialog: Can create request, navigating to NewRequestScreen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewRequestScreen(),
      ),
    );
  }

  /// בדיקת מגבלת בקשות חודשיות
  Future<bool> _checkMonthlyRequestLimit() async {
    try {
      debugPrint('🔍 _checkMonthlyRequestLimit: Starting check');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('🔍 _checkMonthlyRequestLimit: No user found');
        return false;
      }

      debugPrint('🔍 _checkMonthlyRequestLimit: User ID: ${user.uid}');

      // בדיקה אם המשתמש הוא מנהל
      final userEmail = user.email;
      if (userEmail == 'haitham.ay82@gmail.com' || userEmail == 'admin@gmail.com') {
        debugPrint('🔍 _checkMonthlyRequestLimit: Admin user detected, bypassing limits');
        return true;
      }

      // קבלת פרופיל המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('🔍 _checkMonthlyRequestLimit: User document does not exist');
        return false;
      }

      final userData = userDoc.data()!;
      final maxRequestsPerMonth = userData['maxRequestsPerMonth'] ?? 1;
      
      debugPrint('🔍 _checkMonthlyRequestLimit: maxRequestsPerMonth = $maxRequestsPerMonth');
      
      // שימוש באותה לוגיקה כמו הפרופיל
      final currentMonthRequests = await MonthlyRequestsTracker.getCurrentMonthRequestsCount();
      
      debugPrint('🔍 _checkMonthlyRequestLimit: currentMonthRequests = $currentMonthRequests');
      debugPrint('🔍 _checkMonthlyRequestLimit: Checking if $currentMonthRequests >= $maxRequestsPerMonth');

      if (currentMonthRequests >= maxRequestsPerMonth) {
        debugPrint('🔍 _checkMonthlyRequestLimit: LIMIT REACHED! Showing dialog');
        // חישוב תאריך החודש הבא
        final now = DateTime.now();
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final nextMonthFormatted = '${nextMonth.day}/${nextMonth.month}/${nextMonth.year}';
        
        debugPrint('🔍 _checkMonthlyRequestLimit: nextMonthFormatted = $nextMonthFormatted');
        
        // הצגת דיאלוג מגבלה
        await _showMonthlyLimitDialog(nextMonthFormatted, maxRequestsPerMonth);
        return false;
      }

      debugPrint('🔍 _checkMonthlyRequestLimit: Limit not reached, allowing request creation');
      return true;
    } catch (e) {
      debugPrint('🔍 _checkMonthlyRequestLimit: Error: $e');
      return true; // במקרה של שגיאה, אפשר ליצור בקשה
    }
  }

  /// הצגת דיאלוג מגבלת בקשות חודשיות
  Future<void> _showMonthlyLimitDialog(String nextMonthDate, int maxRequests) async {
    if (!mounted) return;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dialogL10n.monthlyLimitReached,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogL10n.monthlyLimitMessage(maxRequests),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  dialogL10n.youCan,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dialogL10n.waitForNextMonth(nextMonthDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.upgrade, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dialogL10n.upgradeSubscription,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                if (context.mounted) {
                Navigator.of(context).pop();
                }
              },
              child: Text(dialogL10n.understood),
            ),
            ElevatedButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                if (context.mounted) {
                Navigator.of(context).pop();
                }
                // ניווט ישירות למסך פרופיל
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: Text(dialogL10n.upgradeSubscriptionInProfile),
            ),
          ],
        );
      },
    );
  }
}
