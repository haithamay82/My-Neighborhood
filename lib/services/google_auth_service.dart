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
        
        // בדיקה אם יש user מחובר כבר (למקרה שהמשתמש חזר מ-Google redirect)
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          debugPrint('✅ User already authenticated: ${currentUser.email}');
          return currentUser;
        }
        
        // בדיקה אם יש redirect result קיים (אחרי חזרה מ-Google)
        try {
          debugPrint('🔍 Checking for redirect result...');
          debugPrint('   Current URL: ${Uri.base}');
          debugPrint('   URL hash: ${Uri.base.fragment}');
          debugPrint('   URL query: ${Uri.base.query}');
          
          final redirectResult = await _auth.getRedirectResult();
          debugPrint('   Redirect result received');
          debugPrint('   Has user: ${redirectResult.user != null}');
          debugPrint('   Has credential: ${redirectResult.credential != null}');
          debugPrint('   Has additionalUserInfo: ${redirectResult.additionalUserInfo != null}');
          
          if (redirectResult.user != null) {
            debugPrint('✅ Google Sign-In redirect successful: ${redirectResult.user!.email}');
            debugPrint('   User ID: ${redirectResult.user!.uid}');
            return redirectResult.user;
          } else {
            debugPrint('⚠️ Redirect result exists but user is null');
            if (redirectResult.credential != null) {
              debugPrint('   But credential exists - trying to sign in with credential');
              try {
                final userCredential = await _auth.signInWithCredential(redirectResult.credential!);
                if (userCredential.user != null) {
                  debugPrint('✅ Signed in with credential successfully');
                  return userCredential.user;
                }
              } catch (credError) {
                debugPrint('❌ Error signing in with credential: $credError');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ No redirect result or error: $e');
          debugPrint('   Error type: ${e.runtimeType}');
          debugPrint('   Error details: ${e.toString()}');
        }
        
        // אם אין redirect result ואין user מחובר, נתחיל תהליך התחברות חדש
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        debugPrint('🔄 Initiating Google Sign-In...');
        debugPrint('   Auth domain: ${_auth.app.options.authDomain}');
        debugPrint('   API key: ${_auth.app.options.apiKey}');
        debugPrint('   Project ID: ${_auth.app.options.projectId}');
        
        // ננסה להשתמש ב-popup במקום redirect כדי להימנע מבעיות עם Flutter router
        // אם popup נכשל, נחזור ל-redirect
        try {
          debugPrint('   Attempting signInWithPopup (preferred method)...');
          final userCredential = await _auth.signInWithPopup(googleProvider);
          if (userCredential.user != null) {
            debugPrint('✅ Google Sign-In popup successful: ${userCredential.user!.email}');
            debugPrint('   User ID: ${userCredential.user!.uid}');
            return userCredential.user;
          }
        } catch (popupError) {
          debugPrint('⚠️ Popup failed, trying redirect: $popupError');
          debugPrint('   Error type: ${popupError.runtimeType}');
          debugPrint('   Error details: ${popupError.toString()}');
          
          // אם popup נכשל (למשל בגלל Cross-Origin-Opener-Policy), נשתמש ב-redirect
          try {
            debugPrint('🔄 Initiating Google Sign-In redirect (fallback)...');
            await _auth.signInWithRedirect(googleProvider);
            debugPrint('✅ Redirect initiated, user will be redirected to Google');
            // נחזור null כי המשתמש יעבור לדף Google
            return null;
          } catch (redirectError) {
            debugPrint('❌ Error initiating redirect: $redirectError');
            debugPrint('   Error type: ${redirectError.runtimeType}');
            debugPrint('   Error details: ${redirectError.toString()}');
            rethrow;
          }
        }
        // אם הגענו לכאן, משהו לא עבד - נחזור null
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
