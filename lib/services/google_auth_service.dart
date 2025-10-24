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
        // 🌐 גרסת Web - מומלץ להשתמש ב-popup כדי למנוע redirect loop
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
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
