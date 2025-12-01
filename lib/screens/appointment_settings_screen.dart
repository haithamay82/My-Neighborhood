import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment.dart';
import '../l10n/app_localizations.dart';

class AppointmentSettingsScreen extends StatefulWidget {
  const AppointmentSettingsScreen({super.key});

  @override
  State<AppointmentSettingsScreen> createState() => _AppointmentSettingsScreenState();
}

class _AppointmentSettingsScreenState extends State<AppointmentSettingsScreen> {
  final List<AppointmentSlot> _slots = [];
  int _selectedDuration = 30; // 15, 30, 60, 90 דקות
  final List<int> _durationOptions = [15, 30, 60, 90];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppointmentSettings();
  }

  Future<void> _loadAppointmentSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final settings = AppointmentSettings.fromFirestore(doc);
        setState(() {
          _slots.clear();
          _slots.addAll(settings.slots);
          if (_slots.isNotEmpty) {
            _selectedDuration = _slots.first.durationMinutes;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading appointment settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAppointmentSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final settings = AppointmentSettings(
        userId: user.uid,
        useAppointments: true,
        slots: _slots,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .set(settings.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הגדרות התורים נשמרו בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving appointment settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת הגדרות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addDaySlot(int dayOfWeek) {
    setState(() {
      // בדיקה אם היום כבר קיים
      final existingIndex = _slots.indexWhere((slot) => slot.dayOfWeek == dayOfWeek);
      if (existingIndex != -1) {
        // עדכון תור קיים
        _slots[existingIndex] = AppointmentSlot(
          dayOfWeek: dayOfWeek,
          startTime: _slots[existingIndex].startTime,
          endTime: _slots[existingIndex].endTime,
          durationMinutes: _selectedDuration,
        );
      } else {
        // הוספת תור חדש
        _slots.add(AppointmentSlot(
          dayOfWeek: dayOfWeek,
          startTime: '09:00',
          endTime: '17:00',
          durationMinutes: _selectedDuration,
        ));
      }
    });
  }

  void _removeDaySlot(int dayOfWeek) {
    setState(() {
      _slots.removeWhere((slot) => slot.dayOfWeek == dayOfWeek);
    });
  }

  void _updateSlotTime(int dayOfWeek, String startTime, String endTime) {
    setState(() {
      final index = _slots.indexWhere((slot) => slot.dayOfWeek == dayOfWeek);
      if (index != -1) {
        _slots[index] = AppointmentSlot(
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          durationMinutes: _slots[index].durationMinutes,
        );
      }
    });
  }

  String _getDayNameHebrew(int dayOfWeek) {
    const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
    return days[dayOfWeek];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('הגדרת תורים'),
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
                    // משך תור
                    Text(
                      'משך תור:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _durationOptions.map((duration) {
                        final isSelected = _selectedDuration == duration;
                        return ChoiceChip(
                          label: Text('$duration דק׳'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedDuration = duration;
                                // עדכון כל התורים הקיימים למשך החדש
                                for (var i = 0; i < _slots.length; i++) {
                                  _slots[i] = AppointmentSlot(
                                    dayOfWeek: _slots[i].dayOfWeek,
                                    startTime: _slots[i].startTime,
                                    endTime: _slots[i].endTime,
                                    durationMinutes: duration,
                                  );
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // רשימת ימים
                    Text(
                      'בחר ימים ושעות:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(7, (index) {
                      final slot = _slots.firstWhere(
                        (s) => s.dayOfWeek == index,
                        orElse: () => AppointmentSlot(
                          dayOfWeek: index,
                          startTime: '09:00',
                          endTime: '17:00',
                          durationMinutes: _selectedDuration,
                        ),
                      );
                      final isSelected = _slots.any((s) => s.dayOfWeek == index);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              if (value == true) {
                                _addDaySlot(index);
                              } else {
                                _removeDaySlot(index);
                              }
                            },
                          ),
                          title: Text(_getDayNameHebrew(index)),
                          children: isSelected
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                decoration: const InputDecoration(
                                                  labelText: 'שעת התחלה',
                                                  hintText: '09:00',
                                                ),
                                                controller: TextEditingController(text: slot.startTime),
                                                onChanged: (value) {
                                                  _updateSlotTime(index, value, slot.endTime);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: TextField(
                                                decoration: const InputDecoration(
                                                  labelText: 'שעת סיום',
                                                  hintText: '17:00',
                                                ),
                                                controller: TextEditingController(text: slot.endTime),
                                                onChanged: (value) {
                                                  _updateSlotTime(index, slot.startTime, value);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ]
                              : [],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    // כפתור שמירה
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAppointmentSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('שמור הגדרות'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

