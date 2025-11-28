import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/payme_config.dart';
import 'payme_payment_service.dart';
import 'notification_service.dart';

/// PayMe Webhook Handler
/// 
/// Handles webhook callbacks from PayMe (x-www-form-urlencoded format)
class PayMeWebhookHandler {
  /// Process webhook callback from PayMe
  /// 
  /// Expected webhook data format (x-www-form-urlencoded):
  /// - transaction_id: The transaction ID we sent
  /// - sale_id: PayMe sale ID
  /// - status: Payment status (approved, declined, etc.)
  /// - amount: Payment amount
  /// - Additional fields as per PayMe documentation
  static Future<Map<String, dynamic>> processWebhook(
    Map<String, dynamic> webhookData,
  ) async {
    try {
      debugPrint('🔔 PayMe webhook received: $webhookData');
      
      // Extract webhook data (PayMe sends notify_type and sale_status)
      final transactionId = webhookData['transaction_id'] as String?;
      final saleId = webhookData['payme_sale_id'] as String? ?? webhookData['sale_id'] as String?;
      final notifyType = webhookData['notify_type'] as String?;
      final saleStatus = webhookData['sale_status'] as String?;
      final status = saleStatus ?? notifyType ?? webhookData['status'] as String?;
      // PayMe sends price in agorot (cents), so divide by 100 to get shekels
      final priceInAgorot = webhookData['price'];
      final amount = priceInAgorot != null 
          ? (priceInAgorot as num).toDouble() / 100.0
          : (webhookData['amount'] as num?)?.toDouble();
      
      // Validate required fields
      if (transactionId == null || transactionId.isEmpty) {
        debugPrint('❌ Webhook missing transaction_id');
        return {
          'success': false,
          'error': 'Missing transaction_id',
        };
      }
      
      if (notifyType == null && saleStatus == null && status == null) {
        debugPrint('❌ Webhook missing notify_type, sale_status, or status');
        return {
          'success': false,
          'error': 'Missing notify_type, sale_status, or status',
        };
      }
      
      debugPrint('📋 Processing webhook:');
      debugPrint('   - Transaction ID: $transactionId');
      debugPrint('   - Sale ID: $saleId');
      debugPrint('   - notify_type: $notifyType');
      debugPrint('   - sale_status: $saleStatus');
      debugPrint('   - status: $status');
      
      // Get payment from Firestore
      final payment = await PayMePaymentService.getPayment(transactionId);
      if (payment == null) {
        debugPrint('❌ Payment not found: $transactionId');
        return {
          'success': false,
          'error': 'Payment not found',
        };
      }
      
      final userId = payment['userId'] as String?;
      if (userId == null) {
        debugPrint('❌ Payment missing userId');
        return {
          'success': false,
          'error': 'Payment missing userId',
        };
      }
      
      // Normalize status based on PayMe callback format
      final normalizedStatus = _normalizeStatus(notifyType, saleStatus, status);
      
      // Update payment status
      await PayMePaymentService.updatePaymentStatus(
        transactionId: transactionId,
        status: normalizedStatus,
        paymeSaleId: saleId,
        additionalData: {
          'webhook_received_at': FieldValue.serverTimestamp(),
          'webhook_data': webhookData,
        },
      );
      
      // Handle successful payment
      if (_isPaymentSuccess(notifyType, saleStatus, status)) {
        debugPrint('✅ Payment successful, activating subscription');
        await _activateSubscription(
          userId: userId,
          transactionId: transactionId,
          amount: amount,
        );
      } else {
        debugPrint('⚠️ Payment status: $status (not activating subscription)');
      }
      
      return {
        'success': true,
        'message': 'Webhook processed successfully',
      };
    } catch (e) {
      debugPrint('❌ Error processing webhook: $e');
      return {
        'success': false,
        'error': 'Internal error: $e',
      };
    }
  }
  
