import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:convert';
import '../services/manual_payment_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.manageCashPayments,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(
                icon: Icon(Icons.pending, size: 20),
                text: 'ממתינות',
              ),
              Tab(
                icon: Icon(Icons.check_circle, size: 20),
                text: 'אושרו',
              ),
              Tab(
                icon: Icon(Icons.cancel, size: 20),
                text: 'נדחו',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPaymentsList('pending', 'ממתינות לאישור'),
            _buildPaymentsList('approved', 'אושרו'),
            _buildPaymentsList('rejected', 'נדחו'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList(String status, String emptyMessage) {
    return StreamBuilder<QuerySnapshot>(
      stream: ManualPaymentService.getAllPayments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'שגיאה: ${snapshot.error}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'טוען $emptyMessage...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final payments = snapshot.data!.docs;

        // סינון לפי סטטוס
        final filteredPayments = payments.where((payment) {
          final data = payment.data() as Map<String, dynamic>;
          final paymentStatus = data['status'] as String?;
          return paymentStatus == status;
        }).toList();
        
        // מיון לפי תאריך יצירה (החדשות ביותר בראש)
        final sortedPayments = filteredPayments
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreatedAt = aData['createdAt'] as Timestamp?;
            final bCreatedAt = bData['createdAt'] as Timestamp?;
            
            if (aCreatedAt == null && bCreatedAt == null) return 0;
            if (aCreatedAt == null) return 1;
            if (bCreatedAt == null) return -1;
            
            return bCreatedAt.compareTo(aCreatedAt); // מיון יורד (חדש לישן)
          });

        if (sortedPayments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 64,
                  color: _getStatusColor(status).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'אין בקשות $emptyMessage',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusDescription(status),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedPayments.length,
          itemBuilder: (context, index) {
            final payment = sortedPayments[index];
            final data = payment.data() as Map<String, dynamic>;
            
            return _buildPaymentCard(context, payment.id, data);
          },
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'כל הבקשות ממתינות לאישור המנהל';
      case 'approved':
        return 'כל הבקשות שאושרו והמנוי הופעל';
      case 'rejected':
        return 'כל הבקשות שנדחו על ידי המנהל';
      default:
        return '';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'ממתין לאישור';
      case 'approved':
        return 'אושר';
      case 'rejected':
        return 'נדחה';
      default:
        return 'לא ידוע';
    }
  }

  Widget _buildPaymentCard(BuildContext context, String paymentId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['userName'] ?? 'משתמש',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final status = data['status'] as String? ?? 'unknown';
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(status).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 16,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildInfoRow('אימייל:', data['userEmail'] ?? ''),
            if (data['phone'] != null && data['phone'].toString().isNotEmpty)
              _buildInfoRow('טלפון:', data['phone'] ?? ''),
            _buildInfoRow('סכום:', '${data['amount']} ${data['currency'] ?? 'ILS'}'),
            _buildInfoRow('סוג מנוי:', _getSubscriptionTypeText(data['subscriptionType'])),
            if (data['paymentMethod'] != 'cash')
              _buildInfoRow('מספר BIT:', '0506505599'),
            if (data['paymentMethod'] == 'cash')
              _buildInfoRow('אמצעי תשלום:', 'מזומן'),
            _buildInfoRow('תאריך:', _formatDate(data['createdAt'])),
            
            if (data['note'] != null && data['note'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'הערה: ${data['note']}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // תמונת התשלום
            if (data['imageUrl'] != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildPaymentProofImage(data['imageUrl']),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // הצגת סיבת הדחייה אם הבקשה נדחית
            if (data['status'] == 'rejected' && data['rejectionReason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'סיבת הדחייה:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['rejectionReason'],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // כפתורי פעולה (רק לבקשות ממתינות)
            if (data['status'] == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approvePayment(context, paymentId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('אשר'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectPayment(context, paymentId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('דחה'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (data['status'] == 'approved') ...[
              // הודעה לבקשה שאושרה
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'בקשה זו אושרה והמנוי הופעל בהצלחה',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (data['status'] == 'rejected') ...[
              // הודעה לבקשה נדחית
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'בקשה זו נדחתה ולא ניתן לפעול עליה',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'לא ידוע';
    
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'לא ידוע';
    }
  }

  String _getSubscriptionTypeText(String? subscriptionType) {
    switch (subscriptionType) {
      case 'business':
        return 'עסקי מנוי (70₪/שנה)';
      case 'personal':
        return 'פרטי מנוי (30₪/שנה)';
      default:
        return 'לא זמין';
    }
  }

  Widget _buildPaymentProofImage(dynamic paymentProof) {
    try {
      if (paymentProof == null) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
              SizedBox(height: 8),
              Text('אין תמונה זמינה'),
            ],
          ),
        );
      }

      final proofString = paymentProof.toString();
      
      // בדיקה אם זה URL של Firebase Storage או HTTP
      if (proofString.startsWith('https://firebasestorage.googleapis.com') || 
          proofString.startsWith('http://') || 
          proofString.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: proofString,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('טוען תמונה...'),
                ],
              ),
          ),
          errorWidget: (context, url, error) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  const Text('שגיאה בטעינת התמונה'),
                  const SizedBox(height: 4),
                  Text(
                    'URL: ${proofString.substring(0, 50)}...',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // רענון התמונה
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('נסה שוב'),
                  ),
                ],
            ),
              ),
        );
      }
      
      // בדיקה אם זה Base64 (הפורמט הנוכחי)
      if (proofString.length > 100 && 
          (proofString.contains('/') || proofString.contains('+') || proofString.contains('='))) {
        try {
          final bytes = base64Decode(proofString);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    const Text('שגיאה בטעינת התמונה'),
                    const SizedBox(height: 4),
                    Text(
                      'Base64 Error: $error',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // רענון התמונה
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('נסה שוב'),
                    ),
                  ],
                ),
              );
            },
          );
        } catch (base64Error) {
          // אם Base64 נכשל, נמשיך לבדיקות הבאות
        }
      }
      
      // בדיקה אם זה נתיב קובץ (נתונים ישנים)
      if (proofString.startsWith('/')) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 48),
              SizedBox(height: 8),
              Text('תמונה לא זמינה'),
              Text(
                'נתונים ישנים - נדרש העלאה מחדש',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }
      
      // אם הגענו לכאן, זה פורמט לא מוכר
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help, color: Colors.blue, size: 48),
            const SizedBox(height: 8),
            const Text('פורמט תמונה לא מוכר'),
            const SizedBox(height: 4),
            Text(
              'Data: ${proofString.substring(0, 50)}...',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text('שגיאה בעיבוד התמונה'),
            const SizedBox(height: 4),
            Text(
              'Error: $e',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Future<void> _approvePayment(BuildContext context, String paymentId) async {
    try {
      // קבלת פרטי המשתמש לפני האישור
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_requests')
          .doc(paymentId)
          .get();
      
      // Guard context usage after async gap - check context.mounted for parameter context
      if (!context.mounted) return;
      
      if (!paymentDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('בקשת התשלום לא נמצאה'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final paymentData = paymentDoc.data()!;
      final userId = paymentData['userId'] as String;
      final userName = paymentData['userName'] as String? ?? 'משתמש';
      final subscriptionType = paymentData['subscriptionType'] as String?;
      final paymentMethod = paymentData['paymentMethod'] as String?;
      
      final success = await ManualPaymentService.approvePayment(paymentId);
      
      if (success) {
        // שליחת התראה למשתמש
        await NotificationService.sendSubscriptionApprovalNotification(
          userId: userId,
          approved: true,
          userName: userName,
          subscriptionType: subscriptionType,
          paymentMethod: paymentMethod,
        );
        
        // Guard context usage after async gap - check context.mounted for parameter context
        if (!context.mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התשלום אושר והמנוי הופעל'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Guard context usage after async gap - check context.mounted for parameter context
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה באישור התשלום'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Guard context usage after async gap - check context.mounted for parameter context
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPayment(BuildContext context, String paymentId) async {
    debugPrint('🚫 _rejectPayment called for paymentId: $paymentId');
    debugPrint('⏰ _rejectPayment start time: ${DateTime.now()}');
    final TextEditingController reasonController = TextEditingController();
    
    debugPrint('📋 About to show dialog...');
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        debugPrint('🔨 Dialog builder called');
        return AlertDialog(
        title: const Text('דחיית תשלום'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'סיבת הדחייה',
            hintText: 'הזן סיבה לדחיית התשלום...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              final reasonText = reasonController.text.trim();
              debugPrint('🔘 Reject button pressed, reason: "$reasonText"');
              if (reasonText.isEmpty) {
                debugPrint('⚠️ Rejection reason is empty, showing error');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('אנא הזן סיבת דחייה'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              debugPrint('✅ About to pop dialog with reason: "$reasonText"');
              Navigator.pop(context, reasonText);
              debugPrint('✅ Dialog popped');
            },
            child: const Text('דחה'),
          ),
        ],
      );
      },
    );
    
    debugPrint('⏰ Dialog closed at: ${DateTime.now()}');
    debugPrint('🔍 Dialog returned reason: $reason (isNull: ${reason == null}, isEmpty: ${reason?.isEmpty ?? true})');
    
    if (reason != null && reason.isNotEmpty) {
      debugPrint('✅ Rejection reason provided: $reason');
      try {
        // קבלת פרטי המשתמש לפני הדחייה
        debugPrint('📋 Fetching payment request: $paymentId');
        debugPrint('⏳ About to call Firestore get()...');
        debugPrint('⏰ Current time: ${DateTime.now()}');
        
        DocumentSnapshot paymentDoc;
        try {
          debugPrint('🔄 Starting Firestore get() call...');
          paymentDoc = await FirebaseFirestore.instance
              .collection('payment_requests')
              .doc(paymentId)
              .get()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⏱️ Firestore get() timed out after 10 seconds');
                  throw TimeoutException('Firestore get() timed out', const Duration(seconds: 10));
                },
              );
          debugPrint('✅ Firestore get() completed at ${DateTime.now()}');
        } catch (firestoreError, stackTrace) {
          debugPrint('❌ ERROR in Firestore get(): $firestoreError');
          debugPrint('❌ Error type: ${firestoreError.runtimeType}');
          debugPrint('❌ Stack trace: $stackTrace');
          if (!context.mounted) {
            debugPrint('⚠️ Context not mounted after error, returning');
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בטעינת בקשת התשלום: $firestoreError'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        debugPrint('📄 Payment document fetched: exists=${paymentDoc.exists}');
        
        // Guard context usage after async gap
        if (!context.mounted) {
          debugPrint('⚠️ Context not mounted, returning');
          return;
        }
        
        debugPrint('✅ Context is still mounted');
        
        if (!paymentDoc.exists) {
          debugPrint('❌ Payment request not found: $paymentId');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('בקשת התשלום לא נמצאה'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        debugPrint('✅ Payment document exists, extracting data...');
        final paymentData = paymentDoc.data()! as Map<String, dynamic>;
        debugPrint('📊 Payment data keys: ${paymentData.keys.toList()}');
        
        final userId = paymentData['userId'] as String?;
        final userName = paymentData['userName'] as String? ?? 'משתמש';
        final subscriptionType = paymentData['subscriptionType'] as String?;
        final paymentMethod = paymentData['paymentMethod'] as String?;
        
        debugPrint('👤 Payment request data: userId=$userId, userName=$userName, subscriptionType=$subscriptionType, paymentMethod=$paymentMethod');
        
        if (userId == null || userId.isEmpty) {
          debugPrint('❌ userId is null or empty!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה: לא נמצא userId בבקשת התשלום'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        debugPrint('🔄 Calling ManualPaymentService.rejectPayment...');
        final success = await ManualPaymentService.rejectPayment(paymentId, reason);
        debugPrint('💰 ManualPaymentService.rejectPayment returned: $success');
        
        // Guard context usage after async gap
        debugPrint('🔍 Checking if context is still mounted...');
        if (!context.mounted) {
          debugPrint('⚠️ Context not mounted after rejectPayment, returning');
          return;
        }
        debugPrint('✅ Context is still mounted after rejectPayment');
        
        debugPrint('🔍 Checking if success is true: $success');
        if (success) {
          debugPrint('✅ Success is true, proceeding to send notification');
          debugPrint('💰 Payment rejected successfully, now sending notification to user: $userId');
          // שליחת התראה למשתמש עם סיבת הדחייה
          try {
            debugPrint('📤 Calling sendSubscriptionApprovalNotification with: userId=$userId, userName=$userName, reason=$reason, subscriptionType=$subscriptionType, paymentMethod=$paymentMethod');
            await NotificationService.sendSubscriptionApprovalNotification(
              userId: userId,
              approved: false,
              userName: userName,
              rejectionReason: reason,
              subscriptionType: subscriptionType,
              paymentMethod: paymentMethod,
            );
            debugPrint('✅ Rejection notification sent successfully to user: $userId');
          } catch (notificationError, stackTrace) {
            debugPrint('⚠️ Error sending rejection notification: $notificationError');
            debugPrint('⚠️ Stack trace: $stackTrace');
            // המשך גם אם יש שגיאה - התשלום כבר נדחה
          }
          
          // Guard context usage after async gap
          if (!context.mounted) {
            debugPrint('⚠️ Context not mounted after sending notification, skipping SnackBar');
            return;
          }
          
          debugPrint('✅ Showing success SnackBar to admin');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('התשלום נדחה וההתראה נשלחה למשתמש'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Guard context usage after async gap
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה בדחיית התשלום'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR in _rejectPayment: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        // Guard context usage after async gap
        if (!context.mounted) {
          debugPrint('⚠️ Context not mounted after error, returning');
          return;
        }
        debugPrint('⚠️ Showing error snackbar to user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
