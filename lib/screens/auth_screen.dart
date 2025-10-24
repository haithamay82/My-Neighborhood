import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_notification_service.dart';
import '../services/admin_auth_service.dart';
import '../services/google_signin_service.dart';
import '../widgets/network_aware_widget.dart';
import '../services/audio_service.dart';

// enum UserRole { personal, business } - הוסר - כל המשתמשים נרשמים כפרטיים

class AuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const AuthScreen({super.key, this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with NetworkAwareMixin, AudioMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  // UserRole _selectedRole = UserRole.personal; - הוסר - כל המשתמשים נרשמים כפרטיים
  bool _rememberMe = false;
  bool _obscurePassword = true; // הצגת/הסתרת סיסמה

  @override
  void initState() {
    super.initState();
    // טעינת פרטי כניסה שמורים אם קיימים
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// טעינת פרטי כניסה שמורים
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;
      
      if (rememberMe && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  /// שמירת פרטי כניסה
  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA), // רקע לבן רך
              Color(0xFFE8F5E8), // ירוק רך מאוד
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Image.asset(
                        'assets/images/logolarge.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'שכונתי',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B5E20),
                        fontSize: 32,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'הצטרף לקהילה שלנו' : 'ברוך הבא',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4CAF50),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 32),

                // שם מלא - רק בהרשמה
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'שם מלא',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'אנא הכנס שם' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // אימייל
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'אימייל',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'אנא הכנס אימייל';
                    }
                    if (!value.contains('@')) {
                      return 'אנא הכנס אימייל תקין';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // סיסמה
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'סיסמה',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'אנא הכנס סיסמה';
                    }
                    if (value.length < 6) {
                      return 'הסיסמה חייבת להכיל לפחות 6 תווים';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // שמירת פרטי כניסה (רק במצב התחברות)
                if (!_isSignUp) ...[
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('שמור פרטי כניסה'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // כל המשתמשים נרשמים כפרטיים - בחירת סוג משתמש הוסרה

                // כפתור פעולה
                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    await playButtonSound();
                    _handleSubmit();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(_isSignUp ? 'הרשמה' : 'התחברות'),
                ),
                const SizedBox(height: 16),

                // מעבר בין התחברות להרשמה
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(_isSignUp
                      ? 'יש לך כבר חשבון? התחבר'
                      : 'אין לך חשבון? הרשם'),
                ),
                const SizedBox(height: 24),

                // קו מפריד
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'או',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // כפתור Google Sign-In
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : () async {
                        await playButtonSound();
                        _handleGoogleSignIn();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google Logo
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 18,
                                  width: 18,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.login,
                                      color: Colors.red,
                                      size: 18,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'התחבר עם Google',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // בדיקת חיבור לאינטרנט לפני התחברות
    if (!isConnected) {
      showNetworkMessage(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final userData = {
          'uid': cred.user!.uid,
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'userType': 'personal', // כל המשתמשים נרשמים כפרטיים
          'createdAt': DateTime.now(),
          'isSubscriptionActive': false, // Default for new users
          'subscriptionStatus': 'inactive', // Default for new users
        };
        
        debugPrint('🔍 Creating user profile with data: $userData');
        debugPrint('🔍 User type: personal (default for all new users)');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set(userData);

        await FirebaseAuth.instance.currentUser
            ?.updateDisplayName(_nameController.text.trim());

        if (!mounted) return; // ✅ בדיקה שהמסך עדיין קיים
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('נרשמת בהצלחה! עכשיו התחבר עם הפרטים שלך'),
            backgroundColor: Colors.green));
        
        await FirebaseAuth.instance.signOut();
        
        if (!mounted) return; // ✅ שוב בדיקה אחרי signOut
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return; // ✅ בדיקה אחרי delay
        setState(() {
          _isSignUp = false;
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
        });
      } else {
        debugPrint('🔐 Starting login process...');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        debugPrint('✅ Login successful, user: ${FirebaseAuth.instance.currentUser?.uid}');
        
        // שמירת פרטי כניסה אם המשתמש בחר
        await _saveCredentials();
        
        // בדיקה אם זה מנהל ועדכון הפרופיל שלו
        if (AdminAuthService.isCurrentUserAdmin()) {
          debugPrint('👑 Admin user detected, updating admin profile...');
          try {
            await AdminAuthService.ensureAdminProfile();
            debugPrint('✅ Admin profile updated successfully');
          } catch (e) {
            debugPrint('⚠️ Admin profile update failed: $e');
            // לא נעצור את התהליך בגלל שגיאה בעדכון פרופיל
          }
        }
        
        // עדכון FCM token אחרי התחברות (לא חוסם)
        try {
          await PushNotificationService.updateUserToken();
          debugPrint('✅ FCM token updated');
        } catch (e) {
          debugPrint('⚠️ FCM token update failed: $e');
          // לא נעצור את התהליך בגלל שגיאה ב-FCM
        }
        
        if (!mounted) {
          debugPrint('❌ Widget not mounted after login');
          return;
        }
        
        debugPrint('🎉 Showing success message and calling callback');
        await playSuccessSound();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('התחברת בהצלחה!'),
            backgroundColor: Colors.green));
        
        // קריאה ל-callback אם קיים
        if (widget.onLoginSuccess != null) {
          debugPrint('📞 Calling onLoginSuccess callback');
          widget.onLoginSuccess!();
        } else {
          debugPrint('⚠️ No onLoginSuccess callback provided');
          // אם אין callback, ננסה לעבור למסך הראשי ישירות
          if (mounted) {
            debugPrint('🔄 Attempting direct navigation to main screen');
            Navigator.pushReplacementNamed(context, '/main');
          }
        }
      }
    } catch (e) {
      if (!mounted) return; // ✅ חשוב גם כאן
      
      // הצגת הודעת שגיאה מותאמת
      await playErrorSound();
      showError(context, e, onRetry: () {
        _handleSubmit();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// כניסה עם Google
  Future<void> _handleGoogleSignIn() async {
    // בדיקת חיבור לאינטרנט לפני התחברות
    if (!isConnected) {
      showNetworkMessage(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await GoogleSignInService.signInWithGoogle();
      
      if (userCredential == null) {
        // המשתמש ביטל את הכניסה
        return;
      }

      final user = userCredential.user;
      if (user == null) {
        debugPrint('❌ Google Sign-In failed: User is null');
        return;
      }
      
      debugPrint('✅ Google Sign-In successful: ${user.email}');

      // בדיקה אם המשתמש הוא מנהל
      if (user.email == null) {
        debugPrint('❌ Google Sign-In failed: User email is null');
        return;
      }
      
      final isAdmin = await GoogleSignInService.isAdmin(user.email!);
      debugPrint('🔍 Admin check: User email: ${user.email}, Is admin: $isAdmin');

      if (isAdmin) {
        try {
          await AdminAuthService.ensureAdminProfile();
          debugPrint('✅ Admin profile updated successfully');
        } catch (e) {
          debugPrint('⚠️ Admin profile update failed: $e');
        }
      }
      
      // עדכון FCM token
      try {
        await PushNotificationService.updateUserToken();
        debugPrint('✅ FCM token updated');
      } catch (e) {
        debugPrint('⚠️ FCM token update failed: $e');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('התחברת בהצלחה עם Google!'),
        backgroundColor: Colors.green,
      ));
      
      // קריאה ל-callback אם קיים
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      // הצגת הודעת שגיאה מותאמת
      showError(context, e, onRetry: () {
        _handleGoogleSignIn();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

}
