import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/yoki_style_auth_screen.dart';
import 'screens/tutorial_center_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/my_requests_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'services/admin_auth_service.dart';
import 'l10n/app_localizations.dart';
import 'services/permission_service.dart';
import 'services/notification_service.dart';
import 'services/app_state_service.dart';
import 'services/audio_service.dart';
import 'services/auto_login_service.dart';
import 'services/tiktok_auth_service.dart';
import 'services/monthly_requests_tracker.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // הגדרת כיוון אנכי בלבד לכל המסכים
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // הצגת מסך Splash מיד - האתחולים יקרו במסך ה-Splash
  runApp(const CommunityApp());
}

class CommunityApp extends StatefulWidget {
  const CommunityApp({super.key});

  @override
  State<CommunityApp> createState() => _CommunityAppState();
}

class _CommunityAppState extends State<CommunityApp> {
  Locale _selectedLocale = const Locale('he'); // ברירת מחדל עברית
  final ValueNotifier<Locale> _localeNotifier = ValueNotifier(const Locale('he'));
  ThemeMode _themeMode = ThemeMode.dark; // ברירת מחדל כהה

  @override
  void initState() {
    super.initState();
    _localeNotifier.value = _selectedLocale;
    _loadThemeMode();
    _requestNotificationPermission();
    _setupDeepLinkHandling();
  }
  
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('theme_mode') ?? 2; // 0 = system, 1 = light, 2 = dark (ברירת מחדל)
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }
  
  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', themeMode.index);
    setState(() {
      _themeMode = themeMode;
    });
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
    }
  }
  
  
  Future<void> _requestNotificationPermission() async {
    // המתן קצת לפני בקשת ההרשאה
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      await PermissionService.requestNotificationPermission(context);
    }
  }

  @override
  void dispose() {
    _localeNotifier.dispose();
    super.dispose();
  }

  void _changeLocale(Locale locale) {
    _localeNotifier.value = locale;
    setState(() {
      _selectedLocale = locale;
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
    return Localizations(
      locale: _selectedLocale,
      delegates: AppLocalizations.localizationsDelegates,
      child: Builder(
        builder: (context) {
          if (!mounted) return const SizedBox.shrink();
          return MaterialApp(
        title: 'שכונתי',
        debugShowCheckedModeBanner: false,
        locale: _selectedLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        onGenerateRoute: _generateRoute,
        themeMode: _themeMode,
        theme: ThemeData(
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
              shadowColor: const Color(0xFF03A9F4).withOpacity(0.3),
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
            shadowColor: Colors.black.withOpacity(0.1),
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
        darkTheme: ThemeData(
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
              shadowColor: const Color(0xFF03A9F4).withOpacity(0.3),
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
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.grey.shade800,
          ),
          // עיצוב משופר ל-AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFF9800), // כתום ענתיק למצב כהה
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
        home: const SplashScreen(),
        routes: {
          '/main': (context) => AuthWrapper(
            onLocaleChange: _changeLocale, 
            localeNotifier: _localeNotifier,
            onThemeChange: _saveThemeMode,
            currentThemeMode: _themeMode,
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
  }
}

class AuthWrapper extends StatefulWidget {
  final void Function(Locale) onLocaleChange;
  final ValueNotifier<Locale> localeNotifier;
  final void Function(ThemeMode) onThemeChange;
  final ThemeMode currentThemeMode;
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
  @override
  void initState() {
    super.initState();
    _handleGoogleSignInRedirect();
  }

  /// טיפול ב-Google Sign-In redirect
  Future<void> _handleGoogleSignInRedirect() async {
    if (kIsWeb) {
      try {
        // בדיקה אם יש redirect result מ-Google Sign-In
        final result = await FirebaseAuth.instance.getRedirectResult();
        if (result.user != null) {
          debugPrint('✅ Google Sign-In redirect successful: ${result.user!.email}');
          // הצג הודעה על התחברות מוצלחת
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('התחברות מוצלחת דרך גוגל!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          debugPrint('ℹ️ No Google Sign-In redirect result');
        }
      } catch (e) {
        debugPrint('❌ Google Sign-In redirect error: $e');
        // התעלם משגיאות minified - זה לא קריטי
        if (e.toString().contains('minified')) {
          debugPrint('⚠️ Ignoring minified error - this is a known issue with getRedirectResult');
        }
      }
    }
  }

  /// קבלת redirect result
  Future<User?> _getRedirectResult() async {
    if (kIsWeb) {
      try {
        final result = await FirebaseAuth.instance.getRedirectResult();
        if (result.user != null) {
          debugPrint('✅ Google Sign-In redirect successful: ${result.user!.email}');
          // הצג הודעה על התחברות מוצלחת
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('התחברות מוצלחת דרך גוגל!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return result.user;
        } else {
          debugPrint('ℹ️ No Google Sign-In redirect result');
          return null;
        }
      } catch (e) {
        debugPrint('❌ Google Sign-In redirect error: $e');
        // התעלם משגיאות minified - זה לא קריטי
        if (e.toString().contains('minified')) {
          debugPrint('⚠️ Ignoring minified error - this is a known issue with getRedirectResult');
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
        return FutureBuilder<User?>(
          future: _getRedirectResult(),
          builder: (context, redirectSnapshot) {
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // בדיקה שה-widget עדיין פעיל
                if (!mounted) {
                  return const SizedBox.shrink();
                }
                
            debugPrint('🔄 AuthWrapper - StreamBuilder update:');
            debugPrint('   - hasError: ${snapshot.hasError}');
            debugPrint('   - connectionState: ${snapshot.connectionState}');
            debugPrint('   - hasData: ${snapshot.hasData}');
            debugPrint('   - user: ${snapshot.data?.uid}');
            debugPrint('   - redirectUser: ${redirectSnapshot.data?.uid}');
            
            // אם יש redirect result, השתמש בו
            if (redirectSnapshot.hasData && redirectSnapshot.data != null) {
              debugPrint('✅ AuthWrapper - Redirect user found, showing MainApp');
              return MainApp(
                onLocaleChange: widget.onLocaleChange, 
                localeNotifier: widget.localeNotifier,
                onThemeChange: widget.onThemeChange,
                currentThemeMode: widget.currentThemeMode,
              );
            }
            
            if (snapshot.hasError) {
              debugPrint('❌ AuthWrapper - Error in stream, showing YokiStyleAuthScreen');
              return YokiStyleAuthScreen(
                onLoginSuccess: () {
                  // אחרי התחברות מוצלחת - המעבר יתבצע אוטומטית דרך StreamBuilder
                  debugPrint('✅ AuthWrapper - Login success callback called');
                },
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              debugPrint('⏳ AuthWrapper - Waiting for auth state, showing loading');
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              debugPrint('✅ AuthWrapper - User authenticated, showing MainApp');
              return MainApp(
                onLocaleChange: widget.onLocaleChange, 
                localeNotifier: widget.localeNotifier,
                onThemeChange: widget.onThemeChange,
                currentThemeMode: widget.currentThemeMode,
              );
            } else {
              debugPrint('🔐 AuthWrapper - No user, showing YokiStyleAuthScreen');
              return YokiStyleAuthScreen(
                onLoginSuccess: () {
                  // אחרי התחברות מוצלחת - המעבר יתבצע אוטומטית דרך StreamBuilder
                  debugPrint('✅ AuthWrapper - Login success callback called');
                },
              );
            }
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
  final void Function(ThemeMode) onThemeChange;
  final ThemeMode currentThemeMode;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // וידוא שהמנהל מוגדר כעסקי
    _ensureAdminProfileIfNeeded();
    // האזנה להתראות
    _listenToNotifications();
    // האזנה לבקשות תשלום ממתינות (רק למנהל)
    if (AdminAuthService.isCurrentUserAdmin()) {
      _listenToPendingPayments();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        break;
      case AppLifecycleState.resumed:
        // כשהאפליקציה חוזרת לקדמה - אין צורך לעשות כלום
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

      print('Notification shown and marked as read');
    } catch (e) {
      print('Error showing notification: $e');
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
    // שמירת context לניווט התראות
    AppStateService.setCurrentContext(context);
    
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
                  tooltip: 'מדריך משתמש',
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
                    return PopupMenuButton<Locale>(
                      icon: const Icon(Icons.language),
                      tooltip: l10n.selectLanguage,
                      onSelected: (locale) {
                        if (mounted) {
                          widget.onLocaleChange(locale);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: const Locale('he'),
                          child: Text(l10n.hebrew),
                        ),
                        PopupMenuItem(
                          value: const Locale('ar'),
                          child: Text(l10n.arabic),
                        ),
                        PopupMenuItem(
                          value: const Locale('en'),
                          child: Text(l10n.english),
                        ),
                      ],
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    if (!mounted) return const SizedBox.shrink();
                    return PopupMenuButton<ThemeMode>(
                      icon: const Icon(Icons.palette),
                      tooltip: l10n.theme,
                      onSelected: (themeMode) {
                        if (mounted) {
                          widget.onThemeChange(themeMode);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: ThemeMode.system,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_auto,
                                color: widget.currentThemeMode == ThemeMode.system 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.systemTheme),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: ThemeMode.light,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_high,
                                color: widget.currentThemeMode == ThemeMode.light 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.lightTheme),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: ThemeMode.dark,
                          child: Row(
                            children: [
                              Icon(
                                Icons.brightness_2,
                                color: widget.currentThemeMode == ThemeMode.dark 
                                    ? const Color(0xFF03A9F4) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.darkTheme),
                            ],
                          ),
                        ),
                      ],
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
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                const HomeScreen(),
                const MyRequestsScreen(),
                const NotificationsScreen(),
                const ProfileScreen(),
                if (AdminAuthService.isCurrentUserAdmin()) const AdminPaymentsScreen(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() => _selectedIndex = index);
                // איפוס ספירת תשלומים ממתינים כאשר המנהל נכנס למסך ניהול תשלומים
                if (AdminAuthService.isCurrentUserAdmin() && index == 4) {
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
                  label: l10n.myRequests,
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
                    label: 'ניהול תשלומים',
                  ),
              ],
            ),
            floatingActionButton: _selectedIndex == 0 // הצג רק במסך הבית (אינדקס 0)
                ? (() {
                    debugPrint('🔍 Building FloatingActionButton for home screen');
                    return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30), // עגול מושלם
                      color: const Color(0xFFFFD700), // צהוב זהב
                      border: Border.all(
                        color: const Color(0xFF2196F3), // מסגרת כחולה
                        width: 3, // עובי המסגרת
                      ),
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        debugPrint('🔍 FloatingActionButton pressed!');
                        _showNewRequestDialog();
                      },
                      backgroundColor: Colors.transparent, // שקוף כדי שהצבע ייראה
                      foregroundColor: Colors.white,
                      elevation: 0, // ללא צל
                      child: const Icon(
                        Icons.add_rounded, // אייקון עגול יותר
                        size: 28,
                      ),
                    ),
                  );
                })()
                : null,
          ),
        );
      },
    );
  }

  void _logout() async {
    // הוספת צליל לכפתור התנתקות
    await AudioService().playSound(AudioEvent.buttonClick);
    
    // הצגת דיאלוג אישור התנתקות
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('התנתקות'),
          content: const Text('האם אתה בטוח שברצונך להתנתק?'),
          actions: [
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                Navigator.of(context).pop(false);
              },
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'התנתקות',
                style: TextStyle(color: Colors.red),
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
        
        // חזרה למסך התחברות
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתנתקות: $e'),
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
    
    // בדיקת מגבלת בקשות חודשיות
    final canCreateRequest = await _checkMonthlyRequestLimit();
    debugPrint('🔍 _showNewRequestDialog: canCreateRequest = $canCreateRequest');
    
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
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700], size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'הגעת למגבלת הבקשות החודשיות',
                  style: TextStyle(fontSize: 16),
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
                  'הגעת למגבלת הבקשות החודשיות שלך ($maxRequests בקשות).',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  'באפשרותך:',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'לחכות לחודש הבא שמתחיל ב-$nextMonthDate',
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
                        'לשדרג מנוי לקבלת יותר בקשות חודשיות',
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
                Navigator.of(context).pop();
              },
              child: const Text('הבנתי'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                Navigator.of(context).pop();
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
              child: const Text('שדרג מנוי בפרופיל'),
            ),
          ],
        );
      },
    );
  }
}
