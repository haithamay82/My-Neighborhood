import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/filter_preferences.dart';

class FilterPreferencesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// שמירת העדפות סינון למשתמש
  static Future<void> saveFilterPreferences(FilterPreferences preferences) async {
    try {
      await _firestore
          .collection('filter_preferences')
          .doc(preferences.userId)
          .set(preferences.toMap());
      
      debugPrint('✅ Filter preferences saved for user: ${preferences.userId}');
    } catch (e) {
      debugPrint('❌ Error saving filter preferences: $e');
      throw Exception('שגיאה בשמירת העדפות הסינון');
    }
  }

  /// קבלת העדפות סינון של משתמש
  static Future<FilterPreferences?> getFilterPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('filter_preferences')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return FilterPreferences.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting filter preferences: $e');
      return null;
    }
  }

  /// עדכון סטטוס הפעלת התראות
  static Future<void> updateNotificationStatus(String userId, bool isEnabled) async {
    try {
      await _firestore
          .collection('filter_preferences')
          .doc(userId)
          .update({
        'isEnabled': isEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Notification status updated for user: $userId - $isEnabled');
    } catch (e) {
      debugPrint('❌ Error updating notification status: $e');
      throw Exception('שגיאה בעדכון סטטוס ההתראות');
    }
  }

  /// מחיקת העדפות סינון
  static Future<void> deleteFilterPreferences(String userId) async {
    try {
      await _firestore
          .collection('filter_preferences')
          .doc(userId)
          .delete();
      
      debugPrint('✅ Filter preferences deleted for user: $userId');
    } catch (e) {
      debugPrint('❌ Error deleting filter preferences: $e');
      throw Exception('שגיאה במחיקת העדפות הסינון');
    }
  }

  /// יצירת העדפות ברירת מחדל
  static FilterPreferences createDefaultPreferences(String userId) {
    return FilterPreferences(
      userId: userId,
      isEnabled: false,
      categories: [],
      maxRadius: 5.0, // 5 ק"מ ברירת מחדל
      urgency: null,
      requestType: null,
      minRating: null,
    );
  }
}
