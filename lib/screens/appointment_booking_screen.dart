import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../models/appointment.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final String adId;
  final String providerId;

  const AppointmentBookingScreen({
    super.key,
    required this.adId,
    required this.providerId,
  });

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
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
      // טעינת הגדרות התורים של נותן השירות
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

      // טעינת תורים תפוסים
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
      debugPrint('❌ Error loading appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // המרת DateTime.weekday ל-DayOfWeek enum index
  // DateTime.weekday: 1=שני, 2=שלישי, ..., 7=ראשון
  // DayOfWeek index: 0=ראשון, 1=שני, ..., 6=שבת
  int _convertWeekdayToDayOfWeekIndex(int weekday) {
    // אם זה ראשון (7), מחזיר 0
    // אחרת מחזיר weekday כמו שהוא (1=שני->1, 2=שלישי->2, וכו')
    return weekday == 7 ? 0 : weekday;
  }

  // יצירת רשימת תורים אפשריים משבוע
  List<TimeSlot> _generateTimeSlotsForWeek() {
    final slots = <TimeSlot>[];
    
    // התחלה משבוע הנוכחי - חישוב ימים לחזרה לראשון
    final daysToSubtract = _selectedWeekStart.weekday == 7 ? 0 : _selectedWeekStart.weekday;
    final weekStart = _selectedWeekStart.subtract(Duration(days: daysToSubtract));

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = weekStart.add(Duration(days: dayOffset));
      final dayOfWeek = _convertWeekdayToDayOfWeekIndex(day.weekday); // 0 = ראשון, 6 = שבת

      // מציאת slots זמינים ליום זה
      final daySlots = _availableSlots.where((slot) => slot.dayOfWeek == dayOfWeek).toList();

      for (final slot in daySlots) {
        final startTime = _parseTime(slot.startTime);
        final endTime = _parseTime(slot.endTime);
        final duration = slot.durationMinutes;

        // יצירת תורים לפי משך
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

          // בדיקה אם התור תפוס לפי תאריך מדויק ושעה
          final slotTimeStr = _formatTime(currentTime);
          final slotDateOnly = DateTime(day.year, day.month, day.day);
          
          final isBooked = _bookedAppointments.any((apt) {
            // בדיקה לפי תאריך מדויק (אם קיים) או לפי יום בשבוע ושעה
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
              // fallback לבדיקה לפי יום בשבוע ושעה
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

  Future<void> _bookAppointment(TimeSlot slot) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // יצירת תור חדש
      final appointmentId = FirebaseFirestore.instance.collection('appointments').doc().id;
      final now = DateTime.now();

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .set({
        'userId': widget.providerId,
        'adId': widget.adId,
        'dayOfWeek': slot.dayOfWeek,
        'startTime': _formatTime(slot.startTime),
        'endTime': _formatTime(slot.endTime),
        'durationMinutes': slot.endTime.difference(slot.startTime).inMinutes,
        'isAvailable': false,
        'bookedBy': currentUserId,
        'bookedAt': Timestamp.fromDate(now),
        'appointmentDate': Timestamp.fromDate(slot.date), // תאריך מדויק של התור
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        Navigator.of(context).pop({
          'appointmentId': appointmentId,
          'date': slot.date,
          'startTime': _formatTime(slot.startTime),
          'endTime': _formatTime(slot.endTime),
        });
      }
    } catch (e) {
      debugPrint('❌ Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת התור: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('בחירת תור'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF9C27B0)
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _availableSlots.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'אין תורים זמינים כרגע',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // בחירת שבוע
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
                      // רשימת תורים
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _generateTimeSlotsForWeek().length,
                          itemBuilder: (context, index) {
                            final slot = _generateTimeSlotsForWeek()[index];
                            return _buildTimeSlotCard(slot);
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot) {
    final dayName = _getDayNameHebrew(slot.dayOfWeek);
    final dateStr = _formatDate(slot.date);
    final timeStr = '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: slot.isBooked
          ? Colors.grey[300]
          : Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: Icon(
          slot.isBooked ? Icons.block : Icons.access_time,
          color: slot.isBooked ? Colors.grey : Colors.green,
        ),
        title: Text('יום $dayName, $dateStr'),
        subtitle: Text(timeStr),
        trailing: slot.isBooked
            ? const Chip(
                label: Text('תפוס'),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
              )
            : ElevatedButton(
                onPressed: () => _bookAppointment(slot),
                child: const Text('בחר'),
              ),
      ),
    );
  }

  String _getDayNameHebrew(int dayOfWeek) {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

