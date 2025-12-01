import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/request.dart';
import 'notification_service.dart';

class ManualPaymentService {
  static const String _bitPhoneNumber = '0506505599'; // מספר BIT של שכונתי
  static const String _bitAccountName = 'שכונתי - מנוי שנתי';
  // סכומי מנוי לפי סוג
  static const double _personalSubscriptionAmount = 30.0;
  static const double _businessSubscriptionAmount = 70.0;
  
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
      debugPrint('Error creating payment request: $e');
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
        debugPrint('Payment request not found: $paymentId');
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
      debugPrint('Error uploading payment proof: $e');
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
      
      // קבלת הקטגוריות מבקשת התשלום (אם יש)
      List<String> paymentRequestCategories = [];
      if (paymentData['businessCategories'] != null) {
        paymentRequestCategories = List<String>.from(paymentData['businessCategories']);
        debugPrint('📋 Found business categories in payment request: $paymentRequestCategories');
      }
      
      // שמירת מיקום העסק הקיים (אם יש) - כדי לא לאבד אותו בתהליך האישור
      Map<String, dynamic> locationData = {};
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        if (userData['latitude'] != null && userData['longitude'] != null) {
          locationData['latitude'] = userData['latitude'];
          locationData['longitude'] = userData['longitude'];
          debugPrint('📍 Preserving existing location: ${userData['latitude']}, ${userData['longitude']}');
        }
        if (userData['village'] != null) {
          locationData['village'] = userData['village'];
        }
        if (userData['exposureRadius'] != null) {
          locationData['exposureRadius'] = userData['exposureRadius'];
        }
      }
      
      // עדכון לפי סוג המנוי שביקש
      Map<String, dynamic> updateData = {
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedPaymentId': paymentId,
        'approvedAt': Timestamp.now(),
        ...locationData, // הוספת מיקום העסק הקיים
      };
      
      if (requestedSubscriptionType == 'business') {
        // עסקי מנוי - צריך תחומי עיסוק
        debugPrint('✅ Setting user as BUSINESS subscription');
        // אם יש קטגוריות בבקשת התשלום - השתמש בהן
        if (paymentRequestCategories.isNotEmpty) {
          currentBusinessCategories = paymentRequestCategories;
          debugPrint('✅ Using categories from payment request: $currentBusinessCategories');
        } else if (currentBusinessCategories.isEmpty) {
          // רק אם אין קטגוריות בבקשת התשלום ואין קטגוריות קיימות - הוסף את כל הקטגוריות
          currentBusinessCategories = RequestCategory.values.map((e) => e.name).toList();
          debugPrint('⚠️ No categories in payment request, using all categories: $currentBusinessCategories');
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
        debugPrint('Warning: Could not update user_profiles collection: $e');
      }
      
      // עדכון סטטוס התשלום
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
        'status': 'approved',
        'approvedAt': Timestamp.now(),
      });

      // לא שולחים התראה כאן - ההתראה תשלח מ-admin_payments_screen
      // כדי לשלוט על התוכן הנכון (פרטי/עסקי) על בסיס ה-subscriptionType
      
      return true;
    } catch (e) {
      debugPrint('Error approving payment: $e');
      return false;
    }
  }
  
  /// דחיית תשלום (למנהל)
  static Future<bool> rejectPayment(String paymentId, String reason) async {
    debugPrint('🚫 ManualPaymentService.rejectPayment called: paymentId=$paymentId, reason=$reason');
    try {
      // קבלת פרטי המשתמש לפני הדחייה
      debugPrint('📋 Fetching payment request: $paymentId');
      debugPrint('⏳ About to call Firestore get() in rejectPayment...');
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      debugPrint('✅ Firestore get() completed in rejectPayment');
      debugPrint('📄 Payment document exists: ${paymentDoc.exists}');
      
      if (!paymentDoc.exists) {
        debugPrint('❌ Payment request not found: $paymentId');
        return false;
      }
      
      debugPrint('✅ Payment document exists, extracting data...');
      final paymentData = Map<String, dynamic>.from(paymentDoc.data()!);
      debugPrint('📊 Payment data keys: ${paymentData.keys.toList()}');
      final userId = paymentData['userId'] as String?;
      final userName = paymentData['userName'] as String? ?? 'משתמש';
      final subscriptionType = paymentData['subscriptionType'] as String?;
      final paymentMethod = paymentData['paymentMethod'] as String?;
      debugPrint('👤 Found payment request for userId: $userId, userName: $userName, subscriptionType: $subscriptionType, paymentMethod: $paymentMethod');
      
      if (userId == null || userId.isEmpty) {
        debugPrint('❌ userId is null or empty in payment request!');
        return false;
      }
      
      // עדכון סטטוס בקשת התשלום
      debugPrint('🔄 Updating payment request status to rejected...');
      await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': Timestamp.now(),
      });
      debugPrint('✅ Payment request status updated to rejected');
      
      // עדכון סטטוס המנוי של המשתמש ל"פרטי חינם" כדי שיוכל שוב ללחוץ "הפעל מנוי"
      debugPrint('🔄 Updating user subscription status to private_free...');
      try {
        await _updateUserSubscriptionStatus(userId, 'private_free');
        debugPrint('✅ User subscription status updated to private_free');
      } catch (updateError, stackTrace) {
        debugPrint('❌ Error updating user subscription status: $updateError');
        debugPrint('❌ Stack trace: $stackTrace');
        // המשך גם אם יש שגיאה בעדכון הסטטוס - התשלום כבר נדחה
      }
      
      // שליחת התראה למשתמש עם סיבת הדחייה
      debugPrint('📤 ========== STARTING NOTIFICATION SEND ==========');
      debugPrint('📤 Sending rejection notification to user: $userId');
      debugPrint('📤 Notification params: userName=$userName, reason=$reason, subscriptionType=$subscriptionType, paymentMethod=$paymentMethod');
      try {
        debugPrint('📤 About to call NotificationService.sendSubscriptionApprovalNotification...');
        await NotificationService.sendSubscriptionApprovalNotification(
          userId: userId,
          approved: false,
          userName: userName,
          rejectionReason: reason,
          subscriptionType: subscriptionType,
          paymentMethod: paymentMethod,
        );
        debugPrint('✅ Rejection notification sent successfully to user: $userId');
        debugPrint('📤 ========== NOTIFICATION SEND COMPLETED ==========');
      } catch (notificationError, stackTrace) {
        debugPrint('⚠️ ========== NOTIFICATION SEND ERROR ==========');
        debugPrint('⚠️ Error sending rejection notification: $notificationError');
        debugPrint('⚠️ Stack trace: $stackTrace');
        debugPrint('⚠️ ========== END NOTIFICATION SEND ERROR ==========');
        // המשך גם אם יש שגיאה בשליחת ההתראה - התשלום כבר נדחה
      }
      
      debugPrint('✅ ManualPaymentService.rejectPayment completed successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error rejecting payment: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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
      debugPrint('Error getting payment status: $e');
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
        
        debugPrint('Admin notification sent for payment request: $paymentId');
      } else {
        debugPrint('No admin found to notify');
      }
    } catch (e) {
      debugPrint('Error notifying admin: $e');
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
        debugPrint('Admin document not found: $adminId');
        return;
      }
      
      final adminData = adminDoc.data()!;
      final fcmToken = adminData['fcmToken'] as String?;
      
      if (fcmToken == null) {
        debugPrint('No FCM token found for admin: $adminId');
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
      
      debugPrint('Direct push notification sent to admin: $adminId');
    } catch (e) {
      debugPrint('Error sending direct push notification: $e');
    }
  }

  /// עדכון סטטוס מנוי המשתמש
  static Future<void> _updateUserSubscriptionStatus(
    String userId,
    String status,
    [DateTime? expiryDate]
  ) async {
    debugPrint('🔄 _updateUserSubscriptionStatus called: userId=$userId, status=$status');
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
        updateData['userType'] = 'personal'; // החזרת המשתמש לפרטי חינם
      }
      
      debugPrint('📝 Updating user document with data: $updateData');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
      debugPrint('✅ User subscription status updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating user subscription status: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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
      List<String> paymentRequestCategories = [];
      if (paymentQuery.docs.isNotEmpty) {
        final paymentData = paymentQuery.docs.first.data();
        requestedSubscriptionType = paymentData['subscriptionType'] ?? 'personal';
        // קבלת הקטגוריות מבקשת התשלום (אם יש)
        if (paymentData['businessCategories'] != null) {
          paymentRequestCategories = List<String>.from(paymentData['businessCategories']);
          debugPrint('📋 Found business categories in payment request: $paymentRequestCategories');
        }
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
      
      // שמירת מיקום העסק הקיים (אם יש) - כדי לא לאבד אותו בתהליך האישור
      Map<String, dynamic> locationData = {};
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        if (userData['latitude'] != null && userData['longitude'] != null) {
          locationData['latitude'] = userData['latitude'];
          locationData['longitude'] = userData['longitude'];
          debugPrint('📍 Preserving existing location: ${userData['latitude']}, ${userData['longitude']}');
        }
        if (userData['village'] != null) {
          locationData['village'] = userData['village'];
        }
        if (userData['exposureRadius'] != null) {
          locationData['exposureRadius'] = userData['exposureRadius'];
        }
      }
      
      // עדכון לפי סוג המנוי שביקש
      Map<String, dynamic> updateData = {
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedAt': Timestamp.now(),
        'approvedPaymentId': paymentQuery.docs.isNotEmpty ? paymentQuery.docs.first.id : null,
        ...locationData, // הוספת מיקום העסק הקיים
      };
      
      if (requestedSubscriptionType == 'business') {
        // עסקי מנוי - צריך תחומי עיסוק
        debugPrint('✅ Setting user as BUSINESS subscription');
        // אם יש קטגוריות בבקשת התשלום - השתמש בהן
        if (paymentRequestCategories.isNotEmpty) {
          currentBusinessCategories = paymentRequestCategories;
          debugPrint('✅ Using categories from payment request: $currentBusinessCategories');
        } else if (currentBusinessCategories.isEmpty) {
          // רק אם אין קטגוריות בבקשת התשלום ואין קטגוריות קיימות - הוסף את כל הקטגוריות
          currentBusinessCategories = RequestCategory.values.map((e) => e.name).toList();
          debugPrint('⚠️ No categories in payment request, using all categories: $currentBusinessCategories');
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

      // לא שולחים התראה כאן - ה-NotificationService תשלח את ההתראה הנכונה
      // (ההתראה נשלחת מ-admin_payments_screen כשהמנהל מאשר את התשלום)
      
      return true;
    } catch (e) {
      debugPrint('Error manually activating user: $e');
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
      debugPrint('🚀 Starting subscription request submission...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No current user');
        return false;
      }
      
      debugPrint('👤 Current user: ${user.email} (${user.uid})');

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
      debugPrint('🔍 Looking for admin users...');
      
      // קודם נבדוק אם יש מנהלים עם isAdmin: true
      var adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      debugPrint('📊 Found ${adminUsers.docs.length} admin users with isAdmin: true');
      
      // אם אין מנהלים, נחפש לפי email
      if (adminUsers.docs.isEmpty) {
        debugPrint('🔍 No admins found with isAdmin: true, searching by email...');
        final adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
        
        for (String email in adminEmails) {
          final emailQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .get();
          
          if (emailQuery.docs.isNotEmpty) {
            debugPrint('👤 Found admin by email: $email');
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
      
      debugPrint('📊 Final admin count: ${adminUsers.docs.length}');
      
      for (final adminDoc in adminUsers.docs) {
        final adminData = adminDoc.data();
        debugPrint('👤 Admin: ${adminData['email']} (${adminDoc.id})');
        
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
        
        debugPrint('✅ Notification sent to admin: ${adminData['email']}');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error submitting subscription request: $e');
      return false;
    }
  }

  /// שליחת בקשת תשלום במזומן למנהל
  static Future<bool> submitCashPaymentRequest({
    required String userId,
    required String userEmail,
    required String userName,
    required String phone,
    required String subscriptionType,
    required double amount,
    List<String>? businessCategories,
  }) async {
    try {
      debugPrint('💰 Starting cash payment request submission...');
      debugPrint('📋 Business categories: $businessCategories');
      
      // יצירת בקשה חדשה ב-payment_requests
      final paymentRequestData = {
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'phone': phone,
        'subscriptionType': subscriptionType,
        'amount': amount,
        'currency': 'ILS',
        'paymentMethod': 'cash',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // הוספת קטגוריות עסקיות אם יש
      if (subscriptionType == 'business' && businessCategories != null && businessCategories.isNotEmpty) {
        paymentRequestData['businessCategories'] = businessCategories;
        debugPrint('✅ Added business categories to payment request: $businessCategories');
      }
      
      final paymentRequestRef = await FirebaseFirestore.instance
          .collection('payment_requests')
          .add(paymentRequestData);
      
      // עדכון סטטוס המשתמש ל-pending_approval
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'subscriptionStatus': 'pending_approval',
        'requestedSubscriptionType': subscriptionType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // שליחת התראה לכל המנהלים
      debugPrint('🔍 Looking for admin users...');
      
      // קודם נבדוק אם יש מנהלים עם isAdmin: true
      var adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      debugPrint('📊 Found ${adminUsers.docs.length} admin users with isAdmin: true');
      
      // אם אין מנהלים, נחפש לפי email
      if (adminUsers.docs.isEmpty) {
        debugPrint('🔍 No admins found with isAdmin: true, searching by email...');
        final adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
        
        for (String email in adminEmails) {
          final emailQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .get();
          
          if (emailQuery.docs.isNotEmpty) {
            debugPrint('👤 Found admin by email: $email');
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
      
      debugPrint('📊 Final admin count: ${adminUsers.docs.length}');
      
      final subscriptionTypeName = subscriptionType == 'business' ? 'עסקי מנוי' : 'פרטי מנוי';
      
      for (final adminDoc in adminUsers.docs) {
        final adminData = adminDoc.data();
        debugPrint('👤 Admin: ${adminData['email']} (${adminDoc.id})');
        
        // שליחת התראה מפורטת למנהל
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'toUserId': adminDoc.id,
          'title': 'בקשת תשלום במזומן חדשה! 💰',
          'message': 'משתמש $userName ($userEmail) הגיש בקשת תשלום במזומן עבור $subscriptionTypeName (₪$amount). טלפון: $phone',
          'type': 'cash_payment_request',
          'paymentRequestId': paymentRequestRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
        
        // שליחת push notification ישירה למנהל
        await _sendDirectPushNotification(
          adminDoc.id,
          'בקשת תשלום במזומן חדשה! 💰',
          'משתמש $userName ($userEmail) הגיש בקשת תשלום במזומן עבור $subscriptionTypeName (₪$amount). טלפון: $phone',
        );
        
        debugPrint('✅ Notification sent to admin: ${adminData['email']}');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error submitting cash payment request: $e');
      return false;
    }
  }
}
