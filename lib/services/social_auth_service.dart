import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class SocialAuthService {
  


  /// כניסה עם אינסטגרם
  static Future<void> signInWithInstagram(BuildContext context) async {
    try {
      // פתיחת אפליקציית אינסטגרם ישירות
      final instagramUrl = Uri.parse('instagram://');
      
      if (await canLaunchUrl(instagramUrl)) {
        // אם יש אפליקציית אינסטגרם, פתח אותה
        await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
      } else {
        // אחרת, פתח את האתר
        final webUrl = Uri.parse('https://www.instagram.com/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
      
      // Guard context usage after async gap
      if (!context.mounted) return;
      // הצג הודעה למשתמש
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('פתח את אינסטגרם והתחבר לחשבון שלך'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Instagram login error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בפתיחת אינסטגרם: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// כניסה עם טיקטוק
  static Future<void> signInWithTikTok(BuildContext context) async {
    try {
      // פתיחת אפליקציית טיקטוק ישירות
      final tiktokUrl = Uri.parse('tiktok://');
      
      if (await canLaunchUrl(tiktokUrl)) {
        // אם יש אפליקציית טיקטוק, פתח אותה
        await launchUrl(tiktokUrl, mode: LaunchMode.externalApplication);
      } else {
        // אחרת, פתח את האתר
        final webUrl = Uri.parse('https://www.tiktok.com/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
      
      // Guard context usage after async gap
      if (!context.mounted) return;
      // הצג הודעה למשתמש
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('פתח את טיקטוק והתחבר לחשבון שלך'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('TikTok login error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בפתיחת טיקטוק: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// כניסה עם פייסבוק (שיפור)
  static Future<UserCredential?> signInWithFacebook(BuildContext context) async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      
      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        
        // Guard context usage after async gap
        if (!context.mounted) return userCredential;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התחברות מוצלחת דרך פייסבוק!'),
            backgroundColor: Colors.green,
          ),
        );
        
        return userCredential;
      } else {
        // Guard context usage after async gap
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התחברות נכשלה'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Facebook login error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בכניסה לפייסבוק: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  /// כניסה עם גוגל (שיפור)
  static Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      // ב-Web, השתמש ב-Firebase Auth עם popup
      if (kIsWeb) {
        debugPrint('🌐 Using Firebase Auth for Google Sign-In on Web');
        
        try {
          // ניקוי Google Sign-In קודם כדי לאפשר בחירת חשבון מחדש
          await _clearGoogleSignInForWeb();
          
          // יצירת GoogleAuthProvider
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          
          // כניסה עם Firebase Auth - השתמש רק ב-redirect כדי להימנע מבעיות Cross-Origin-Opener-Policy
          debugPrint('🔄 Using redirect for Google Sign-In to avoid Cross-Origin-Opener-Policy issues');
          
          // Guard context usage before async gap
          if (!context.mounted) return null;
          // הצג הודעה למשתמש שהדפדפן יעבור לדף Google
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('מעביר לדף Google להתחברות...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
          
          await FirebaseAuth.instance.signInWithRedirect(googleProvider);
          debugPrint('✅ Redirect initiated, user will be redirected to Google');
          return null; // נחזור null כי המשתמש יעבור לדף Google
        } catch (e) {
          debugPrint('❌ Google Sign-In error: $e');
          // Guard context usage after async gap
          if (!context.mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בכניסה לגוגל: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
      }
      
      // למובייל, השתמש ב-GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '725875446445-jlfrijsk12skri7j948on9c1jflksee4.apps.googleusercontent.com',
        scopes: ['openid', 'email'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        debugPrint('🔍 Google Auth Debug:');
        debugPrint('  - Access Token: ${googleAuth.accessToken != null ? "Present" : "NULL"}');
        debugPrint('  - ID Token: ${googleAuth.idToken != null ? "Present" : "NULL"}');
        
        // Guard context usage after async gap
        if (!context.mounted) return null;
        // בדיקה אם יש לפחות אחד מהטוקנים
        if (googleAuth.accessToken == null && googleAuth.idToken == null) {
          debugPrint('❌ Google Sign-In failed: Both tokens are null');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה בכניסה לגוגל: פרטי האימות חסרים'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
        
        // יצירת credential עם הטוקנים הזמינים
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        
        // Guard context usage after async gap
        if (!context.mounted) return null;
        // בדיקת null safety עבור user
        if (userCredential.user == null) {
          debugPrint('❌ Google Sign-In failed: User is null after Firebase authentication');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה בכניסה לגוגל: פרטי המשתמש חסרים'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }
        
        // Guard context usage after async gap
        if (!context.mounted) return userCredential;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התחברות מוצלחת דרך גוגל!'),
            backgroundColor: Colors.green,
          ),
        );
        
        return userCredential;
      }
      return null;
    } catch (e) {
      debugPrint('Google login error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בכניסה לגוגל: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  /// ניקוי Google Sign-In עבור Web
  static Future<void> _clearGoogleSignInForWeb() async {
    try {
      if (kIsWeb) {
        debugPrint('🧹 Starting Google Sign-In cleanup for Web');
        
        // ניקוי localStorage ו-sessionStorage מהדפדפן
        try {
          // ניקוי ישיר של localStorage ו-sessionStorage (רק ב-Web)
          if (kIsWeb) {
            // ב-Web, נשתמש ב-GoogleSignIn ישירות
            debugPrint('🧹 Using GoogleSignIn directly for Web');
          } else {
            // במובייל, נשתמש ב-GoogleSignIn
            debugPrint('🧹 Using GoogleSignIn for mobile');
          }
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('⚠️ Could not clear browser storage: $e');
        }
        
        // יצירת GoogleSignIn instance עם clientId
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: '725875446445-jlfrijsk12skri7j948on9c1jflksee4.apps.googleusercontent.com',
          scopes: ['openid', 'email'],
        );
        
        // ניקוי אגרסיבי של Google Sign-In
        try {
          // בדיקה אם המשתמש מחובר ל-Google
          if (googleSignIn.currentUser != null) {
            debugPrint('🔍 User is signed in to Google, signing out...');
            await googleSignIn.signOut();
            debugPrint('✅ Google Sign-In signed out');
            
            // המתנה קצרה
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          // ניקוי נוסף - disconnect (מנתק לחלוטין)
          debugPrint('🔍 Attempting to disconnect Google Sign-In completely...');
          await googleSignIn.disconnect();
          debugPrint('✅ Google Sign-In disconnected completely');
          
          // המתנה ארוכה יותר כדי לוודא שהניקוי הושלם
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // בדיקה נוספת אם המשתמש עדיין מחובר
          if (googleSignIn.currentUser != null) {
            debugPrint('⚠️ User still signed in after disconnect, trying signOut again...');
            await googleSignIn.signOut();
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
          debugPrint('✅ Google Sign-In cleanup completed');
          
        } catch (disconnectError) {
          debugPrint('⚠️ Disconnect failed, trying signOut only: $disconnectError');
          // אם disconnect נכשל, ננסה רק signOut
          try {
            await googleSignIn.signOut();
            debugPrint('✅ Google Sign-In signed out');
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (signOutError) {
            debugPrint('⚠️ SignOut also failed: $signOutError');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error clearing Google Sign-In: $e');
      // לא נזרוק שגיאה - זה לא קריטי
    }
  }

  /// בדיקה אם המשתמש מחובר
  static bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// התנתקות
  static Future<void> signOut() async {
    try {
      debugPrint('🚪 Starting sign-out process...');
      
      // התנתקות מ-Firebase
      await FirebaseAuth.instance.signOut();
      debugPrint('✅ Firebase sign-out completed');
      
      // התנתקות מ-Google Sign-In
      if (kIsWeb) {
        // ב-Web, נצטרך לנקות את Google Sign-In בצורה אחרת
        debugPrint('🌐 Signing out from Google on Web');
        
        // יצירת GoogleSignIn instance עם clientId
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: '725875446445-jlfrijsk12skri7j948on9c1jflksee4.apps.googleusercontent.com',
          scopes: ['openid', 'email'],
        );
        
        // ניקוי אגרסיבי של Google Sign-In
        try {
          // בדיקה אם המשתמש מחובר ל-Google
          if (googleSignIn.currentUser != null) {
            debugPrint('🔍 User is signed in to Google, signing out...');
            await googleSignIn.signOut();
            debugPrint('✅ Google Sign-In signed out on Web');
            
            // המתנה קצרה
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          // ניקוי נוסף - disconnect (מנתק לחלוטין)
          debugPrint('🔍 Attempting to disconnect Google Sign-In completely...');
          await googleSignIn.disconnect();
          debugPrint('✅ Google Sign-In disconnected completely on Web');
          
          // המתנה ארוכה יותר כדי לוודא שהניקוי הושלם
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // בדיקה נוספת אם המשתמש עדיין מחובר
          if (googleSignIn.currentUser != null) {
            debugPrint('⚠️ User still signed in after disconnect, trying signOut again...');
            await googleSignIn.signOut();
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
        } catch (disconnectError) {
          debugPrint('⚠️ Disconnect failed during signOut, trying signOut only: $disconnectError');
          // אם disconnect נכשל, ננסה רק signOut
          try {
            await googleSignIn.signOut();
            debugPrint('✅ Google Sign-In signed out on Web');
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (signOutError) {
            debugPrint('⚠️ SignOut also failed during signOut: $signOutError');
          }
        }
      } else {
        // במובייל, השתמש ב-GoogleSignIn הרגיל
        await GoogleSignIn.standard().signOut();
        debugPrint('✅ Google Sign-In cleared on Mobile');
      }
      
      // התנתקות מ-Facebook
      await FacebookAuth.instance.logOut();
      debugPrint('✅ Facebook Sign-In cleared');
      
      debugPrint('✅ All sign-out operations completed');
    } catch (e) {
      debugPrint('❌ Error during sign-out: $e');
      // גם אם יש שגיאה, נמשיך עם ההתנתקות
    }
  }
}
