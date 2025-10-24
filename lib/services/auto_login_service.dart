import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';

class AutoLoginService {
  static const String _rememberMeKey = 'remember_me';
  static const String _loginMethodKey = 'login_method';
  static const String _userEmailKey = 'user_email';
  static const String _userPasswordKey = 'user_password';
  static const String _googleTokenKey = 'google_token';
  static const String _facebookTokenKey = 'facebook_token';
  static const String _instagramTokenKey = 'instagram_token';
  static const String _tiktokTokenKey = 'tiktok_token';
  static const String _userLoggedOutKey = 'user_logged_out';

  /// שמירת העדפת "זכור אותי"
  static Future<void> saveRememberMePreference({
    required bool rememberMe,
    required String loginMethod,
    String? email,
    String? password,
    String? token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_rememberMeKey, rememberMe);
      await prefs.setString(_loginMethodKey, loginMethod);
      
      if (rememberMe) {
        // שמירת פרטי הכניסה
        if (email != null) {
          await prefs.setString(_userEmailKey, email);
        }
        if (password != null) {
          await prefs.setString(_userPasswordKey, password);
        }
        if (token != null) {
          switch (loginMethod) {
            case 'google':
              await prefs.setString(_googleTokenKey, token);
              break;
            case 'facebook':
              await prefs.setString(_facebookTokenKey, token);
              break;
            case 'instagram':
              await prefs.setString(_instagramTokenKey, token);
              break;
            case 'tiktok':
              await prefs.setString(_tiktokTokenKey, token);
              break;
          }
        }
      } else {
        // מחיקת פרטי הכניסה
        await prefs.remove(_userEmailKey);
        await prefs.remove(_userPasswordKey);
        await prefs.remove(_googleTokenKey);
        await prefs.remove(_facebookTokenKey);
        await prefs.remove(_instagramTokenKey);
        await prefs.remove(_tiktokTokenKey);
      }
      
      debugPrint('Remember me preference saved: $rememberMe for $loginMethod');
    } catch (e) {
      debugPrint('Error saving remember me preference: $e');
    }
  }

  /// בדיקה אם המשתמש בחר "זכור אותי"
  static Future<bool> shouldRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      debugPrint('Error checking remember me preference: $e');
      return false;
    }
  }

  /// קבלת שיטת הכניסה השמורה
  static Future<String?> getSavedLoginMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_loginMethodKey);
    } catch (e) {
      debugPrint('Error getting saved login method: $e');
      return null;
    }
  }

  /// התחברות אוטומטית
  static Future<UserCredential?> autoLogin() async {
    try {
      // בדיקה אם המשתמש התנתק מפורשות
      final userLoggedOut = await _hasUserLoggedOut();
      if (userLoggedOut) {
        debugPrint('User logged out explicitly, skipping auto login');
        return null;
      }

      final shouldRemember = await shouldRememberMe();
      if (!shouldRemember) {
        debugPrint('User chose not to remember login');
        return null;
      }

      final loginMethod = await getSavedLoginMethod();
      if (loginMethod == null) {
        debugPrint('No saved login method found');
        return null;
      }

      debugPrint('Attempting auto login with method: $loginMethod');

      switch (loginMethod) {
        case 'email':
          return await _autoLoginWithEmail();
        case 'google':
          return await _autoLoginWithGoogle();
        case 'facebook':
          return await _autoLoginWithFacebook();
        case 'instagram':
          return await _autoLoginWithInstagram();
        case 'tiktok':
          return await _autoLoginWithTikTok();
        default:
          debugPrint('Unknown login method: $loginMethod');
          return null;
      }
    } catch (e) {
      debugPrint('Error during auto login: $e');
      return null;
    }
  }

  /// התחברות אוטומטית עם אימייל
  static Future<UserCredential?> _autoLoginWithEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);
      final password = prefs.getString(_userPasswordKey);

      if (email == null || password == null) {
        debugPrint('Email or password not found for auto login');
        return null;
      }

      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Error in email auto login: $e');
      return null;
    }
  }

  /// התחברות אוטומטית עם גוגל
  static Future<UserCredential?> _autoLoginWithGoogle() async {
    try {
      // ב-Web, דלג על auto login עם Google כדי להימנע משגיאות minified
      if (kIsWeb) {
        debugPrint('Skipping Google auto login on Web to avoid minified errors');
        return null;
      }
      
      final googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      
      // בדיקה אם המשתמש כבר מחובר
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('No cached Google user found');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      
      // בדיקת null safety עבור הטוקנים
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        debugPrint('❌ Auto login failed: Both tokens are null');
        return null;
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error in Google auto login: $e');
      return null;
    }
  }

  /// התחברות אוטומטית עם פייסבוק
  static Future<UserCredential?> _autoLoginWithFacebook() async {
    try {
      // בדיקה אם המשתמש כבר מחובר
      final result = await FacebookAuth.instance.accessToken;
      if (result == null) {
        debugPrint('No cached Facebook token found');
        return null;
      }

      final credential = FacebookAuthProvider.credential(result.tokenString);
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error in Facebook auto login: $e');
      return null;
    }
  }

  /// התחברות אוטומטית עם אינסטגרם
  static Future<UserCredential?> _autoLoginWithInstagram() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_instagramTokenKey);
      
      if (token == null) {
        debugPrint('No cached Instagram token found');
        return null;
      }

      // כאן תצטרך לטפל ב-custom token או refresh token
      // זה דורש Cloud Function או backend
      debugPrint('Instagram auto login not fully implemented yet');
      return null;
    } catch (e) {
      debugPrint('Error in Instagram auto login: $e');
      return null;
    }
  }

  /// התחברות אוטומטית עם טיקטוק
  static Future<UserCredential?> _autoLoginWithTikTok() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tiktokTokenKey);
      
      if (token == null) {
        debugPrint('No cached TikTok token found');
        return null;
      }

      // כאן תצטרך לטפל ב-custom token או refresh token
      // זה דורש Cloud Function או backend
      debugPrint('TikTok auto login not fully implemented yet');
      return null;
    } catch (e) {
      debugPrint('Error in TikTok auto login: $e');
      return null;
    }
  }

  /// מחיקת כל הנתונים השמורים
  static Future<void> clearSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_loginMethodKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPasswordKey);
      await prefs.remove(_googleTokenKey);
      await prefs.remove(_facebookTokenKey);
      await prefs.remove(_instagramTokenKey);
      await prefs.remove(_tiktokTokenKey);
      
      debugPrint('All saved login data cleared');
    } catch (e) {
      debugPrint('Error clearing saved data: $e');
    }
  }

  /// בדיקה אם המשתמש התנתק מפורשות
  static Future<bool> _hasUserLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_userLoggedOutKey) ?? false;
    } catch (e) {
      debugPrint('Error checking logout status: $e');
      return false;
    }
  }

  /// סימון שהמשתמש התנתק מפורשות
  static Future<void> _markUserLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userLoggedOutKey, true);
      debugPrint('User marked as logged out');
    } catch (e) {
      debugPrint('Error marking user as logged out: $e');
    }
  }

  /// איפוס דגל ההתנתקות (המשתמש נכנס שוב)
  static Future<void> _resetLogoutFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userLoggedOutKey, false);
      debugPrint('Logout flag reset');
    } catch (e) {
      debugPrint('Error resetting logout flag: $e');
    }
  }

  /// התנתקות וניקוי נתונים
  static Future<void> logout() async {
    try {
      // התנתקות מ-Firebase
      await FirebaseAuth.instance.signOut();
      
      // התנתקות מגוגל
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      // התנתקות מפייסבוק
      await FacebookAuth.instance.logOut();
      
      // סימון שהמשתמש התנתק מפורשות
      await _markUserLoggedOut();
      
      // ניקוי נתונים שמורים
      await clearSavedData();
      
      debugPrint('User logged out and data cleared');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// התחברות מוצלחת - איפוס דגל ההתנתקות
  static Future<void> onSuccessfulLogin() async {
    await _resetLogoutFlag();
  }
}
