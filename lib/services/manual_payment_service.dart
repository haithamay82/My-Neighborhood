import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/request.dart';

class ManualPaymentService {
  static const String _bitPhoneNumber = '0506505599'; // מספר BIT של שכונתי
  static const String _bitAccountName = 'שכונתי - מנוי שנתי';
  // סכומי מנוי לפי סוג
  static const double _personalSubscriptionAmount = 10.0;
  static const double _businessSubscriptionAmount = 50.0;
  
  /// קבלת סכום המנוי לפי סוג
  static double _getSubscriptionAmount(String? subscriptionType) {
    switch (subscriptionType) {
      case 'business':
        return _businessSubscriptionAmount;
      case 'personal':
      default:
        return _personalSubscriptionAmount;
    }
  }
  
  /// יצירת בקשת תשלום ידני (רק הוראות תשלום, ללא יצירת רשומה)
  static Future<Map<String, dynamic>> createPaymentRequest({
    required String userId,
    required String userEmail,
    required String userName,
    String? subscriptionType,
  }) async {
    try {
      // עדכון סטטוס המשתמש ל"מנוי בתהליך אישור" (ללא יצירת רשומה ב-payment_requests)
      await _updateUserSubscriptionStatus(userId, 'pending_approval');
      
      // שמירת פרטי הבקשה זמנית ב-UserProfile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'requestedSubscriptionType': subscriptionType ?? 'personal',
        'pendingPaymentAmount': _getSubscriptionAmount(subscriptionType),
        'pendingPaymentCurrency': 'ILS',
        'pendingPaymentCreatedAt': Timestamp.now(),
      });
      
