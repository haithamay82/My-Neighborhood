import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart' as order_model;
import '../l10n/app_localizations.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _selectedTab = 'pending'; // 'pending', 'in_progress', 'completed', 'cancelled'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('הזמנות שלי'),
        ),
        body: Center(
          child: Text(l10n.userNotConnected),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'הזמנות שלי',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
        ),
        body: Column(
          children: [
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  _buildTab('ממתינות', 'pending', Icons.pending),
                  _buildTab('בתהליך', 'in_progress', Icons.local_shipping),
                  _buildTab('הושלמו', 'completed', Icons.done_all),
                  _buildTab('בוטלו', 'cancelled', Icons.cancel),
                ],
              ),
            ),
            // Orders List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: user.uid)
                    .snapshots(),
                // נסנן את ההזמנות שנמחקו (soft delete) בצד הלקוח
                builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              debugPrint('❌ Error loading orders: ${snapshot.error}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'שגיאה בטעינת ההזמנות',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('נסה שוב'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final orders = snapshot.data?.docs ?? [];

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'אין הזמנות',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Parse orders and sort by createdAt descending
            // נסנן את ההזמנות שנמחקו (soft delete) - אם customerId נמצא ב-deletedForCustomers
            // ונמיין לפי הסטטוס לטאבים
            final parsedOrders = <order_model.Order>[];
            for (var doc in orders) {
              try {
                final orderData = doc.data() as Map<String, dynamic>;
                final deletedForCustomers = orderData['deletedForCustomers'] as List<dynamic>?;
                
                // אם ההזמנה נמחקה עבור המזמין הנוכחי (soft delete) - נדלג עליה
                if (deletedForCustomers != null && deletedForCustomers.contains(user.uid)) {
                  continue;
                }
                
                final order = order_model.Order.fromFirestore(doc);
                
                // סינון לפי הטאב הנבחר
                bool matchesTab = false;
                if (_selectedTab == 'pending') {
                  matchesTab = order.status == 'pending';
                } else if (_selectedTab == 'in_progress') {
                  matchesTab = order.status == 'confirmed' || order.status == 'preparing';
                } else if (_selectedTab == 'completed') {
                  matchesTab = order.status == 'completed';
                } else if (_selectedTab == 'cancelled') {
                  matchesTab = order.status == 'cancelled';
                }
                
                if (matchesTab) {
                  parsedOrders.add(order);
                }
              } catch (e) {
                debugPrint('❌ Error parsing order ${doc.id}: $e');
                debugPrint('   Document data: ${doc.data()}');
              }
            }

            // Sort by createdAt descending
            parsedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (parsedOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedTab == 'pending'
                          ? Icons.pending_outlined
                          : _selectedTab == 'in_progress'
                              ? Icons.local_shipping_outlined
                              : _selectedTab == 'completed'
                                  ? Icons.done_all_outlined
                                  : Icons.cancel_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedTab == 'pending'
                          ? 'אין הזמנות ממתינות'
                          : _selectedTab == 'in_progress'
                              ? 'אין הזמנות בתהליך'
                              : _selectedTab == 'completed'
                                  ? 'אין הזמנות שהושלמו'
                                  : 'אין הזמנות שבוטלו',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: parsedOrders.length,
              itemBuilder: (context, index) {
                final order = parsedOrders[index];
                return _buildOrderCard(order);
              },
            );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String value, IconData icon) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(order_model.Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת עם סטטוס
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'הזמנה #${order.orderNumber}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'מ: ${order.providerName}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // פירוט השירותים
            const Text(
              'שירותים:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.serviceName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (item.selectedIngredients.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'מרכיבים: ${item.selectedIngredients.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'כמות: ${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.totalItemPrice != null)
                      Text(
                        '₪${item.totalItemPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      )
                    else if (item.isCustomPrice)
                      const Text(
                        'בהתאמה אישית',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              );
            }),
            
            // סוג שירות
            if (order.deliveryType != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    order.deliveryType == 'pickup' ? Icons.store : Icons.local_shipping,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.deliveryType == 'pickup' ? 'איסוף עצמי' : 'משלוח',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (order.deliveryType == 'delivery' && order.deliveryLocation != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryLocation!['address'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              // פרטי השליח (אם יש)
              if (order.deliveryType == 'delivery' && order.courierName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'שליח: ${order.courierName}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      if (order.courierPhone != null && order.courierPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'טלפון: ${order.courierPhone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
            
            // סוג תשלום
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  order.paymentType == 'cash' 
                      ? Icons.money
                      : order.paymentType == 'bit'
                          ? Icons.account_balance_wallet
                          : Icons.credit_card,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  order.paymentType == 'cash'
                      ? 'מזומן'
                      : order.paymentType == 'bit'
                          ? 'BIT'
                          : 'כרטיס אשראי',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            
            // סך הכל
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'סך הכל:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₪${order.totalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            
            // לחצן מחק הזמנה - רק אם הסטטוס הוא pending, completed, או cancelled
            if (order.status == 'pending' || order.status == 'completed' || order.status == 'cancelled') ...[
              const Divider(height: 24),
              ElevatedButton(
                onPressed: () => _deleteOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('מחק הזמנה'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'preparing':
        return Colors.purple; // גם confirmed וגם preparing - אותו צבע
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'ממתין לאישור';
      case 'confirmed':
      case 'preparing':
        return 'מאושרת בתהליך הכנה'; // גם confirmed וגם preparing - אותו טקסט
      case 'completed':
        return 'הושלם';
      case 'cancelled':
        return 'בוטל';
      default:
        return status;
    }
  }

  Future<void> _deleteOrder(order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת הזמנה'),
        content: Text(
          order.status == 'pending'
              ? 'האם אתה בטוח שברצונך למחוק את ההזמנה? ההזמנה תימחק מכל המקומות (עסק, שליחים). פעולה זו לא ניתנת לביטול.'
              : 'האם אתה בטוח שברצונך למחוק את ההזמנה? ההזמנה תימחק רק מהרשימה שלך, אך תישאר אצל העסק והשליחים.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (order.status == 'pending') {
          // אם ההזמנה במצב "ממתין לאישור" - למחוק אותה לחלוטין מכל המקומות
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(order.orderId)
              .delete();

          // מחיקת התראות קשורות לשליחים
          final notificationsSnapshot = await FirebaseFirestore.instance
              .collection('notifications')
              .where('type', isEqualTo: 'order_delivery')
              .get();

          for (var notificationDoc in notificationsSnapshot.docs) {
            final data = notificationDoc.data();
            if (data['data']?['orderId'] == order.orderId) {
              await notificationDoc.reference.delete();
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ההזמנה נמחקה בהצלחה מכל המקומות'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // אם ההזמנה במצב "הושלם" או "בוטל" - למחוק אותה רק מהרשימה של המזמין
          // נוסיף שדה deletedForCustomers שמכיל רשימת customerIds שהמזמינים שלהם מחקו את ההזמנה
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(order.orderId)
                .update({
              'deletedForCustomers': FieldValue.arrayUnion([currentUser.uid]),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ההזמנה נמחקה מהרשימה שלך'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error deleting order: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה במחיקת ההזמנה: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

