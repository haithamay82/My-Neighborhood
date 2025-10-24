import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/bit_config.dart';

class BitPaymentService {
  
  /// יצירת תשלום BIT חדש
  static Future<Map<String, dynamic>?> createPayment({
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    try {
      // יצירת מזהה תשלום ייחודי
      final paymentId = 'sub_${DateTime.now().millisecondsSinceEpoch}_$userId';
      
      // בדיקת הגדרות BIT
      if (!BitConfig.isConfigured) {
        print('BIT configuration error: ${BitConfig.configurationError}');
        // מצב DEMO - נדמה תשלום מוצלח
        return _createDemoPayment(paymentId);
      }
      
      // פרטי התשלום
      final paymentData = {
        'merchant_id': BitConfig.merchantId,
        'amount': BitConfig.subscriptionAmount,
        'currency': BitConfig.currency,
        'description': BitConfig.paymentDescription,
        'order_id': paymentId,
        'customer': {
          'email': userEmail,
          'name': userName,
        },
        'success_url': BitConfig.successUrl,
        'cancel_url': BitConfig.cancelUrl,
        'webhook_url': BitConfig.webhookUrl,
      };
      
      // שליחת בקשה ל-BIT API
      final response = await http.post(
        Uri.parse('${BitConfig.baseUrl}/v1/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${BitConfig.apiKey}',
        },
        body: json.encode(paymentData),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // שמירת פרטי התשלום ב-Firestore
        await _savePaymentDetails(userId, paymentId, responseData);
        
        return responseData;
      } else {
        print('BIT Payment Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('BIT Payment Exception: $e');
      return null;
    }
  }
  
  /// פתיחת דף התשלום של BIT בדפדפן
  static Future<bool> openPaymentPage(String paymentUrl) async {
    try {
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('Error opening payment page: $e');
      return false;
    }
  }
  
  /// בדיקת סטטוס תשלום
  static Future<Map<String, dynamic>?> checkPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('${BitConfig.baseUrl}/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer ${BitConfig.apiKey}',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error checking payment status: $e');
      return null;
    }
  }
  
  /// שמירת פרטי התשלום ב-Firestore
  static Future<void> _savePaymentDetails(
    String userId,
    String paymentId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .set({
        'userId': userId,
        'paymentId': paymentId,
        'amount': BitConfig.subscriptionAmount,
        'currency': BitConfig.currency,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'bitPaymentId': paymentData['id'],
        'paymentUrl': paymentData['payment_url'],
        'type': 'subscription',
      });
    } catch (e) {
      print('Error saving payment details: $e');
    }
  }
  
  /// עדכון סטטוס תשלום (נקרא מ-webhook)
  static Future<void> updatePaymentStatus(
    String paymentId,
    String status,
  ) async {
    try {
      // עדכון סטטוס התשלום
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
      
      // אם התשלום הצליח, הפעל את המנוי
      if (status == 'completed') {
        await _activateSubscription(paymentId);
      }
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }
  
  /// הפעלת מנוי לאחר תשלום מוצלח
  static Future<void> _activateSubscription(String paymentId) async {
    try {
      // קבלת פרטי התשלום
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .get();
      
      if (paymentDoc.exists) {
        final paymentData = paymentDoc.data()!;
        final userId = paymentData['userId'] as String;
        
        // חישוב תאריך פג תוקף המנוי (שנה מהיום)
        final subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
        
        // עדכון פרופיל המשתמש
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'isSubscriptionActive': true,
          'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
          'lastPaymentId': paymentId,
        });
        
        print('Subscription activated for user: $userId');
      }
    } catch (e) {
      print('Error activating subscription: $e');
    }
  }
  
  /// יצירת תשלום מנוי למשתמש נוכחי
  static Future<bool> createSubscriptionPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // קבלת פרטי המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] ?? user.email ?? '';
      final userName = userData['displayName'] ?? user.displayName ?? 'משתמש';
      
      // יצירת התשלום
      final paymentData = await createPayment(
        userId: user.uid,
        userEmail: userEmail,
        userName: userName,
      );
      
      if (paymentData != null && paymentData['payment_url'] != null) {
        // פתיחת דף התשלום
        return await openPaymentPage(paymentData['payment_url']);
      }
      
      return false;
    } catch (e) {
      print('Error creating subscription payment: $e');
      return false;
    }
  }
  
  /// בדיקת מנוי פעיל
  static Future<bool> isSubscriptionActive(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final isActive = userData['isSubscriptionActive'] as bool? ?? false;
      final expiryDate = userData['subscriptionExpiry'] as Timestamp?;
      
      if (!isActive || expiryDate == null) return false;
      
      // בדיקה שהמנוי לא פג תוקף
      final now = DateTime.now();
      final expiry = expiryDate.toDate();
      
      return now.isBefore(expiry);
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }
  
  /// יצירת תשלום DEMO (לבדיקות)
  static Map<String, dynamic> _createDemoPayment(String paymentId) {
    return {
      'id': 'demo_${DateTime.now().millisecondsSinceEpoch}',
      'payment_url': 'https://demo.bit.co.il/payment/$paymentId',
      'status': 'pending',
      'amount': BitConfig.subscriptionAmount,
      'currency': BitConfig.currency,
      'demo': true,
    };
  }
  
  /// סימולציה של תשלום מוצלח (למצב DEMO)
  static Future<void> simulateSuccessfulPayment(String userId) async {
    try {
      // הפעלת המנוי ישירות (ללא תשלום אמיתי)
      final subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isSubscriptionActive': true,
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'demoPayment': true,
      });
      
      print('Demo subscription activated for user: $userId');
    } catch (e) {
      print('Error activating demo subscription: $e');
    }
  }
}
