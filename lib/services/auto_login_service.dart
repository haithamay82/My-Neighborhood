import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        // מחיקת כל פרטי הכניסה - המשתמש לא רוצה לשמור
        await prefs.remove(_userEmailKey);
        await prefs.remove(_userPasswordKey);
        await prefs.remove(_googleTokenKey);
        await prefs.remove(_facebookTokenKey);
        await prefs.remove(_instagramTokenKey);
        await prefs.remove(_tiktokTokenKey);
        await prefs.remove(_loginMethodKey); // גם מוחק את שיטת הכניסה
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

      debugPrint('Attempting email auto login for: $email');
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Email auto login successful');
      return credential;
    } catch (e) {
      debugPrint('❌ Error in email auto login: $e');
      // אם יש שגיאה, נקה את הפרטים השמורים כדי לא לנסות שוב
      await clearSavedData();
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
      
      // ✅ שימוש ב-signInSilently() לכניסה אוטומטית (ללא דיאלוג)
      // זה ינסה להתחבר עם החשבון השמור, אם יש
      final googleUser = await googleSignIn.signInSilently();
      if (googleUser == null) {
        debugPrint('No cached Google user found for auto login');
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

      debugPrint('✅ Google auto login successful');
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
      // מחיקת כל פרטי הכניסה השמורים
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_loginMethodKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPasswordKey);
      await prefs.remove(_googleTokenKey);
      await prefs.remove(_facebookTokenKey);
      await prefs.remove(_instagramTokenKey);
      await prefs.remove(_tiktokTokenKey);
      await prefs.remove(_userLoggedOutKey); // גם מוחק את דגל ההתנתקות
      
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

  /// בדיקה אם המשתמש התנתק מפורשות (public method)
  static Future<bool> hasUserLoggedOut() async {
    return await _hasUserLoggedOut();
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
  /// מוחקת את כל פרטי הכניסה השמורים - המשתמש יידרש להתחבר שוב בפעם הבאה
  static Future<void> logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      
      // בדיקה אם המשתמש הוא אורח זמני - אם כן, נמחק אותו לחלוטין
      if (userId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            final isTemporaryGuest = userData?['isTemporaryGuest'] ?? false;
            
            if (isTemporaryGuest == true) {
              debugPrint('🗑️ Temporary guest detected - deleting completely');
              await _deleteTemporaryGuestCompletely(userId);
              return; // לא נמשיך עם logout רגיל - המשתמש כבר נמחק
            }
          }
        } catch (e) {
          debugPrint('Error checking temporary guest status: $e');
          // נמשיך עם logout רגיל גם אם יש שגיאה
        }
      }
      
      // התנתקות רגילה למשתמשים שאינם אורחים זמניים
      // התנתקות מ-Firebase
      await FirebaseAuth.instance.signOut();
      
      // התנתקות מגוגל
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      // התנתקות מפייסבוק
      await FacebookAuth.instance.logOut();
      
      // סימון שהמשתמש התנתק מפורשות
      await _markUserLoggedOut();
      
      // ניקוי כל הנתונים השמורים - כולל email, password, tokens, rememberMe flag
      // המשתמש יידרש להתחבר שוב בפעם הבאה (גוגל או שכונתי)
      await clearSavedData();
      
      debugPrint('User logged out and all saved data cleared');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// מחיקת משתמש אורח זמני לחלוטין - מ-Firestore ו-Firebase Authentication
  static Future<void> _deleteTemporaryGuestCompletely(String userId) async {
    try {
      debugPrint('🗑️ Starting complete deletion of temporary guest: $userId');
      
      // 1. מחיקת כל הנתונים מ-Firestore
      await _deleteTemporaryGuestFromFirestore(userId);
      
      // 2. מחיקת המשתמש מ-Firebase Authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == userId) {
        try {
          await user.delete();
          debugPrint('✅ User deleted from Firebase Authentication');
        } catch (e) {
          debugPrint('⚠️ Error deleting user from Auth (may need re-authentication): $e');
          // אם יש שגיאה, ננסה להתנתק רגיל
          await FirebaseAuth.instance.signOut();
        }
      }
      
      // 3. ניקוי כל הנתונים השמורים
      await clearSavedData();
      await _markUserLoggedOut();
      
      debugPrint('✅ Temporary guest completely deleted');
    } catch (e) {
      debugPrint('❌ Error deleting temporary guest: $e');
      rethrow;
    }
  }

  /// מחיקת כל נתוני האורח הזמני מ-Firestore
  static Future<void> _deleteTemporaryGuestFromFirestore(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // מחיקת פרופיל המשתמש
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      batch.delete(userRef);
      
      // מחיקת בקשות שהמשתמש יצר
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdBy', isEqualTo: userId)
          .get();
      for (var doc in requestsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // מחיקת בקשות שהמשתמש פנה אליהן (helpers)
      final requestsWithHelpers = await FirebaseFirestore.instance
          .collection('requests')
          .where('helpers', arrayContains: userId)
          .get();
      for (var doc in requestsWithHelpers.docs) {
        final data = doc.data();
        final helpers = List<String>.from(data['helpers'] ?? []);
        helpers.remove(userId);
        batch.update(doc.reference, {'helpers': helpers, 'helpersCount': FieldValue.increment(-1)});
      }
      
      // מחיקת user_interests
      final interestsQuery = await FirebaseFirestore.instance
          .collection('user_interests')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in interestsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // מחיקת התראות
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .get();
      for (var doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // מחיקת צ'אטים
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();
      for (var doc in chatsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // מחיקת הודעות
      final messagesQuery = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();
      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // ביצוע המחיקה
      await batch.commit();
      debugPrint('✅ Temporary guest data deleted from Firestore');
    } catch (e) {
      debugPrint('❌ Error deleting temporary guest from Firestore: $e');
      rethrow;
    }
  }

  /// התחברות מוצלחת - איפוס דגל ההתנתקות
  static Future<void> onSuccessfulLogin() async {
    await _resetLogoutFlag();
  }
}
