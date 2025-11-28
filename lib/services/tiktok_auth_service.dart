import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TikTokAuthService {
  // Deep Link URL scheme לאפליקציה שלך
  static const String _callbackUrl = 'shchunati://auth/tiktok';
  
  // מפתחות TikTok (תצטרך לקבל אותם מ-TikTok Developer Console)
  static const String _clientKey = 'awp702poi5i8i6xp';
  
  /// התחברות עם TikTok
  static Future<bool> signInWithTikTok(BuildContext context) async {
    try {
      // יצירת state אקראי לאבטחה
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      await _saveState(state);
      
      // יצירת TikTok OAuth URL
      final authUrl = Uri.parse('https://www.tiktok.com/auth/authorize/'
          '?client_key=$_clientKey'
          '&scope=user.info.basic'
          '&response_type=code'
          '&redirect_uri=$_callbackUrl'
          '&state=$state');
      
      // פתיחת דפדפן לאימות
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        
        // Guard context usage after async gap
        if (!context.mounted) return true;
        // הצג הודעה למשתמש
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('פתח את TikTok והתחבר עם החשבון שלך'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
        
        return true;
      } else {
        throw Exception('לא ניתן לפתוח את TikTok');
      }
    } catch (e) {
      debugPrint('TikTok login error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בפתיחת TikTok: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
  
  /// שמירת state לאבטחה
  static Future<void> _saveState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tiktok_auth_state', state);
  }
  
  /// קבלת state שמור
  static Future<String?> _getSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tiktok_auth_state');
  }
  
  /// טיפול ב-callback מ-TikTok
  static Future<bool> handleCallback(String callbackUrl) async {
    try {
      final uri = Uri.parse(callbackUrl);
      
      // בדוק אם זה callback מ-TikTok
      if (uri.scheme == 'shchunati' && uri.host == 'auth' && uri.pathSegments.contains('tiktok')) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];
        final error = uri.queryParameters['error'];
        
        if (error != null) {
          debugPrint('TikTok auth error: $error');
          return false;
        }
        
        if (code != null && state != null) {
          // בדוק את ה-state
          final savedState = await _getSavedState();
          if (savedState != state) {
            debugPrint('Invalid state parameter');
            return false;
          }
          
          // החלף את ה-code ב-access token
          final success = await _exchangeCodeForToken(code);
          
          if (success) {
            // שמור את פרטי המשתמש
            await _saveUserData();
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Callback handling error: $e');
      return false;
    }
  }
  
  /// החלפת authorization code ב-access token
  static Future<bool> _exchangeCodeForToken(String code) async {
    try {
      // כאן תצטרך לשלוח בקשה לשרת שלך
      // השרת יחליף את ה-code ב-access token
      // כרגע נחזיר true רק לבדיקה
      
      debugPrint('Exchanging code for token: $code');
      
      // TODO: שליחת בקשה לשרת
      // final response = await http.post(
      //   Uri.parse('https://your-server.com/auth/tiktok/token'),
      //   body: {
      //     'code': code,
      //     'client_key': _clientKey,
      //     'client_secret': _clientSecret,
      //   },
      // );
      
      return true; // זמני
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }
  
  /// שמירת פרטי המשתמש
  static Future<void> _saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // שמור שהמשתמש מחובר דרך TikTok
      await prefs.setString('auth_provider', 'tiktok');
      await prefs.setString('auth_timestamp', DateTime.now().toIso8601String());
      
      debugPrint('User data saved for TikTok auth');
    } catch (e) {
      debugPrint('Save user data error: $e');
    }
  }
  
  /// בדיקה אם המשתמש מחובר דרך TikTok
  static Future<bool> isLoggedInWithTikTok() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('auth_provider');
      return provider == 'tiktok';
    } catch (e) {
      debugPrint('Check login status error: $e');
      return false;
    }
  }
  
  /// התנתקות
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_provider');
      await prefs.remove('auth_timestamp');
      await prefs.remove('tiktok_auth_state');
      
      debugPrint('TikTok sign out completed');
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
  
  /// פתיחת TikTok ישירות (כמו שהיה קודם)
  static Future<void> openTikTokApp(BuildContext context) async {
    try {
      final tiktokUrl = Uri.parse('tiktok://');
      
      if (await canLaunchUrl(tiktokUrl)) {
        await launchUrl(tiktokUrl, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse('https://www.tiktok.com/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
      
      // Guard context usage after async gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('פתח את TikTok והתחבר לחשבון שלך'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Open TikTok app error: $e');
      // Guard context usage after async gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בפתיחת TikTok: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