      return {
        'amount': _getSubscriptionAmount(subscriptionType),
        'bitPhoneNumber': _bitPhoneNumber,
        'bitAccountName': _bitAccountName,
        'instructions': _getPaymentInstructions(subscriptionType),
      };
    } catch (e) {
      print('Error creating payment request: $e');
      rethrow;
    }
  }
  
  /// הוראות תשלום
  static String _getPaymentInstructions(String? subscriptionType) {
    return '''
להפעלת המנוי, אנא העלה תמונת הוכחת תשלום העברה דרך bit למספר טלפון 0506505599.

הוראות תשלום:

1. פתח את אפליקציית BIT
2. לחץ על "שלח כסף"
3. הזן את המספר: $_bitPhoneNumber
4. הזן את הסכום: ${_getSubscriptionAmount(subscriptionType)} ש״ח
5. הוסף הערה: "$_bitAccountName"
6. שלח את התשלום
7. צלם צילום מסך של התשלום
8. חזור לאפליקציה והעלה את התמונה
''';
  }
  
  /// העלאת תמונת תשלום (Base64)
  static Future<bool> uploadPaymentProof({
    required String paymentId,
    required XFile imageFile,
    String? note,
  }) async {
    try {
      // קריאת התמונה והמרה ל-Base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // קבלת פרטי המשתמש מהבקשה
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      if (!paymentDoc.exists) {
        print('Payment request not found: $paymentId');
        return false;
      }
      
      final paymentData = paymentDoc.data()!;
      final userName = paymentData['userName'] as String? ?? 'משתמש';
      final userEmail = paymentData['userEmail'] as String? ?? '';
      
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
        'paymentProof': base64String,
        'note': note,
        'proofUploadedAt': Timestamp.now(),
        'status': 'proof_uploaded',
      });
      
      // שליחת התראה למנהל על בקשת תשלום חדשה (רק אחרי העלאת התמונה)
      await _notifyAdminOfNewPaymentRequest(paymentId, userName, userEmail);
      
      return true;
    } catch (e) {
      print('Error uploading payment proof: $e');
      return false;
    }
  }
  
  /// קבלת כל בקשת התשלום הממתינות (למנהל)
  static Stream<QuerySnapshot> getPendingPayments() {
    return FirebaseFirestore.instance
        .collection('payment_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
  
  /// קבלת כל בקשת התשלום (ממתינות ונדחות) (למנהל)
  static Stream<QuerySnapshot> getAllPayments() {
    return FirebaseFirestore.instance
        .collection('payment_requests')
        .snapshots();
  }
  
  /// אישור תשלום (למנהל)
  static Future<bool> approvePayment(String paymentId) async {
    try {
      // קבלת פרטי התשלום
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      if (!paymentDoc.exists) return false;
      
      final paymentData = paymentDoc.data()!;
      final userId = paymentData['userId'] as String;
      final requestedSubscriptionType = paymentData['subscriptionType'] ?? 'personal';
      
      debugPrint('🔍 approvePayment - requestedSubscriptionType: $requestedSubscriptionType');
      
      // הפעלת המנוי
      final subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
      
      // קבלת הפרופיל הנוכחי של המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      List<String> currentBusinessCategories = [];
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        currentBusinessCategories = List<String>.from(userData['businessCategories'] ?? []);
      }
      
      // עדכון לפי סוג המנוי שביקש
      Map<String, dynamic> updateData = {
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedPaymentId': paymentId,
        'approvedAt': Timestamp.now(),
      };
      
      if (requestedSubscriptionType == 'business') {
        // עסקי מנוי - צריך תחומי עיסוק
        debugPrint('✅ Setting user as BUSINESS subscription');
        if (currentBusinessCategories.isEmpty) {
          currentBusinessCategories = RequestCategory.values.map((e) => e.name).toList();
        }
        updateData['userType'] = 'business';
        updateData['businessCategories'] = currentBusinessCategories;
      } else {
        // פרטי מנוי - ללא תחומי עיסוק
        debugPrint('✅ Setting user as PERSONAL subscription');
        updateData['userType'] = 'personal';
        updateData['businessCategories'] = FieldValue.delete();
      }
      
      // עדכון ב-users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);

      // עדכון גם ב-user_profiles collection (אם קיים)
      try {
        final userProfilesDoc = await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .get();
        
        if (userProfilesDoc.exists) {
          await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(userId)
              .update({
            'userType': 'business',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'active',
            'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
            'businessCategories': currentBusinessCategories,
            'approvedPaymentId': paymentId,
            'approvedAt': Timestamp.now(),
          });
        }
      } catch (e) {
        print('Warning: Could not update user_profiles collection: $e');
      }
      
      // עדכון סטטוס התשלום
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
        'status': 'approved',
        'approvedAt': Timestamp.now(),
      });

      // שליחת התראה למשתמש דרך Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'toUserId': userId,
        'title': 'מנוי אושר! 🎉',
        'message': 'המנוי העסקי שלך אושר בהצלחה. כעת תוכל לראות בקשות בתשלום.',
        'type': 'subscription_approved',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      return true;
    } catch (e) {
      print('Error approving payment: $e');
      return false;
    }
  }
  
  /// דחיית תשלום (למנהל)
  static Future<bool> rejectPayment(String paymentId, String reason) async {
    try {
      // קבלת פרטי המשתמש לפני הדחייה
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      if (!paymentDoc.exists) {
        print('Payment request not found: $paymentId');
        return false;
      }
      
      final paymentData = paymentDoc.data()!;
      final userId = paymentData['userId'] as String;
      
      // עדכון סטטוס בקשת התשלום
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': Timestamp.now(),
      });
      
      // עדכון סטטוס המנוי של המשתמש ל"פרטי חינם" כדי שיוכל שוב ללחוץ "הפעל מנוי"
      await _updateUserSubscriptionStatus(userId, 'private_free');
      
      return true;
    } catch (e) {
      print('Error rejecting payment: $e');
      return false;
    }
  }
  
  /// בדיקת סטטוס תשלום
  static Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting payment status: $e');
      return null;
    }
  }
  
  /// שליחת התראה למנהל על בקשת תשלום חדשה
  static Future<void> _notifyAdminOfNewPaymentRequest(
    String paymentId,
    String userName,
    String userEmail,
  ) async {
    try {
      // מציאת המנהל (המשתמש הראשון עם isAdmin: true)
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .limit(1)
          .get();
      
      if (adminQuery.docs.isNotEmpty) {
        final adminId = adminQuery.docs.first.id;
        
        // שליחת התראה למנהל
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'toUserId': adminId,
          'title': 'בקשת מנוי חדשה! 🔔',
          'message': 'משתמש $userName ($userEmail) הגיש בקשת מנוי חדשה לאישור.',
          'type': 'new_payment_request',
          'paymentId': paymentId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
        
        // שליחת push notification ישירה למנהל
        await _sendDirectPushNotification(adminId, 'בקשת מנוי חדשה! 🔔', 'משתמש $userName ($userEmail) הגיש בקשת מנוי חדשה לאישור.');
        
        print('Admin notification sent for payment request: $paymentId');
      } else {
        print('No admin found to notify');
      }
    } catch (e) {
      print('Error notifying admin: $e');
    }
  }

  /// שליחת push notification ישירה למנהל
  static Future<void> _sendDirectPushNotification(String adminId, String title, String message) async {
    try {
      // קבלת FCM token של המנהל
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();
      
      if (!adminDoc.exists) {
        print('Admin document not found: $adminId');
        return;
      }
      
      final adminData = adminDoc.data()!;
      final fcmToken = adminData['fcmToken'] as String?;
      
      if (fcmToken == null) {
        print('No FCM token found for admin: $adminId');
        return;
      }
      
      // שליחת push notification דרך collection מיוחד
      await FirebaseFirestore.instance
          .collection('push_notifications')
          .add({
        'userId': adminId,
        'title': title,
        'body': message,
        'payload': 'new_payment_request',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Direct push notification sent to admin: $adminId');
    } catch (e) {
      print('Error sending direct push notification: $e');
    }
  }

  /// עדכון סטטוס מנוי המשתמש
  static Future<void> _updateUserSubscriptionStatus(
    String userId,
    String status,
    [DateTime? expiryDate]
  ) async {
    try {
      final updateData = <String, dynamic>{
        'subscriptionStatus': status,
      };
      
      if (status == 'active' && expiryDate != null) {
        updateData['isSubscriptionActive'] = true;
        updateData['subscriptionExpiry'] = Timestamp.fromDate(expiryDate);
      } else if (status == 'pending_approval') {
        updateData['isSubscriptionActive'] = false;
        updateData['subscriptionExpiry'] = null;
      } else if (status == 'private_free') {
        updateData['isSubscriptionActive'] = false;
        updateData['subscriptionExpiry'] = null;
        updateData['requestedSubscriptionType'] = null; // איפוס סוג המנוי המבוקש
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
    } catch (e) {
      print('Error updating user subscription status: $e');
    }
  }
  
  /// עדכון ידני של משתמש שכבר אושר (למנהל)
  static Future<bool> manuallyActivateUser(String userId) async {
    try {
      final subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
      
      // קבלת בקשת התשלום האחרונה של המשתמש כדי לדעת איזה סוג מנוי ביקש
      final paymentQuery = await FirebaseFirestore.instance
          .collection('payment_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      String requestedSubscriptionType = 'personal'; // ברירת מחדל
      if (paymentQuery.docs.isNotEmpty) {
        final paymentData = paymentQuery.docs.first.data();
        requestedSubscriptionType = paymentData['subscriptionType'] ?? 'personal';
        debugPrint('🔍 Payment request subscription type: $requestedSubscriptionType');
      } else {
        debugPrint('⚠️ No payment request found for user: $userId');
      }
      
      // קבלת הפרופיל הנוכחי של המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      List<String> currentBusinessCategories = [];
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        currentBusinessCategories = List<String>.from(userData['businessCategories'] ?? []);
      }
      
      // עדכון לפי סוג המנוי שביקש
      Map<String, dynamic> updateData = {
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedAt': Timestamp.now(),
        'approvedPaymentId': paymentQuery.docs.isNotEmpty ? paymentQuery.docs.first.id : null,
      };
      
      if (requestedSubscriptionType == 'business') {
        // עסקי מנוי - צריך תחומי עיסוק
        debugPrint('✅ Setting user as BUSINESS subscription');
        if (currentBusinessCategories.isEmpty) {
          currentBusinessCategories = RequestCategory.values.map((e) => e.name).toList();
        }
        updateData['userType'] = 'business';
        updateData['businessCategories'] = currentBusinessCategories;
      } else {
        // פרטי מנוי - ללא תחומי עיסוק
        debugPrint('✅ Setting user as PERSONAL subscription');
        updateData['userType'] = 'personal';
        updateData['businessCategories'] = FieldValue.delete();
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);

      // שליחת התראה למשתמש דרך Firestore
      String subscriptionTypeName = requestedSubscriptionType == 'business' ? 'עסקי' : 'פרטי';
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'toUserId': userId,
        'title': 'מנוי הופעל! 🎉',
        'message': 'המנוי $subscriptionTypeName שלך הופעל בהצלחה! כעת תוכל ליהנות מכל התכונות.',
        'type': 'subscription_activated',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      return true;
    } catch (e) {
      print('Error manually activating user: $e');
      return false;
    }
  }

  /// שליחת בקשת מנוי למנהל
  static Future<bool> submitSubscriptionRequest({
    required String subscriptionType,
    required double amount,
    required XFile imageFile,
    required String note,
  }) async {
    try {
      print('🚀 Starting subscription request submission...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No current user');
        return false;
      }
      
      print('👤 Current user: ${user.email} (${user.uid})');

      // קבלת פרטי המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final userName = userData['displayName'] ?? userData['name'] ?? user.email ?? 'משתמש';
      
      // קבלת פרטי הבקשה הזמניים
      final pendingAmount = userData['pendingPaymentAmount'] ?? amount;
      final pendingCurrency = userData['pendingPaymentCurrency'] ?? 'ILS';
      final pendingCreatedAt = userData['pendingPaymentCreatedAt'] ?? Timestamp.now();
      
      // העלאת התמונה ל-Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment_proofs')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final uploadTask = await storageRef.putFile(File(imageFile.path));
      final imageUrl = await uploadTask.ref.getDownloadURL();
      
      // יצירת בקשה חדשה ב-payment_requests
      final paymentRequestRef = await FirebaseFirestore.instance
          .collection('payment_requests')
          .add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userName,
        'subscriptionType': subscriptionType,
        'amount': pendingAmount,
        'currency': pendingCurrency,
        'imageUrl': imageUrl,
        'note': note,
        'status': 'pending',
        'createdAt': pendingCreatedAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // עדכון סטטוס המשתמש ל-pending_approval וניקוי פרטים זמניים
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'subscriptionStatus': 'pending_approval',
        'requestedSubscriptionType': subscriptionType,
        'updatedAt': FieldValue.serverTimestamp(),
        // ניקוי פרטים זמניים
        'pendingPaymentAmount': FieldValue.delete(),
        'pendingPaymentCurrency': FieldValue.delete(),
        'pendingPaymentCreatedAt': FieldValue.delete(),
      });
      
      // שליחת התראה לכל המנהלים
      print('🔍 Looking for admin users...');
      
      // קודם נבדוק אם יש מנהלים עם isAdmin: true
      var adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      print('📊 Found ${adminUsers.docs.length} admin users with isAdmin: true');
      
      // אם אין מנהלים, נחפש לפי email
      if (adminUsers.docs.isEmpty) {
        print('🔍 No admins found with isAdmin: true, searching by email...');
        final adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
        
        for (String email in adminEmails) {
          final emailQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .get();
          
          if (emailQuery.docs.isNotEmpty) {
            print('👤 Found admin by email: $email');
            // נוסיף את isAdmin: true למנהל
            await FirebaseFirestore.instance
                .collection('users')
                .doc(emailQuery.docs.first.id)
                .update({
              'isAdmin': true,
              'userType': 'business',
              'isSubscriptionActive': true,
              'subscriptionStatus': 'active',
            });
            
            // נוסיף למשתמשים שמצאנו
            adminUsers = emailQuery;
            break;
          }
        }
      }
      
      print('📊 Final admin count: ${adminUsers.docs.length}');
      
      for (final adminDoc in adminUsers.docs) {
        final adminData = adminDoc.data();
        print('👤 Admin: ${adminData['email']} (${adminDoc.id})');
        
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'toUserId': adminDoc.id,
          'title': 'בקשת מנוי חדשה! 📋',
          'message': '$userName ביקש לשדרג ל${subscriptionType == 'business' ? 'עסקי מנוי' : 'פרטי מנוי'}',
          'type': 'subscription_request',
          'paymentRequestId': paymentRequestRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
        
        print('✅ Notification sent to admin: ${adminData['email']}');
      }
      
      return true;
    } catch (e) {
      print('Error submitting subscription request: $e');
      return false;
    }
  }
}
