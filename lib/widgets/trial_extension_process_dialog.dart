import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/app_sharing_service.dart';

class TrialExtensionProcessDialog extends StatefulWidget {
  final UserProfile userProfile;
  final DateTime startTime;
  final VoidCallback onExtensionGranted;

  const TrialExtensionProcessDialog({
    super.key,
    required this.userProfile,
    required this.startTime,
    required this.onExtensionGranted,
  });

  @override
  State<TrialExtensionProcessDialog> createState() => _TrialExtensionProcessDialogState();
}

class _TrialExtensionProcessDialogState extends State<TrialExtensionProcessDialog> {
  bool _sharingCompleted = false;
  bool _ratingCompleted = false;
  bool _requestPublished = false;
  bool _isProcessing = false;
  String _statusMessage = '';
  int _sharingCount = 0;
  int _requestCount = 0;
  bool _disposed = false;
  DateTime? _actualStartTime;

  @override
  void initState() {
    super.initState();
    _loadActualStartTime();
    _checkCurrentStatus();
    _startPeriodicCheck();
  }

  Future<void> _loadActualStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startTimeString = prefs.getString('trial_extension_start_time');
      if (startTimeString != null) {
        _actualStartTime = DateTime.parse(startTimeString);
        debugPrint('🔍 Loaded actual start time: $_actualStartTime');
      } else {
        _actualStartTime = widget.startTime;
        debugPrint('🔍 Using widget start time: $_actualStartTime');
      }
    } catch (e) {
      debugPrint('Error loading actual start time: $e');
      _actualStartTime = widget.startTime;
    }
  }

  Future<void> _clearTrialExtensionStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('trial_extension_start_time');
      debugPrint('🔍 Cleared trial extension start time');
    } catch (e) {
      debugPrint('Error clearing trial extension start time: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // בדיקה מחדש כשהמשתמש חוזר לדיאלוג
    _checkCurrentStatus();
  }

  void _startPeriodicCheck() {
    // בדיקה כל 5 שניות אם הפעולות בוצעו
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_disposed) {
        _checkCurrentStatus();
        _startPeriodicCheck();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _checkCurrentStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // אם עדיין לא טענו את הזמן האמיתי, נחכה קצת
      if (_actualStartTime == null) {
        await _loadActualStartTime();
      }

      final startTime = _actualStartTime ?? widget.startTime;
      
      // בדיקת בקשות שפורסמו - נבדוק בקשות מהיום (לא מתחילת הטיימר)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdBy', isEqualTo: user.uid)
          .get();
      
      debugPrint('🔍 All requests for user: ${requestsQuery.docs.length}');
      debugPrint('🔍 Checking requests from today: $startOfDay');
      
      // סינון ידני לפי תאריך - בקשות מהיום
      final requestCount = requestsQuery.docs.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) {
          debugPrint('  - Request ${doc.id}: no createdAt');
          return false;
        }
        final requestDate = createdAt.toDate();
        final isToday = requestDate.isAfter(startOfDay);
        debugPrint('  - Request ${doc.id}: ${requestDate} vs ${startOfDay} = $isToday');
        return isToday;
      }).length;
      
      // בדיקת שיתופים - נבדוק ב-users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      int sharingCount = 0;
      if (userDoc.exists) {
        final data = userDoc.data()!;
        sharingCount = data['recommendationsCount'] ?? 0;
      }
      
      // בדיקת דירוג - נבדוק אם יש רשומה של דירוג
      final ratingDoc = await FirebaseFirestore.instance
          .collection('user_activities')
          .doc(user.uid)
          .get();
      
      bool ratingCompleted = false;
      if (ratingDoc.exists) {
        final data = ratingDoc.data()!;
        // נניח שהדירוג הושלם אם המשתמש ניסה לדרג
        // (בפועל צריך לבדוק אם באמת דירג)
        ratingCompleted = data['rating_attempted'] ?? false;
      }
      
      debugPrint('🔍 Trial Extension Check:');
      debugPrint('  - Sharing count: $sharingCount/5');
      debugPrint('  - Request count: $requestCount');
      debugPrint('  - Rating completed: $ratingCompleted');
      
      if (mounted && !_disposed) {
        setState(() {
          _sharingCount = sharingCount;
          _requestCount = requestCount;
          _sharingCompleted = sharingCount >= 5;
          _requestPublished = requestCount > 0;
          _ratingCompleted = ratingCompleted;
        });
      }

      _checkRequirements();
    } catch (e) {
      debugPrint('Error checking current status: $e');
    }
  }

  void _checkRequirements() {
    // בדיקה אם כל הדרישות הושלמו
    if (_sharingCompleted && _ratingCompleted && _requestPublished) {
      _grantExtension();
    }
  }

  void _grantExtension() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _statusMessage = 'מעניק הארכה של 14 ימים...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // הארכת תקופת הניסיון ב-14 ימים
      final currentEndDate = widget.userProfile.guestTrialEndDate ?? DateTime.now().add(const Duration(days: 30));
      final newEndDate = currentEndDate.add(const Duration(days: 14));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'guestTrialEndDate': Timestamp.fromDate(newEndDate),
        'guestTrialExtensionReceived': true,
      });

      // ניקוי זמן ההתחלה מ-SharedPreferences
      await _clearTrialExtensionStartTime();

      if (mounted) {
        setState(() {
          _statusMessage = 'הארכה של 14 ימים ניתנה בהצלחה!';
        });

        // סגירת הדיאלוג אחרי 2 שניות
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
        widget.onExtensionGranted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'שגיאה במתן הארכה: $e';
        });
      }
    }
  }

  void _shareApp() {
    AppSharingService.shareAppForTrialExtension(context);
    // לא נסמן כמושלם - נחכה לבדיקה האמיתית
    _showMessage('שיתוף האפליקציה נפתח. אנא שתף ל-5 חברים כדי להשלים את הדרישה.');
    
    // בדיקה מחדש אחרי 2 שניות (כדי לתת זמן לעדכון)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_disposed) {
        _checkCurrentStatus();
      }
    });
  }

  void _rateApp() async {
    // פתיחת חנות האפליקציות לדירוג
    await _openAppStore();
    _showMessage('חנות האפליקציות נפתחה. אנא דרג 5 כוכבים כדי להשלים את הדרישה.');
    
    // בדיקה מחדש אחרי 2 שניות (כדי לתת זמן לעדכון)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_disposed) {
        _checkCurrentStatus();
      }
    });
  }

  Future<void> _openAppStore() async {
    try {
      // פתיחת חנות האפליקציות
      // כאן צריך להוסיף קוד לפתיחת חנות האפליקציות
      // כרגע רק נציג הודעה
      
      // סימון שהמשתמש ניסה לדרג (לא בהכרח דירג בפועל)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('user_activities')
            .doc(user.uid)
            .set({
          'rating_attempted': true,
          'rating_attempt_date': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error opening app store: $e');
    }
  }

  void _publishRequest() {
    // ניווט למסך יצירת בקשה חדשה
    Navigator.pop(context); // סגירת הדיאלוג הנוכחי
    // כאן צריך להוסיף ניווט למסך יצירת בקשה חדשה
    _showMessage('מעבר למסך יצירת בקשה. אנא פרסם בקשה כדי להשלים את הדרישה.');
    
    // בדיקה מחדש אחרי 3 שניות (כדי לתת זמן ליצירת הבקשה)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_disposed) {
        _checkCurrentStatus();
      }
    });
  }


  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // בדיקה מחדש בכל build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        _checkCurrentStatus();
      }
    });
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange[600], size: 28),
          const SizedBox(width: 8),
          const Text('הארכת תקופת ניסיון'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isProcessing ? Colors.blue[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isProcessing ? Colors.blue[200]! : Colors.green[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.check_circle,
                    color: _isProcessing ? Colors.blue[600] : Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isProcessing ? Colors.blue[700] : Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // דרישה 1: שיתוף
          _buildRequirementCard(
            icon: Icons.share,
            title: 'שתף את האפליקציה ל-5 חברים',
            description: 'WhatsApp, SMS, Email (${_sharingCount}/5)',
            isCompleted: _sharingCompleted,
            onTap: _shareApp,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          
          // דרישה 2: דירוג
          _buildRequirementCard(
            icon: Icons.star,
            title: 'דרג את האפליקציה בחנות 5 כוכבים',
            description: 'עזור לנו לשפר את האפליקציה',
            isCompleted: _ratingCompleted,
            onTap: _rateApp,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          
          // דרישה 3: פרסום בקשה
          _buildRequirementCard(
            icon: Icons.add_circle,
            title: 'פרסם בקשה חדשה',
            description: 'בכל תחום שתרצה (${_requestCount > 0 ? 'הושלם' : 'לא הושלם'})',
            isCompleted: _requestPublished,
            onTap: _publishRequest,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          
          // טיימר
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'נותר זמן: ${_getRemainingTime()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('סגור'),
        ),
      ],
    );
  }

  Widget _buildRequirementCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isCompleted,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green[200] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted ? Colors.green[400]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : icon,
              color: isCompleted ? Colors.green[700] : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.green[800] : Colors.grey[800],
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompleted)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[700],
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  String _getRemainingTime() {
    final startTime = _actualStartTime ?? widget.startTime;
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(hours: 1) - elapsed;
    
    if (remaining.isNegative) {
      return 'הזמן הסתיים';
    }
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
