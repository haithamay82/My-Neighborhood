import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../widgets/animated_background.dart';
import '../services/audio_service.dart';

class ModernAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const ModernAuthScreen({super.key, this.onLoginSuccess});

  @override
  State<ModernAuthScreen> createState() => _ModernAuthScreenState();
}

class _ModernAuthScreenState extends State<ModernAuthScreen> with AudioMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                
                // לוגו וכותרת
                _buildLogoAndTitle(),
                
                const SizedBox(height: 60),
                
                // כפתורי כניסה חברתית
                _buildSocialLoginButtons(),
                
                const SizedBox(height: 30),
                
                // מפריד
                _buildDivider(),
                
                const SizedBox(height: 30),
                
                // כניסה עם טלפון
                _buildPhoneLoginButton(),
                
                const SizedBox(height: 30),
                
                // או כניסה עם אימייל
                _buildEmailLoginOption(),
                
                const SizedBox(height: 40),
                
                // תנאי שימוש
                _buildTermsAndConditions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoAndTitle() {
    return Column(
      children: [
        // לוגו
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Image.asset(
              'assets/images/logolarge.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // כותרת
        Text(
          'שכונתי',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'קהילה מקומית • עזרה הדדית',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        // פייסבוק
        _buildSocialButton(
          icon: Icons.facebook,
          label: 'המשך עם פייסבוק',
          color: const Color(0xFF1877F2),
          onPressed: _handleFacebookLogin,
        ),
        
        const SizedBox(height: 16),
        
        // פייסבוק
        _buildSocialButton(
          icon: Icons.facebook,
          label: 'המשך עם פייסבוק',
          color: const Color(0xFF1877F2),
          onPressed: _handleFacebookLogin,
        ),
        
        const SizedBox(height: 16),
        
        // גוגל
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          label: 'המשך עם גוגל',
          color: Colors.white,
          textColor: Colors.black87,
          onPressed: _handleGoogleLogin,
        ),
        
        const SizedBox(height: 16),
        
        // אינסטגרם
        _buildSocialButton(
          icon: Icons.camera_alt,
          label: 'המשך עם אינסטגרם',
          color: const Color(0xFFE4405F),
          onPressed: _handleInstagramLogin,
        ),
        
        const SizedBox(height: 16),
        
        // אפל (iOS בלבד)
        if (Theme.of(context).platform == TargetPlatform.iOS)
          _buildSocialButton(
            icon: Icons.apple,
            label: 'המשך עם Apple',
            color: Colors.black,
            onPressed: _handleAppleLogin,
          ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () async {
          await playButtonSound();
          onPressed();
        },
        icon: Icon(icon, size: 24, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          child: Text(
            'או',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
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

  Widget _buildPhoneLoginButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _isLoading ? null : () async {
          await playButtonSound();
          _showPhoneLoginDialog();
        },
        icon: const Icon(
          Icons.phone,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmailLoginOption() {
    return TextButton(
      onPressed: _isLoading ? null : () async {
        await playButtonSound();
        _showEmailLoginDialog();
      },
      child: Text(
        'התחבר עם אימייל',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'התחברות משמעה הסכמה לתנאי השימוש, מדיניות פרטיות ומדיניות בטיחות ילדים',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
    );
  }

  void _showPhoneLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('כניסה עם טלפון'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'מספר טלפון',
                prefixText: '+972 ',
                hintText: '50-123-4567',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement phone authentication
            },
            child: const Text('שלח קוד'),
          ),
        ],
      ),
    );
  }

  void _showEmailLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isSignUp ? 'הרשמה' : 'התחברות'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSignUp)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'שם מלא',
                  ),
                ),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'אימייל',
                ),
              ),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'סיסמה',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
              });
            },
            child: Text(_isSignUp ? 'יש לך חשבון? התחבר' : 'אין לך חשבון? הירשם'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailAuth,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isSignUp ? 'הירשם' : 'התחבר'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        await FirebaseAuth.instance.signInWithCredential(credential);
        await playSuccessSound();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בהתחברות: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInstagramLogin() async {
    setState(() => _isLoading = true);
    try {
      // אינסטגרם לא תומך ישירות ב-Firebase Auth
      // נציג הודעה למשתמש
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('כניסה דרך אינסטגרם תהיה זמינה בקרוב!'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: ['email'],
      ).signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await playSuccessSound();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בהתחברות: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      await playSuccessSound();
      // Guard context usage after async gap
      if (!mounted) return;
      widget.onLoginSuccess?.call();
    } catch (e) {
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בהתחברות: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        // Firebase Auth יכשל אוטומטית אם האימייל כבר קיים
        final email = _emailController.text.trim();
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        await FirebaseAuth.instance.currentUser?.updateDisplayName(_nameController.text);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await playSuccessSound();
      widget.onLoginSuccess?.call();
    } catch (e) {
      await playErrorSound();
      // Guard context usage after async gap
      if (!mounted) return;
      
      // טיפול בשגיאות Firebase Auth
      String errorMessage = 'שגיאה בהתחברות';
      
      if (e is FirebaseAuthException) {
        // שימוש בקוד המדויק של Firebase
        switch (e.code) {
          case 'user-not-found':
          case 'USER_NOT_FOUND':
            errorMessage = 'אימייל זה אינו רשום במערכת';
            break;
          case 'wrong-password':
          case 'WRONG_PASSWORD':
            errorMessage = 'הסיסמה שגויה';
            break;
          case 'invalid-credential':
          case 'INVALID_CREDENTIAL':
            // Firebase לא מבדיל בין אימייל לא רשום לסיסמה שגויה מטעמי אבטחה
            // נציג הודעה כללית
            errorMessage = 'הסיסמה שגויה';
            break;
          case 'email-already-in-use':
          case 'EMAIL_ALREADY_IN_USE':
            errorMessage = 'אימייל זה כבר רשום במערכת';
            break;
          default:
            // בדיקה נוספת למקרה שהקוד לא מזוהה
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('user-not-found')) {
              errorMessage = 'אימייל זה אינו רשום במערכת';
            } else if (errorString.contains('wrong-password') || 
                       errorString.contains('invalid-credential')) {
              errorMessage = 'הסיסמה שגויה';
            }
        }
      } else {
        // בדיקה לגביית שגיאות לא מ-FirebaseAuthException
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('user-not-found') || 
            errorString.contains('user_not_found')) {
          errorMessage = 'אימייל זה אינו רשום במערכת';
        } else if (errorString.contains('wrong-password') || 
                   errorString.contains('wrong_password')) {
          errorMessage = 'הסיסמה שגויה';
        } else if (errorString.contains('invalid-credential') ||
                   errorString.contains('invalid_credential')) {
          errorMessage = 'הסיסמה שגויה';
        } else if (errorString.contains('email-already-in-use')) {
          errorMessage = 'אימייל זה כבר רשום במערכת';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
