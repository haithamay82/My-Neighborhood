import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsService {
  static const String _termsAcceptedKey = 'terms_accepted';
  static const String _termsVersionKey = 'terms_version';
  static const String _currentTermsVersion = '2.0'; // גרסה נוכחית של התנאים

  /// בדיקה אם המשתמש כבר אישר את תנאי השימוש
  static Future<bool> hasUserAcceptedTerms() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // בדיקה ראשונה - SharedPreferences (מקומי)
      final prefs = await SharedPreferences.getInstance();
      final localAccepted = prefs.getBool(_termsAcceptedKey) ?? false;
      final localVersion = prefs.getString(_termsVersionKey) ?? '';

      // אם הגרסה המקומית שונה מהנוכחית, נחשב שלא אישר
      if (localVersion != _currentTermsVersion) {
        return false;
      }

      // בדיקה שנייה - Firestore (מרכזי)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final firestoreAccepted = data['hasAcceptedTerms'] ?? false;
      final firestoreVersion = data['termsVersion'] ?? '';

      // אם הגרסה ב-Firestore שונה מהנוכחית, נחשב שלא אישר
      if (firestoreVersion != _currentTermsVersion) {
        return false;
      }

      return localAccepted && firestoreAccepted;
    } catch (e) {
      print('Error checking terms acceptance: $e');
      return false;
    }
  }

  /// שמירת אישור תנאי השימוש
  static Future<bool> acceptTerms() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // שמירה מקומית
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_termsAcceptedKey, true);
      await prefs.setString(_termsVersionKey, _currentTermsVersion);

      // שמירה ב-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'hasAcceptedTerms': true,
        'termsVersion': _currentTermsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error accepting terms: $e');
      return false;
    }
  }

  /// איפוס אישור התנאים (למקרה של עדכון תנאים)
  static Future<void> resetTermsAcceptance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // איפוס מקומי
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_termsAcceptedKey);
      await prefs.remove(_termsVersionKey);

      // איפוס ב-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'hasAcceptedTerms': false,
        'termsVersion': '',
        'termsAcceptedAt': FieldValue.delete(),
      });
    } catch (e) {
      print('Error resetting terms acceptance: $e');
    }
  }

  /// בדיקה אם יש עדכון בתנאי השימוש
  static Future<bool> hasTermsUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString(_termsVersionKey) ?? '';
      return localVersion != _currentTermsVersion;
    } catch (e) {
      print('Error checking terms update: $e');
      return true; // במקרה של שגיאה, נציג את התנאים
    }
  }

  /// קבלת גרסת התנאים הנוכחית
  static String getCurrentTermsVersion() {
    return _currentTermsVersion;
  }
}
