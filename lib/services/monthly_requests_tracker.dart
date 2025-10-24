import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// שירות למעקב אחר מספר הבקשות שנוצרו בחודש (כולל כאלה שנמחקו)
class MonthlyRequestsTracker {
  static const String _collectionName = 'monthly_requests_tracker';
  
  /// רישום בקשה חדשה שנוצרה
  static Future<void> recordRequestCreation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // עדכון או יצירת רשומה לחודש הנוכחי
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .set({
        monthKey: FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ Recorded request creation for month: $monthKey');
    } catch (e) {
      debugPrint('❌ Error recording request creation: $e');
    }
  }
  
  /// קבלת מספר הבקשות שנוצרו בחודש הנוכחי
  static Future<int> getCurrentMonthRequestsCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return 0;
      
      final data = doc.data()!;
      final count = data[monthKey] as int? ?? 0;
      
      debugPrint('Current month requests count: $count for month: $monthKey');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting current month requests count: $e');
      return 0;
    }
  }
  
  /// קבלת מספר הבקשות שנוצרו בחודש ספציפי
  static Future<int> getMonthRequestsCount(int year, int month) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return 0;
      
      final data = doc.data()!;
      final count = data[monthKey] as int? ?? 0;
      
      debugPrint('Month requests count: $count for month: $monthKey');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting month requests count: $e');
      return 0;
    }
  }
  
  /// איפוס מונה הבקשות לחודש הנוכחי (לצורך בדיקות)
  static Future<void> resetCurrentMonthCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .update({
        monthKey: 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Reset current month requests count');
    } catch (e) {
      debugPrint('❌ Error resetting current month count: $e');
    }
  }
  
  /// מחיקת כל הנתונים של משתמש (לצורך בדיקות)
  static Future<void> clearUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .delete();
      
      debugPrint('✅ Cleared user monthly requests data');
    } catch (e) {
      debugPrint('❌ Error clearing user data: $e');
    }
  }
  
  /// קבלת כל הנתונים של משתמש (לצורך בדיקות)
  static Future<Map<String, dynamic>> getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};
      
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return {};
      
      return doc.data()!;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return {};
    }
  }
}

