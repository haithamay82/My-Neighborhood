import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart' as order_model;
import '../models/request.dart';
import '../models/user_profile.dart';
import '../models/appointment.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedTab = 'pending'; // 'pending', 'confirmed', 'completed'
  bool? _isCourier;
  UserProfile? _userProfile;
  bool? _requiresAppointment;
  DateTime _selectedWeekStart = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedWeek = 1; // שבוע בחודש (1-4 או 5)

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final profile = UserProfile.fromFirestore(userDoc);
        final userData = userDoc.data()!;
        setState(() {
          _userProfile = profile;
          // בדיקה אם המשתמש הוא שליח
          final courierCategories = [
            RequestCategory.foodDelivery,
            RequestCategory.groceryDelivery,
            RequestCategory.smallMoving,
            RequestCategory.largeMoving,
          ];
          _isCourier = profile.businessCategories?.any((cat) =>
              courierCategories.any((c) => c.name == cat.name)) ?? false;
          // בדיקה אם העסק דורש תורים
          _requiresAppointment = userData['requiresAppointment'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ניהול הזמנות'),
        ),
        body: const Center(
          child: Text('יש להתחבר כדי לראות הזמנות'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ניהול הזמנות',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
        ),
        body: _requiresAppointment == true
            ? _buildAppointmentWeekView(user.uid)
            : Column(
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
                  if (_isCourier == true) 
                    _buildTabWithCount('בתהליך', 'preparing', Icons.local_shipping, user.uid)
                  else
                    _buildTabWithCount('בתהליך', 'in_progress', Icons.local_shipping, user.uid),
                  _buildTabWithCount('הושלמו', 'completed', Icons.done_all, user.uid),
                ],
              ),
            ),
            // Orders List
            Expanded(
              child: _isCourier == true && (_selectedTab == 'pending' || _selectedTab == 'preparing')
                  ? _buildCourierOrdersList(user.uid)
                  : StreamBuilder<QuerySnapshot>(
                      stream: _selectedTab == 'in_progress'
                          ? _firestore
                              .collection('orders')
                              .where('providerId', isEqualTo: user.uid)
                              .where('status', whereIn: ['confirmed', 'preparing']) // גם confirmed (הזמנות ישנות) וגם preparing
                              .snapshots()
                          : _isCourier == true && _selectedTab == 'completed'
                              ? _firestore
                                  .collection('orders')
                                  .where('courierId', isEqualTo: user.uid)
                                  .where('status', isEqualTo: 'completed')
                                  .snapshots()
                              : _firestore
                                  .collection('orders')
                                  .where('providerId', isEqualTo: user.uid)
                                  .where('status', isEqualTo: _selectedTab)
                                  .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('שגיאה בטעינת ההזמנות: ${snapshot.error}'),
                    );
                  }

                  final orders = snapshot.data?.docs ?? [];

                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedTab == 'pending'
                                ? Icons.pending_outlined
                                : _selectedTab == 'in_progress'
                                    ? Icons.local_shipping_outlined
                                    : Icons.done_all_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedTab == 'pending'
                                ? 'אין הזמנות ממתינות'
                                : _selectedTab == 'in_progress'
                                    ? 'אין הזמנות בתהליך'
                                    : 'אין הזמנות שהושלמו',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort by createdAt descending
                  final sortedOrders = orders.toList()
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedOrders.length,
                    itemBuilder: (context, index) {
                      try {
                        final order = order_model.Order.fromFirestore(sortedOrders[index]);
                        return _buildOrderCard(order, index);
                      } catch (e) {
                        debugPrint('Error parsing order: $e');
                        return const SizedBox.shrink();
                      }
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

  Widget _buildCourierOrdersList(String userId) {
    // טעינת הזמנות שהשליח קיבל התראות עליהן (גם נקראות וגם לא נקראות)
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'order_delivery')
          .snapshots(),
      builder: (context, notificationsSnapshot) {
        if (notificationsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = notificationsSnapshot.data?.docs ?? [];
        debugPrint('📬 Found ${notifications.length} notifications for courier $userId');
        
        final orderIds = notifications
            .map((n) {
              final data = n.data() as Map<String, dynamic>;
              final notificationData = data['data'] as Map<String, dynamic>?;
              final orderId = notificationData?['orderId'] as String?;
              debugPrint('   Notification ${n.id}:');
              debugPrint('     - orderId: $orderId');
              debugPrint('     - type: ${data['type']}');
              debugPrint('     - read: ${data['read']}');
              debugPrint('     - data: $notificationData');
              if (orderId == null) {
                debugPrint('     - ⚠️ WARNING: orderId is null!');
              }
              return orderId;
            })
            .where((id) => id != null)
            .toSet()
            .toList();

        debugPrint('📦 Found ${orderIds.length} unique order IDs');

        if (orderIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'אין הזמנות חדשות למשלוח',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // טעינת הזמנות - נטען את כל ההזמנות עם status pending או confirmed ונסנן לפי orderIds
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('orders')
              .where('deliveryType', isEqualTo: 'delivery')
              .snapshots(),
          builder: (context, ordersSnapshot) {
            if (ordersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // סינון הזמנות לפי orderIds - נציג גם pending (ממתין לאישור) וגם confirmed (מאושר)
            final allOrders = ordersSnapshot.data?.docs ?? [];
            debugPrint('📋 Found ${allOrders.length} delivery orders (all statuses)');
            
            final currentUserId = _auth.currentUser?.uid;
            final orders = allOrders
                .where((doc) {
                  final orderData = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id;
                  final status = orderData['status'] as String?;
                  final isInList = orderIds.contains(orderId);
                  
                  // אם זה טאב "pending" - נציג pending, confirmed או preparing (אבל רק אם אין שליח)
                  // אם זה טאב "preparing" - נציג רק preparing עם שליח שזה השליח הנוכחי (הזמנה שהוא לקח)
                  bool isValidStatus;
                  if (_selectedTab == 'pending') {
                    final courierId = orderData['courierId'];
                    // נציג pending, confirmed (הזמנות ישנות) או preparing (אבל רק אם אין שליח - כלומר הזמנה מאושרת שעדיין לא נלקחה)
                    isValidStatus = ((status == 'pending') || (status == 'confirmed') || (status == 'preparing')) && courierId == null;
                  } else if (_selectedTab == 'preparing') {
                    final courierId = orderData['courierId'];
                    // נציג preparing רק אם יש שליח והשליח הוא המשתמש הנוכחי (הזמנה שהוא לקח)
                    isValidStatus = status == 'preparing' && courierId != null && courierId == currentUserId;
                  } else {
                    isValidStatus = status == _selectedTab;
                  }
                  
                  debugPrint('   Order $orderId:');
                  debugPrint('     - in list: $isInList');
                  debugPrint('     - status: $status');
                  debugPrint('     - courierId: ${orderData['courierId']}');
                  debugPrint('     - currentUserId: $currentUserId');
                  debugPrint('     - selected tab: $_selectedTab');
                  debugPrint('     - valid status: $isValidStatus');
                  
                  return isInList && isValidStatus;
                })
                .toList();

            debugPrint('✅ Filtered to ${orders.length} matching orders');

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'אין הזמנות חדשות למשלוח',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Sort by createdAt descending
            final sortedOrders = orders.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedOrders.length,
              itemBuilder: (context, index) {
                try {
                  final order = order_model.Order.fromFirestore(sortedOrders[index]);
                  return _buildCourierOrderCard(order, index);
                } catch (e) {
                  debugPrint('Error parsing order: $e');
                  return const SizedBox.shrink();
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCourierOrderCard(order_model.Order order, int index) {
    final isPending = order.status == 'pending';
    final isConfirmed = order.status == 'confirmed';
    final isPreparing = order.status == 'preparing';
    final currentUserId = _auth.currentUser?.uid;
    // ניתן לקחת הזמנה אם היא pending, confirmed (הזמנות ישנות) או preparing (אבל רק אם אין שליח)
    final canTakeOrder = (isPending || isConfirmed || isPreparing) && order.courierId == null;
    final isMyOrder = order.courierId == currentUserId;
    
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                // Column עם הלחצן "נמסרה" והסטטוס
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // לחצן "נמסרה" לשליח (מעל הסטטוס) - רק אם הוא לקח את ההזמנה והיא בתהליך או הושלמה
                    if ((isPreparing || order.status == 'completed') && isMyOrder && !order.isDelivered) ...[
                      TextButton.icon(
                        onPressed: () => _markAsDelivered(order),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('נמסרה'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
                        color: (isPreparing || isConfirmed) ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (isPreparing || isConfirmed) ? 'מאושרת בתהליך הכנה' : 'ממתין לאישור',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            
            // פרטי המזמין
            const Text(
              'פרטי המזמין:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('שם: ${order.customerName}'),
            GestureDetector(
              onTap: () => _makePhoneCall(order.customerPhone),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'טלפון: ${order.customerPhone}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // שירותים
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
            const SizedBox(height: 16),
            
            // כתובת עסק
            const Text(
              'כתובת עסק:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(order.providerId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Text(
                    order.providerName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  );
                }
                final providerData = snapshot.data!.data() as Map<String, dynamic>?;
                final businessLat = (providerData?['latitude'] as num?)?.toDouble();
                final businessLng = (providerData?['longitude'] as num?)?.toDouble();
                final businessAddress = providerData?['businessAddress'] as String?;
                
                return GestureDetector(
                  onTap: () {
                    if (businessLat != null && businessLng != null && order.deliveryLocation != null) {
                      _showMapDialog(
                        businessLat,
                        businessLng,
                        order.providerName,
                        businessAddress ?? order.providerName,
                        order.deliveryLocation!['latitude'] as double,
                        order.deliveryLocation!['longitude'] as double,
                        order.deliveryLocation!['address'] as String,
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessAddress ?? order.providerName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                              ),
                            ),
                            if (businessLat != null && businessLng != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'מיקום: ${businessLat.toStringAsFixed(6)}, ${businessLng.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // כתובת למשלוח
            if (order.deliveryLocation != null) ...[
              const Text(
                'כתובת למשלוח:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  // טעינת מיקום העסק
                  final providerDoc = await _firestore.collection('users').doc(order.providerId).get();
                  final providerData = providerDoc.data();
                  final businessLat = (providerData?['latitude'] as num?)?.toDouble();
                  final businessLng = (providerData?['longitude'] as num?)?.toDouble();
                  final businessAddress = providerData?['businessAddress'] as String?;
                  
                  if (businessLat != null && businessLng != null) {
                    _showMapDialog(
                      businessLat,
                      businessLng,
                      order.providerName,
                      businessAddress ?? order.providerName,
                      (order.deliveryLocation!['latitude'] as num).toDouble(),
                      (order.deliveryLocation!['longitude'] as num).toDouble(),
                      order.deliveryLocation!['address'] as String,
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryLocation!['address'] ?? 'מיקום לא זמין',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // צורת תשלום
            const Text(
              'צורת תשלום:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 16),
            
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
            
            // Action Buttons
            const Divider(height: 24),
            if (isPreparing && isMyOrder) ...[
              // אם השליח הנוכחי לקח את ההזמנה - לחצן שחרר הזמנה
              ElevatedButton(
                onPressed: () => _releaseCourierOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('שחרר הזמנה'),
              ),
            ] else if (isPending) ...[
              // אם ההזמנה עדיין ממתינה לאישור העסק - לחצן לא לחיץ
              ElevatedButton(
                onPressed: null, // לא לחיץ
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.grey[600],
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('בתהליך אישור העסק'),
              ),
            ] else if (canTakeOrder) ...[
              // אם העסק אישר והשליח עדיין לא לקח - לחצן קח הזמנה
              ElevatedButton(
                onPressed: () => _acceptCourierOrder(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('קח הזמנה'),
              ),
            ] else if (order.courierId != null && !isMyOrder) ...[
              // אם שליח אחר לקח את ההזמנה
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'הזמנה זו כבר נלקחה על ידי שליח אחר',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
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

  Future<void> _acceptCourierOrder(order_model.Order order) async {
    final user = _auth.currentUser;
    if (user == null || _userProfile == null) return;

    try {
      // קבלת מספר הטלפון של השליח
      final courierPhone = _userProfile!.phoneNumber ?? '';

      await _firestore.collection('orders').doc(order.orderId).update({
        'courierId': user.uid,
        'courierName': _userProfile!.displayName,
        'courierPhone': courierPhone, // שמירת מספר הטלפון של השליח
        'status': 'preparing', // שינוי הסטטוס ל"מאושרת בתהליך הכנה"
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // סמן את ההתראות כנקראות
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'order_delivery')
          .get();

      for (var notificationDoc in notificationsSnapshot.docs) {
        final data = notificationDoc.data();
        if (data['data']?['orderId'] == order.orderId) {
          await notificationDoc.reference.update({'read': true});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה התקבלה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting courier order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בקבלת ההזמנה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _releaseCourierOrder(order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('שחרור הזמנה'),
        content: const Text('האם אתה בטוח שברצונך לשחרר את ההזמנה? ההזמנה תחזור לממתינות אצל השליחים המתאימים.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('שחרר'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // שמירת הסטטוס כ-preparing (כך שהעסק יראה אותה בטאב "בתהליך")
        // רק מסירים את פרטי השליח כדי שההזמנה תופיע שוב אצל השליחים המתאימים
        await _firestore.collection('orders').doc(order.orderId).update({
          'courierId': null,
          'courierName': null,
          'courierPhone': null,
          'status': 'preparing', // נשאר בטאב "בתהליך" אצל העסק
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // שליחת התראות מחדש לשליחים המתאימים
        if (order.deliveryType == 'delivery' && 
            order.deliveryLocation != null && 
            order.deliveryCategory != null) {
          // קריאה לפונקציה ששולחת התראות לשליחים (דומה ל-_notifyCouriersForOrder)
          await _notifyCouriersForReleasedOrder(order);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ההזמנה שוחררה והחזרה לממתינות אצל השליחים המתאימים'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error releasing courier order: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בשחרור ההזמנה: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _notifyCouriersForReleasedOrder(order_model.Order order) async {
    try {
      debugPrint('📦 Notifying couriers for released order: ${order.orderId}');
      
      if (order.deliveryLocation == null || order.deliveryCategory == null) {
        debugPrint('❌ Missing delivery location or category');
        return;
      }

      final deliveryLat = order.deliveryLocation!['latitude'] as double?;
      final deliveryLng = order.deliveryLocation!['longitude'] as double?;

      if (deliveryLat == null || deliveryLng == null) {
        debugPrint('❌ Invalid delivery location coordinates');
        return;
      }

      // קביעת הקטגוריה
      RequestCategory? selectedCategory;
      try {
        selectedCategory = RequestCategory.values.firstWhere(
          (cat) => cat.name == order.deliveryCategory,
          orElse: () {
            return RequestCategory.values.firstWhere(
              (cat) => cat.categoryDisplayName == order.deliveryCategory,
              orElse: () => throw Exception('Category not found'),
            );
          },
        );
      } catch (e) {
        debugPrint('❌ Invalid delivery category: ${order.deliveryCategory} - $e');
        return;
      }

      // חיפוש שליחים מתאימים
      final couriersSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();

      debugPrint('🔍 Found ${couriersSnapshot.docs.length} business users');

      final eligibleCouriers = <String>[];

      for (var courierDoc in couriersSnapshot.docs) {
        final courierData = courierDoc.data();
        final courierId = courierDoc.id;

        // בדיקת קטגוריות
        final businessCategories = courierData['businessCategories'] as List<dynamic>?;
        if (businessCategories == null || businessCategories.isEmpty) {
          continue;
        }

        bool hasMatchingCategory = false;
        for (var category in businessCategories) {
          String categoryName;
          if (category is String) {
            categoryName = category;
          } else {
            final categoryStr = category.toString();
            if (categoryStr.startsWith('RequestCategory.')) {
              categoryName = categoryStr.replaceFirst('RequestCategory.', '');
            } else {
              categoryName = categoryStr;
            }
          }

          if (categoryName == selectedCategory.name || 
              categoryName == selectedCategory.categoryDisplayName) {
            hasMatchingCategory = true;
            break;
          }
        }

        if (!hasMatchingCategory) {
          continue;
        }

        // בדיקת מיקום וטווח
        final latitude = courierData['latitude'] as num?;
        final longitude = courierData['longitude'] as num?;
        final maxRadius = courierData['maxRadius'] as num?;

        if (latitude == null || longitude == null || maxRadius == null) {
          continue;
        }

        final distance = LocationService.calculateDistance(
          latitude.toDouble(),
          longitude.toDouble(),
          deliveryLat,
          deliveryLng,
        );

        if (distance <= maxRadius.toDouble()) {
          eligibleCouriers.add(courierId);
        }
      }

      debugPrint('📦 Found ${eligibleCouriers.length} eligible couriers for released order');

      // שליחת התראות לשליחים המתאימים (רק למי שעדיין לא קיבל התראה על ההזמנה הזו)
      for (var courierId in eligibleCouriers) {
        // בדיקה אם השליח כבר קיבל התראה על ההזמנה הזו
        final existingNotification = await _firestore
            .collection('notifications')
            .where('toUserId', isEqualTo: courierId)
            .where('type', isEqualTo: 'order_delivery')
            .where('data.orderId', isEqualTo: order.orderId)
            .get();

        // אם אין התראה קיימת, נשלח אחת חדשה
        if (existingNotification.docs.isEmpty) {
          await NotificationService.sendNotification(
            toUserId: courierId,
            type: 'order_delivery',
            title: 'הזמנת משלוח חדשה',
            message: 'הזמנה חדשה זמינה למשלוח',
            data: {
              'orderId': order.orderId,
              'providerName': order.providerName,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying couriers for released order: $e');
    }
  }

  Widget _buildTabWithCount(String label, String value, IconData icon, String userId) {
    final isSelected = _selectedTab == value;
    final isCourier = _isCourier == true;
    
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
          child: isCourier
              ? _buildCourierTabCount(label, value, icon, isSelected, userId)
              : _buildBusinessTabCount(label, value, icon, isSelected, userId),
        ),
      ),
    );
  }

  Widget _buildCourierTabCount(String label, String value, IconData icon, bool isSelected, String userId) {
    // לטאב "הושלמו" - נספור ישירות מההזמנות (בדיוק כמו שמוצג בפועל)
    if (value == 'completed') {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('courierId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          int count = 0;
          if (snapshot.hasData) {
            count = snapshot.data?.docs.length ?? 0;
          }
          return _buildTabContent(label, icon, isSelected, count);
        },
      );
    }
    
    // לטאבים "ממתינות" ו"בתהליך" - נספור בדיוק כמו שמוצג בפועל ב-_buildCourierOrdersList
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'order_delivery')
          .snapshots(),
      builder: (context, notificationsSnapshot) {
        if (notificationsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildTabContent(label, icon, isSelected, 0);
        }
        
        final notifications = notificationsSnapshot.data?.docs ?? [];
        final orderIds = notifications
            .map((n) {
              final data = n.data() as Map<String, dynamic>;
              final notificationData = data['data'] as Map<String, dynamic>?;
              return notificationData?['orderId'] as String?;
            })
            .where((id) => id != null)
            .toSet()
            .toList();

        if (orderIds.isEmpty) {
          return _buildTabContent(label, icon, isSelected, 0);
        }

        // טעינת הזמנות - בדיוק כמו ב-_buildCourierOrdersList
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('orders')
              .where('deliveryType', isEqualTo: 'delivery')
              .snapshots(),
          builder: (context, ordersSnapshot) {
            int count = 0;
            
            if (ordersSnapshot.hasData) {
              final allOrders = ordersSnapshot.data?.docs ?? [];
              final currentUserId = _auth.currentUser?.uid;
              
              debugPrint('📊 Tab count - userId: $userId, currentUserId: $currentUserId, value: $value, orderIds: ${orderIds.length}');
              
              // סינון בדיוק כמו ב-_buildCourierOrdersList
              final filteredOrders = allOrders.where((doc) {
                final orderData = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;
                final status = orderData['status'] as String?;
                final isInList = orderIds.contains(orderId);
                
                bool isValidStatus;
                if (value == 'pending') {
                  final courierId = orderData['courierId'];
                  // בדיוק כמו ב-_buildCourierOrdersList - שורה 299
                  isValidStatus = ((status == 'pending') || (status == 'confirmed') || (status == 'preparing')) && courierId == null;
                } else if (value == 'preparing') {
                  final courierId = orderData['courierId'];
                  // בדיוק כמו ב-_buildCourierOrdersList - שורה 303 (משתמש ב-currentUserId)
                  isValidStatus = status == 'preparing' && courierId != null && courierId == currentUserId;
                } else {
                  isValidStatus = false;
                }
                
                if (isInList && isValidStatus) {
                  final courierIdForLog = orderData['courierId'];
                  debugPrint('   ✅ Order $orderId matches: status=$status, courierId=$courierIdForLog, isInList=$isInList, isValidStatus=$isValidStatus');
                }
                
                return isInList && isValidStatus;
              }).toList();
              
              count = filteredOrders.length;
              debugPrint('📊 Tab count - final count: $count for tab: $value, userId: $userId');
            }
            
            return _buildTabContent(label, icon, isSelected, count);
          },
        );
      },
    );
  }

  Widget _buildBusinessTabCount(String label, String value, IconData icon, bool isSelected, String userId) {
    Stream<QuerySnapshot> stream;
    
    if (value == 'in_progress') {
      stream = _firestore
          .collection('orders')
          .where('providerId', isEqualTo: userId)
          .where('status', whereIn: ['confirmed', 'preparing'])
          .snapshots();
    } else if (value == 'completed') {
      stream = _firestore
          .collection('orders')
          .where('providerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .snapshots();
    } else {
      stream = _firestore
          .collection('orders')
          .where('providerId', isEqualTo: userId)
          .where('status', isEqualTo: value)
          .snapshots();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data?.docs.length ?? 0;
        }
        
        return _buildTabContent(label, icon, isSelected, count);
      },
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
            // Header
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
                        'מ: ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      if (order.customerPhone.isNotEmpty)
                        GestureDetector(
                          onTap: () => _makePhoneCall(order.customerPhone),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.blue[600]),
                              const SizedBox(width: 4),
                              Text(
                                'טלפון: ${order.customerPhone}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[600],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.customerPhone.isNotEmpty)
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
                // Column עם הלחצן "נמסרה" והסטטוס
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // לחצן "ההזמנה בדרך" לשליח בטאב "הושלמו" (רק אם הוא לקח את ההזמנה והיא לא בדרך ולא נמסרה)
                    if (_isCourier == true && order.status == 'completed' && order.courierId == _auth.currentUser?.uid && !order.isOnTheWay && !order.isDelivered) ...[
                      TextButton.icon(
                        onPressed: () => _markAsOnTheWay(order),
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: const Text('ההזמנה בדרך'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // לחצן "נמסרה" לשליח בטאב "הושלמו" (רק אם הוא לקח את ההזמנה והיא לא נמסרה)
                    if (_isCourier == true && order.status == 'completed' && order.courierId == _auth.currentUser?.uid && !order.isDelivered) ...[
                      TextButton.icon(
                        onPressed: () => _markAsDelivered(order),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('נמסרה'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // הצגת "נמסרה" אם ההזמנה נמסרה (לכל המשתמשים)
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
              ],
            ),
            const Divider(height: 24),
            
            // Services
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
            
            // Delivery Type
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
                      child: GestureDetector(
                        onTap: () async {
                          // טעינת מיקום העסק
                          final providerDoc = await _firestore.collection('users').doc(order.providerId).get();
                          final providerData = providerDoc.data();
                          final businessLat = (providerData?['latitude'] as num?)?.toDouble();
                          final businessLng = (providerData?['longitude'] as num?)?.toDouble();
                          final businessAddress = providerData?['businessAddress'] as String?;
                          
                          if (businessLat != null && businessLng != null && order.deliveryLocation != null) {
                            _showMapDialog(
                              businessLat,
                              businessLng,
                              order.providerName,
                              businessAddress ?? order.providerName,
                              (order.deliveryLocation!['latitude'] as num).toDouble(),
                              (order.deliveryLocation!['longitude'] as num).toDouble(),
                              order.deliveryLocation!['address'] as String,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                order.deliveryLocation!['address'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            
            // Courier Info
            if (order.courierId != null && order.courierName != null) ...[
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
            
            // Payment Type
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
            
            // Total Price
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
            
            // Action Buttons
            if (order.status == 'pending') ...[
              // הזמנות ממתינות - לחצני אשר/דחה
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _rejectOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('דחה'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('אשר'),
                    ),
                  ),
                ],
              ),
            ] else if (order.status == 'preparing' || order.status == 'confirmed') ...[
              // הזמנות בתהליך הכנה - לחצני הושלמה ובטל הזמנה
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () => _cancelOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('בטל הזמנה'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _completeOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('הושלמה'),
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

  Future<void> _acceptOrder(order_model.Order order) async {
    try {
      // כאשר העסק מאשר, ההזמנה עוברת למצב preparing (מאושרת בתהליך הכנה)
      await _firestore.collection('orders').doc(order.orderId).update({
        'status': 'preparing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // שליחת התראה למזמין
      try {
        final orderNumber = order.orderNumber.toString();
        final providerName = order.providerName.isEmpty ? 'העסק' : order.providerName;
        await NotificationService.sendNotification(
          toUserId: order.customerId,
          title: 'הזמנה מאושרת',
          message: 'ההזמנה שלך ($orderNumber) מאושרת בתהליך הכנה מ-$providerName',
          type: 'order_approved',
          data: {
            'orderId': order.orderId,
            'orderNumber': orderNumber,
            'providerName': providerName,
          },
        );
        debugPrint('✅ Notification sent to customer: ${order.customerId}');
      } catch (notificationError) {
        debugPrint('⚠️ Error sending notification to customer: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה אושרה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה באישור ההזמנה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOrder(order_model.Order order) async {
    // בדיקה אם יש משלוח ללא שליח
    if (order.deliveryType == 'delivery' && 
        order.courierId == null && 
        order.status == 'preparing') {
      // הצגת דיאלוג התראה
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('אין שליח משובץ'),
          content: const Text(
            'ההזמנה כוללת משלוח ועדיין אין שליח משובץ להזמנה זו.\n\n'
            'האם אתה בטוח שברצונך לסמן את ההזמנה כהושלמה?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('סמן כהושלמה'),
            ),
          ],
        ),
      );

      // אם המשתמש ביטל, לא נמשיך
      if (shouldContinue != true) {
        return;
      }
    }

    try {
      // עדכון הסטטוס ל-completed - ההזמנה תופיע בטאב "הושלמו" אצל העסק, המזמין והשליח (אם יש)
      // חשוב: שומרים את courierId, courierName, courierPhone אם הם קיימים כדי שהשליח יוכל לראות את ההזמנה בטאב "הושלמו"
      final updateData = <String, dynamic>{
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // אם יש שליח משובץ, נשמור את פרטיו כדי שההזמנה תופיע אצלו בטאב "הושלמו"
      if (order.courierId != null) {
        updateData['courierId'] = order.courierId;
        if (order.courierName != null) {
          updateData['courierName'] = order.courierName;
        }
        if (order.courierPhone != null) {
          updateData['courierPhone'] = order.courierPhone;
        }
      }
      
      await _firestore.collection('orders').doc(order.orderId).update(updateData);

      // טעינת ההזמנה המעודכנת מ-Firestore כדי לוודא שיש לנו את ה-courierId העדכני
      final updatedOrderDoc = await _firestore.collection('orders').doc(order.orderId).get();
      final updatedOrderData = updatedOrderDoc.data();
      final updatedCourierId = updatedOrderData?['courierId'] as String?;
      
      debugPrint('📦 Order completed - checking for courier notification:');
      debugPrint('   - Order ID: ${order.orderId}');
      debugPrint('   - Original courierId: ${order.courierId}');
      debugPrint('   - Updated courierId from Firestore: $updatedCourierId');

      // שליחת התראה למזמין
      try {
        final orderNumber = order.orderNumber.toString();
        String message;
        if (updatedCourierId != null && order.courierName != null) {
          message = 'ההזמנה שלך ($orderNumber) מוכנה, השליח: ${order.courierName}';
        } else {
          message = 'ההזמנה שלך ($orderNumber) מוכנה';
        }
        
        await NotificationService.sendNotification(
          toUserId: order.customerId,
          title: 'הזמנה מוכנה',
          message: message,
          type: 'order_ready',
          data: {
            'orderId': order.orderId,
            'orderNumber': orderNumber,
            'courierName': order.courierName,
          },
        );
        debugPrint('✅ Notification sent to customer: ${order.customerId}');
      } catch (notificationError) {
        debugPrint('⚠️ Error sending notification to customer: $notificationError');
      }

      // שליחת התראה לשליח אם יש שליח משובץ (בודקים גם את הערך המקורי וגם את הערך המעודכן)
      final courierIdToNotify = updatedCourierId ?? order.courierId;
      if (courierIdToNotify != null && courierIdToNotify.isNotEmpty) {
        try {
          final orderNumber = order.orderNumber.toString();
          final message = 'הזמנה מס ($orderNumber) הושלמה ומוכנה לשילוח!';
          
          debugPrint('📤 Sending notification to courier: $courierIdToNotify');
          debugPrint('   - Message: $message');
          debugPrint('   - Order ID: ${order.orderId}');
          
          await NotificationService.sendNotification(
            toUserId: courierIdToNotify,
            title: 'הזמנה מוכנה לשילוח',
            message: message,
            type: 'order_ready_for_delivery',
            data: {
              'orderId': order.orderId,
              'orderNumber': orderNumber,
              'providerName': order.providerName,
            },
          );
          debugPrint('✅ Notification sent to courier: $courierIdToNotify');
        } catch (notificationError) {
          debugPrint('⚠️ Error sending notification to courier: $notificationError');
          debugPrint('   - Error details: ${notificationError.toString()}');
        }
      } else {
        debugPrint('⚠️ No courier ID found - skipping courier notification');
        debugPrint('   - updatedCourierId: $updatedCourierId');
        debugPrint('   - order.courierId: ${order.courierId}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה סומנה כהושלמה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בסימון ההזמנה כהושלמה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// סימון הזמנה כ"בדרך" על ידי השליח
  Future<void> _markAsOnTheWay(order_model.Order order) async {
    try {
      // עדכון הסטטוס ל-isOnTheWay = true
      final updateData = <String, dynamic>{
        'isOnTheWay': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('orders').doc(order.orderId).update(updateData);

      // שליחת התראה למזמין
      try {
        final orderNumber = order.orderNumber.toString();
        final message = 'ההזמנה שלך ($orderNumber) מ- ${order.providerName}, בדרך אליך 😊';
        
        await NotificationService.sendNotification(
          toUserId: order.customerId,
          title: 'ההזמנה בדרך',
          message: message,
          type: 'order_on_the_way',
          data: {
            'orderId': order.orderId,
            'orderNumber': orderNumber,
            'providerName': order.providerName,
          },
        );
        debugPrint('✅ Notification sent to customer: ${order.customerId}');
      } catch (notificationError) {
        debugPrint('⚠️ Error sending notification to customer: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה סומנה כבדרך'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking order as on the way: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בסימון ההזמנה כבדרך: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// סימון הזמנה כ"נמסרה" על ידי השליח
  Future<void> _markAsDelivered(order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('סימון כנמסרה'),
        content: const Text(
          'האם אתה בטוח שההזמנה נמסרה ללקוח?\n\n'
          'ההזמנה תעבור לטאב "הושלמו" אצלך, אצל העסק ואצל המזמין.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('סמן כנמסרה'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // עדכון הסטטוס ל-completed ו-isDelivered ל-true - ההזמנה תופיע בטאב "הושלמו" אצל השליח, העסק והמזמין
        // וגם יוצג "נמסרה" אצל כל המשתמשים
        final updateData = <String, dynamic>{
          'status': 'completed',
          'isDelivered': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // אם יש שליח משובץ, נשמור את פרטיו כדי שההזמנה תופיע אצלו בטאב "הושלמו"
        if (order.courierId != null) {
          updateData['courierId'] = order.courierId;
          if (order.courierName != null) {
            updateData['courierName'] = order.courierName;
          }
          if (order.courierPhone != null) {
            updateData['courierPhone'] = order.courierPhone;
          }
        }
        
        await _firestore.collection('orders').doc(order.orderId).update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ההזמנה סומנה כנמסרה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error marking order as delivered: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בסימון ההזמנה כנמסרה: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelOrder(order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ביטול הזמנה'),
        content: const Text(
          'האם אתה בטוח שברצונך לבטל את ההזמנה?\n\n'
          'ההזמנה תחזור לטאב ממתינות.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('בטל הזמנה'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // החזרת ההזמנה למצב pending (ממתינות)
        await _firestore.collection('orders').doc(order.orderId).update({
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // שליחת התראה למזמין
        try {
          final orderNumber = order.orderNumber.toString();
          final providerName = order.providerName.isEmpty ? 'העסק' : order.providerName;
          await NotificationService.sendNotification(
            toUserId: order.customerId,
            title: 'הזמנה בוטלה',
            message: 'ההזמנה שלך ($orderNumber) בוטלה על ידי $providerName והוחזרה לממתינות',
            type: 'order_cancelled',
            data: {
              'orderId': order.orderId,
              'orderNumber': orderNumber,
              'providerName': providerName,
            },
          );
          debugPrint('✅ Notification sent to customer: ${order.customerId}');
        } catch (notificationError) {
          debugPrint('⚠️ Error sending notification to customer: $notificationError');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ההזמנה בוטלה והוחזרה לממתינות'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error cancelling order: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בביטול ההזמנה: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectOrder(order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('דחיית הזמנה'),
        content: const Text('האם אתה בטוח שברצונך לדחות את ההזמנה?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('דחה'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('orders').doc(order.orderId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // שליחת התראה למזמין
        try {
          final orderNumber = order.orderNumber.toString();
          final providerName = order.providerName.isEmpty ? 'העסק' : order.providerName;
          await NotificationService.sendNotification(
            toUserId: order.customerId,
            title: 'הזמנה נדחתה',
            message: 'מצטערים ההזמנה שלך ($orderNumber) נדחתה על ידי $providerName',
            type: 'order_rejected',
            data: {
              'orderId': order.orderId,
              'orderNumber': orderNumber,
              'providerName': providerName,
            },
          );
          debugPrint('✅ Notification sent to customer: ${order.customerId}');
        } catch (notificationError) {
          debugPrint('⚠️ Error sending notification to customer: $notificationError');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ההזמנה נדחתה'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error rejecting order: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בדחיית ההזמנה: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// הצגת דיאלוג עם מפה שמציגה את מיקום העסק וכתובת המשלוח
  Future<void> _showMapDialog(
    double businessLat,
    double businessLng,
    String businessName,
    String businessAddress,
    double deliveryLat,
    double deliveryLng,
    String deliveryAddress,
  ) async {
    // חישוב מרחק
    final distance = LocationService.calculateDistance(
      businessLat,
      businessLng,
      deliveryLat,
      deliveryLng,
    );

    // קבלת המיקום הנוכחי של השליח (אם הוא שליח)
    double? courierLat;
    double? courierLng;
    String? courierName;
    
    if (_isCourier == true) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          // ניסיון לקבל את המיקום הנוכחי מהמכשיר
          final position = await LocationService.getCurrentPosition();
          if (position != null) {
            courierLat = position.latitude;
            courierLng = position.longitude;
            courierName = _userProfile?.displayName ?? 'מיקום נוכחי';
          } else {
            // אם לא הצלחנו לקבל מיקום מהמכשיר, ננסה לקבל מ-Firestore
            final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
            final userData = userDoc.data();
            courierLat = (userData?['mobileLatitude'] as num?)?.toDouble() ?? 
                        (userData?['latitude'] as num?)?.toDouble();
            courierLng = (userData?['mobileLongitude'] as num?)?.toDouble() ?? 
                        (userData?['longitude'] as num?)?.toDouble();
            courierName = _userProfile?.displayName ?? 'מיקום נוכחי';
          }
        } catch (e) {
          debugPrint('Error getting courier location: $e');
        }
      }
    }

    // חישוב מרכז המפה - כולל את המיקום הנוכחי של השליח אם קיים
    double centerLat;
    double centerLng;
    if (courierLat != null && courierLng != null) {
      // ממוצע של שלושת הנקודות
      centerLat = (businessLat + deliveryLat + courierLat) / 3;
      centerLng = (businessLng + deliveryLng + courierLng) / 3;
    } else {
      // ממוצע של שתי הנקודות
      centerLat = (businessLat + deliveryLat) / 2;
      centerLng = (businessLng + deliveryLng) / 2;
    }

    // חישוב המרחק המקסימלי לזום
    double maxDistance = distance;
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
      maxDistance = [distance, distanceToBusiness, distanceToDelivery].reduce((a, b) => a > b ? a : b);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'מיקום העסק וכתובת המשלוח',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // מידע על המרחק
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'מרחק: ${distance.toStringAsFixed(2)} ק"מ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // מפה
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(centerLat, centerLng),
                      zoom: _calculateZoom(maxDistance),
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('business'),
                        position: LatLng(businessLat, businessLng),
                        infoWindow: InfoWindow(
                          title: businessName,
                          snippet: businessAddress,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      ),
                      Marker(
                        markerId: const MarkerId('delivery'),
                        position: LatLng(deliveryLat, deliveryLng),
                        infoWindow: InfoWindow(
                          title: 'כתובת למשלוח',
                          snippet: deliveryAddress,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                      // מיקום נוכחי של השליח (אם קיים)
                      if (courierLat != null && courierLng != null)
                        Marker(
                          markerId: const MarkerId('courier'),
                          position: LatLng(courierLat, courierLng),
                          infoWindow: InfoWindow(
                            title: 'מיקום נוכחי',
                            snippet: courierName ?? 'שלי',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // כפתור לפתיחת Waze לכתובת המשלוח
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openWazeNavigation(deliveryLat, deliveryLng);
                },
                icon: Image.asset(
                  'assets/images/waze.png',
                  width: 24,
                  height: 24,
                ),
                label: const Text('נווט ב-Waze לכתובת המשלוח'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// חישוב זום מתאים לפי המרחק
  double _calculateZoom(double distanceKm) {
    if (distanceKm < 1) return 15.0;
    if (distanceKm < 5) return 13.0;
    if (distanceKm < 10) return 12.0;
    if (distanceKm < 20) return 11.0;
    return 10.0;
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

  /// פותח את אפליקציית Waze לניווט למיקום המבוקש
  Future<void> _openWazeNavigation(double latitude, double longitude) async {
    try {
      // ניסיון לפתוח את Waze ישירות (אם מותקן)
      final wazeAppUri = Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes');
      
      // ניסיון לפתוח את Waze ישירות
      bool launched = false;
      try {
        launched = await launchUrl(wazeAppUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Waze app not found, trying web URL: $e');
      }
      
      // אם Waze לא מותקן, נפתח את Waze דרך הדפדפן
      if (!launched) {
        final wazeWebUri = Uri.parse('https://waze.com/ul?q=$latitude,$longitude&navigate=yes');
        launched = await launchUrl(wazeWebUri, mode: LaunchMode.externalApplication);
      }
      
      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא ניתן לפתוח את Waze. אנא ודא שהאפליקציה מותקנת.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening Waze: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בפתיחת Waze: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // תצוגת שבוע עבור עסקים עם קביעת תורים
  Widget _buildAppointmentWeekView(String userId) {
    // חישוב מספר השבועות בחודש הנבחר
    final weeksInMonth = _getWeeksInMonth(_selectedYear, _selectedMonth);
    
    // וידוא ש-_selectedWeek לא גדול ממספר השבועות
    if (_selectedWeek > weeksInMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedWeek = weeksInMonth;
          _selectedWeekStart = _calculateWeekDate(_selectedYear, _selectedMonth, _selectedWeek);
        });
      });
    }
    
    return CustomScrollView(
      slivers: [
        // סליידרים קבועים בחלק העליון - נשארים קבועים בעת גלילה
        SliverToBoxAdapter(
          child: Container(
            color: Colors.blue[50],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  // סליידר בחירת שנה
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'בחר שנה:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text('${DateTime.now().year}'),
                            Expanded(
                              child: Slider(
                                value: _selectedYear.toDouble(),
                                min: DateTime.now().year.toDouble(),
                                max: (DateTime.now().year + 1).toDouble(),
                                divisions: 1,
                                label: '$_selectedYear',
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value.toInt();
                                    // עדכון השבוע אם צריך
                                    final newWeeksInMonth = _getWeeksInMonth(_selectedYear, _selectedMonth);
                                    if (_selectedWeek > newWeeksInMonth) {
                                      _selectedWeek = newWeeksInMonth;
                                    }
                                    _selectedWeekStart = _calculateWeekDate(_selectedYear, _selectedMonth, _selectedWeek);
                                  });
                                },
                              ),
                            ),
                            Text('${DateTime.now().year + 1}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // סליידר בחירת חודש
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'בחר חודש:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Text('1'),
                            Expanded(
                              child: Slider(
                                value: _selectedMonth.toDouble(),
                                min: 1,
                                max: 12,
                                divisions: 11,
                                label: _getMonthName(_selectedMonth),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMonth = value.toInt();
                                    // עדכון השבוע אם צריך
                                    final newWeeksInMonth = _getWeeksInMonth(_selectedYear, _selectedMonth);
                                    if (_selectedWeek > newWeeksInMonth) {
                                      _selectedWeek = newWeeksInMonth;
                                    }
                                    _selectedWeekStart = _calculateWeekDate(_selectedYear, _selectedMonth, _selectedWeek);
                                  });
                                },
                              ),
                            ),
                            const Text('12'),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _getMonthName(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // סליידר בחירת שבוע
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'בחר שבוע:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Text('1'),
                            Expanded(
                              child: Slider(
                                value: _selectedWeek.clamp(1, weeksInMonth).toDouble(),
                                min: 1,
                                max: weeksInMonth.toDouble(),
                                divisions: weeksInMonth > 1 ? weeksInMonth - 1 : 0,
                                label: 'שבוע ${_selectedWeek.clamp(1, weeksInMonth)}',
                                onChanged: (value) {
                                  setState(() {
                                    _selectedWeek = value.toInt();
                                    _selectedWeekStart = _calculateWeekDate(_selectedYear, _selectedMonth, _selectedWeek);
                                  });
                                },
                              ),
                            ),
                            Text('$weeksInMonth'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // תצוגת השבוע - scrollable
        _buildWeekCalendarSliver(userId),
      ],
    );
  }

  // חישוב תאריך השבוע לפי שנה, חודש ושבוע
  DateTime _calculateWeekDate(int year, int month, int week) {
    // מציאת היום הראשון של החודש
    final firstDayOfMonth = DateTime(year, month, 1);
    
    // מציאת ראשון השבוע הראשון של החודש
    final firstDayWeekday = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    final firstWeekStart = firstDayOfMonth.subtract(Duration(days: firstDayWeekday));
    
    // חישוב תחילת השבוע הנבחר (שבוע 1 = השבוע הראשון, שבוע 2 = השבוע השני, וכו')
    final weekStart = firstWeekStart.add(Duration(days: (week - 1) * 7));
    
    return weekStart;
  }

  // חישוב מספר השבועות בחודש
  int _getWeeksInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    
    // מציאת ראשון השבוע הראשון
    final firstDayWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final firstWeekStart = firstDay.subtract(Duration(days: firstDayWeekday));
    
    // מציאת ראשון השבוע האחרון
    final lastDayWeekday = lastDay.weekday == 7 ? 0 : lastDay.weekday;
    final lastWeekStart = lastDay.subtract(Duration(days: lastDayWeekday));
    
    // חישוב מספר השבועות
    final weeks = ((lastWeekStart.difference(firstWeekStart).inDays) / 7).floor() + 1;
    
    return weeks;
  }

  // שם חודש בעברית
  String _getMonthName(int month) {
    const months = [
      'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
      'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
    ];
    return months[month - 1];
  }

  // תצוגת לוח שנה שבועי - Sliver
  Widget _buildWeekCalendarSliver(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadWeekAppointments(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text('שגיאה בטעינת התורים: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final appointmentSettings = data['settings'] as AppointmentSettings?;
        final bookedAppointments = data['booked'] as List<Appointment>? ?? [];
        final ordersWithAppointments = data['orders'] as List<order_model.Order>? ?? [];

        if (appointmentSettings == null || appointmentSettings.slots.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Text('לא הוגדרו תורים זמינים'),
            ),
          );
        }

        // חישוב ימי השבוע
        final daysToSubtract = _selectedWeekStart.weekday == 7 ? 0 : _selectedWeekStart.weekday;
        final weekStart = _selectedWeekStart.subtract(Duration(days: daysToSubtract));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, dayIndex) {
              final day = weekStart.add(Duration(days: dayIndex));
              final dayOfWeek = _convertWeekdayToDayOfWeekIndex(day.weekday);
              final daySlots = appointmentSettings.slots
                  .where((slot) => slot.dayOfWeek == dayOfWeek)
                  .toList();

              if (daySlots.isEmpty) {
                return const SizedBox.shrink();
              }

              return _buildDayColumn(day, dayOfWeek, daySlots, bookedAppointments, ordersWithAppointments);
            },
            childCount: 7,
          ),
        );
      },
    );
  }

  // עמודה ליום אחד
  Widget _buildDayColumn(
    DateTime day,
    int dayOfWeek,
    List<AppointmentSlot> daySlots,
    List<Appointment> bookedAppointments,
    List<order_model.Order> ordersWithAppointments,
  ) {
    final dayName = _getDayNameHebrew(dayOfWeek);
    final dateStr = _formatDateOnly(day);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // כותרת היום
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'יום $dayName, $dateStr',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // רשימת תורים
          ...daySlots.expand((slot) => _generateTimeSlotsForDay(
                day,
                slot,
                bookedAppointments,
                ordersWithAppointments,
              )),
        ],
      ),
    );
  }

  // יצירת תורים ליום אחד
  List<Widget> _generateTimeSlotsForDay(
    DateTime day,
    AppointmentSlot slot,
    List<Appointment> bookedAppointments,
    List<order_model.Order> ordersWithAppointments,
  ) {
    final slots = <Widget>[];
    final startTime = _parseTime(slot.startTime);
    final endTime = _parseTime(slot.endTime);
    final duration = slot.durationMinutes;

    var currentTime = startTime;
    while (currentTime.add(Duration(minutes: duration)).isBefore(endTime) ||
           currentTime.add(Duration(minutes: duration)) == endTime) {
      final slotEnd = currentTime.add(Duration(minutes: duration));
      final slotTimeStr = _formatTime(currentTime);
      final slotDateOnly = DateTime(day.year, day.month, day.day);

      // מציאת תור תפוס
      Appointment? bookedAppointment;
      for (final apt in bookedAppointments) {
        bool matches = false;
        if (apt.appointmentDate != null) {
          final aptDateOnly = DateTime(
            apt.appointmentDate!.year,
            apt.appointmentDate!.month,
            apt.appointmentDate!.day,
          );
          matches = aptDateOnly == slotDateOnly &&
                   apt.startTime == slotTimeStr &&
                   !apt.isAvailable;
        }
        if (matches) {
          bookedAppointment = apt;
          break;
        }
      }

      // מציאת הזמנה קשורה - נחפש לפי appointmentId
      order_model.Order? relatedOrder;
      if (bookedAppointment != null) {
        try {
          relatedOrder = ordersWithAppointments.firstWhere(
            (order) {
              // נבדוק אם יש appointmentId בהזמנה
              // נטען את זה מ-Firestore אם צריך
              return false; // נטען את זה בדיאלוג
            },
            orElse: () => ordersWithAppointments.first,
          );
        } catch (e) {
          relatedOrder = null;
        }
      }

      slots.add(
        _buildTimeSlotCard(
          day,
          slotTimeStr,
          _formatTime(slotEnd),
          bookedAppointment,
          relatedOrder,
        ),
      );

      currentTime = slotEnd;
    }

    return slots;
  }

  // כרטיס תור
  Widget _buildTimeSlotCard(
    DateTime date,
    String startTime,
    String endTime,
    Appointment? bookedAppointment,
    order_model.Order? order,
  ) {
    final isBooked = bookedAppointment != null;
    final appointment = bookedAppointment; // Capture for type promotion

    return InkWell(
      onTap: isBooked && appointment != null ? () => _showAppointmentDetailsDialog(appointment, order) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isBooked ? Colors.orange[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBooked ? Colors.orange[300]! : Colors.green[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$startTime - $endTime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBooked ? Colors.orange[900] : Colors.green[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isBooked)
              const Icon(Icons.event_busy, color: Colors.orange)
            else
              const Icon(Icons.event_available, color: Colors.green),
          ],
        ),
      ),
    );
  }

  // טעינת תורים לשבוע
  Future<Map<String, dynamic>> _loadWeekAppointments(String userId) async {
    try {
      // טעינת הגדרות תורים
      final settingsDoc = await _firestore
          .collection('appointments')
          .doc(userId)
          .get();

      AppointmentSettings? settings;
      if (settingsDoc.exists) {
        settings = AppointmentSettings.fromFirestore(settingsDoc);
      }

      // טעינת תורים תפוסים
      final bookedQuery = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .where('isAvailable', isEqualTo: false)
          .get();

      final bookedAppointments = bookedQuery.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();

      // טעינת הזמנות עם תורים
      final ordersQuery = await _firestore
          .collection('orders')
          .where('providerId', isEqualTo: userId)
          .where('appointmentId', isNotEqualTo: null)
          .get();

      final orders = ordersQuery.docs
          .map((doc) => order_model.Order.fromFirestore(doc))
          .toList();

      return {
        'settings': settings,
        'booked': bookedAppointments,
        'orders': orders,
      };
    } catch (e) {
      debugPrint('Error loading week appointments: $e');
      return {};
    }
  }

  // המרת DateTime.weekday ל-DayOfWeek enum index
  int _convertWeekdayToDayOfWeekIndex(int weekday) {
    return weekday == 7 ? 0 : weekday;
  }

  // שם יום בעברית
  String _getDayNameHebrew(int dayOfWeek) {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }

  // המרת זמן
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  // פורמט זמן
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // דיאלוג פרטי המזמין
  Future<void> _showAppointmentDetailsDialog(Appointment appointment, order_model.Order? order) async {
    order_model.Order? loadedOrder = order;
    
    // נטען את ההזמנה אם לא קיבלנו אותה
    if (loadedOrder == null) {
      try {
        final orderQuery = await _firestore
            .collection('orders')
            .where('appointmentId', isEqualTo: appointment.appointmentId)
            .limit(1)
            .get();

        if (orderQuery.docs.isNotEmpty) {
          loadedOrder = order_model.Order.fromFirestore(orderQuery.docs.first);
        }
      } catch (e) {
        debugPrint('Error loading order: $e');
      }
    }

    if (loadedOrder == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא נמצאה הזמנה קשורה'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final finalOrder = loadedOrder;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרטי התור'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('שם המזמין: ${finalOrder.customerName}'),
              const SizedBox(height: 8),
              Text('טלפון: ${finalOrder.customerPhone}'),
              const SizedBox(height: 8),
              const Text('שירותים:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...finalOrder.items.map((item) => Padding(
                    padding: const EdgeInsets.only(right: 16, top: 4),
                    child: Text('• ${item.serviceName} x${item.quantity}'),
                  )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _cancelAppointment(appointment, finalOrder),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('בטל תור'),
                  ),
                  ElevatedButton(
                    onPressed: () => _moveAppointment(appointment, finalOrder),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text('הזז תור'),
                  ),
                ],
              ),
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
  }

  // ביטול תור
  Future<void> _cancelAppointment(Appointment appointment, order_model.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ביטול תור'),
        content: const Text('האם אתה בטוח שברצונך לבטל את התור הזה?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('בטל תור'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // שחרור התור
      await _firestore
          .collection('appointments')
          .doc(appointment.appointmentId)
          .update({
        'isAvailable': true,
        'bookedBy': null,
        'orderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // עדכון ההזמנה
      await _firestore
          .collection('orders')
          .doc(order.orderId)
          .update({
        'appointmentId': null,
        'appointmentDate': null,
        'appointmentStartTime': null,
        'appointmentEndTime': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // שליחת התראה למזמין
      await NotificationService.sendNotification(
        toUserId: order.customerId,
        title: 'תור בוטל',
        message: 'התור שלך בוטל על ידי ${order.providerName}',
        type: 'appointment_cancelled',
        data: {
          'orderId': order.orderId,
          'appointmentId': appointment.appointmentId,
        },
      );

      if (mounted) {
        Navigator.pop(context); // סגירת דיאלוג הפרטים
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התור בוטל בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בביטול התור: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // הזזת תור
  Future<void> _moveAppointment(Appointment appointment, order_model.Order order) async {
    // נסגור את הדיאלוג הנוכחי ונפתח מסך בחירת תור חדש
    Navigator.pop(context); // סגירת דיאלוג הפרטים

    // פתיחת מסך בחירת תור חדש
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderAppointmentMoveScreen(
          providerId: order.providerId,
          currentAppointment: appointment,
          order: order,
        ),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('התור הוזז בהצלחה'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

// מסך הזזת תור
class OrderAppointmentMoveScreen extends StatefulWidget {
  final String providerId;
  final Appointment currentAppointment;
  final order_model.Order order;

  const OrderAppointmentMoveScreen({
    super.key,
    required this.providerId,
    required this.currentAppointment,
    required this.order,
  });

  @override
  State<OrderAppointmentMoveScreen> createState() => _OrderAppointmentMoveScreenState();
}

class _OrderAppointmentMoveScreenState extends State<OrderAppointmentMoveScreen> {
  List<AppointmentSlot> _availableSlots = [];
  List<Appointment> _bookedAppointments = [];
  bool _isLoading = true;
  DateTime _selectedWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.providerId)
          .get();

      if (settingsDoc.exists) {
        final settings = AppointmentSettings.fromFirestore(settingsDoc);
        setState(() {
          _availableSlots = settings.slots;
        });
      }

      final bookedQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: widget.providerId)
          .where('isAvailable', isEqualTo: false)
          .get();

      setState(() {
        _bookedAppointments = bookedQuery.docs
            .map((doc) => Appointment.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _convertWeekdayToDayOfWeekIndex(int weekday) {
    return weekday == 7 ? 0 : weekday;
  }

  List<TimeSlot> _generateTimeSlotsForWeek() {
    final slots = <TimeSlot>[];
    final daysToSubtract = _selectedWeekStart.weekday == 7 ? 0 : _selectedWeekStart.weekday;
    final weekStart = _selectedWeekStart.subtract(Duration(days: daysToSubtract));

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = weekStart.add(Duration(days: dayOffset));
      final dayOfWeek = _convertWeekdayToDayOfWeekIndex(day.weekday);
      final daySlots = _availableSlots.where((slot) => slot.dayOfWeek == dayOfWeek).toList();

      for (final slot in daySlots) {
        final startTime = _parseTime(slot.startTime);
        final endTime = _parseTime(slot.endTime);
        final duration = slot.durationMinutes;

        var currentTime = startTime;
        while (currentTime.add(Duration(minutes: duration)).isBefore(endTime) ||
               currentTime.add(Duration(minutes: duration)) == endTime) {
          final slotEnd = currentTime.add(Duration(minutes: duration));
          final timeSlot = TimeSlot(
            date: day,
            startTime: currentTime,
            endTime: slotEnd,
            dayOfWeek: dayOfWeek,
          );

          final slotTimeStr = _formatTime(currentTime);
          final slotDateOnly = DateTime(day.year, day.month, day.day);

          final isBooked = _bookedAppointments.any((apt) {
            if (apt.appointmentDate != null) {
              final aptDateOnly = DateTime(
                apt.appointmentDate!.year,
                apt.appointmentDate!.month,
                apt.appointmentDate!.day,
              );
              return aptDateOnly == slotDateOnly &&
                     apt.startTime == slotTimeStr &&
                     !apt.isAvailable;
            } else {
              return apt.dayOfWeek == dayOfWeek &&
                     apt.startTime == slotTimeStr &&
                     !apt.isAvailable;
            }
          });

          timeSlot.isBooked = isBooked;
          slots.add(timeSlot);

          currentTime = slotEnd;
        }
      }
    }

    return slots;
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _moveToSlot(TimeSlot slot) async {
    try {
      // שחרור התור הישן
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.currentAppointment.appointmentId)
          .update({
        'isAvailable': true,
        'bookedBy': null,
        'orderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // יצירת תור חדש
      final appointmentId = FirebaseFirestore.instance.collection('appointments').doc().id;
      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .set({
        'userId': widget.providerId,
        'dayOfWeek': slot.dayOfWeek,
        'startTime': _formatTime(slot.startTime),
        'endTime': _formatTime(slot.endTime),
        'durationMinutes': slot.endTime.difference(slot.startTime).inMinutes,
        'isAvailable': false,
        'bookedBy': widget.order.customerId,
        'bookedAt': Timestamp.fromDate(now),
        'appointmentDate': Timestamp.fromDate(slot.date),
        'orderId': widget.order.orderId,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // עדכון ההזמנה
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.orderId)
          .update({
        'appointmentId': appointmentId,
        'appointmentDate': Timestamp.fromDate(slot.date),
        'appointmentStartTime': _formatTime(slot.startTime),
        'appointmentEndTime': _formatTime(slot.endTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // שליחת התראה למזמין
      await NotificationService.sendNotification(
        toUserId: widget.order.customerId,
        title: 'תור הוזז',
        message: 'התור שלך הוזז ל-${_formatDate(slot.date)} ${_formatTime(slot.startTime)}',
        type: 'appointment_moved',
        data: {
          'orderId': widget.order.orderId,
          'appointmentId': appointmentId,
        },
      );

      if (mounted) {
        Navigator.of(context).pop({'moved': true});
      }
    } catch (e) {
      debugPrint('Error moving appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהזזת התור: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDayNameHebrew(int dayOfWeek) {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הזזת תור'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _selectedWeekStart = _selectedWeekStart.subtract(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                      Text(
                        '${_formatDate(_selectedWeekStart)} - ${_formatDate(_selectedWeekStart.add(const Duration(days: 6)))}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _selectedWeekStart = _selectedWeekStart.add(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _generateTimeSlotsForWeek().where((s) => !s.isBooked).length,
                    itemBuilder: (context, index) {
                      final availableSlots = _generateTimeSlotsForWeek().where((s) => !s.isBooked).toList();
                      final slot = availableSlots[index];
                      final dayName = _getDayNameHebrew(slot.dayOfWeek);
                      final dateStr = _formatDate(slot.date);
                      final timeStr = '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.access_time, color: Colors.green),
                          title: Text('יום $dayName, $dateStr'),
                          subtitle: Text(timeStr),
                          trailing: ElevatedButton(
                            onPressed: () => _moveToSlot(slot),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text('הזז לכאן'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class TimeSlot {
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int dayOfWeek;
  bool isBooked;

  TimeSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
    this.isBooked = false,
  });
}