  /// Normalize payment status based on PayMe callback format
  static String _normalizeStatus(String? notifyType, String? saleStatus, String? status) {
    // Check notify_type first (PayMe's primary indicator)
    if (notifyType != null) {
      final notifyTypeLower = notifyType.toLowerCase();
      if (notifyTypeLower == 'sale-complete' || notifyTypeLower == 'sale-authorized') {
        return 'completed';
      } else if (notifyTypeLower == 'sale-failure' || notifyTypeLower == 'refund') {
        return 'failed';
      }
    }
    
    // Check sale_status as fallback
    if (saleStatus != null) {
      final saleStatusLower = saleStatus.toLowerCase();
      if (saleStatusLower == 'completed' || saleStatusLower == 'authorized') {
        return 'completed';
      } else if (saleStatusLower == 'failed' || saleStatusLower == 'declined') {
        return 'failed';
      }
    }
    
    // Fallback to old status check
    if (status != null) {
      final normalized = status.toLowerCase();
      if (normalized.contains('approve') || 
          normalized.contains('success') || 
          normalized.contains('complete') || 
          normalized == 'paid') {
        return 'completed';
      } else if (normalized.contains('decline') || 
                 normalized.contains('fail') || 
                 normalized.contains('cancel')) {
        return 'failed';
      }
    }
    
    return 'pending';
  }
  
  /// Check if payment status indicates success
  static bool _isPaymentSuccess(String? notifyType, String? saleStatus, String? status) {
    // Check notify_type first
    if (notifyType != null) {
      final notifyTypeLower = notifyType.toLowerCase();
      if (notifyTypeLower == 'sale-complete' || notifyTypeLower == 'sale-authorized') {
        return true;
      } else if (notifyTypeLower == 'sale-failure') {
        return false;
      }
    }
    
    // Check sale_status
    if (saleStatus != null) {
      final saleStatusLower = saleStatus.toLowerCase();
      if (saleStatusLower == 'completed' || saleStatusLower == 'authorized') {
        return true;
      } else if (saleStatusLower == 'failed' || saleStatusLower == 'declined') {
        return false;
      }
    }
    
    // Fallback to old status check
    if (status != null) {
      final normalized = status.toLowerCase();
      return normalized.contains('approve') ||
             normalized.contains('success') ||
             normalized.contains('complete') ||
             normalized == 'paid';
    }
    
    return false;
  }
  
  /// Activate subscription after successful payment
  static Future<void> _activateSubscription({
    required String userId,
    required String transactionId,
    dynamic amount,
  }) async {
    try {
      debugPrint('🎉 Activating subscription for user: $userId');
      
      // Get payment details to determine subscription type
      final payment = await PayMePaymentService.getPayment(transactionId);
      if (payment == null) {
        debugPrint('❌ Payment not found for subscription activation');
        return;
      }
      
      final amountPaid = (payment['amount'] as num?)?.toDouble() ?? 0.0;
      
      // קבלת הקטגוריות מבקשת התשלום (אם יש)
      List<String> paymentRequestCategories = [];
      if (payment['businessCategories'] != null) {
        paymentRequestCategories = List<String>.from(payment['businessCategories']);
        debugPrint('📋 Found business categories in payment: $paymentRequestCategories');
      }
      
      // Determine subscription type based on amount
      // TODO: During testing (both prices are 1 ILS), check businessCategories to determine type
      // After testing, return to: amountPaid >= PayMeConfig.businessSubscriptionAmount
      final hasBusinessCategories = paymentRequestCategories.isNotEmpty;
      final subscriptionType = (amountPaid >= PayMeConfig.businessSubscriptionAmount || hasBusinessCategories)
          ? 'business'
          : 'personal';
      
      final subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
      
      // Get current user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      List<String> currentBusinessCategories = [];
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        currentBusinessCategories = List<String>.from(userData['businessCategories'] ?? []);
      }
      
      // Prepare update data
      final updateData = <String, dynamic>{
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry),
        'approvedPaymentId': transactionId,
        'approvedAt': Timestamp.now(),
        'paymentMethod': 'payme',
      };
      
