import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/payme_config.dart';
import 'notification_service.dart';
import '../models/request.dart';

/// שירות לטיפול בתשלומים דרך PayMe
class PayMeService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: PayMeConfig.baseUrl,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${PayMeConfig.apiKey}',
    },
    connectTimeout: PayMeConfig.apiTimeout,
    receiveTimeout: PayMeConfig.apiTimeout,
  ));

  /// יצירת תשלום BIT
  static Future<PayMePaymentResponse> createBitPayment({
    required String subscriptionType,
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      if (!PayMeConfig.isConfigured) {
        return PayMePaymentResponse(
          success: false,
          message: PayMeConfig.configurationErrorMessage,
        );
      }

      final amount = PayMeConfig.getSubscriptionAmount(subscriptionType);
      final typeName = subscriptionType == 'business' ? 'עסקי' : 'פרטי';
      
      debugPrint('💳 Creating PayMe BIT payment: ₪$amount for $typeName subscription');
      
      final paymentData = {
        'merchant_id': PayMeConfig.merchantId,
        'amount': amount,
        'currency': 'ILS',
        'description': 'מנוי $typeName שכונתי - ₪$amount',
        'payment_method': 'bit',
        'customer': {
          'email': userEmail,
          'name': userName,
        },
        'metadata': {
          'subscription_type': subscriptionType,
          'user_id': userId,
          'app_version': '1.0.0',
        },
        'return_url': PayMeConfig.successUrl,
        'cancel_url': PayMeConfig.cancelUrl,
        'webhook_url': PayMeConfig.webhookUrl,
      };

      final response = await _dio.post('/payments', data: paymentData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        debugPrint('✅ PayMe BIT payment created successfully: ${data['payment_id']}');
        
        // שמירת פרטי התשלום ב-Firestore
        await _savePaymentToFirestore(
          paymentId: data['payment_id'],
          userId: userId,
          userEmail: userEmail,
          userName: userName,
          subscriptionType: subscriptionType,
          amount: amount,
          paymentMethod: 'bit',
          status: 'pending',
        );
        
        return PayMePaymentResponse(
          success: true,
          paymentId: data['payment_id'],
          paymentUrl: data['payment_url'],
          status: data['status'],
          message: 'תשלום BIT נוצר בהצלחה',
        );
      } else {
        debugPrint('❌ PayMe BIT payment creation failed: ${response.statusCode}');
        return PayMePaymentResponse(
          success: false,
          message: 'שגיאה ביצירת תשלום BIT: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in createBitPayment: ${e.message}');
      return PayMePaymentResponse(
        success: false,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in createBitPayment: $e');
      return PayMePaymentResponse(
        success: false,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }

  /// יצירת תשלום כרטיס אשראי
  static Future<PayMePaymentResponse> createCreditCardPayment({
    required String subscriptionType,
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      if (!PayMeConfig.isConfigured) {
        return PayMePaymentResponse(
          success: false,
          message: PayMeConfig.configurationErrorMessage,
        );
      }

      final amount = PayMeConfig.getSubscriptionAmount(subscriptionType);
      final typeName = subscriptionType == 'business' ? 'עסקי' : 'פרטי';
      
      debugPrint('💳 Creating PayMe Credit Card payment: ₪$amount for $typeName subscription');
      
      final paymentData = {
        'merchant_id': PayMeConfig.merchantId,
        'amount': amount,
        'currency': 'ILS',
        'description': 'מנוי $typeName שכונתי - ₪$amount',
        'payment_method': 'credit_card',
        'customer': {
          'email': userEmail,
          'name': userName,
        },
        'metadata': {
          'subscription_type': subscriptionType,
          'user_id': userId,
          'app_version': '1.0.0',
        },
        'return_url': PayMeConfig.successUrl,
        'cancel_url': PayMeConfig.cancelUrl,
        'webhook_url': PayMeConfig.webhookUrl,
      };

      final response = await _dio.post('/payments', data: paymentData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        debugPrint('✅ PayMe Credit Card payment created successfully: ${data['payment_id']}');
        
        // שמירת פרטי התשלום ב-Firestore
        await _savePaymentToFirestore(
          paymentId: data['payment_id'],
          userId: userId,
          userEmail: userEmail,
          userName: userName,
          subscriptionType: subscriptionType,
          amount: amount,
          paymentMethod: 'credit_card',
          status: 'pending',
        );
        
        return PayMePaymentResponse(
          success: true,
          paymentId: data['payment_id'],
          paymentUrl: data['payment_url'],
          status: data['status'],
          message: 'תשלום כרטיס אשראי נוצר בהצלחה',
        );
      } else {
        debugPrint('❌ PayMe Credit Card payment creation failed: ${response.statusCode}');
        return PayMePaymentResponse(
          success: false,
          message: 'שגיאה ביצירת תשלום כרטיס אשראי: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in createCreditCardPayment: ${e.message}');
      return PayMePaymentResponse(
        success: false,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in createCreditCardPayment: $e');
      return PayMePaymentResponse(
        success: false,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }

  /// בדיקת סטטוס תשלום
  static Future<PayMePaymentStatus> checkPaymentStatus(String paymentId) async {
    try {
      debugPrint('🔍 Checking PayMe payment status: $paymentId');
      
      final response = await _dio.get('/payments/$paymentId');
      
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('✅ PayMe payment status retrieved: ${data['status']}');
        
        return PayMePaymentStatus(
          success: true,
          paymentId: data['payment_id'],
          status: data['status'],
          amount: data['amount'],
          currency: data['currency'],
          message: 'סטטוס התשלום נטען בהצלחה',
        );
      } else {
        debugPrint('❌ Failed to get PayMe payment status: ${response.statusCode}');
        return PayMePaymentStatus(
          success: false,
          message: 'שגיאה בקבלת סטטוס התשלום: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in checkPaymentStatus: ${e.message}');
      return PayMePaymentStatus(
        success: false,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in checkPaymentStatus: $e');
      return PayMePaymentStatus(
        success: false,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }

  /// טיפול ב-webhook מאישור תשלום
  static Future<void> handlePaymentWebhook(Map<String, dynamic> webhookData) async {
    try {
      debugPrint('🔔 PayMe webhook received: $webhookData');
      
      final paymentId = webhookData['payment_id'] as String?;
      final status = webhookData['status'] as String?;
      final amount = (webhookData['amount'] as num?)?.toDouble();
      
      if (paymentId == null || status == null) {
        debugPrint('❌ Invalid webhook data');
        return;
      }

      // עדכון סטטוס התשלום ב-Firestore
      await FirebaseFirestore.instance
          .collection('payme_payments')
          .doc(paymentId)
          .update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        'webhook_received_at': FieldValue.serverTimestamp(),
      });

      // אם התשלום הצליח, הפעל את המנוי
      if (status == 'completed' || status == 'paid') {
        await _activateSubscription(paymentId, amount);
      }
      
    } catch (e) {
      debugPrint('❌ Error handling PayMe webhook: $e');
    }
  }

  /// שמירת פרטי תשלום ב-Firestore
  static Future<void> _savePaymentToFirestore({
    required String paymentId,
    required String userId,
    required String userEmail,
    required String userName,
    required String subscriptionType,
    required double amount,
    required String paymentMethod,
    required String status,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('payme_payments')
          .doc(paymentId)
          .set({
        'payment_id': paymentId,
        'user_id': userId,
        'user_email': userEmail,
        'user_name': userName,
        'subscription_type': subscriptionType,
        'amount': amount,
        'currency': 'ILS',
        'payment_method': paymentMethod,
        'status': status,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Payment saved to Firestore: $paymentId');
    } catch (e) {
      debugPrint('❌ Error saving payment to Firestore: $e');
    }
  }

  /// הפעלת מנוי לאחר תשלום מוצלח
  static Future<void> _activateSubscription(String paymentId, double? amount) async {
    try {
      debugPrint('🎉 Activating subscription for payment: $paymentId');
      
      // קבלת פרטי התשלום
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payme_payments')
          .doc(paymentId)
          .get();
      
      if (!paymentDoc.exists) {
        debugPrint('❌ Payment document not found: $paymentId');
        return;
      }
      
      final paymentData = paymentDoc.data()!;
      final userId = paymentData['user_id'] as String;
      final subscriptionType = paymentData['subscription_type'] as String;
      final userEmail = paymentData['user_email'] as String;
      final userName = paymentData['user_name'] as String;
      
      // הפעלת המנוי באמצעות ManualPaymentService
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
      
      // עדכון לפי סוג המנוי
      Map<String, dynamic> updateData = {
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedPaymentId': paymentId,
        'approvedAt': Timestamp.now(),
        'paymentMethod': 'payme',
      };
      
      if (subscriptionType == 'business') {
        debugPrint('✅ Setting user as BUSINESS subscription via PayMe');
        if (currentBusinessCategories.isEmpty) {
          currentBusinessCategories = RequestCategory.values.map((e) => e.name).toList();
        }
        updateData['userType'] = 'business';
        updateData['businessCategories'] = currentBusinessCategories;
      } else {
        debugPrint('✅ Setting user as PERSONAL subscription via PayMe');
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
              .update(updateData);
        }
      } catch (e) {
        debugPrint('Warning: Could not update user_profiles collection: $e');
      }
      
      // עדכון סטטוס התשלום
      await FirebaseFirestore.instance
          .collection('payme_payments')
          .doc(paymentId)
          .update({
        'status': 'completed',
        'subscription_activated': true,
        'activated_at': FieldValue.serverTimestamp(),
      });

      // שליחת התראות
      await _sendPaymentNotifications(userId, userEmail, userName, subscriptionType, amount);
      
      debugPrint('✅ Subscription activated successfully via PayMe');
      
    } catch (e) {
      debugPrint('❌ Error activating subscription: $e');
    }
  }

  /// שליחת התראות על תשלום מוצלח
  static Future<void> _sendPaymentNotifications(
    String userId,
    String userEmail,
    String userName,
    String subscriptionType,
    double? amount,
  ) async {
    try {
      final typeName = subscriptionType == 'business' ? 'עסקי' : 'פרטי';
      final amountText = amount != null ? '₪$amount' : '';
      
      // התראה למשתמש
      await NotificationService.sendNotification(
        toUserId: userId,
        title: 'תשלום אושר! 🎉',
        message: 'המנוי $typeName שלך הופעל בהצלחה $amountText',
        type: 'payment_success',
      );
      
      // התראה למנהלים
      final adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      for (final adminDoc in adminUsers.docs) {
        final adminId = adminDoc.id;
        await NotificationService.sendNotification(
          toUserId: adminId,
          title: 'תשלום חדש התקבל 💰',
          message: '$userName ($userEmail) שילם עבור מנוי $typeName $amountText',
          type: 'admin_payment_received',
        );
      }
      
      debugPrint('✅ Payment notifications sent successfully');
      
    } catch (e) {
      debugPrint('❌ Error sending payment notifications: $e');
    }
  }
}

/// תגובת יצירת תשלום PayMe
class PayMePaymentResponse {
  final bool success;
  final String? paymentId;
  final String? paymentUrl;
  final String? status;
  final String message;

  PayMePaymentResponse({
    required this.success,
    this.paymentId,
    this.paymentUrl,
    this.status,
    required this.message,
  });
}

/// סטטוס תשלום PayMe
class PayMePaymentStatus {
  final bool success;
  final String? paymentId;
  final String? status;
  final double? amount;
  final String? currency;
  final String message;

  PayMePaymentStatus({
    required this.success,
    this.paymentId,
    this.status,
    this.amount,
    this.currency,
    required this.message,
  });
}
