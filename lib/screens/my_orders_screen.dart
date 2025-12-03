import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/order.dart' as order_model;
import '../l10n/app_localizations.dart';
import '../services/location_service.dart';

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
                  _buildTabWithCount('ממתינות', 'pending', Icons.pending, user.uid),
                  _buildTabWithCount('בתהליך', 'in_progress', Icons.local_shipping, user.uid),
                  _buildTabWithCount('הושלמו', 'completed', Icons.done_all, user.uid),
                  _buildTabWithCount('בוטלו', 'cancelled', Icons.cancel, user.uid),
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
                return _buildOrderCard(order, index);
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

  Widget _buildTabWithCount(String label, String value, IconData icon, String userId) {
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('customerId', isEqualTo: userId)
                .snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) {
                final orders = snapshot.data?.docs ?? [];
                for (var doc in orders) {
                  try {
                    final orderData = doc.data() as Map<String, dynamic>;
                    final deletedForCustomers = orderData['deletedForCustomers'] as List<dynamic>?;
                    
                    // אם ההזמנה נמחקה עבור המזמין הנוכחי (soft delete) - נדלג עליה
                    if (deletedForCustomers != null && deletedForCustomers.contains(userId)) {
                      continue;
                    }
                    
                    final order = order_model.Order.fromFirestore(doc);
                    
                    // סינון לפי הטאב
                    bool matchesTab = false;
                    if (value == 'pending') {
                      matchesTab = order.status == 'pending';
                    } else if (value == 'in_progress') {
                      matchesTab = order.status == 'confirmed' || order.status == 'preparing';
                    } else if (value == 'completed') {
                      matchesTab = order.status == 'completed';
                    } else if (value == 'cancelled') {
                      matchesTab = order.status == 'cancelled';
                    }
                    
                    if (matchesTab) {
                      count++;
                    }
                  } catch (e) {
                    // Skip invalid orders
                  }
                }
              }
              
              return _buildTabContent(label, icon, isSelected, count);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String label, IconData icon, bool isSelected, int count) {
    return Row(
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
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderCard(order_model.Order order, int index) {
    // צבע רקע לסירוגין
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEven = index % 2 == 0;
    Color? backgroundColor;
    if (isDark) {
      // בערכה כהה: הפרדה ברקעים
      backgroundColor = isEven 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest;
    } else {
      // בערכה בהירה: לבן או beige בהיר
      backgroundColor = isEven 
          ? Colors.white
          : Colors.brown[50]; // beige בהיר
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: backgroundColor,
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
                      Text(
                        'הזמנה #${order.orderNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'מ: ${order.providerName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
                // הצגת "נמסרה" אם ההזמנה נמסרה
                if (order.isDelivered) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text(
                          'נמסרה',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
                        GestureDetector(
                          onTap: () => _makePhoneCall(order.courierPhone!),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.blue[600]),
                              const SizedBox(width: 4),
                              Text(
                                'טלפון: ${order.courierPhone}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
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
            
            // מפה עם מיקום ההזמנה, העסק והשליח - רק אם יש שליח וההזמנה היא delivery
            Builder(
              builder: (context) {
                // לוגים לדיבוג
                debugPrint('🗺️ Order ${order.orderNumber} - Map conditions:');
                debugPrint('   courierId: ${order.courierId}');
                debugPrint('   deliveryType: ${order.deliveryType}');
                debugPrint('   deliveryLocation: ${order.deliveryLocation}');
                debugPrint('   courierName: ${order.courierName}');
                debugPrint('   status: ${order.status}');
                
                if (order.courierId != null && order.deliveryType == 'delivery' && order.deliveryLocation != null) {
                  debugPrint('   ✅ All conditions met - showing map');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 24),
                      const Text(
                        'מיקום המשלוח',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildOrderTrackingMap(order),
                      const SizedBox(height: 16),
                    ],
                  );
                } else {
                  debugPrint('   ❌ Conditions not met:');
                  if (order.courierId == null) debugPrint('      - courierId is null');
                  if (order.deliveryType != 'delivery') debugPrint('      - deliveryType is ${order.deliveryType}, not "delivery"');
                  if (order.deliveryLocation == null) debugPrint('      - deliveryLocation is null');
                  return const SizedBox.shrink();
                }
              },
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

  Widget _buildOrderTrackingMap(order_model.Order order) {
    if (order.deliveryLocation == null || order.courierId == null) {
      return const SizedBox.shrink();
    }

    final deliveryLat = (order.deliveryLocation!['latitude'] as num?)?.toDouble();
    final deliveryLng = (order.deliveryLocation!['longitude'] as num?)?.toDouble();
    
    if (deliveryLat == null || deliveryLng == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(order.providerId)
              .snapshots(),
          builder: (context, providerSnapshot) {
            // טעינת מיקום העסק
            double? businessLat;
            double? businessLng;
            if (providerSnapshot.hasData) {
              final providerData = providerSnapshot.data!.data() as Map<String, dynamic>?;
              businessLat = (providerData?['latitude'] as num?)?.toDouble();
              businessLng = (providerData?['longitude'] as num?)?.toDouble();
            }

            // טעינת מיקום השליח - מתעדכן כל 10 שניות
            // נשתמש ב-Stream.periodic כדי לעדכן כל 10 שניות
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(order.courierId)
                  .get(),
              builder: (context, initialSnapshot) {
                // לאחר הטעינה הראשונית, נשתמש ב-Stream.periodic לעדכון כל 10 שניות
                return StreamBuilder<DocumentSnapshot>(
                  stream: Stream.periodic(const Duration(seconds: 10))
                      .asyncMap((_) async {
                        final doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(order.courierId)
                            .get();
                        return doc;
                      }),
                  builder: (context, periodicSnapshot) {
                    // נשתמש בנתונים מהעדכון התקופתי, או מהטעינה הראשונית אם אין עדכון
                    final courierSnapshot = periodicSnapshot.hasData 
                        ? periodicSnapshot 
                        : initialSnapshot;
                double? courierLat;
                double? courierLng;
                String? courierName;
                
                if (courierSnapshot.hasData) {
                  final courierData = courierSnapshot.data!.data() as Map<String, dynamic>?;
                  courierLat = (courierData?['mobileLatitude'] as num?)?.toDouble() ?? 
                              (courierData?['latitude'] as num?)?.toDouble();
                  courierLng = (courierData?['mobileLongitude'] as num?)?.toDouble() ?? 
                              (courierData?['longitude'] as num?)?.toDouble();
                  courierName = courierData?['displayName'] as String? ?? 'שליח';
                }

                // חישוב מרכז המפה
                double centerLat = deliveryLat;
                double centerLng = deliveryLng;
                if (businessLat != null && businessLng != null) {
                  if (courierLat != null && courierLng != null) {
                    centerLat = (businessLat + deliveryLat + courierLat) / 3;
                    centerLng = (businessLng + deliveryLng + courierLng) / 3;
                  } else {
                    centerLat = (businessLat + deliveryLat) / 2;
                    centerLng = (businessLng + deliveryLng) / 2;
                  }
                }

                // חישוב זום
                double zoom = 13.0;
                if (businessLat != null && businessLng != null) {
                  final distance = LocationService.calculateDistance(
                    businessLat,
                    businessLng,
                    deliveryLat,
                    deliveryLng,
                  );
                  if (courierLat != null && courierLng != null) {
                    final distanceToBusiness = LocationService.calculateDistance(
                      courierLat,
                      courierLng,
                      businessLat,
                      businessLng,
                    );
                    final distanceToDelivery = LocationService.calculateDistance(
                      courierLat,
                      courierLng,
                      deliveryLat,
                      deliveryLng,
                    );
                    final maxDistance = [distance, distanceToBusiness, distanceToDelivery].reduce((a, b) => a > b ? a : b);
                    zoom = _calculateZoom(maxDistance);
                  } else {
                    zoom = _calculateZoom(distance);
                  }
                }

                // יצירת markers
                Set<Marker> markers = {};
                
                // Marker למיקום ההזמנה (אדום)
                markers.add(
                  Marker(
                    markerId: const MarkerId('delivery'),
                    position: LatLng(deliveryLat, deliveryLng),
                    infoWindow: InfoWindow(
                      title: 'כתובת למשלוח',
                      snippet: order.deliveryLocation!['address'] as String? ?? 'מיקום המשלוח',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                );

                // Marker למיקום העסק (כחול)
                if (businessLat != null && businessLng != null) {
                  markers.add(
                    Marker(
                      markerId: const MarkerId('business'),
                      position: LatLng(businessLat, businessLng),
                      infoWindow: InfoWindow(
                        title: 'מיקום העסק',
                        snippet: order.providerName,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  );
                }

                // Marker למיקום השליח (ירוק)
                if (courierLat != null && courierLng != null) {
                  markers.add(
                    Marker(
                      markerId: const MarkerId('courier'),
                      position: LatLng(courierLat, courierLng),
                      infoWindow: InfoWindow(
                        title: 'מיקום השליח',
                        snippet: courierName ?? 'שליח',
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                  );
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(centerLat, centerLng),
                    zoom: zoom,
                  ),
                  markers: markers,
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    // המפה נוצרה בהצלחה
                  },
                );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _calculateZoom(double distanceInMeters) {
    // חישוב זום לפי מרחק
    if (distanceInMeters < 500) {
      return 15.0;
    } else if (distanceInMeters < 1000) {
      return 14.0;
    } else if (distanceInMeters < 5000) {
      return 13.0;
    } else if (distanceInMeters < 10000) {
      return 12.0;
    } else {
      return 11.0;
    }
  }

  // התקשרות למספר טלפון
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // ניקוי מספר הטלפון (הסרת תווים לא רלוונטיים)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // יצירת URI להתקשרות
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן להתקשר למספר זה'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתקשרות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