      if (subscriptionType == 'business') {
        debugPrint('✅ Setting user as BUSINESS subscription');
        // אם יש קטגוריות בבקשת התשלום - השתמש בהן
        if (paymentRequestCategories.isNotEmpty) {
          currentBusinessCategories = paymentRequestCategories;
          debugPrint('✅ Using categories from payment: $currentBusinessCategories');
        } else if (currentBusinessCategories.isEmpty) {
          // רק אם אין קטגוריות בבקשת התשלום ואין קטגוריות קיימות - הוסף את כל הקטגוריות
          currentBusinessCategories = [
            'flooringAndCeramics', 'paintingAndPlaster', 'plumbing', 'electrical', 'carpentry',
            'roofsAndWalls', 'elevatorsAndStairs', 'carRepair', 'carServices', 'movingAndTransport',
            'ridesAndShuttles', 'bicyclesAndScooters', 'heavyVehicles', 'babysitting', 'privateLessons',
            'childrenActivities', 'childrenHealth', 'birthAndParenting', 'specialEducation',
            'officeServices', 'marketingAndAdvertising', 'consulting', 'businessEvents',
            'cleaningServices', 'security', 'paintingAndSculpture', 'handicrafts', 'music',
            'photography', 'design', 'performingArts', 'physiotherapy', 'yogaAndPilates',
            'nutrition', 'mentalHealth', 'alternativeMedicine', 'beautyAndCosmetics',
            'computersAndTechnology', 'electricalAndElectronics', 'internetAndCommunication',
            'appsAndDevelopment', 'smartSystems', 'medicalEquipment', 'privateLessonsEducation',
            'languages', 'professionalTraining', 'lifeSkills', 'higherEducation',
            'vocationalTraining', 'events', 'entertainment', 'sports', 'tourism',
            'partiesAndEvents', 'photographyAndVideo', 'gardening', 'environmentalCleaning',
            'cleaningServicesEnv', 'environmentalQuality'
          ];
          debugPrint('⚠️ No categories in payment, using all categories: $currentBusinessCategories');
        }
        updateData['userType'] = 'business';
        updateData['businessCategories'] = currentBusinessCategories;
      } else {
        debugPrint('✅ Setting user as PERSONAL subscription');
        updateData['userType'] = 'personal';
        updateData['businessCategories'] = FieldValue.delete();
      }
      
      // Remove guest trial fields if user was a guest
      final currentUserData = userDoc.data();
      final currentUserType = currentUserData?['userType'] as String?;
      if (currentUserType == 'guest') {
        debugPrint('🗑️ Removing guest trial fields for user: $userId');
        updateData['guestTrialStartDate'] = FieldValue.delete();
        updateData['guestTrialEndDate'] = FieldValue.delete();
      }
      
      // Update user profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
      
      // Update user_profiles collection if it exists
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
        debugPrint('⚠️ Warning: Could not update user_profiles collection: $e');
      }
      
      // Send notifications
      await _sendPaymentNotifications(
        userId: userId,
        subscriptionType: subscriptionType,
        amount: amountPaid,
      );
      
      debugPrint('✅ Subscription activated successfully');
    } catch (e) {
      debugPrint('❌ Error activating subscription: $e');
    }
  }
  
  /// Send payment success notifications
  static Future<void> _sendPaymentNotifications({
    required String userId,
    required String subscriptionType,
    required double amount,
  }) async {
    try {
      final typeName = subscriptionType == 'business' ? 'עסקי' : 'פרטי';
      final amountText = '₪$amount';
      
      // Get user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final userName = userDoc.data()?['name'] as String? ?? 'משתמש';
      final userEmail = userDoc.data()?['email'] as String? ?? '';
      
      // Notify user
      await NotificationService.sendNotification(
        toUserId: userId,
        title: 'תשלום אושר! 🎉',
        message: 'המנוי $typeName שלך הופעל בהצלחה $amountText',
        type: 'payment_success',
      );
      
      // Notify admins
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
      
      debugPrint('✅ Payment notifications sent');
    } catch (e) {
      debugPrint('❌ Error sending notifications: $e');
    }
  }
}

