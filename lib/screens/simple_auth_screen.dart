import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/audio_service.dart';

class SimpleAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const SimpleAuthScreen({super.key, this.onLoginSuccess});

  @override
  State<SimpleAuthScreen> createState() => _SimpleAuthScreenState();
}

class _SimpleAuthScreenState extends State<SimpleAuthScreen> with AudioMixin {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Container(
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
        child: SafeArea(
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
                _buildSocialButtons(),
                
                const SizedBox(height: 30),
                
                // מפריד
                _buildDivider(),
                
                const SizedBox(height: 30),
                
                // כפתור טלפון
                _buildPhoneLoginButton(),
                
                const SizedBox(height: 30),
                
                // כניסה עם אימייל
                _buildEmailLoginOption(),
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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Image.asset(
              'assets/images/logolarge.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // כותרת
        const Text(
          'שכונתי',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 8),
        
        const Text(
          'ברוך הבא',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
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
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
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

  Future<void> _handleInstagramLogin() async {
    setState(() => _isLoading = true);
    try {
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

  void _showPhoneLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('כניסה עם מספר טלפון'),
        content: const Text('פונקציה זו תהיה זמינה בקרוב!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
  }

  void _showEmailLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('כניסה עם אימייל'),
        content: const Text('פונקציה זו תהיה זמינה בקרוב!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
  }
}
