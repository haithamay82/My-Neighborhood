import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audio_service.dart';
import '../services/google_auth_service.dart';
import '../services/auto_login_service.dart';
import '../services/terms_service.dart';
import '../services/push_notification_service.dart';
import '../services/cloud_function_service.dart';
import '../services/permission_service.dart';
import '../widgets/remember_me_dialog.dart';
import 'terms_and_privacy_screen.dart';
import 'about_app_screen.dart';
import '../l10n/app_localizations.dart';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class YokiStyleAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const YokiStyleAuthScreen({super.key, this.onLoginSuccess});

  @override
  State<YokiStyleAuthScreen> createState() => _YokiStyleAuthScreenState();
}

class _YokiStyleAuthScreenState extends State<YokiStyleAuthScreen> 
    with AudioMixin, TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _pendingVerificationEmail;
  String? _pendingVerificationPassword;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    _animationController.repeat();
    
    // טיפול ב-Google Sign-In redirect ב-web (לפני בדיקת auto login)
    // זה חשוב כי אם המשתמש חזר מ-Google, צריך לטפל בזה לפני ש-auto login מנתק אותו
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleGoogleRedirect();
        // רק אחרי טיפול ב-redirect, נבדוק auto login
        if (mounted) {
          await _checkAutoLogin();
        }
      });
    } else {
      // בדיקת התחברות אוטומטית (רק במובייל)
      _checkAutoLogin();
    }
    
    // בקשות הרשאות - רק במסך התחברות
    _requestNotificationPermission();
    _requestLocationPermission();
  }
  
  /// טיפול ב-Google Sign-In redirect ב-web
  Future<void> _handleGoogleRedirect() async {
    if (!kIsWeb) return;
    
    try {
      debugPrint('🔍 Checking for Google Sign-In redirect result...');
      final fullUrl = Uri.base;
      debugPrint('   Full URL: $fullUrl');
      debugPrint('   URL path: ${fullUrl.path}');
      debugPrint('   URL query: ${fullUrl.query}');
      debugPrint('   URL query parameters: ${fullUrl.queryParameters}');
      debugPrint('   URL hash: ${fullUrl.fragment}');
      
      // בדיקה אם יש query parameters של redirect (לפני שהדפדפן משנה את ה-URL)
      final hasRedirectParams = fullUrl.queryParameters.containsKey('__firebase_request_key__') ||
          fullUrl.queryParameters.containsKey('apiKey') ||
          fullUrl.queryParameters.containsKey('mode') ||
          fullUrl.queryParameters.containsKey('oobCode');
      
      debugPrint('   Has redirect params: $hasRedirectParams');
      
      // המתנה קצרה כדי לאפשר ל-redirect result להתעדכן
      // חשוב: Firebase Auth צריך זמן לעבד את ה-redirect
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // בדיקה נוספת של currentUser לפני getRedirectResult
      final currentUserBeforeCheck = FirebaseAuth.instance.currentUser;
      if (currentUserBeforeCheck != null) {
        debugPrint('✅ Found current user before getRedirectResult: ${currentUserBeforeCheck.email}');
        debugPrint('   User ID: ${currentUserBeforeCheck.uid}');
        // אם יש user כבר, נטפל בו ישירות
        await _handleAuthenticatedUser(currentUserBeforeCheck);
        return;
      }
      
      debugPrint('🔍 Calling getRedirectResult...');
      try {
        final redirectResult = await FirebaseAuth.instance.getRedirectResult();
        debugPrint('   Redirect result received');
        debugPrint('   Has user: ${redirectResult.user != null}');
        debugPrint('   Has credential: ${redirectResult.credential != null}');
        debugPrint('   Has additionalUserInfo: ${redirectResult.additionalUserInfo != null}');
        
        // אם יש credential אבל אין user, ננסה להתחבר עם ה-credential
        if (redirectResult.user == null && redirectResult.credential != null) {
          debugPrint('⚠️ Redirect result has credential but no user - trying to sign in with credential');
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCredential(redirectResult.credential!);
            if (userCredential.user != null) {
              debugPrint('✅ Signed in with credential successfully: ${userCredential.user!.email}');
              await _handleAuthenticatedUser(userCredential.user!);
              return;
            }
          } catch (credError) {
            debugPrint('❌ Error signing in with credential: $credError');
            debugPrint('   Error type: ${credError.runtimeType}');
            debugPrint('   Error details: ${credError.toString()}');
          }
        }
        
        if (redirectResult.user != null) {
          debugPrint('✅ Google Sign-In redirect detected: ${redirectResult.user!.email}');
          debugPrint('   User ID: ${redirectResult.user!.uid}');
          await _handleAuthenticatedUser(redirectResult.user!);
          return;
        }
      } catch (redirectError) {
        debugPrint('❌ Error getting redirect result: $redirectError');
        debugPrint('   Error type: ${redirectError.runtimeType}');
        debugPrint('   Error details: ${redirectError.toString()}');
      }
      
      // בדיקה נוספת של currentUser אחרי getRedirectResult
      final currentUserAfterCheck = FirebaseAuth.instance.currentUser;
      if (currentUserAfterCheck != null) {
        debugPrint('✅ Found current user after getRedirectResult: ${currentUserAfterCheck.email}');
        debugPrint('   User ID: ${currentUserAfterCheck.uid}');
        // אם יש user אחרי getRedirectResult, נטפל בו
        await _handleAuthenticatedUser(currentUserAfterCheck);
        return;
      }
      
      debugPrint('⚠️ No redirect result found and no current user');
    } catch (e) {
      debugPrint('⚠️ Error handling Google redirect: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Error details: ${e.toString()}');
      // התעלם משגיאות - זה לא קריטי
    }
  }
  
  /// טיפול במשתמש מאומת (אחרי התחברות מוצלחת)
  Future<void> _handleAuthenticatedUser(User user) async {
    if (!mounted) return;
    
    try {
      debugPrint('🔐 Handling authenticated user: ${user.email}');
      
      // בדיקה אם המשתמש כבר קיים במערכת
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        // משתמש חדש - יצירת פרופיל פרטי מנוי
        debugPrint('📝 Creating new user profile...');
        final now = DateTime.now();
        final displayNameValue = user.displayName ?? user.email?.split('@')[0] ?? 'משתמש';
        
        final userData = {
          'uid': user.uid,
          'displayName': displayNameValue,
          'name': displayNameValue,
          'email': user.email ?? '',
          'userType': 'personal',
          'createdAt': Timestamp.fromDate(now),
          'isSubscriptionActive': true,
          'subscriptionStatus': 'active',
          'subscriptionExpiry': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365))
          ),
          'emailVerified': user.emailVerified,
          'accountStatus': 'active',
          'maxRequestsPerMonth': 5,
          'maxRadius': 10.0,
          'canCreatePaidRequests': false,
          'businessCategories': [],
          'hasAcceptedTerms': true,
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData);
        debugPrint('✅ New user profile created');
      } else {
        debugPrint('✅ User profile already exists');
      }
      
      // בדיקת תנאי שימוש
      final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
      
      if (!hasAcceptedTerms) {
        // הצגת מסך תנאי שימוש
        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TermsAndPrivacyScreen(
                onAccept: () async {
                  await TermsService.acceptTerms();
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
                onDecline: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pop(context, false);
                },
              ),
            ),
          );
          
          if (result != true) {
            debugPrint('❌ User declined terms');
            return; // המשתמש לא הסכים לתנאים
          }
        }
      }
      
      if (!mounted) return;
      
      // הצגת הודעה והתחברות
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('התחברת בהצלחה עם Google!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // קריאה ל-callback אם קיים
      if (widget.onLoginSuccess != null) {
        debugPrint('✅ Calling onLoginSuccess callback');
        widget.onLoginSuccess!();
      }
    } catch (e) {
      debugPrint('❌ Error handling authenticated user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתחברות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _requestNotificationPermission() async {
    // המתן קצת לפני בקשת ההרשאה
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      // בקשת הרשאות דרך PermissionService (דיאלוג)
      await PermissionService.requestNotificationPermission(context);
      
      // בקשת הרשאות דרך PushNotificationService (FCM)
      await PushNotificationService.requestPermissions();
    }
  }

  Future<void> _requestLocationPermission() async {
    // המתן יותר זמן לפני בקשת ההרשאה
    await Future.delayed(const Duration(seconds: 5));
    
    if (mounted) {
      await PermissionService.requestLocationPermission(context);
    }
  }
  
  /// בדיקת התחברות אוטומטית
  Future<void> _checkAutoLogin() async {
    try {
      // ✅ בדיקה אם יש user מחובר (יכול להיות מ-redirect)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // אם יש user מחובר, לא ננתק אותו (יכול להיות מ-Google redirect)
        debugPrint('✅ User is already logged in: ${currentUser.email}');
        debugPrint('   User ID: ${currentUser.uid}');
        // אם המשתמש מחובר, נבדוק אם צריך להציג תנאי שימוש
        final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
        if (!hasAcceptedTerms) {
          // הצגת מסך תנאי שימוש
          if (mounted) {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => TermsAndPrivacyScreen(
                  onAccept: () async {
                    await TermsService.acceptTerms();
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  },
                  onDecline: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pop(context, false);
                  },
                ),
              ),
            );
            
            if (result == true && mounted) {
              // המשתמש הסכים לתנאים - כניסה לאפליקציה
              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              }
            }
          }
        } else {
          // המשתמש מחובר והסכים לתנאים - כניסה לאפליקציה
          if (mounted && widget.onLoginSuccess != null) {
            widget.onLoginSuccess!();
          }
        }
        return;
      }
      
      // ✅ בדיקה אם יש redirect result (אפילו אם user הוא null)
      if (kIsWeb) {
        try {
          final redirectResult = await FirebaseAuth.instance.getRedirectResult();
          if (redirectResult.user != null || redirectResult.credential != null) {
            debugPrint('✅ Redirect result found in _checkAutoLogin - user should be handled by _handleGoogleRedirect');
            // אם יש redirect result, _handleGoogleRedirect כבר טיפל בזה
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error checking redirect result in _checkAutoLogin: $e');
        }
      }
      
      // ✅ בדיקה אם המשתמש התנתק מפורשות
      final userLoggedOut = await AutoLoginService.hasUserLoggedOut();
      if (userLoggedOut) {
        debugPrint('User logged out explicitly, signing out');
        await FirebaseAuth.instance.signOut();
        return;
      }

      // ✅ בדיקה אם המשתמש בחר "זכור אותי"
      final shouldRemember = await AutoLoginService.shouldRememberMe();
      if (!shouldRemember) {
        debugPrint('User chose not to remember login - signing out');
        // אם המשתמש לא בחר "זכור אותי" (לחץ "לא תודה"), נתנתק אותו
        // כך שבפעם הבאה יצטרך להתחבר שוב
        await FirebaseAuth.instance.signOut();
        return;
      }

      // ✅ אם המשתמש בחר "זכור אותי", נבדוק אם הוא כבר מחובר (שוב, למקרה שהתחבר בינתיים)
      final userAfterCheck = FirebaseAuth.instance.currentUser;
      if (userAfterCheck != null) {
        debugPrint('✅ User already logged in (${userAfterCheck.uid}) and chose to remember - keeping logged in');
        // המשתמש כבר מחובר ובחר "זכור אותי" - ה-StreamBuilder ב-main.dart כבר יציג את MainApp
        return;
      }

      // ✅ המשתמש לא מחובר אבל בחר "זכור אותי" - ננסה auto-login
      debugPrint('Attempting auto login (user chose to remember login)');
      final userCredential = await AutoLoginService.autoLogin();
      if (userCredential != null && mounted) {
        // התחברות אוטומטית הצליחה
        debugPrint('✅ Auto login successful');
        await playSuccessSound();
        widget.onLoginSuccess?.call();
      } else {
        debugPrint('Auto login failed or returned null');
      }
    } catch (e) {
      debugPrint('Auto login failed: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // רקע Full Screen עם אנימציית Rainbow Gradient
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSVColor.fromAHSV(
                        1,
                        (_animation.value * 360) % 360, // מחזור צבעים
                        0.75,
                        0.85,
                      ).toColor(),
                      HSVColor.fromAHSV(
                        1,
                        ((_animation.value * 360) + 60) % 360,
                        0.75,
                        0.85,
                      ).toColor(),
                      HSVColor.fromAHSV(
                        1,
                        ((_animation.value * 360) + 120) % 360,
                        0.75,
                        0.85,
                      ).toColor(),
                    ],
                  ),
                ),
                // שכבה שקופה קלה להוספת עומק בעיצוב
                          child: Container(
                            decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                                colors: [
                        Colors.white.withOpacity(0.06),
                        Colors.black.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                  ),
                ),
              );
            },
          ),
          
          // תוכן המסך
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // לוגו וכותרת
                    _buildLogoAndTitle(),
                    
                    const SizedBox(height: 25),
                    
                    const SizedBox(height: 20),
                    
                    // כפתורי כניסה חברתית (רק גוגל)
                    _buildGoogleButton(),
                    
                    const SizedBox(height: 15),
                    
                    // מפריד
                    _buildDivider(),
                    
                    const SizedBox(height: 15),
                    
                    // כניסה עם אימייל
                    _buildEmailLoginOption(),
                    
                    const SizedBox(height: 15),
                    
                    // המשך ללא הרשמה
                    _buildContinueWithoutRegistrationButton(),
                    
                    const SizedBox(height: 20),
                    
                    // קישורים לתנאי שימוש, מדיניות פרטיות ואודות
                    _buildLegalLinks(),
                    
                    // רווח נוסף בתחתית
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLogoAndTitle() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // לוגו שכונתי
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset(
              'assets/images/logolarge.png',
              fit: BoxFit.contain,
                    ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // כותרת
        Text(
          l10n.appTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          l10n.welcome,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          l10n.welcomeSubtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    final l10n = AppLocalizations.of(context);
    return _buildSocialButton(
      icon: null, // נשתמש בלוגו מותאם אישית
      customIcon: _buildGoogleLogo(),
      label: l10n.continueWithGoogle,
      color: Colors.white,
      textColor: Colors.black87,
      onPressed: _handleGoogleLogin,
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 18,
      height: 18,
      child: Image.asset(
        'assets/images/google logo.png',
        fit: BoxFit.contain,
        colorBlendMode: BlendMode.dstATop,
      ),
    );
  }

  Widget _buildSocialButton({
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () async {
          await playButtonSound();
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null) 
              customIcon
            else if (icon != null)
              Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n.or,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
              );
            },
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }


  Widget _buildEmailLoginOption() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await playButtonSound();
              _showEmailLoginDialog();
            },
            icon: const Icon(Icons.email, size: 20, color: Colors.white),
            label: Text(
              l10n.loginWithShchunati,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: Colors.purple.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWithoutRegistrationButton() {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: _isLoading ? null : () async {
          await playButtonSound();
          await _handleContinueWithoutRegistration();
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1),
          ),
        ),
        child: Text(
          l10n.continueWithoutRegistration,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// טיפול בכניסה ללא הרשמה - יצירת משתמש אורח עם email וסיסמה זמניים
  Future<void> _handleContinueWithoutRegistration() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // יצירת email וסיסמה זמניים ייחודיים
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomId = timestamp.toString();
      final tempEmail = 'guest_$randomId@temp.shchunati.com';
      final tempPassword = 'temp_${timestamp}_${math.Random().nextInt(10000)}';
      
      debugPrint('🔐 Creating temporary guest user with email: $tempEmail');

      // יצירת משתמש עם email וסיסמה זמניים
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: tempEmail,
        password: tempPassword,
      );
      
      final user = userCredential.user;
      
      if (user == null) {
        throw Exception('לא ניתן ליצור משתמש אורח');
      }

      debugPrint('✅ Guest user created: ${user.uid}');

      // יצירת פרופיל אורח אוטומטי
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 30));
      
      final guestProfile = {
        'userId': user.uid,
        'displayName': 'אורח',
        'email': tempEmail,
        'userType': 'guest',
        'createdAt': Timestamp.fromDate(now),
        'isSubscriptionActive': true,
        'subscriptionStatus': 'guest_trial',
        'businessCategories': [],
        'guestTrialStartDate': Timestamp.fromDate(now),
        'guestTrialEndDate': Timestamp.fromDate(trialEndDate),
        'maxRequestsPerMonth': 10,
        'maxRadius': 3.0,
        'canCreatePaidRequests': true,
        'hasAcceptedTerms': true,
        'isTemporaryGuest': true, // סימון שזה משתמש זמני
      };

      // שמירת הפרופיל ב-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(guestProfile);

      debugPrint('✅ Guest profile created for temporary user');

      // הצגת הודעת הצלחה
      if (mounted) {
        await playSuccessSound();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      debugPrint('❌ Error in continue without registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בכניסה ללא הרשמה: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLegalLinks() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            l10n.byContinuingYouAgree,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildLegalLink(
                l10n.termsAndPrivacyButton,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TermsAndPrivacyScreen(
                      onAccept: () {},
                      onDecline: () {},
                      readOnly: true, // קריאה בלבד - לא להציג לחצנים
                    ),
                  ),
                ),
              ),
              Text(
                ' • ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              _buildLegalLink(
                l10n.aboutButton,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutAppScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Copyright
          Text(
            l10n.copyright,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showEmailLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(isSignUp ? l10n.register : l10n.login),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                TextField(
                  controller: emailController,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        prefixIcon: const Icon(Icons.email),
                        border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                        labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: obscurePassword,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isSignUp,
                      onChanged: (value) => setState(() => isSignUp = value ?? false),
                    ),
                        Text(l10n.newRegistration),
                  ],
                ),
                if (!isSignUp) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showForgotPasswordDialog();
                      },
                          child: Text(
                            l10n.forgotPassword,
                            style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
            ),
            // ✅ לחצן "התחבר ללא אימות" - מופיע גם בהתחברות וגם בהרשמה
            TextButton(
              onPressed: () async {
                // סגירת הדיאלוג לפני ההתחברות
                if (mounted) {
                  Navigator.pop(context);
                }
                if (isSignUp) {
                  // הרשמה ללא אימות
                  await _handleEmailLoginWithoutVerification(
                    emailController.text,
                    passwordController.text,
                  );
                } else {
                  // התחברות ללא אימות - ננסה להתחבר בלי לבדוק אימות אימייל
                  await _handleEmailLoginWithoutVerificationForExistingUser(
                    emailController.text,
                    passwordController.text,
                  );
                }
              },
              child: Text(l10n.loginWithoutVerification),
            ),
            ElevatedButton(
              onPressed: () async {
                // סגירת הדיאלוג לפני ההתחברות
                if (mounted) {
                  Navigator.pop(context);
                }
                await _handleEmailLogin(
                  emailController.text,
                  passwordController.text,
                  isSignUp,
                );
              },
                child: Text(isSignUp ? l10n.register : l10n.login),
            ),
          ],
          );
        },
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.forgotPassword),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Text(
                  l10n.pleaseEnterEmail,
                  style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                hintText: 'example@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Theme.of(context).colorScheme.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.verifyEmailBelongsToYou,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.pleaseEnterEmail),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _handleForgotPassword(emailController.text);
            },
              child: Text(l10n.sendLink),
          ),
        ],
        );
      },
    );
  }

  Future<void> _handleForgotPassword(String email) async {
    if (!mounted) return;
    try {
      setState(() => _isLoading = true);
      
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.passwordResetLinkSentTo(email)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'שגיאה בשליחת אימייל איפוס סיסמה';
        
        if (e.toString().contains('user-not-found')) {
          errorMessage = 'לא נמצא משתמש עם כתובת אימייל זו';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'כתובת אימייל לא תקינה';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = 'יותר מדי בקשות. נסה שוב מאוחר יותר';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ התחברות למשתמש קיים ללא אימות אימייל
  Future<void> _handleEmailLoginWithoutVerificationForExistingUser(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא מלא את כל השדות'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // ניסיון להתחבר למשתמש קיים
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('✅ User signed in: ${cred.user!.uid}');
      
      // ✅ לא בודקים אימות אימייל - מכניסים את המשתמש ישירות
      // טעינת הפרופיל
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      
      if (userDoc.exists) {
        debugPrint('✅ User profile found - logged in without email verification');
        await playSuccessSound();
        
        if (mounted) {
          widget.onLoginSuccess?.call();
        }
      } else {
        debugPrint('⚠️ User profile not found');
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פרופיל המשתמש לא נמצא'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error in login without verification: $e');
      if (mounted) {
        String errorMessage = 'שגיאה בהתחברות';
        if (e.code == 'user-not-found') {
          errorMessage = 'משתמש לא נמצא. אנא הירשם תחילה.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'סיסמה שגויה';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'כתובת אימייל לא תקינה';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in login without verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ התחברות/הרשמה ללא אימות אימייל - פשוט לרשום בפיירבייס ולהכניס
  Future<void> _handleEmailLoginWithoutVerification(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא מלא את כל השדות'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // בדיקה אם המשתמש כבר אישר את תנאי השימוש
      final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
      
      if (!hasAcceptedTerms) {
        // הצגת מסך תנאי שימוש ומדיניות פרטיות
        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TermsAndPrivacyScreen(
                onAccept: () async {
                  await TermsService.acceptTerms();
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
                onDecline: () {
                  Navigator.pop(context, false);
                },
              ),
            ),
          );
          
          if (result != true) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            return;
          }
        }
      }
      
      // יצירת משתמש חדש ב-Firebase Auth
      debugPrint('🌐 Creating user with email/password on Web');
      debugPrint('   Email: $email');
      debugPrint('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
      if (kIsWeb) {
        final currentApp = Firebase.app();
        debugPrint('   Firebase App Name: ${currentApp.name}');
        debugPrint('   Firebase App Options: ${currentApp.options.appId}');
      }
      
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('✅ User created in Firebase Auth: ${cred.user!.uid}');
      
      // ✅ לא שולחים אימייל אימות - המשתמש נרשם ללא אימות
      // ✅ לא מתנתקים - המשתמש נכנס ישירות לאפליקציה
      
      // יצירת פרופיל משתמש פרטי מנוי ב-Firestore
      final now = DateTime.now();
      
      final userData = {
        'uid': cred.user!.uid,
        'displayName': email.split('@')[0],
        'email': email,
        'userType': 'personal', // משתמשים חדשים דרך שכונתי נרשמים כפרטי מנוי
        'createdAt': Timestamp.fromDate(now),
        'isSubscriptionActive': true, // פרטי מנוי פעיל
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 365)) // שנה אחת
        ),
        'emailVerified': false, // לא מאומת אבל יכול להשתמש באפליקציה
        'accountStatus': 'active',
        'maxRequestsPerMonth': 5, // פרטי מנוי - 5 בקשות בחודש
        'maxRadius': 10.0, // 10 ק"מ
        'canCreatePaidRequests': false, // פרטי מנוי - רק בקשות חינמיות
        'businessCategories': [],
        'hasAcceptedTerms': true,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(userData);
      
      debugPrint('✅ User registered without email verification - logged in immediately');
      
      await playSuccessSound();
      
      // ✅ המשתמש נשאר מחובר ונכנס ישירות לאפליקציה
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      debugPrint('❌ Error in login without verification: $e');
      String errorMessage = 'שגיאה בהרשמה';
      
      // טיפול בשגיאות ספציפיות של Firebase Auth
      final errorString = e.toString();
      if (errorString.contains('android-client-application') || 
          errorString.contains('requests-from-this-android-client')) {
        errorMessage = 'שגיאת הגדרה: יש לבדוק את הגדרות Firebase Console עבור Web app. אנא פנה למנהל המערכת.';
        debugPrint('⚠️ Firebase Web configuration issue detected - Android client application ID is being used on Web');
      } else if (errorString.contains('email-already-in-use')) {
        errorMessage = 'האימייל כבר רשום במערכת. נסה להתחבר במקום להרשם.';
      } else if (errorString.contains('weak-password')) {
        errorMessage = 'הסיסמה חלשה מדי. אנא בחר סיסמה חזקה יותר.';
      } else if (errorString.contains('invalid-email')) {
        errorMessage = 'כתובת האימייל לא תקינה. אנא בדוק את כתובת האימייל.';
      } else if (errorString.contains('network-request-failed')) {
        errorMessage = 'בעיית חיבור לאינטרנט. אנא בדוק את החיבור ונסה שוב.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailLogin(String email, String password, bool isSignUp) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא מלא את כל השדות'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (isSignUp) {
        // בדיקה אם המשתמש כבר אישר את תנאי השימוש
        final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
        
        if (!hasAcceptedTerms) {
          // הצגת מסך תנאי שימוש ומדיניות פרטיות
          if (mounted) {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => TermsAndPrivacyScreen(
                  onAccept: () async {
                    // שמירת אישור התנאים
                    await TermsService.acceptTerms();
                    // Guard context usage after async gap - check context.mounted for builder context
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  },
                  onDecline: () {
                    // המשתמש לא הסכים - ביטול הרשמה
                    Navigator.pop(context, false);
                  },
                ),
              ),
            );
            
            // אם המשתמש לא אישר את התנאים, לא נמשיך
            if (result != true) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
              return;
            }
          }
        }
        
        // Firebase Auth יכשל אוטומטית אם האימייל כבר קיים
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // שמירת האימייל והסיסמה לשליחה מחדש
        _pendingVerificationEmail = email;
        _pendingVerificationPassword = password;
        
        // בדיקה אם האימייל כבר מאומת (למקרה ש-Firebase Auth מאמת אוטומטית)
        await cred.user!.reload();
        final isEmailVerified = cred.user!.emailVerified;
        
        if (isEmailVerified) {
          // האימייל כבר מאומת - לא צריך לשלוח אימייל אימות
          debugPrint('⚠️ Email is already verified - skipping verification email');
        } else {
          // שליחת אימייל אימות מותאם אישית דרך Cloud Function
          try {
            final emailSent = await CloudFunctionService.sendCustomVerificationEmail(
              email: email,
              userId: cred.user!.uid,
              password: password, // שולח את הסיסמה לאימייל
            );
            
            if (emailSent) {
              debugPrint('✅ Custom verification email sent to: $email');
            } else {
              // אם Cloud Function נכשל, נשתמש ב-Firebase Auth כגיבוי
              debugPrint('⚠️ Cloud Function failed, using Firebase Auth as fallback');
              // זיהוי platform להגדרת actionCodeSettings
              final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
              final actionCodeSettings = ActionCodeSettings(
                url: 'https://nearme-970f3.web.app/?email=${Uri.encodeComponent(email)}',
                handleCodeInApp: isMobile, // true אם mobile, false אם web
                androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
                iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
              );
              await cred.user!.sendEmailVerification(actionCodeSettings);
            }
          } catch (e) {
            // אם יש שגיאה, נשתמש ב-Firebase Auth כגיבוי
            debugPrint('⚠️ Error sending custom email, using Firebase Auth: $e');
            
            // זיהוי platform להגדרת actionCodeSettings
            final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
            final actionCodeSettings = ActionCodeSettings(
              url: 'https://nearme-970f3.web.app/?email=${Uri.encodeComponent(email)}',
              handleCodeInApp: isMobile, // true אם mobile, false אם web
              androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
              iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
            );
            await cred.user!.sendEmailVerification(actionCodeSettings);
          }
        }
        
        // יצירת פרופיל משתמש פרטי מנוי ב-Firestore
        final now = DateTime.now();
        
        final userData = {
          'uid': cred.user!.uid,
          'displayName': email.split('@')[0], // שם משתמש מהאימייל
          'email': email,
          'userType': 'personal', // משתמשים חדשים דרך שכונתי נרשמים כפרטי מנוי
          'createdAt': Timestamp.fromDate(now),
          'isSubscriptionActive': isEmailVerified, // פרטי מנוי פעיל רק אם האימייל מאומת
          'subscriptionStatus': isEmailVerified ? 'active' : 'pending_verification', // ממתין לאימות אימייל
          'subscriptionExpiry': isEmailVerified ? Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365)) // שנה אחת
          ) : null,
          'emailVerified': isEmailVerified, // שמירת הסטטוס האמיתי
          'accountStatus': isEmailVerified ? 'active' : 'pending_verification', // ממתין לאימות אימייל
          'maxRequestsPerMonth': isEmailVerified ? 5 : 1, // פרטי מנוי - 5 בקשות בחודש (או 1 אם לא מאומת)
          'maxRadius': isEmailVerified ? 10.0 : 3.0, // 10 ק"מ (או 3 אם לא מאומת)
          'canCreatePaidRequests': false, // פרטי מנוי - רק בקשות חינמיות
          'businessCategories': [], // יבחרו במסך הבא
          'hasAcceptedTerms': true,
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set(userData);
        
        // אם האימייל לא מאומת - התנתקות מהמשתמש עד שיאמת את האימייל
        if (!isEmailVerified) {
          await FirebaseAuth.instance.signOut();
          debugPrint('🔒 User signed out - waiting for email verification');
        } else {
          debugPrint('✅ Email already verified - user can continue');
        }
        
        await playSuccessSound();
        
        // אם האימייל לא מאומת - הצגת הודעה למשתמש שהוא צריך לאמת את האימייל
        if (!isEmailVerified && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('אימות אימייל נדרש 📧'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'שלחנו לך אימייל אימות לכתובת:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'אנא פתח את האימייל ולחץ על הקישור לאימות.\n'
                    'לאחר האימות תוכל להתחבר לאפליקציה.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      // שליחה מחדש של אימייל אימות
                      try {
                        if (_pendingVerificationEmail != null && _pendingVerificationPassword != null) {
                          // התחברות זמנית לשליחת אימייל
                          final tempCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: _pendingVerificationEmail!,
                            password: _pendingVerificationPassword!,
                          );
                          // שליחת אימייל אימות מותאם אישית דרך Cloud Function
                          try {
                            final emailSent = await CloudFunctionService.sendCustomVerificationEmail(
                              email: _pendingVerificationEmail!,
                              userId: tempCred.user!.uid,
                              password: _pendingVerificationPassword!, // שולח את הסיסמה לאימייל
                            );
                            
                            if (!emailSent) {
                              // אם Cloud Function נכשל, נשתמש ב-Firebase Auth כגיבוי
                              final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                              final actionCodeSettings = ActionCodeSettings(
                                url: 'https://nearme-970f3.web.app/?email=${Uri.encodeComponent(_pendingVerificationEmail!)}',
                                handleCodeInApp: isMobile,
                                androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
                                iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
                              );
                              await tempCred.user!.sendEmailVerification(actionCodeSettings);
                            }
                          } catch (e) {
                            // אם יש שגיאה, נשתמש ב-Firebase Auth כגיבוי
                            final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                            final actionCodeSettings = ActionCodeSettings(
                              url: 'https://nearme-970f3.web.app/?email=${Uri.encodeComponent(_pendingVerificationEmail!)}',
                              handleCodeInApp: isMobile,
                              androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
                              iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
                            );
                            await tempCred.user!.sendEmailVerification(actionCodeSettings);
                          }
                          await FirebaseAuth.instance.signOut();
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('אימייל אימות נשלח מחדש!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('שגיאה בשליחת אימייל: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('שלח אימייל אימות מחדש'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('הבנתי'),
                ),
              ],
            ),
          );
          
          return; // לא ממשיכים להתחברות עד אימות אימייל
        } else if (isEmailVerified && mounted) {
          // האימייל מאומת - המשך ישירות למסך הבית
          widget.onLoginSuccess?.call();
          return;
        }
      } else {
        // התחברות - בדיקת אימות אימייל
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // בדיקה אם האימייל מאומת
        await cred.user!.reload(); // רענון נתוני המשתמש
        final currentUser = cred.user!;
        
        // ✅ בדיקה אם המשתמש נרשם ללא אימות (emailVerified: false ב-Firestore)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        final userData = userDoc.data();
        final emailVerifiedInFirestore = userData?['emailVerified'] as bool?;
        
        // אם המשתמש נרשם ללא אימות (emailVerified: false), נכניס אותו ישירות
        final shouldSkipVerification = emailVerifiedInFirestore == false;
        
        if (!shouldSkipVerification && !currentUser.emailVerified) {
          // האימייל לא מאומת - הצגת הודעה
          await FirebaseAuth.instance.signOut(); // התנתקות
          
          // שמירת האימייל והסיסמה לשליחה מחדש
          final loginEmail = email;
          final loginPassword = password;
          
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.email, color: Colors.blue, size: 28),
                    const SizedBox(width: 8),
                    const Text('אימות אימייל נדרש 📧'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'עליך לאמת את האימייל שלך לפני שתוכל להתחבר.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'אנא פתח את האימייל שנשלח לך ולחץ על הקישור לאימות.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'כתובת האימייל: $loginEmail',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'לא קיבלת את האימייל? לחץ על הכפתור למטה כדי לשלוח אותו שוב.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop(); // סגירת הדיאלוג
                            
                            // שליחה מחדש של אימייל אימות
                            try {
                              setState(() => _isLoading = true);
                              
                              // התחברות זמנית לשליחת אימייל
                              final tempCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                email: loginEmail,
                                password: loginPassword,
                              );
                              
                              // שליחת אימייל אימות מותאם אישית דרך Cloud Function
                              // זיהוי פלטפורמה
                              final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                              
                              try {
                                final emailSent = await CloudFunctionService.sendCustomVerificationEmail(
                                  email: loginEmail,
                                  userId: tempCred.user!.uid,
                                  password: loginPassword, // שולח את הסיסמה לאימייל
                                );
                                
                                if (!emailSent) {
                                  // אם Cloud Function נכשל, נשתמש ב-Firebase Auth כגיבוי
                                  final actionCodeSettings = ActionCodeSettings(
                                    url: 'https://nearme-970f3.web.app/email-verified?email=${Uri.encodeComponent(loginEmail)}',
                                    handleCodeInApp: isMobile,
                                    androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
                                    iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
                                  );
                                  await tempCred.user!.sendEmailVerification(actionCodeSettings);
                                }
                              } catch (e) {
                                debugPrint('Error sending custom email: $e');
                                // אם יש שגיאה, נשתמש ב-Firebase Auth כגיבוי
                                final actionCodeSettings = ActionCodeSettings(
                                  url: 'https://nearme-970f3.web.app/email-verified?email=${Uri.encodeComponent(loginEmail)}',
                                  handleCodeInApp: isMobile,
                                  androidPackageName: isMobile && Platform.isAndroid ? 'com.example.flutter1' : null,
                                  iOSBundleId: isMobile && Platform.isIOS ? 'com.example.flutter1' : null,
                                );
                                await tempCred.user!.sendEmailVerification(actionCodeSettings);
                              }
                              
                              await FirebaseAuth.instance.signOut();
                              
                              if (mounted) {
                                setState(() => _isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ אימייל אימות נשלח מחדש! בדוק את תיבת הדואר הנכנס שלך.'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error resending verification email: $e');
                              if (mounted) {
                                setState(() => _isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ שגיאה בשליחת אימייל: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.send, size: 20),
                          label: const Text('שלח אימייל אימות מחדש'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('הבנתי'),
                  ),
                ],
              ),
            );
          }
          setState(() => _isLoading = false);
          return; // לא ממשיכים להתחברות
        }
        
        // ✅ אם המשתמש נרשם ללא אימות, נכניס אותו ישירות
        if (shouldSkipVerification && mounted) {
          debugPrint('✅ User registered without verification - logging in directly');
          await playSuccessSound();
          widget.onLoginSuccess?.call();
          setState(() => _isLoading = false);
          return;
        }
        
        // האימייל מאומת - עדכון Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'emailVerified': true,
          'isSubscriptionActive': true,
          'subscriptionStatus': 'active',
          'accountStatus': 'active',
          'canCreatePaidRequests': true,
        });
        
        // שמירת FCM token למשתמש
        await PushNotificationService.updateUserToken();
        
        await playSuccessSound();
        // Guard context usage after async gap
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התחברות הושלמה בהצלחה!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // הצגת דיאלוג "זכור אותי" רק בהתחברות (לא בהרשמה)
        if (mounted) {
          await showRememberMeDialog(
            context: context,
            loginMethod: 'email',
            onRemember: () async {
              await AutoLoginService.saveRememberMePreference(
                rememberMe: true,
                loginMethod: 'email',
                email: email,
                password: password,
              );
              await AutoLoginService.onSuccessfulLogin();
              widget.onLoginSuccess?.call();
            },
            onDontRemember: () async {
              await AutoLoginService.saveRememberMePreference(
                rememberMe: false,
                loginMethod: 'email',
              );
              await AutoLoginService.onSuccessfulLogin();
              widget.onLoginSuccess?.call();
            },
          );
        }
      }
      
      // אם זה הרשמה, לא נציג דיאלוג "זכור אותי"
      if (isSignUp) {
        await AutoLoginService.onSuccessfulLogin();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      
      debugPrint('❌ Login error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        debugPrint('❌ Firebase Auth error code: ${e.code}');
        debugPrint('❌ Firebase Auth error message: ${e.message}');
      }
      
      final l10n = AppLocalizations.of(context);
      
      // טיפול בשגיאות Firebase Auth
      String errorMessage = l10n.loginError;
      
      if (e is FirebaseAuthException) {
        // שימוש בקוד המדויק של Firebase
        switch (e.code) {
          case 'user-not-found':
          case 'USER_NOT_FOUND':
            errorMessage = l10n.emailNotRegistered;
            break;
          case 'wrong-password':
          case 'WRONG_PASSWORD':
            errorMessage = l10n.wrongPassword;
            break;
          case 'invalid-credential':
          case 'INVALID_CREDENTIAL':
            // Firebase לא מבדיל בין אימייל לא רשום לסיסמה שגויה מטעמי אבטחה
            // במקרה של permission-denied ב-Firestore, לא ננסה לבדוק את האימייל
            // ונציג הודעה כללית
            errorMessage = l10n.emailOrPasswordWrong;
            break;
          case 'email-already-in-use':
          case 'EMAIL_ALREADY_IN_USE':
            errorMessage = l10n.userAlreadyRegisteredPleaseLogin;
            break;
          default:
            // בדיקה נוספת למקרה שהקוד לא מזוהה
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('user-not-found')) {
              errorMessage = l10n.emailNotRegistered;
            } else if (errorString.contains('wrong-password') || 
                       errorString.contains('invalid-credential')) {
              errorMessage = l10n.wrongPassword;
            } else if (errorString.contains('email-already-in-use')) {
              errorMessage = l10n.userAlreadyRegisteredPleaseLogin;
            }
        }
      } else {
        // בדיקה לגביית שגיאות לא מ-FirebaseAuthException
        // בדיקה אם זו שגיאת Firestore permission-denied
        if (e.toString().contains('permission-denied') || 
            e.toString().contains('PERMISSION_DENIED') ||
            e.toString().contains('cloud_firestore/permission-denied')) {
          errorMessage = l10n.loginError; // הודעה כללית במקרה של permission denied
        } else {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('user-not-found') || 
              errorString.contains('user_not_found')) {
            errorMessage = l10n.emailNotRegistered;
          } else if (errorString.contains('wrong-password') || 
                     errorString.contains('wrong_password') ||
                     errorString.contains('invalid-credential') ||
                     errorString.contains('invalid_credential')) {
            errorMessage = l10n.wrongPassword;
          } else if (errorString.contains('email-already-in-use') ||
                     errorString.contains('email_already_in_use')) {
            errorMessage = l10n.userAlreadyRegisteredPleaseLogin;
          }
        }
      }
      
      // Guard context usage after async gap
      if (!mounted) return;
      
      // אם זו הודעה על משתמש שכבר רשום, נציג אותה בכחול (לא אדום)
      final isUserAlreadyRegistered = errorMessage == l10n.userAlreadyRegisteredPleaseLogin || 
                                      errorMessage == l10n.userAlreadyRegistered;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: isUserAlreadyRegistered ? Colors.blue : Colors.red,
          duration: isUserAlreadyRegistered ? const Duration(seconds: 4) : const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _handleGoogleLogin() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = await GoogleAuthService.signInWithGoogle();
      
      // ב-web, אם יש redirect, הפונקציה מחזירה null כי המשתמש יעבור לדף Google
      if (kIsWeb && user == null) {
        // בדיקה אם יש redirect result (אחרי חזרה מ-Google)
        // אם אין, זה אומר שהמשתמש עובר לדף Google עכשיו
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('מעביר לדף Google להתחברות...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isLoading = false);
        return; // נצא מהפונקציה כי המשתמש יעבור לדף Google
      }
      
      if (user != null) {
        // Firebase Auth כבר מטפל בבדיקת אימייל קיים
        // אם יש משתמש עם אותו אימייל, Firebase Auth יזרוק שגיאה
        // נבדוק רק אם המשתמש כבר קיים ב-Firestore לפי UID (אחרי שהמשתמש מאומת)
        
        await playSuccessSound();
        
        // בדיקה אם המשתמש כבר קיים במערכת
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) {
          // משתמש חדש - יצירת פרופיל פרטי מנוי
          final now = DateTime.now();
          
          final displayNameValue = user.displayName ?? user.email?.split('@')[0] ?? 'משתמש';
          final userData = {
            'uid': user.uid,
            'displayName': displayNameValue,
            'name': displayNameValue, // שמירת השם המקורי ב-name גם כן
            'email': user.email ?? '',
            'userType': 'personal', // משתמש חדש דרך גוגל נרשם כפרטי מנוי
            'createdAt': Timestamp.fromDate(now),
            'isSubscriptionActive': true, // פרטי מנוי פעיל
            'subscriptionStatus': 'active',
            'subscriptionExpiry': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 365)) // שנה אחת
            ),
            'emailVerified': user.emailVerified,
            'accountStatus': 'active',
            'maxRequestsPerMonth': 5, // פרטי מנוי - 5 בקשות בחודש
            'maxRadius': 10.0, // 10 ק"מ
            'canCreatePaidRequests': false, // פרטי מנוי - רק בקשות חינמיות
            'businessCategories': [], // יבחרו במסך הבא
            'hasAcceptedTerms': true,
          };
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(userData);
          
          // מעבר ישיר למסך הבית (ללא בחירת קטגוריות)
          if (mounted) {
            // קריאה לפונקציית ההצלחה
            widget.onLoginSuccess?.call();
            return;
          }
        } else {
          // משתמש קיים - בדיקת תנאי שימוש
          final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
          
          if (!hasAcceptedTerms) {
            // הצגת מסך תנאי שימוש ומדיניות פרטיות
            if (mounted) {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAndPrivacyScreen(
                    onAccept: () async {
                      // שמירת אישור התנאים
                      await TermsService.acceptTerms();
                      // Guard context usage after async gap - check context.mounted for builder context
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
                    onDecline: () {
                      // המשתמש לא הסכים - התנתקות
                      FirebaseAuth.instance.signOut();
                      Navigator.pop(context, false);
                    },
                  ),
                ),
              );
              
              // אם המשתמש לא אישר את התנאים, לא נמשיך
              if (result != true) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
                return;
              }
            }
          }
          
          // הצגת דיאלוג "זכור אותי"
          if (mounted) {
            await showRememberMeDialog(
              context: context,
              loginMethod: 'google',
              onRemember: () async {
                await AutoLoginService.saveRememberMePreference(
                  rememberMe: true,
                  loginMethod: 'google',
                  token: 'google_token', // כאן תצטרך לקבל את ה-token האמיתי
                );
                await AutoLoginService.onSuccessfulLogin();
                widget.onLoginSuccess?.call();
              },
              onDontRemember: () async {
                await AutoLoginService.saveRememberMePreference(
                  rememberMe: false,
                  loginMethod: 'google',
                );
                await AutoLoginService.onSuccessfulLogin();
                widget.onLoginSuccess?.call();
              },
            );
          }
        }
      } else {
        // הצג הודעת שגיאה ידידותית
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loginError),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      await playErrorSound();
      debugPrint('❌ Google login error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.loginError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

}
