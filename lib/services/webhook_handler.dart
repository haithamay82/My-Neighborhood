import 'package:cloud_firestore/cloud_firestore.dart';
import 'bit_payment_service.dart';

class WebhookHandler {
  /// עיבוד webhook מ-BIT
  static Future<Map<String, dynamic>> handleBitWebhook(Map<String, dynamic> data) async {
    try {
      // קבלת פרטי התשלום מה-webhook
      final paymentId = data['order_id'] as String?;
      final bitPaymentId = data['payment_id'] as String?;
      final status = data['status'] as String?;
      final amount = data['amount'] as double?;
      
      if (paymentId == null || status == null) {
        return {'error': 'Missing required fields'};
      }
      
      // עדכון סטטוס התשלום
      await BitPaymentService.updatePaymentStatus(paymentId, status);
      
      // לוג של התשלום
      await _logPayment(paymentId, bitPaymentId, status, amount);
      
      return {'success': true, 'message': 'Webhook processed successfully'};
      
    } catch (e) {
      print('Webhook processing error: $e');
      return {'error': 'Internal server error'};
    }
  }
  
  /// שמירת לוג התשלום
  static Future<void> _logPayment(
    String paymentId,
    String? bitPaymentId,
    String status,
    double? amount,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_logs')
          .add({
        'paymentId': paymentId,
        'bitPaymentId': bitPaymentId,
        'status': status,
        'amount': amount,
        'timestamp': Timestamp.now(),
        'processed': true,
      });
    } catch (e) {
      print('Error logging payment: $e');
    }
  }
  
  /// בדיקת תשלומים ממתינים
  static Future<void> checkPendingPayments() async {
    try {
      // קבלת כל התשלומים הממתינים
      final pendingPayments = await FirebaseFirestore.instance
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5))
          ))
          .get();
      
      for (final doc in pendingPayments.docs) {
        final paymentData = doc.data();
        final paymentId = paymentData['bitPaymentId'] as String?;
        
        if (paymentId != null) {
          // בדיקת סטטוס התשלום ב-BIT
          final status = await BitPaymentService.checkPaymentStatus(paymentId);
          
          if (status != null) {
            final newStatus = status['status'] as String?;
            if (newStatus != null && newStatus != 'pending') {
              await BitPaymentService.updatePaymentStatus(
                doc.id,
                newStatus,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }
}
