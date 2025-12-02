import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל לתור (Appointment)
class Appointment {
  final String appointmentId;
  final String userId; // נותן השירות
  final String? adId; // קישור למודעה (אם קיים)
  final int dayOfWeek; // 0 = ראשון, 1 = שני, ..., 6 = שבת
  final String startTime; // פורמט: "HH:mm" (למשל "09:00")
  final String endTime; // פורמט: "HH:mm" (למשל "17:00")
  final int durationMinutes; // משך תור בדקות (15, 30, 60, 90)
  final bool isAvailable; // האם התור פנוי או תפוס
  final String? bookedBy; // userId של מבקש השירות (אם תפוס)
  final DateTime? bookedAt; // תאריך ושעה של תפיסת התור
  final DateTime? appointmentDate; // תאריך מדויק של התור (אם קיים)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Appointment({
    required this.appointmentId,
    required this.userId,
    this.adId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.isAvailable,
    this.bookedBy,
    this.bookedAt,
    this.appointmentDate,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory method from Firestore
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Appointment(
      appointmentId: doc.id,
      userId: data['userId'] ?? '',
      adId: data['adId'],
      dayOfWeek: data['dayOfWeek'] ?? 0,
      startTime: data['startTime'] ?? '09:00',
      endTime: data['endTime'] ?? '17:00',
      durationMinutes: data['durationMinutes'] ?? 30,
      isAvailable: data['isAvailable'] ?? true,
      bookedBy: data['bookedBy'],
      bookedAt: data['bookedAt'] != null && data['bookedAt'] is Timestamp
          ? (data['bookedAt'] as Timestamp).toDate()
          : null,
      appointmentDate: data['appointmentDate'] != null && data['appointmentDate'] is Timestamp
          ? (data['appointmentDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'adId': adId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'isAvailable': isAvailable,
      'bookedBy': bookedBy,
      'bookedAt': bookedAt != null ? Timestamp.fromDate(bookedAt!) : null,
      'appointmentDate': appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Helper method to get day name in Hebrew
  String getDayNameHebrew() {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }

  // Helper method to check if a specific time slot is available
  bool isTimeSlotAvailable(String time) {
    if (!isAvailable) return false;
    if (bookedBy != null) return false;
    
    // Parse time strings
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    final check = _parseTime(time);
    
    return check.isAfter(start) || check.isAtSameMomentAs(start) &&
           (check.isBefore(end) || check.isAtSameMomentAs(end));
  }

  // Helper method to parse time string to DateTime (using today as base)
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

/// מודל להגדרת תורים של משתמש (AppointmentSettings)
class AppointmentSettings {
  final String userId;
  final bool useAppointments; // true = תורים, false = זמינות
  final List<AppointmentSlot> slots; // רשימת תורים
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppointmentSettings({
    required this.userId,
    required this.useAppointments,
    required this.slots,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory method from Firestore
  factory AppointmentSettings.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final slots = (data['slots'] as List<dynamic>?)
        ?.map((e) => AppointmentSlot.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];

    return AppointmentSettings(
      userId: doc.id,
      useAppointments: data['useAppointments'] ?? false,
      slots: slots,
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'useAppointments': useAppointments,
      'slots': slots.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// מודל להפסקה (BreakTime)
class BreakTime {
  final String startTime; // פורמט: "HH:mm"
  final String endTime; // פורמט: "HH:mm"

  BreakTime({
    required this.startTime,
    required this.endTime,
  });

  // Factory method from map
  factory BreakTime.fromMap(Map<String, dynamic> map) {
    return BreakTime(
      startTime: map['startTime'] ?? '12:00',
      endTime: map['endTime'] ?? '13:00',
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  // Copy with method
  BreakTime copyWith({
    String? startTime,
    String? endTime,
  }) {
    return BreakTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

/// מודל לתור בודד (AppointmentSlot)
class AppointmentSlot {
  final int dayOfWeek; // 0 = ראשון, 1 = שני, ..., 6 = שבת
  final String startTime; // פורמט: "HH:mm"
  final String endTime; // פורמט: "HH:mm"
  final int durationMinutes; // משך תור בדקות
  final List<BreakTime> breaks; // רשימת הפסקות

  AppointmentSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.breaks = const [],
  });

  // Factory method from map
  factory AppointmentSlot.fromMap(Map<String, dynamic> map) {
    final breaksList = (map['breaks'] as List<dynamic>?)
        ?.map((e) => BreakTime.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];
    
    return AppointmentSlot(
      dayOfWeek: map['dayOfWeek'] ?? 0,
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      durationMinutes: map['durationMinutes'] ?? 30,
      breaks: breaksList,
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'breaks': breaks.map((b) => b.toMap()).toList(),
    };
  }

  // Copy with method
  AppointmentSlot copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    List<BreakTime>? breaks,
  }) {
    return AppointmentSlot(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      breaks: breaks ?? this.breaks,
    );
  }

  // Helper method to get day name in Hebrew
  String getDayNameHebrew() {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }
}

