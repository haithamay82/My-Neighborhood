import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/payme_config.dart';

/// PayMe Payment Service
/// 
/// Handles payment creation and checkout flow using PayMe API
class PayMePaymentService {
  static Dio? _dio;
  
  static Dio get _httpClient {
    _dio ??= Dio(BaseOptions(
      baseUrl: PayMeConfig.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${PayMeConfig.apiKey}',
      },
      connectTimeout: PayMeConfig.apiTimeout,
      receiveTimeout: PayMeConfig.apiTimeout,
    ));
    return _dio!;
  }
  
  /// Create a PayMe payment sale
  /// 
  /// Returns the sale URL that should be opened for checkout
  static Future<PayMePaymentResult> createPayment({
    required String userId,
    required double amount,
    required String productName,
    String? transactionId,
    List<String>? businessCategories,
  }) async {
    try {
      // Validate configuration
      if (!PayMeConfig.isConfigured) {
        debugPrint('❌ PayMe not configured');
        return PayMePaymentResult(
          success: false,
          error: PayMeConfig.configurationErrorMessage,
        );
      }
      
      // Generate unique transaction ID if not provided
      final txId = transactionId ?? 'tx_${DateTime.now().millisecondsSinceEpoch}_$userId';
      
      // Convert amount to agorot (multiply by 100)
      final amountInAgorot = PayMeConfig.shekelsToAgorot(amount);
      
      debugPrint('💳 Creating PayMe payment:');
      debugPrint('   - Amount: ₪$amount ($amountInAgorot agorot)');
      debugPrint('   - Product: $productName');
      debugPrint('   - Transaction ID: $txId');
      
      // Prepare request body
      final requestBody = {
        'seller_payme_id': PayMeConfig.sellerPaymeId,
        'sale_price': amountInAgorot,
        'currency': PayMeConfig.currency,
        'product_name': productName,
        'transaction_id': txId,
        'sale_payment_method': 'multi', // Critical: allows user to choose Bit or credit card
        'sale_callback_url': PayMeConfig.callbackUrl,
        'sale_return_url': PayMeConfig.returnUrl,
        'language': PayMeConfig.language,
      };
      
      debugPrint('📤 Sending request to: ${PayMeConfig.baseUrl}${PayMeConfig.generateSaleEndpoint}');
      
      // Send API request
      final response = await _httpClient.post(
        PayMeConfig.generateSaleEndpoint,
        data: requestBody,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final saleUrl = data['sale_url'] as String?;
        final saleId = data['sale_id'] as String?;
        
        if (saleUrl == null || saleUrl.isEmpty) {
          debugPrint('❌ PayMe response missing sale_url');
          return PayMePaymentResult(
            success: false,
            error: 'PayMe response missing sale_url',
          );
        }
        
        debugPrint('✅ PayMe payment created successfully');
        debugPrint('   - Sale ID: $saleId');
        debugPrint('   - Sale URL: $saleUrl');
        
        // Save payment to Firestore
        await _savePaymentToFirestore(
          transactionId: txId,
          userId: userId,
          amount: amount,
          productName: productName,
          saleId: saleId ?? txId,
          saleUrl: saleUrl,
          status: 'pending',
          businessCategories: businessCategories,
        );
        
        return PayMePaymentResult(
          success: true,
          transactionId: txId,
          saleId: saleId ?? txId,
          saleUrl: saleUrl,
        );
      } else {
        debugPrint('❌ PayMe API error: ${response.statusCode}');
        debugPrint('   Response: ${response.data}');
        return PayMePaymentResult(
          success: false,
          error: 'PayMe API error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in createPayment: ${e.message}');
      debugPrint('   Status code: ${e.response?.statusCode}');
      debugPrint('   Response data: ${e.response?.data}');
      return PayMePaymentResult(
        success: false,
        error: 'Network error: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in createPayment: $e');
      return PayMePaymentResult(
        success: false,
        error: 'Unexpected error: $e',
      );
    }
  }
  
  /// Open PayMe checkout page
  /// 
  /// Opens the sale URL in external browser/app
  static Future<bool> openCheckout(String saleUrl) async {
    try {
      debugPrint('🔗 Opening PayMe checkout: $saleUrl');
      
      final uri = Uri.parse(saleUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        debugPrint('✅ Checkout page opened successfully');
      } else {
        debugPrint('❌ Failed to open checkout page');
      }
      
      return launched;
    } catch (e) {
      debugPrint('❌ Error opening checkout: $e');
      return false;
    }
  }
  
  /// Update payment status in Firestore
  static Future<void> updatePaymentStatus({
    required String transactionId,
    required String status,
    String? paymeSaleId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (paymeSaleId != null) {
        updateData['payme_sale_id'] = paymeSaleId;
      }
      
      if (additionalData != null) {
        updateData.addAll(additionalData);
      }
      
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(transactionId)
          .update(updateData);
      
      debugPrint('✅ Payment status updated: $transactionId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating payment status: $e');
    }
  }
  
  /// Save payment to Firestore
  static Future<void> _savePaymentToFirestore({
    required String transactionId,
    required String userId,
    required double amount,
    required String productName,
    required String saleId,
    required String saleUrl,
    required String status,
    List<String>? businessCategories,
  }) async {
    try {
      final paymentData = {
        'userId': userId,
        'amount': amount,
        'status': status,
        'payme_sale_id': saleId,
        'payme_sale_url': saleUrl,
        'productName': productName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // הוספת קטגוריות עסקיות אם יש
      if (businessCategories != null && businessCategories.isNotEmpty) {
        paymentData['businessCategories'] = businessCategories;
        debugPrint('✅ Added business categories to payment: $businessCategories');
      }
      
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(transactionId)
          .set(paymentData);
      
      debugPrint('✅ Payment saved to Firestore: $transactionId');
    } catch (e) {
      debugPrint('❌ Error saving payment to Firestore: $e');
    }
  }
  
  /// Get payment from Firestore
  static Future<Map<String, dynamic>?> getPayment(String transactionId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(transactionId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting payment: $e');
      return null;
    }
  }
  
  /// Create subscription payment
  /// 
  /// This is the main function to call from UI to create a subscription payment.
  /// It creates a PayMe sale and opens the checkout page.
  /// 
  /// Usage:
  /// ```dart
  /// final result = await PayMePaymentService.createSubscriptionPayment(
  ///   subscriptionType: 'personal', // or 'business'
  /// );
  /// 
  /// if (result.success && result.saleUrl != null) {
  ///   await PayMePaymentService.openCheckout(result.saleUrl!);
  /// }
  /// ```
  static Future<PayMePaymentResult> createSubscriptionPayment({
    required String subscriptionType,
    List<String>? businessCategories,
  }) async {
    try {
      // Get current Firebase user
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      
      if (user == null) {
        debugPrint('❌ No authenticated user');
        return PayMePaymentResult(
          success: false,
          error: 'User not authenticated',
        );
      }
      
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      final userName = userData?['name'] as String? ?? user.displayName ?? 'משתמש';
      final userEmail = user.email ?? '';
      
      // Get subscription amount
      final amount = PayMeConfig.getSubscriptionAmount(subscriptionType);
      final typeName = subscriptionType == 'business' ? 'עסקי' : 'פרטי';
      final productName = 'מנוי $typeName שכונתי - ₪$amount';
      
      debugPrint('💰 Creating subscription payment:');
      debugPrint('   - Type: $typeName');
      debugPrint('   - Amount: ₪$amount');
      debugPrint('   - User: $userName ($userEmail)');
      
      // Create payment
      final result = await createPayment(
        userId: user.uid,
        amount: amount,
        productName: productName,
        businessCategories: businessCategories,
      );
      
      if (result.success && result.saleUrl != null) {
        // Open checkout page
        final opened = await openCheckout(result.saleUrl!);
        if (!opened) {
          debugPrint('⚠️ Payment created but checkout page failed to open');
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Error in createSubscriptionPayment: $e');
      return PayMePaymentResult(
        success: false,
        error: 'Error creating subscription payment: $e',
      );
    }
  }
}

/// PayMe Payment Result
class PayMePaymentResult {
  final bool success;
  final String? transactionId;
  final String? saleId;
  final String? saleUrl;
  final String? error;
  
  PayMePaymentResult({
    required this.success,
    this.transactionId,
    this.saleId,
    this.saleUrl,
    this.error,
  });
}

