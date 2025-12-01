import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// התחברות עם Google (עובד גם ב-Web וגם במובייל)
  static Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 🌐 גרסת Web - נשתמש ב-redirect כי popup יכול להיכשל בגלל Cross-Origin-Opener-Policy
        debugPrint('🌐 Starting Google Sign-In on Web');
        
        // בדיקה אם יש redirect result קיים (אחרי חזרה מ-Google)
        try {
          final redirectResult = await _auth.getRedirectResult();
          if (redirectResult.user != null) {
            debugPrint('✅ Google Sign-In redirect successful: ${redirectResult.user!.email}');
            return redirectResult.user;
          }
        } catch (e) {
          debugPrint('⚠️ No redirect result or error: $e');
        }
        
        // אם אין redirect result, נתחיל תהליך התחברות חדש
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        debugPrint('🔄 Initiating Google Sign-In redirect...');
        await _auth.signInWithRedirect(googleProvider);
        debugPrint('✅ Redirect initiated, user will be redirected to Google');
        // נחזור null כי המשתמש יעבור לדף Google
        return null;
      } else {
        // 📱 גרסת מובייל - Google Sign-In
        // ביטול session קודם לפני התחברות חדשה
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('Google signOut error (ignoring): $e');
        }
        
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          // המשתמש ביטל את ההתחברות
          return null;
        }

        // קבלת פרטי האימות מ-Google
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // יצירת credential חדש
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // התחברות ל-Firebase עם ה-credential
        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      return null;
    }
  }

  /// בדיקת התחברות חוזרת (במקרה של redirect)
  static Future<void> handleRedirectIfNeeded() async {
    if (kIsWeb) {
      try {
        final result = await _auth.getRedirectResult();
        if (result.user != null) {
          debugPrint('✅ Redirect sign-in success: ${result.user!.email}');
        }
      } catch (e) {
        debugPrint('⚠️ Ignoring redirect error: $e');
      }
    }
  }

  static Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
    } else {
      // התנתקות מ-Google Sign-In במובייל
      await _googleSignIn.signOut();
      await _auth.signOut();
    }
  }
}
