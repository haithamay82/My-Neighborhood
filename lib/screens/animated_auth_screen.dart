import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/audio_service.dart';
import 'dart:math' as math;

class AnimatedAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const AnimatedAuthScreen({super.key, this.onLoginSuccess});

  @override
  State<AnimatedAuthScreen> createState() => _AnimatedAuthScreenState();
}

class _AnimatedAuthScreenState extends State<AnimatedAuthScreen> 
    with AudioMixin, TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
      body: Stack(
        children: [
          // רקע אנימטיבי
          AnimatedBuilder(
            animation: _animation,
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
                      final animationOffset = _animation.value * (screenWidth + 200) - 100;
                      
                      return Positioned(
                        left: animationOffset + (index * 150),
                        top: 50 + (index * 80) % 300,
                        child: Transform.rotate(
                          angle: _animation.value * 0.5 * math.pi + index,
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
                      final animationOffset = (_animation.value * (screenWidth + 300) - 150) * (index % 2 == 0 ? 1 : -1);
                      
                      return Positioned(
                        left: animationOffset + (index * 200),
                        top: 100 + (index * 120) % 400,
                        child: Transform.scale(
                          scale: 0.5 + (math.sin(_animation.value * 2 * math.pi + index) * 0.3),
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
          SafeArea(
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
        ],
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
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite,
            size: 60,
            color: Color(0xFF6C5CE7),
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
          shadowColor: Colors.black.withOpacity(0.3),
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
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'או',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
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
            color: const Color(0xFF6C5CE7).withOpacity(0.4),
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
          color: Colors.white.withOpacity(0.8),
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
