import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/order.dart' as order_model;
import '../l10n/app_localizations.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _selectedOrderType = 'courier'; // 'courier', 'appointment', 'other'
  String _selectedTab = 'pending'; // 'pending', 'in_progress', 'completed', 'cancelled' (להזמנות עם שליח)
  String _selectedAppointmentTab = 'my_appointments'; // 'my_appointments', 'weekly_schedule' (להזמנות עם תור)
  DateTime _selectedWeekStart = DateTime.now();
  int _selectedWeekIndex = 0;

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
            // בחירת סוג הזמנות
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildOrderTypeButton(
                      'הזמנות עם שליח',
                      'courier',
                      Icons.local_shipping,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOrderTypeButton(
                      'הזמנות עם תור',
                      'appointment',
                      Icons.calendar_today,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOrderTypeButton(
                      'הזמנות אחרות',
                      'other',
                      Icons.shopping_cart,
                    ),
                  ),
                ],
              ),
            ),
            // Tabs לפי סוג ההזמנות
            if (_selectedOrderType == 'courier' || _selectedOrderType == 'other')
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
            if (_selectedOrderType == 'appointment')
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    _buildAppointmentTab('תורים שקבעתי', 'my_appointments', Icons.event),
                    _buildAppointmentTab('לוז שבועי', 'weekly_schedule', Icons.calendar_view_week),
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
                
                // סינון לפי סוג ההזמנות
                bool matchesOrderType = false;
                if (_selectedOrderType == 'courier') {
                  // הזמנות עם שליח - יש courierId או deliveryType == 'delivery'
                  matchesOrderType = order.courierId != null || order.deliveryType == 'delivery';
                } else if (_selectedOrderType == 'appointment') {
                  // הזמנות עם תור - יש appointmentId
                  matchesOrderType = order.appointmentId != null;
                } else if (_selectedOrderType == 'other') {
                  // הזמנות אחרות - אין שליח ואין תור
                  matchesOrderType = order.courierId == null && 
                                     order.deliveryType != 'delivery' && 
                                     order.appointmentId == null;
                }
                
                if (!matchesOrderType) {
                  continue;
                }
                
                // סינון לפי הטאב הנבחר (רק להזמנות עם שליח או אחרות)
                if (_selectedOrderType == 'courier' || _selectedOrderType == 'other') {
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
                
                  if (!matchesTab) {
                    continue;
                }
                }
                
                parsedOrders.add(order);
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

            // תצוגה לפי סוג ההזמנות
            if (_selectedOrderType == 'appointment' && _selectedAppointmentTab == 'weekly_schedule') {
              return _buildWeeklyScheduleView(parsedOrders);
            } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: parsedOrders.length,
              itemBuilder: (context, index) {
                final order = parsedOrders[index];
                return _buildOrderCard(order, index);
              },
            );
            }
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
                    _getStatusText(order.status, hasAppointment: order.appointmentId != null && order.appointmentId!.isNotEmpty),
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
            
            // Delivery Fee (if exists)
            if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
              const SizedBox(height: 16),
              const Text(
                'עלות משלוח:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'עלות משלוח',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '₪${order.deliveryFee!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ],
            
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
            
            // פרטי תור (אם יש)
            if (order.appointmentDate != null && order.appointmentStartTime != null) ...[
              const Divider(height: 24),
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
                        Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'פרטי התור:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatAppointmentDate(order.appointmentDate!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.appointmentStartTime}${order.appointmentEndTime != null ? ' - ${order.appointmentEndTime}' : ''}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            
            // לחצנים מחק וערוך הזמנה
            // להזמנות רגילות: pending, completed, cancelled
            // להזמנות עם תור: תמיד להציג (כי הן במצב confirmed)
            if (order.appointmentId != null && order.appointmentId!.isNotEmpty) ...[
              // להזמנות עם תור - תמיד להציג את הלחצנים
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _editOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('ערוך הזמנה'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                onPressed: () => _deleteOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('מחק הזמנה'),
              ),
                  ),
                ],
              ),
            ] else if (order.status == 'pending' || order.status == 'completed' || order.status == 'cancelled') ...[
              // להזמנות רגילות - רק אם הסטטוס הוא pending, completed, או cancelled
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _editOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('ערוך הזמנה'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _deleteOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('מחק הזמנה'),
                    ),
                  ),
                ],
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

  String _getStatusText(String status, {bool hasAppointment = false}) {
    switch (status) {
      case 'pending':
        return 'ממתין לאישור';
      case 'confirmed':
        return hasAppointment ? 'מאושרת' : 'מאושרת בתהליך הכנה';
      case 'preparing':
        return 'מאושרת בתהליך הכנה';
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
        // שחרור התור אם יש appointmentId
        if (order.appointmentId != null && order.appointmentId!.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('appointments')
                .doc(order.appointmentId!)
                .update({
              'isAvailable': true,
              'bookedBy': null,
              'orderId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Appointment ${order.appointmentId} released successfully');
          } catch (e) {
            debugPrint('⚠️ Error releasing appointment ${order.appointmentId}: $e');
            // ממשיכים למחוק את ההזמנה גם אם שחרור התור נכשל
          }
        }

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
                content: Text('ההזמנה נמחקה בהצלחה מכל המקומות והתור שוחרר'),
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
                SnackBar(
                  content: Text(
                    order.appointmentId != null && order.appointmentId!.isNotEmpty
                        ? 'ההזמנה נמחקה מהרשימה שלך והתור שוחרר'
                        : 'ההזמנה נמחקה מהרשימה שלך',
                  ),
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

  // פונקציה לבניית לחצן סוג הזמנות
  Widget _buildOrderTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedOrderType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrderType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // פונקציה לבניית טאב תורים
  Widget _buildAppointmentTab(String label, String value, IconData icon) {
    final isSelected = _selectedAppointmentTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedAppointmentTab = value;
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
              const SizedBox(width: 8),
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

  // פונקציה לעריכת הזמנה
  Future<void> _editOrder(order_model.Order order) async {
    // אם זו הזמנה עם תור, נפתח מסך עריכה מיוחד
    if (order.appointmentId != null && order.appointmentId!.isNotEmpty) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditAppointmentOrderScreen(order: order),
        ),
      );
      
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה עודכנה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // להזמנות רגילות - TODO: להוסיף מסך עריכה רגיל
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('עריכת הזמנות רגילות תגיע בקרוב'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // פונקציה לפורמט תאריך תור
  String _formatAppointmentDate(DateTime date) {
    final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    final dayName = days[date.weekday % 7];
    return 'יום $dayName, ${date.day}/${date.month}/${date.year}';
  }

  // תצוגת לוז שבועי
  Widget _buildWeeklyScheduleView(List<order_model.Order> orders) {
    // חישוב ראשון השבוע
    final daysToSubtract = _selectedWeekStart.weekday == 7 ? 0 : _selectedWeekStart.weekday;
    final weekStart = _selectedWeekStart.subtract(Duration(days: daysToSubtract));

    return Column(
      children: [
        // ניווט בין שבועות
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _selectedWeekIndex > 0
                    ? () {
                        setState(() {
                          _selectedWeekIndex--;
                          _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
                        });
                      }
                    : null,
              ),
              Expanded(
                child: Text(
                  '${weekStart.day}/${weekStart.month}/${weekStart.year} - ${weekStart.add(const Duration(days: 6)).day}/${weekStart.add(const Duration(days: 6)).month}/${weekStart.add(const Duration(days: 6)).year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _selectedWeekIndex < 3
                    ? () {
                        setState(() {
                          _selectedWeekIndex++;
                          _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
        // תצוגת השבוע
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: 7,
            itemBuilder: (context, dayIndex) {
              final day = weekStart.add(Duration(days: dayIndex));
              final dayOrders = orders.where((order) {
                if (order.appointmentDate == null) return false;
                final orderDate = DateTime(
                  order.appointmentDate!.year,
                  order.appointmentDate!.month,
                  order.appointmentDate!.day,
                );
                final currentDate = DateTime(day.year, day.month, day.day);
                return orderDate == currentDate;
              }).toList();

              if (dayOrders.isEmpty) {
                return const SizedBox.shrink();
              }

              final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
              final dayName = days[day.weekday % 7];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Text(
                    'יום $dayName, ${day.day}/${day.month}/${day.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: dayOrders.map((order) {
                    return ListTile(
                      leading: Icon(Icons.event, color: Colors.blue[700]),
                      title: Text(order.providerName),
                      subtitle: Text(
                        '${order.appointmentStartTime ?? ''}${order.appointmentEndTime != null ? ' - ${order.appointmentEndTime}' : ''}',
                      ),
                      trailing: Text(
                        'הזמנה #${order.orderNumber}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      onTap: () {
                        // הצגת פרטי ההזמנה
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('הזמנה #${order.orderNumber}'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('עסק: ${order.providerName}'),
                                  const SizedBox(height: 8),
                                  Text('תאריך: ${_formatAppointmentDate(order.appointmentDate!)}'),
                                  const SizedBox(height: 8),
                                  Text('שעה: ${order.appointmentStartTime ?? ''}${order.appointmentEndTime != null ? ' - ${order.appointmentEndTime}' : ''}'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('סגור'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// מסך עריכת הזמנה עם תור
class EditAppointmentOrderScreen extends StatefulWidget {
  final order_model.Order order;

  const EditAppointmentOrderScreen({
    super.key,
    required this.order,
  });

  @override
  State<EditAppointmentOrderScreen> createState() => _EditAppointmentOrderScreenState();
}

class _EditAppointmentOrderScreenState extends State<EditAppointmentOrderScreen> {
  late List<order_model.OrderItem> _orderItems;
  String? _selectedAppointmentId;
  DateTime? _selectedAppointmentDate;
  String? _selectedAppointmentStartTime;
  String? _selectedAppointmentEndTime;
  bool _isLoading = false;
  int _providerServicesCount = 0;

  @override
  void initState() {
    super.initState();
    _orderItems = List.from(widget.order.items);
    _selectedAppointmentId = widget.order.appointmentId;
    _selectedAppointmentDate = widget.order.appointmentDate;
    _selectedAppointmentStartTime = widget.order.appointmentStartTime;
    _selectedAppointmentEndTime = widget.order.appointmentEndTime;
    _loadProviderServicesCount();
  }

  // טעינת מספר השירותים של העסק
  Future<void> _loadProviderServicesCount() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.order.providerId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final services = userData['businessServices'] as List<dynamic>?;
        if (services != null) {
          // ספירת רק שירותים זמינים
          final availableServices = services.where((service) {
            if (service is Map<String, dynamic>) {
              return service['isAvailable'] as bool? ?? true;
            }
            return false;
          }).toList();
          setState(() {
            _providerServicesCount = availableServices.length;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading provider services count: $e');
    }
  }

  Future<void> _saveOrder() async {
    // בדיקה שיש לפחות שירות אחד
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('חייב לבחור לפחות שירות אחד'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAppointmentDate == null || _selectedAppointmentStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור תור'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // חישוב מחיר כולל
      double totalPrice = 0;
      for (var item in _orderItems) {
        if (item.totalItemPrice != null) {
          totalPrice += item.totalItemPrice! * item.quantity;
        }
      }

      // שחרור התור הישן אם השתנה
      if (widget.order.appointmentId != null && 
          widget.order.appointmentId != _selectedAppointmentId) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.order.appointmentId!)
            .update({
          'isAvailable': true,
          'bookedBy': null,
          'orderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // עדכון התור החדש (אם השתנה)
      if (_selectedAppointmentId != null && 
          _selectedAppointmentId != widget.order.appointmentId) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(_selectedAppointmentId!)
            .update({
          'isAvailable': false,
          'bookedBy': currentUser.uid,
          'orderId': widget.order.orderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // עדכון ההזמנה
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.orderId)
          .update({
        'items': _orderItems.map((item) => item.toMap()).toList(),
        'totalPrice': totalPrice,
        'appointmentId': _selectedAppointmentId,
        'appointmentDate': _selectedAppointmentDate != null 
            ? Timestamp.fromDate(_selectedAppointmentDate!) 
            : null,
        'appointmentStartTime': _selectedAppointmentStartTime,
        'appointmentEndTime': _selectedAppointmentEndTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון ההזמנה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectNewAppointment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderAppointmentBookingScreen(
          providerId: widget.order.providerId,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAppointmentId = result['appointmentId'] as String?;
        _selectedAppointmentDate = result['date'] as DateTime?;
        _selectedAppointmentStartTime = result['startTime'] as String?;
        _selectedAppointmentEndTime = result['endTime'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('עריכת הזמנה'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // פרטי התור הנוכחי
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'תור נוכחי:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedAppointmentDate != null)
                              Text(
                                _formatAppointmentDate(_selectedAppointmentDate!),
                                style: const TextStyle(fontSize: 14),
                              ),
                            if (_selectedAppointmentStartTime != null)
                              Text(
                                '${_selectedAppointmentStartTime}${_selectedAppointmentEndTime != null ? ' - $_selectedAppointmentEndTime' : ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _selectNewAppointment,
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('בחר תור אחר'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // רשימת שירותים
                    const Text(
                      'שירותים:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._orderItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      // בדיקה אם זה השירות האחרון והעסק יש לו רק שירות אחד
                      final canDelete = !(_orderItems.length == 1 && _providerServicesCount == 1);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item.serviceName),
                          subtitle: Text('כמות: ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.totalItemPrice != null)
                                Text(
                                  '₪${(item.totalItemPrice! * item.quantity).toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: canDelete ? Colors.red : Colors.grey,
                                ),
                                onPressed: canDelete
                                    ? () {
                                        setState(() {
                                          _orderItems.removeAt(index);
                                        });
                                      }
                                    : () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('לא ניתן למחוק את השירות האחרון - העסק מציע רק שירות אחד'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    // סך הכל
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'סך הכל:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₪${_orderItems.fold<double>(0, (sum, item) => sum + (item.totalItemPrice ?? 0) * item.quantity).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // לחצן שמירה
                    ElevatedButton(
                      onPressed: _saveOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('שמור שינויים'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatAppointmentDate(DateTime date) {
    final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    final dayName = days[date.weekday % 7];
    return 'יום $dayName, ${date.day}/${date.month}/${date.year}';
  }
}

