import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/app_sharing_service.dart';
import '../l10n/app_localizations.dart';

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
        debugPrint('  - Request ${doc.id}: $requestDate vs $startOfDay = $isToday');
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
    
    if (mounted) {
      final l10n = AppLocalizations.of(context);
    setState(() {
      _isProcessing = true;
        _statusMessage = l10n.granting14DayExtension;
    });
    }

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

      // שליחת התראה על הארכת תקופת אורח בשבועיים
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'userId': user.uid,
        'title': l10n.guestPeriodExtendedTwoWeeks,
        'body': l10n.thankYouForActions,
        'payload': {
          'type': 'trial_extension',
          'screen': 'profile',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': user.uid,
        'title': l10n.guestPeriodExtendedTwoWeeks,
        'message': l10n.thankYouForActions,
        'type': 'trial_extension',
        'read': false,
        'data': {
          'extensionDays': 14,
          'newEndDate': newEndDate.toIso8601String(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ניקוי זמן ההתחלה מ-SharedPreferences
      await _clearTrialExtensionStartTime();

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _statusMessage = l10n.extensionGrantedSuccessfully;
        });

        // סגירת הדיאלוג אחרי 2 שניות
        await Future.delayed(const Duration(seconds: 2));
        // Guard context usage after async gap
        if (!mounted) return;
        Navigator.pop(context);
        widget.onExtensionGranted();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _statusMessage = '${l10n.errorGrantingExtension}: $e';
        });
      }
    }
  }

  void _shareApp() {
    AppSharingService.shareAppForTrialExtension(context);
    // לא נסמן כמושלם - נחכה לבדיקה האמיתית
    _showMessage(AppLocalizations.of(context).shareAppOpened);
    
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
    if (!mounted) return;
    _showMessage(AppLocalizations.of(context).appStoreOpened);
    
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
    _showMessage(AppLocalizations.of(context).navigateToNewRequest);
    
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
          Text(AppLocalizations.of(context).extendTrialPeriod),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage.isNotEmpty) ...[
            Builder(
              builder: (context) {
                // בדיקה אם ה-widget עדיין פעיל לפני גישה ל-context
                if (!mounted) return const SizedBox.shrink();
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                    color: _isProcessing 
                        ? (isDark ? Colors.blue[800] : Colors.blue[50])
                        : (isDark ? Colors.green[800] : Colors.green[50]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                      color: _isProcessing 
                          ? (isDark ? Colors.blue[600]! : Colors.blue[200]!)
                          : (isDark ? Colors.green[600]! : Colors.green[200]!),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.check_circle,
                        color: _isProcessing 
                            ? (isDark ? Colors.blue[200] : Colors.blue[800])
                            : (isDark ? Colors.green[200] : Colors.green[800]),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                            color: _isProcessing 
                                ? (isDark ? Colors.blue[200] : Colors.blue[800])
                                : (isDark ? Colors.green[200] : Colors.green[800]),
                      ),
                    ),
                  ),
                ],
              ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          
          // דרישה 1: שיתוף
          _buildRequirementCard(
            icon: Icons.share,
            title: AppLocalizations.of(context).shareAppTo5FriendsForTrial,
            description: 'WhatsApp, SMS, Email ($_sharingCount/5)',
            isCompleted: _sharingCompleted,
            onTap: _shareApp,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          
          // דרישה 2: דירוג
          _buildRequirementCard(
            icon: Icons.star,
            title: AppLocalizations.of(context).rateApp5StarsForTrial,
            description: AppLocalizations.of(context).helpUsImproveApp,
            isCompleted: _ratingCompleted,
            onTap: _rateApp,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          
          // דרישה 3: פרסום בקשה
          _buildRequirementCard(
            icon: Icons.add_circle,
            title: AppLocalizations.of(context).publishNewRequestForTrial,
            description: '${AppLocalizations.of(context).publishNewRequestForTrial} (${_requestCount > 0 ? AppLocalizations.of(context).completed : AppLocalizations.of(context).notCompleted})',
            isCompleted: _requestPublished,
            onTap: _publishRequest,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          
          // טיימר
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                  color: isDark ? Colors.orange[900] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.orange[700]! : Colors.orange[200]!,
                  ),
            ),
            child: Row(
              children: [
                    Icon(
                      Icons.access_time, 
                      color: isDark ? Colors.orange[200] : Colors.orange[800], 
                      size: 20,
                    ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context).remainingTime} ${_getRemainingTime()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                          color: isDark ? Colors.orange[100] : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).close),
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
    // בדיקה אם ה-widget עדיין פעיל לפני גישה ל-context
    if (!mounted) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // רקעים נייטרליים עם ניגודיות גבוהה
          color: isCompleted 
              ? (isDark ? Colors.green[800] : Colors.green[100])
              : (isDark ? Colors.black : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted 
                ? (isDark ? Colors.green[600]! : Colors.green[300]!)
                : (isDark ? Colors.white24 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : icon,
              color: isCompleted 
                  ? (isDark ? Colors.green[200] : Colors.green[800])
                  : (isDark ? Colors.white : Colors.black),
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
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompleted)
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.white : Colors.black,
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
      return AppLocalizations.of(context).timeExpired;
    }
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
