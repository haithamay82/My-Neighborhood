import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../firebase_messaging_background.dart';
import '../services/notification_service_local.dart';
import '../services/push_notification_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/network_service.dart';
import '../services/google_auth_service.dart';
import '../l10n/app_localizations.dart';

class YokiSplashScreen extends StatefulWidget {
  final Function(Locale)? onLanguageSelected;
  
  const YokiSplashScreen({super.key, this.onLanguageSelected});

  @override
  State<YokiSplashScreen> createState() => _YokiSplashScreenState();
}

class _YokiSplashScreenState extends State<YokiSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late AnimationController _spinFadeController;
  late AnimationController _starsController;
  late Animation<double> _logoAnimation;
  late Animation<double> _spinAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isInitializing = true;
  String _initializationStatus = '';
  bool _languageSelected = false; // Flag לעקיבה אחרי בחירת שפה

  @override
  void initState() {
    super.initState();
    
    // אנימציה ללוגו (מופיע)
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // אנימציה לרקע (כוכבים מנצנצים) - 2 שניות בדיוק
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // אנימציה לכוכבים נופלים עם rainbow gradient
    _starsController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );
    _starsController.repeat();

    // אנימציה לסיבוב + fade out (1 שנייה)
    _spinFadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _spinAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0, // 10 סיבובים מלאים - סיבוב מהיר מאוד
    ).animate(CurvedAnimation(
      parent: _spinFadeController,
      curve: Curves.linear,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _spinFadeController,
      curve: Curves.easeOut,
    ));

    // התחלת אנימציות
    _logoController.forward();
    _backgroundController.repeat(); // התחל כוכבים מנצנצים
    
    // לאחר 2 שניות בדיוק - עצור כוכבים והתחל סיבוב + fade out
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _backgroundController.stop(); // עצור את האנימציה
        _spinFadeController.forward().then((_) {
          // לאחר סיום האנימציה - הצג דיאלוג בחירת שפה (אם נדרש)
          if (mounted) {
            _checkFirstLaunchAndNavigate();
          }
        });
      }
    });

    // טיפול ב-redirect אם נדרש
    GoogleAuthService.handleRedirectIfNeeded();

    // אתחול כל השירותים
    _initializeServices();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    _spinFadeController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    debugPrint('🔍 _initializeServices started');
    try {
      // אתחול Firebase
      debugPrint('🔍 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
      
      // הגדרת Firebase Messaging Background Handler (לא עובד ב-web)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        debugPrint('Firebase Messaging background handler set');
      }
      
      // Initialize local notifications (לא עובד ב-web)
      if (!kIsWeb) {
        try {
          await NotificationServiceLocal.initialize();
          debugPrint('Local notifications initialized successfully');
        } catch (e) {
          debugPrint('⚠️ Local notifications initialization failed: $e');
        }
      }
      
      // Initialize push notifications (עובד ב-web)
      try {
        await PushNotificationService.initialize();
        debugPrint('Push notifications initialized successfully');
      } catch (e) {
        debugPrint('⚠️ Push notifications initialization failed: $e');
      }

      // Initialize subscription notification service (לא עובד ב-web)
      if (!kIsWeb) {
        try {
          await NotificationService.initialize();
          // הערה: בקשות הרשאות מועברות למסך התחברות בלבד
          debugPrint('Subscription notification service initialized successfully');
        } catch (e) {
          debugPrint('⚠️ Subscription notification service initialization failed: $e');
        }
      }
      
      // Initialize audio service (עובד ב-web)
      try {
        await AudioService().initialize();
        debugPrint('Audio service initialized successfully');
      } catch (e) {
        debugPrint('⚠️ Audio service initialization failed: $e');
      }
      
      // Initialize network service
      try {
        NetworkService.initialize();
        debugPrint('Network service initialized successfully');
      } catch (e) {
        debugPrint('⚠️ Network service initialization failed: $e');
      }
      
      // סיום האתחול
      debugPrint('🔍 Setting initialization status to ready');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _initializationStatus = l10n.ready;
          _isInitializing = false;
        });
      }
      
      // המתן קצת לפני המעבר למסך הבא
      debugPrint('🔍 Waiting 500ms before navigating...');
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔍 Wait completed');
      
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _initializationStatus = l10n.errorInitialization(e.toString());
          _isInitializing = false;
        });
      }
      
      // גם במקרה של שגיאה, המשך למסך הבא
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // הערה: _checkFirstLaunchAndNavigate() ייקרא רק אחרי שהאנימציה של הסיבוב מסתיימת
    // זה מבטיח שהדיאלוג "בחר שפה" יופיע רק אחרי שהאנימציה מסתיימת
    debugPrint('🔍 _initializeServices completed');
  }

  Future<void> _checkFirstLaunchAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // אם אין שפה שמורה, זו הפעם הראשונה - הצג דיאלוג בחירת שפה
      // הדיאלוג יחסם את המעבר למסך הבא עד שהמשתמש בוחר שפה
      final currentLanguage = prefs.getString('selected_language');
      if (currentLanguage == null) {
        // המתן קצת כדי שהמסך יטען
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          return;
        }
        // זו הפעם הראשונה - הצג דיאלוג בחירת שפה
        // הדיאלוג יחסם את המעבר למסך הבא עד שהמשתמש בוחר שפה
        await _showLanguageSelectionDialog();
      }
      
      // אם יש שפה שמורה, סמן שהשפה כבר נבחרה
      if (currentLanguage != null) {
        _languageSelected = true;
        // בדוק אם האנימציה כבר הסתיימה - אם כן, עבור למסך הבא
        _checkAndNavigateAfterLanguageSelection();
      }
      // אם אין שפה שמורה, הדיאלוג יוצג ויסמן _languageSelected = true אחרי בחירה
    } catch (e) {
      debugPrint('❌ Error checking first launch: $e');
      // במקרה של שגיאה, נסמן שפה כברירת מחדל ונעבור למסך הבא
      if (mounted) {
        _languageSelected = true;
        _navigateToNextScreen();
      }
    }
  }

  Future<void> _showLanguageSelectionDialog() async {
    debugPrint('🌐 _showLanguageSelectionDialog called');
    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, cannot show dialog');
      return;
    }
    
    Locale? selectedLocale;
    
    debugPrint('🌐 Showing language selection dialog');
    // בדיקה שהמסך עדיין מוצג
    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, cannot show dialog');
      return;
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false, // לא ניתן לסגור את הדיאלוג בלחיצה מחוץ לו
      useRootNavigator: true, // שימוש ב-root navigator כדי להציג את הדיאלוג מעל כל המסכים
      builder: (BuildContext dialogContext) {
        debugPrint('🌐 Language selection dialog builder called');
        return Directionality(
          textDirection: TextDirection.rtl, // RTL עבור עברית וערבית
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppLocalizations.of(context).selectLanguage,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageOption(
                  context,
                  AppLocalizations.of(context).hebrew,
                  'Hebrew',
                  Icons.language,
                  Colors.blue,
                  () {
                    selectedLocale = const Locale('he');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  context,
                  'العربية',
                  'Arabic',
                  Icons.language,
                  Colors.green,
                  () {
                    selectedLocale = const Locale('ar');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  context,
                  'English',
                  'English',
                  Icons.language,
                  Colors.orange,
                  () {
                    selectedLocale = const Locale('en');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    debugPrint('🌐 Dialog closed, selectedLocale: $selectedLocale');
    
    // שמירת השפה שנבחרה
    if (selectedLocale != null) {
      // הצג Progress Dialog בזמן החלת השפה
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext progressContext) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: PopScope(
                canPop: false, // מונע סגירה
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          // ✅ יצירת AppLocalizations עם השפה שנבחרה במקום context שעדיין לא עודכן
                          final l10n = AppLocalizations(selectedLocale!);
                          return Text(
                            l10n.applyingLanguage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', selectedLocale!.languageCode);
      debugPrint('🌐 Saved language to SharedPreferences: ${selectedLocale!.languageCode}');
      
      // קריאה ל-callback אם קיים - זה יחיל את השפה מיד
      if (widget.onLanguageSelected != null) {
        debugPrint('🌐 Calling onLanguageSelected callback to apply language');
        widget.onLanguageSelected!(selectedLocale!);
        // המתן קצר רק כדי שה-ValueListenableBuilder יתעדכן
        // Flutter מטפל בעדכונים אוטומטית, אין צורך בהמתנות ארוכות
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('🌐 Language change callback completed');
      }
      
      // סגירת Progress Dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      debugPrint('🌐 Language selected: ${selectedLocale!.languageCode}');
      
      // סמן שהשפה נבחרה ועבור למסך הבא
      _languageSelected = true;
      if (mounted) {
        _navigateToNextScreen();
      }
    } else {
      // אם המשתמש לא בחר שפה, נשתמש בעברית כברירת מחדל
      debugPrint('🌐 No language selected, using Hebrew as default');
      
      // הצג Progress Dialog בזמן החלת השפה
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext progressContext) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: PopScope(
                canPop: false, // מונע סגירה
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          // ✅ יצירת AppLocalizations עם עברית כברירת מחדל
                          final l10n = AppLocalizations(const Locale('he'));
                          return Text(
                            l10n.applyingLanguage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', 'he');
      if (widget.onLanguageSelected != null) {
        widget.onLanguageSelected!(const Locale('he'));
        // המתן כדי שהשפה תוחל לפני המעבר למסך הבא
        debugPrint('🌐 Waiting for default language (Hebrew) to be applied...');
        await Future.delayed(const Duration(milliseconds: 2000));
        debugPrint('🌐 Default language should be applied now');
        
        // המתן עוד קצת כדי שהמסך יתעדכן עם השפה החדשה
        await Future.delayed(const Duration(milliseconds: 1000));
        debugPrint('🌐 Additional wait completed, default language should be fully applied');
      }
      
      // סגירת Progress Dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // סמן שהשפה נבחרה (עברית כברירת מחדל) ועבור למסך הבא
      _languageSelected = true;
      if (mounted) {
        _navigateToNextScreen();
      }
    }
  }
  
  /// בדיקה אם השפה נבחרה לפני מעבר למסך הבא
  void _checkAndNavigateAfterLanguageSelection() {
    if (_languageSelected) {
      // השפה כבר נבחרה - עבור למסך הבא
      _navigateToNextScreen();
    } else {
      // השפה עדיין לא נבחרה - המתן
      // המעבר יקרה אחרי שהמשתמש יבחר שפה ב-_showLanguageSelectionDialog
      debugPrint('⏳ Waiting for language selection before navigation...');
    }
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNextScreen() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // המשתמש מחובר - מעבר למסך הראשי
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      // המשתמש לא מחובר - מעבר למסך כניסה
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // רקע rainbow gradient עם כוכבים נופלים
          AnimatedBuilder(
            animation: _starsController,
            builder: (context, child) {
              return CustomPaint(
                painter: RainbowStarsPainter(_starsController.value),
                child: const SizedBox.expand(),
              );
            },
          ),
          
          // תוכן המסך
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_logoAnimation, _spinAnimation, _fadeAnimation, _spinFadeController]),
              builder: (context, child) {
                // הגבלת opacity בין 0.0 ל-1.0
                final logoValue = _logoAnimation.value.clamp(0.0, 1.0);
                final fadeValue = _fadeAnimation.value.clamp(0.0, 1.0);
                final opacity = (logoValue * fadeValue).clamp(0.0, 1.0);
                
                // חישוב scale גדילה - הלוגו גדל למלוא המסך במהלך הסיבוב
                final screenSize = MediaQuery.of(context).size;
                final minDimension = math.min(screenSize.width, screenSize.height);
                final initialSize = 150.0;
                final maxScale = (minDimension / initialSize) * 1.5; // גדילה למלוא המסך + 50%
                final scaleValue = _logoAnimation.value.clamp(0.0, 1.0);
                // במהלך הסיבוב, ה-scale גדל בהדרגה
                final spinProgress = _spinFadeController.isAnimating ? _spinFadeController.value : 0.0;
                final totalScale = scaleValue + (spinProgress * (maxScale - scaleValue));
                
                return Opacity(
                  opacity: opacity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // לוגו שכונתי אנימטיבי - רק הוא מסתובב וגדל
                      Transform.scale(
                        scale: totalScale,
                        child: Transform.rotate(
                          angle: _spinAnimation.value * 2 * math.pi, // סיבוב מהיר מאוד
                          child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: Image.asset(
                            'assets/images/logolarge.png',
                            fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // כותרת
                      Text(
                        AppLocalizations.of(context).appTitle,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        AppLocalizations.of(context).strongNeighborhoodInAction,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // סטטוס אתחול
                      Text(
                        _initializationStatus,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // אינדיקטור טעינה
                      if (_isInitializing)
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter לכוכבים מנצנצים
// Custom Painter לרקע rainbow gradient עם כוכבים נופלים
class RainbowStarsPainter extends CustomPainter {
  final double animationValue;
  static final List<FallingStar> _stars = List.generate(90, (index) {
    final random = math.Random(index * 9973);
    return FallingStar(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 8.0 + random.nextDouble() * 12.0,
      fallSpeed: 0.3 + random.nextDouble() * 0.7,
      rotationSpeed: 0.5 + random.nextDouble() * 1.5,
      horizontalRotationSpeed: 1.0 + random.nextDouble() * 2.0, // מהירות סיבוב אופקי מהירה יותר
      baseOpacity: 0.7 + random.nextDouble() * 0.3,
    );
  });

  RainbowStarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // ציור רקע rainbow gradient אנימטיבי
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSVColor.fromAHSV(1, (animationValue * 360) % 360, 0.8, 0.3).toColor(),
        HSVColor.fromAHSV(1, ((animationValue * 360) + 60) % 360, 0.8, 0.25).toColor(),
        HSVColor.fromAHSV(1, ((animationValue * 360) + 120) % 360, 0.8, 0.2).toColor(),
        HSVColor.fromAHSV(1, ((animationValue * 360) + 180) % 360, 0.8, 0.15).toColor(),
      ],
    );
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // ציור כוכבים נופלים
    final starPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    for (int i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      // חישוב מיקום נופל
      final currentY = (star.y + animationValue * star.fallSpeed) % 1.2; // % 1.2 כדי שיחזור מלמעלה
      final actualY = currentY * size.height;
      final actualX = star.x * size.width;
      
      // חישוב סיבוב רגיל (סביב ציר Z)
      final rotation = animationValue * star.rotationSpeed * 2 * math.pi;
      
      // חישוב סיבוב אופקי (סביב ציר Y) - משפיע על scaleX
      final horizontalRotation = animationValue * star.horizontalRotationSpeed * 2 * math.pi;
      // scaleX משתנה לפי זווית הסיבוב האופקי (cos) - יוצר אפקט 3D
      final horizontalScale = math.cos(horizontalRotation).abs();
      // scaleX נע בין 0.3 ל-1.0 כדי שהכוכב לא ייעלם לגמרי
      final scaleX = 0.3 + (horizontalScale * 0.7);
      
      // חישוב opacity (מנצנץ)
      final twinkle = (math.sin(animationValue * 2 * math.pi * 2 + star.x * 10) + 1) / 2;
      final opacity = star.baseOpacity * (0.5 + twinkle * 0.5);
      
      // שמירת מצב canvas
      canvas.save();
      
      // מעבר למיקום הכוכב
      canvas.translate(actualX, actualY);
      
      // סיבוב אופקי (scaleX לפני הסיבוב הרגיל)
      canvas.scale(scaleX, 1.0);
      
      // סיבוב רגיל (סביב ציר Z)
      canvas.rotate(rotation);
      
      // ציור כוכב 5 נקודות עם צבע שונה
      starPaint.color = _getStarColor(i, opacity);
      _drawStar(canvas, Offset.zero, star.size, starPaint);
      
      // שחזור מצב canvas
      canvas.restore();
    }
  }

  // פונקציה לציור כוכב 5 נקודות
  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final angle = math.pi / 5; // 36 מעלות
    
    for (int i = 0; i < 10; i++) {
      final currentAngle = i * angle - math.pi / 2;
      final r = (i % 2 == 0) ? radius : radius * 0.4;
      final x = center.dx + r * math.cos(currentAngle);
      final y = center.dy + r * math.sin(currentAngle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // פונקציה לקבלת צבע אקראי לכוכב
  Color _getStarColor(int index, double opacity) {
    final colors = [
      Colors.white,
      Colors.yellow,
      Colors.cyan,
      Colors.pink,
      Colors.lightBlue,
      Colors.lightGreen,
      Colors.orange,
      Colors.purple,
    ];
    final baseColor = colors[index % colors.length];
    return baseColor.withOpacity(opacity);
  }

  @override
  bool shouldRepaint(covariant RainbowStarsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class FallingStar {
  final double x;
  final double y;
  final double size;
  final double fallSpeed;
  final double rotationSpeed;
  final double horizontalRotationSpeed; // מהירות סיבוב אופקי סביב ציר Y
  final double baseOpacity;

  FallingStar({
    required this.x,
    required this.y,
    required this.size,
    required this.fallSpeed,
    required this.rotationSpeed,
    required this.horizontalRotationSpeed,
    required this.baseOpacity,
  });
}
