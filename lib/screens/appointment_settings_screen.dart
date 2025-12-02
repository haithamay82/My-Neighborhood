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
  final TextEditingController _customDurationController = TextEditingController();
  bool _isCustomDuration = false; // האם משתמש בהזנה ידנית

  @override
  void initState() {
    super.initState();
    _loadAppointmentSettings();
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
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
            // בדיקה אם משך התור הוא אחד מהאופציות הקבועות
            _isCustomDuration = !_durationOptions.contains(_selectedDuration);
            if (_isCustomDuration) {
              _customDurationController.text = _selectedDuration.toString();
            }
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
        // עדכון תור קיים - שמירה על ההפסקות הקיימות
        _slots[existingIndex] = AppointmentSlot(
          dayOfWeek: dayOfWeek,
          startTime: _slots[existingIndex].startTime,
          endTime: _slots[existingIndex].endTime,
          durationMinutes: _selectedDuration,
          breaks: _slots[existingIndex].breaks,
        );
      } else {
        // הוספת תור חדש
        _slots.add(AppointmentSlot(
          dayOfWeek: dayOfWeek,
          startTime: '09:00',
          endTime: '17:00',
          durationMinutes: _selectedDuration,
          breaks: [],
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
          breaks: _slots[index].breaks, // שמירה על ההפסקות הקיימות
        );
      }
    });
  }

  // הוספת הפסקה ליום מסוים
  void _addBreak(int dayOfWeek) {
    setState(() {
      final index = _slots.indexWhere((slot) => slot.dayOfWeek == dayOfWeek);
      if (index != -1) {
        final slot = _slots[index];
        final newBreaks = List<BreakTime>.from(slot.breaks);
        // הוספת הפסקה חדשה עם ערכי ברירת מחדל
        newBreaks.add(BreakTime(
          startTime: '12:00',
          endTime: '13:00',
        ));
        _slots[index] = slot.copyWith(breaks: newBreaks);
      }
    });
  }

  // עדכון הפסקה
  void _updateBreak(int dayOfWeek, int breakIndex, String startTime, String endTime) {
    setState(() {
      final index = _slots.indexWhere((slot) => slot.dayOfWeek == dayOfWeek);
      if (index != -1 && breakIndex < _slots[index].breaks.length) {
        final slot = _slots[index];
        final newBreaks = List<BreakTime>.from(slot.breaks);
        newBreaks[breakIndex] = BreakTime(
          startTime: startTime,
          endTime: endTime,
        );
        _slots[index] = slot.copyWith(breaks: newBreaks);
      }
    });
  }

  // מחיקת הפסקה
  void _removeBreak(int dayOfWeek, int breakIndex) {
    setState(() {
      final index = _slots.indexWhere((slot) => slot.dayOfWeek == dayOfWeek);
      if (index != -1 && breakIndex < _slots[index].breaks.length) {
        final slot = _slots[index];
        final newBreaks = List<BreakTime>.from(slot.breaks);
        newBreaks.removeAt(breakIndex);
        _slots[index] = slot.copyWith(breaks: newBreaks);
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
                        final isSelected = _selectedDuration == duration && !_isCustomDuration;
                        return ChoiceChip(
                          label: Text('$duration דק׳'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isCustomDuration = false;
                                _customDurationController.clear();
                                _selectedDuration = duration;
                                // עדכון כל התורים הקיימים למשך החדש
                                for (var i = 0; i < _slots.length; i++) {
                                  _slots[i] = AppointmentSlot(
                                    dayOfWeek: _slots[i].dayOfWeek,
                                    startTime: _slots[i].startTime,
                                    endTime: _slots[i].endTime,
                                    durationMinutes: duration,
                                    breaks: _slots[i].breaks, // שמירה על ההפסקות
                                  );
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // הזנה ידנית של משך התור
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customDurationController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'משך תור מותאם אישית (דקות)',
                              hintText: 'הכנס מספר דקות',
                              border: OutlineInputBorder(),
                              suffixText: 'דק׳',
                              errorText: _isCustomDuration && (_selectedDuration <= 0 || _selectedDuration > 1440)
                                  ? 'מספר לא תקין (1-1440 דקות)'
                                  : null,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final intValue = int.tryParse(value);
                                if (intValue != null && intValue > 0 && intValue <= 1440) {
                                  setState(() {
                                    _isCustomDuration = true;
                                    _selectedDuration = intValue;
                                    // עדכון כל התורים הקיימים למשך החדש
                                    for (var i = 0; i < _slots.length; i++) {
                                      _slots[i] = AppointmentSlot(
                                        dayOfWeek: _slots[i].dayOfWeek,
                                        startTime: _slots[i].startTime,
                                        endTime: _slots[i].endTime,
                                        durationMinutes: intValue,
                                        breaks: _slots[i].breaks, // שמירה על ההפסקות
                                      );
                                    }
                                  });
                                } else if (intValue != null) {
                                  setState(() {
                                    _isCustomDuration = true;
                                    _selectedDuration = intValue; // נשמור גם אם לא תקין כדי להציג שגיאה
                                  });
                                }
                              } else {
                                setState(() {
                                  _isCustomDuration = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_isCustomDuration && _selectedDuration > 0 && _selectedDuration <= 1440) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'משך התור נקבע ל-${_selectedDuration} דקות',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      final slotIndex = _slots.indexWhere((s) => s.dayOfWeek == index);
                      final isSelected = slotIndex != -1;
                      final slot = isSelected 
                          ? _slots[slotIndex]
                          : AppointmentSlot(
                              dayOfWeek: index,
                              startTime: '09:00',
                              endTime: '17:00',
                              durationMinutes: _selectedDuration,
                            );

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
                                        // שעת התחלה
                                        Builder(
                                          builder: (context) {
                                            final currentSlot = _slots.firstWhere(
                                              (s) => s.dayOfWeek == index,
                                              orElse: () => slot,
                                            );
                                            return ListTile(
                                              title: const Text('שעת התחלה'),
                                              trailing: TextButton(
                                                onPressed: () async {
                                                  final TimeOfDay? picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: TimeOfDay(
                                                      hour: int.parse(currentSlot.startTime.split(':')[0]),
                                                      minute: int.parse(currentSlot.startTime.split(':')[1]),
                                                    ),
                                                  );
                                                  if (picked != null) {
                                                    final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                    _updateSlotTime(index, timeStr, currentSlot.endTime);
                                                    setState(() {}); // רענון ה-widget
                                                  }
                                                },
                                                child: Text(
                                                  currentSlot.startTime,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const Divider(),
                                        // שעת סיום
                                        Builder(
                                          builder: (context) {
                                            final currentSlot = _slots.firstWhere(
                                              (s) => s.dayOfWeek == index,
                                              orElse: () => slot,
                                            );
                                            return ListTile(
                                              title: const Text('שעת סיום'),
                                              trailing: TextButton(
                                                onPressed: () async {
                                                  final TimeOfDay? picked = await showTimePicker(
                                                    context: context,
                                                    initialTime: TimeOfDay(
                                                      hour: int.parse(currentSlot.endTime.split(':')[0]),
                                                      minute: int.parse(currentSlot.endTime.split(':')[1]),
                                                    ),
                                                  );
                                                  if (picked != null) {
                                                    final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                    _updateSlotTime(index, currentSlot.startTime, timeStr);
                                                    setState(() {}); // רענון ה-widget
                                                  }
                                                },
                                                child: Text(
                                                  currentSlot.endTime,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const Divider(),
                                        // הפסקות
                                        Builder(
                                          builder: (context) {
                                            final currentSlot = _slots.firstWhere(
                                              (s) => s.dayOfWeek == index,
                                              orElse: () => slot,
                                            );
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        'הפסקות',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                                                        onPressed: () => _addBreak(index),
                                                        tooltip: 'הוסף הפסקה',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (currentSlot.breaks.isEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    child: Text(
                                                      'אין הפסקות מוגדרות',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  ...currentSlot.breaks.asMap().entries.map((entry) {
                                                    final breakIndex = entry.key;
                                                    final breakTime = entry.value;
                                                    return Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: Theme.of(context).colorScheme.outlineVariant,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: ListTile(
                                                                  contentPadding: EdgeInsets.zero,
                                                                  title: const Text('שעת התחלה'),
                                                                  trailing: TextButton(
                                                                    onPressed: () async {
                                                                      final TimeOfDay? picked = await showTimePicker(
                                                                        context: context,
                                                                        initialTime: TimeOfDay(
                                                                          hour: int.parse(breakTime.startTime.split(':')[0]),
                                                                          minute: int.parse(breakTime.startTime.split(':')[1]),
                                                                        ),
                                                                      );
                                                                      if (picked != null) {
                                                                        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                                        _updateBreak(index, breakIndex, timeStr, breakTime.endTime);
                                                                        setState(() {});
                                                                      }
                                                                    },
                                                                    child: Text(
                                                                      breakTime.startTime,
                                                                      style: TextStyle(
                                                                        color: Theme.of(context).colorScheme.primary,
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: Icon(Icons.delete, color: Colors.red),
                                                                onPressed: () => _removeBreak(index, breakIndex),
                                                                tooltip: 'מחק הפסקה',
                                                              ),
                                                            ],
                                                          ),
                                                          ListTile(
                                                            contentPadding: EdgeInsets.zero,
                                                            title: const Text('שעת סיום'),
                                                            trailing: TextButton(
                                                              onPressed: () async {
                                                                final TimeOfDay? picked = await showTimePicker(
                                                                  context: context,
                                                                  initialTime: TimeOfDay(
                                                                    hour: int.parse(breakTime.endTime.split(':')[0]),
                                                                    minute: int.parse(breakTime.endTime.split(':')[1]),
                                                                  ),
                                                                );
                                                                if (picked != null) {
                                                                  final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                                                  _updateBreak(index, breakIndex, breakTime.startTime, timeStr);
                                                                  setState(() {});
                                                                }
                                                              },
                                                              child: Text(
                                                                breakTime.endTime,
                                                                style: TextStyle(
                                                                  color: Theme.of(context).colorScheme.primary,
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                              ],
                                            );
                                          },
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

