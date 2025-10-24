import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:math' as math;
import '../firebase_options.dart';
import '../firebase_messaging_background.dart';
import '../services/notification_service_local.dart';
import '../services/push_notification_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/network_service.dart';
import '../services/google_auth_service.dart';

class YokiSplashScreen extends StatefulWidget {
  const YokiSplashScreen({super.key});

  @override
  State<YokiSplashScreen> createState() => _YokiSplashScreenState();
}

class _YokiSplashScreenState extends State<YokiSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late Animation<double> _logoAnimation;
  late Animation<double> _backgroundAnimation;
  
  bool _isInitializing = true;
  String _initializationStatus = 'מאתחל...';

  @override
  void initState() {
    super.initState();
    
    // אנימציה ללוגו
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

    // אנימציה לרקע
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    ));

    // התחלת אנימציות
    _logoController.forward();
    _backgroundController.repeat();

    // טיפול ב-redirect אם נדרש
    GoogleAuthService.handleRedirectIfNeeded();

    // אתחול כל השירותים
    _initializeServices();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // אתחול Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
      
      // הגדרת Firebase Messaging Background Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('Firebase Messaging background handler set');
      
      // Initialize local notifications
      await NotificationServiceLocal.initialize();
      debugPrint('Local notifications initialized successfully');
      
      // Initialize push notifications
      await PushNotificationService.initialize();
      debugPrint('Push notifications initialized successfully');

      // Initialize subscription notification service
      await NotificationService.initialize();
      await NotificationService.requestPermissions();
      debugPrint('Subscription notification service initialized successfully');
      
      // Initialize audio service
      await AudioService().initialize();
      debugPrint('Audio service initialized successfully');
      
      // Initialize network service
      NetworkService.initialize();
      debugPrint('Network service initialized successfully');
      
      // סיום האתחול
      setState(() {
        _initializationStatus = 'מוכן!';
        _isInitializing = false;
      });
      
      // המתן קצת לפני המעבר למסך הבא
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _initializationStatus = 'שגיאה באתחול: $e';
        _isInitializing = false;
      });
      
      // גם במקרה של שגיאה, המשך למסך הבא
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // מעבר למסך הבא
    if (mounted) {
      _navigateToNextScreen();
    }
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
          // רקע אנימטיבי
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                      Color(0xFF0F3460),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // תמונות רקע אנימטיביות - תנועה משמאל לימין
                    ...List.generate(8, (index) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final animationOffset = _backgroundAnimation.value * (screenWidth + 200) - 100;
                      
                      return Positioned(
                        left: animationOffset + (index * 150),
                        top: 50 + (index * 80) % 300,
                        child: Transform.rotate(
                          angle: _backgroundAnimation.value * 0.5 * math.pi + index,
                          child: Container(
                            width: 120 + (index * 20),
                            height: 120 + (index * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.4),
                                  Colors.blue.withOpacity(0.3),
                                  Colors.pink.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // תמונות מטושטשות נוספות - תנועה משמאל לימין
                    ...List.generate(6, (index) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final animationOffset = (_backgroundAnimation.value * (screenWidth + 300) - 150) * (index % 2 == 0 ? 1 : -1);
                      
                      return Positioned(
                        left: animationOffset + (index * 200),
                        top: 100 + (index * 120) % 400,
                        child: Transform.scale(
                          scale: 0.5 + (math.sin(_backgroundAnimation.value * 2 * math.pi + index) * 0.3),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.cyan.withOpacity(0.3),
                                  Colors.teal.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          
          // תוכן המסך
          Center(
            child: AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // לוגו שכונתי אנימטיבי
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // לב אדום במרכז
                            const Icon(
                              Icons.favorite,
                              size: 40,
                              color: Colors.red,
                            ),
                            // ידיים צבעוניות סביב הלב
                            ...List.generate(8, (index) {
                              final angle = (index * 45) * (3.14159 / 180);
                              final radius = 45.0;
                              final x = radius * math.cos(angle);
                              final y = radius * math.sin(angle);
                              
                              return Positioned(
                                left: 75 + x - 10,
                                top: 75 + y - 10,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: [
                                      Colors.blue,
                                      Colors.green,
                                      Colors.orange,
                                      Colors.pink,
                                      Colors.purple,
                                      Colors.yellow,
                                      Colors.cyan,
                                      Colors.teal,
                                    ][index],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // כותרת
                      const Text(
                        'שכונתי',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      const Text(
                        'שכונה חזקה בפעולה',
                        style: TextStyle(
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
