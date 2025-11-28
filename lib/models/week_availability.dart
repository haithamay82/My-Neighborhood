enum DayOfWeek {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
}

class DayAvailability {
  final DayOfWeek day;
  final bool isAvailable;
  final String? startTime; // Format: "HH:mm" (e.g., "09:00")
  final String? endTime; // Format: "HH:mm" (e.g., "17:00")

  DayAvailability({
    required this.day,
    this.isAvailable = false,
    this.startTime,
    this.endTime,
  });

  factory DayAvailability.fromFirestore(Map<String, dynamic> data) {
    return DayAvailability(
      day: DayOfWeek.values.firstWhere(
        (e) => e.name == data['day'],
        orElse: () => DayOfWeek.sunday,
      ),
      isAvailable: data['isAvailable'] ?? false,
      startTime: data['startTime'],
      endTime: data['endTime'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'day': day.name,
      'isAvailable': isAvailable,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  DayAvailability copyWith({
    DayOfWeek? day,
    bool? isAvailable,
    String? startTime,
    String? endTime,
  }) {
    return DayAvailability(
      day: day ?? this.day,
      isAvailable: isAvailable ?? this.isAvailable,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class WeekAvailability {
  final List<DayAvailability> days;

  WeekAvailability({List<DayAvailability>? days})
      : days = days ??
            DayOfWeek.values
                .map((day) => DayAvailability(day: day, isAvailable: false))
                .toList();

  factory WeekAvailability.fromFirestore(List<dynamic> data) {
    return WeekAvailability(
      days: data
          .map((e) => DayAvailability.fromFirestore(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<Map<String, dynamic>> toFirestore() {
    return days.map((day) => day.toFirestore()).toList();
  }

  WeekAvailability copyWith({List<DayAvailability>? days}) {
    return WeekAvailability(days: days ?? this.days);
  }

  // Helper to get availability for a specific day
  DayAvailability? getDayAvailability(DayOfWeek day) {
    try {
      return days.firstWhere((d) => d.day == day);
    } catch (e) {
      return null;
    }
  }
}

extension DayOfWeekExtension on DayOfWeek {
  String get displayName {
    switch (this) {
      case DayOfWeek.sunday:
        return 'ראשון';
      case DayOfWeek.monday:
        return 'שני';
      case DayOfWeek.tuesday:
        return 'שלישי';
      case DayOfWeek.wednesday:
        return 'רביעי';
      case DayOfWeek.thursday:
        return 'חמישי';
      case DayOfWeek.friday:
        return 'שישי';
      case DayOfWeek.saturday:
        return 'שבת';
    }
  }
}

