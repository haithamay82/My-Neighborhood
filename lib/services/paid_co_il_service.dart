import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/paid_co_il_config.dart';

/// שירות לטיפול בתשלומים דרך Paid.co.il
class PaidCoIlService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: PaidCoIlConfig.baseUrl,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${PaidCoIlConfig.apiKey}',
    },
    connectTimeout: PaidCoIlConfig.apiTimeout,
    receiveTimeout: PaidCoIlConfig.apiTimeout,
  ));

  /// יצירת תשלום חדש
  static Future<PaidCoIlPaymentResponse> createPayment({
    required double amount,
    required String currency,
    required String description,
    required String customerEmail,
    String? customerPhone,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // בדיקה שההגדרות מוכנות
      if (!PaidCoIlConfig.isConfigured) {
        return PaidCoIlPaymentResponse(
          success: false,
          message: PaidCoIlConfig.configurationErrorMessage,
        );
      }

      debugPrint('💳 Creating Paid.co.il payment: ₪$amount');
      
      final paymentData = {
        'merchant_id': PaidCoIlConfig.merchantId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'customer': {
          'email': customerEmail,
          if (customerPhone != null) 'phone': customerPhone,
        },
        'return_url': PaidCoIlConfig.successUrl,
        'cancel_url': PaidCoIlConfig.cancelUrl,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _dio.post('/payments', data: paymentData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        debugPrint('✅ Payment created successfully: ${data['payment_id']}');
        
        return PaidCoIlPaymentResponse(
          success: true,
          paymentId: data['payment_id'],
          paymentUrl: data['payment_url'],
          status: data['status'],
          message: 'תשלום נוצר בהצלחה',
        );
      } else {
        debugPrint('❌ Payment creation failed: ${response.statusCode}');
        return PaidCoIlPaymentResponse(
          success: false,
          message: 'שגיאה ביצירת התשלום: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in createPayment: ${e.message}');
      return PaidCoIlPaymentResponse(
        success: false,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in createPayment: $e');
      return PaidCoIlPaymentResponse(
        success: false,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }

  /// בדיקת סטטוס תשלום
  static Future<PaidCoIlPaymentStatus> checkPaymentStatus(String paymentId) async {
    try {
      debugPrint('🔍 Checking payment status: $paymentId');
      
      final response = await _dio.get('/payments/$paymentId');
      
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('✅ Payment status retrieved: ${data['status']}');
        
        return PaidCoIlPaymentStatus(
          success: true,
          paymentId: data['payment_id'],
          status: data['status'],
          amount: data['amount'],
          currency: data['currency'],
          message: 'סטטוס התשלום נטען בהצלחה',
        );
      } else {
        debugPrint('❌ Failed to get payment status: ${response.statusCode}');
        return PaidCoIlPaymentStatus(
          success: false,
          message: 'שגיאה בקבלת סטטוס התשלום: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in checkPaymentStatus: ${e.message}');
      return PaidCoIlPaymentStatus(
        success: false,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in checkPaymentStatus: $e');
      return PaidCoIlPaymentStatus(
        success: false,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }

  /// קבלת רשימת תשלומים
  static Future<PaidCoIlPaymentsList> getPayments({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      debugPrint('📋 Getting payments list: page $page, limit $limit');
      
      final queryParams = {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      };

      final response = await _dio.get('/payments', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('✅ Payments list retrieved: ${data['payments']?.length ?? 0} payments');
        
        return PaidCoIlPaymentsList(
          success: true,
          payments: (data['payments'] as List?)
              ?.map((payment) => PaidCoIlPayment.fromJson(payment))
              .toList() ?? [],
          totalCount: data['total_count'] ?? 0,
          currentPage: data['current_page'] ?? 1,
          totalPages: data['total_pages'] ?? 1,
          message: 'רשימת התשלומים נטענה בהצלחה',
        );
      } else {
        debugPrint('❌ Failed to get payments list: ${response.statusCode}');
        return PaidCoIlPaymentsList(
          success: false,
          payments: [],
          totalCount: 0,
          currentPage: 1,
          totalPages: 1,
          message: 'שגיאה בקבלת רשימת התשלומים: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException in getPayments: ${e.message}');
      return PaidCoIlPaymentsList(
        success: false,
        payments: [],
        totalCount: 0,
        currentPage: 1,
        totalPages: 1,
        message: 'שגיאת רשת: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error in getPayments: $e');
      return PaidCoIlPaymentsList(
        success: false,
        payments: [],
        totalCount: 0,
        currentPage: 1,
        totalPages: 1,
        message: 'שגיאה לא צפויה: $e',
      );
    }
  }
}

/// תגובת יצירת תשלום
class PaidCoIlPaymentResponse {
  final bool success;
  final String? paymentId;
  final String? paymentUrl;
  final String? status;
  final String message;

  PaidCoIlPaymentResponse({
    required this.success,
    this.paymentId,
    this.paymentUrl,
    this.status,
    required this.message,
  });
}

/// סטטוס תשלום
class PaidCoIlPaymentStatus {
  final bool success;
  final String? paymentId;
  final String? status;
  final double? amount;
  final String? currency;
  final String message;

  PaidCoIlPaymentStatus({
    required this.success,
    this.paymentId,
    this.status,
    this.amount,
    this.currency,
    required this.message,
  });
}

/// רשימת תשלומים
class PaidCoIlPaymentsList {
  final bool success;
  final List<PaidCoIlPayment> payments;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final String message;

  PaidCoIlPaymentsList({
    required this.success,
    required this.payments,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.message,
  });
}

/// תשלום בודד
class PaidCoIlPayment {
  final String paymentId;
  final String status;
  final double amount;
  final String currency;
  final String description;
  final String customerEmail;
  final String? customerPhone;
  final DateTime createdAt;
  final DateTime? paidAt;
  final Map<String, dynamic>? metadata;

  PaidCoIlPayment({
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.description,
    required this.customerEmail,
    this.customerPhone,
    required this.createdAt,
    this.paidAt,
    this.metadata,
  });

  factory PaidCoIlPayment.fromJson(Map<String, dynamic> json) {
    return PaidCoIlPayment(
      paymentId: json['payment_id'] ?? '',
      status: json['status'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'ILS',
      description: json['description'] ?? '',
      customerEmail: json['customer']?['email'] ?? '',
      customerPhone: json['customer']?['phone'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
      metadata: json['metadata'],
    );
  }
}
