import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל להזמנה
class Order {
  final String orderId;
  final String customerId; // ID של הלקוח
  final String customerName; // שם הלקוח
  final String customerPhone; // טלפון הלקוח
  final String providerId; // ID של נותן השירות
  final String providerName; // שם נותן השירות
  final List<OrderItem> items; // רשימת השירותים בהזמנה
  final double totalPrice; // סך הכל מחיר
  final double? deliveryFee; // עלות משלוח (אם יש)
  final String? deliveryType; // 'pickup' או 'delivery'
  final Map<String, dynamic>? deliveryLocation; // מיקום למשלוח
  final String? deliveryCategory; // קטגוריית משלוח (foodDelivery, groceryDelivery, smallMoving, largeMoving)
  final String paymentType; // 'cash', 'bit', 'credit'
  final String status; // 'pending', 'confirmed', 'completed', 'cancelled'
  final String? courierId; // ID של השליח (אם יש)
  final String? courierName; // שם השליח (אם יש)
  final String? courierPhone; // טלפון השליח (אם יש)
  final int orderNumber; // מספר הזמנה (החל מ-100, רץ לכל עסק בנפרד)
  final bool isDelivered; // האם ההזמנה נמסרה על ידי השליח
  final bool isOnTheWay; // האם ההזמנה בדרך (השליח לחץ על "ההזמנה בדרך")
  final DateTime? appointmentDate; // תאריך התור
  final String? appointmentStartTime; // שעת התחלת התור
  final String? appointmentEndTime; // שעת סיום התור
  final String? appointmentId; // מזהה התור
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.providerId,
    required this.providerName,
    required this.items,
    required this.totalPrice,
    this.deliveryFee,
    this.deliveryType,
    this.deliveryLocation,
    this.deliveryCategory,
    required this.paymentType,
    this.status = 'pending',
    this.courierId,
    this.courierName,
    this.courierPhone,
    required this.orderNumber,
    this.isDelivered = false,
    this.isOnTheWay = false,
    this.appointmentDate,
    this.appointmentStartTime,
    this.appointmentEndTime,
    this.appointmentId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Parse items with error handling
      final itemsList = <OrderItem>[];
      if (data['items'] != null && data['items'] is List) {
        final itemsData = data['items'] as List<dynamic>;
        for (var itemData in itemsData) {
          try {
            if (itemData is Map<String, dynamic>) {
              itemsList.add(OrderItem.fromMap(itemData));
            }
          } catch (e) {
            // Skip invalid items
            print('Error parsing order item: $e');
          }
        }
      }

      // Parse createdAt with better error handling
      DateTime createdAt;
      if (data['createdAt'] != null) {
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is DateTime) {
          createdAt = data['createdAt'] as DateTime;
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      // Parse updatedAt
      DateTime? updatedAt;
      if (data['updatedAt'] != null) {
        if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['updatedAt'] is DateTime) {
          updatedAt = data['updatedAt'] as DateTime;
        }
      }

      return Order(
        orderId: doc.id,
        customerId: data['customerId']?.toString() ?? '',
        customerName: data['customerName']?.toString() ?? '',
        customerPhone: data['customerPhone']?.toString() ?? '',
        providerId: data['providerId']?.toString() ?? '',
        providerName: data['providerName']?.toString() ?? '',
        items: itemsList,
        totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
        deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
        deliveryType: data['deliveryType']?.toString(),
        deliveryLocation: data['deliveryLocation'] as Map<String, dynamic>?,
        deliveryCategory: data['deliveryCategory']?.toString(),
        paymentType: data['paymentType']?.toString() ?? 'cash',
        status: data['status']?.toString() ?? 'pending',
        courierId: data['courierId']?.toString(),
        courierName: data['courierName']?.toString(),
        courierPhone: data['courierPhone']?.toString(),
        orderNumber: data['orderNumber'] as int? ?? 0,
        isDelivered: data['isDelivered'] == true,
        isOnTheWay: data['isOnTheWay'] == true,
        appointmentDate: data['appointmentDate'] != null && data['appointmentDate'] is Timestamp
            ? (data['appointmentDate'] as Timestamp).toDate()
            : null,
        appointmentStartTime: data['appointmentStartTime']?.toString(),
        appointmentEndTime: data['appointmentEndTime']?.toString(),
        appointmentId: data['appointmentId']?.toString(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      print('Error parsing Order from Firestore: $e');
      print('Document ID: ${doc.id}');
      print('Document data: ${doc.data()}');
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'providerId': providerId,
      'providerName': providerName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalPrice': totalPrice,
      'deliveryFee': deliveryFee,
      'deliveryType': deliveryType,
      'deliveryLocation': deliveryLocation,
      'deliveryCategory': deliveryCategory,
      'paymentType': paymentType,
      'status': status,
      'courierId': courierId,
      'courierName': courierName,
      'courierPhone': courierPhone,
      'orderNumber': orderNumber,
      'isDelivered': isDelivered,
      'isOnTheWay': isOnTheWay,
      'appointmentDate': appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
      'appointmentStartTime': appointmentStartTime,
      'appointmentEndTime': appointmentEndTime,
      'appointmentId': appointmentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// מודל לפריט בהזמנה
class OrderItem {
  final String serviceName; // שם השירות
  final int quantity; // כמות
  final List<String> selectedIngredients; // מרכיבים שנבחרו
  final double? servicePrice; // מחיר השירות (אם לא בהתאמה אישית)
  final bool isCustomPrice; // האם מחיר בהתאמה אישית
  final double? totalItemPrice; // מחיר כולל מרכיבים

  OrderItem({
    required this.serviceName,
    required this.quantity,
    required this.selectedIngredients,
    this.servicePrice,
    this.isCustomPrice = false,
    this.totalItemPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    try {
      // Parse selectedIngredients with better error handling
      List<String> ingredients = [];
      if (map['selectedIngredients'] != null) {
        if (map['selectedIngredients'] is List) {
          ingredients = (map['selectedIngredients'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } else if (map['selectedIngredients'] is String) {
          ingredients = [map['selectedIngredients'] as String];
        }
      }

      // Parse quantity
      int quantity = 0;
      if (map['quantity'] != null) {
        if (map['quantity'] is int) {
          quantity = map['quantity'] as int;
        } else if (map['quantity'] is num) {
          quantity = (map['quantity'] as num).toInt();
        }
      }

      return OrderItem(
        serviceName: map['serviceName']?.toString() ?? '',
        quantity: quantity,
        selectedIngredients: ingredients,
        servicePrice: (map['servicePrice'] as num?)?.toDouble(),
        isCustomPrice: map['isCustomPrice'] == true,
        totalItemPrice: (map['totalItemPrice'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('Error parsing OrderItem from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceName': serviceName,
      'quantity': quantity,
      'selectedIngredients': selectedIngredients,
      'servicePrice': servicePrice,
      'isCustomPrice': isCustomPrice,
      'totalItemPrice': totalItemPrice,
    };
  }
}

