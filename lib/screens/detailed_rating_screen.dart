import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/request.dart';
import '../models/detailed_rating.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_tracking_service.dart';

class DetailedRatingScreen extends StatefulWidget {
  final Request request;
  final Map<String, dynamic> helper;

  const DetailedRatingScreen({
    super.key,
    required this.request,
    required this.helper,
  });

  @override
  State<DetailedRatingScreen> createState() => _DetailedRatingScreenState();
}

class _DetailedRatingScreenState extends State<DetailedRatingScreen> {
  // דירוגים לכל קטגוריה (1-5)
  int _reliability = 0; // אמינות
  int _availability = 0; // זמינות
  int _attitude = 0; // יחס
  int _fairPrice = 0; // מחיר הוגן
  
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  String _selectedCategory = '';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.request.category.name;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 DetailedRatingScreen build called');
    debugPrint('🔍 Helper UID: ${widget.helper['uid']}');
    debugPrint('🔍 Helper name: ${widget.helper['displayName']}');
    debugPrint('🔍 Request ID: ${widget.request.requestId}');
    debugPrint('🔍 Selected category: $_selectedCategory');
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('דרג את השירות שקיבלת'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(l10n),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // כרטיס בקשה
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'בקשה:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.request.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // כרטיס משתמש
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      widget.helper['displayName'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.helper['displayName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.helper['email'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // כותרת דירוג מפורט
          Text(
            'דרג את השירות שקיבלת לפי הקטגוריות הבאות:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // אמינות
          _buildRatingCategory(
            'אמינות',
            'האם השירות בוצע כפי שהובטח?',
            _reliability,
            (rating) => setState(() => _reliability = rating),
            Icons.verified_user,
            Colors.blue,
          ),
          const SizedBox(height: 20),

          // זמינות
          _buildRatingCategory(
            'זמינות',
            'האם השירות בוצע בזמן?',
            _availability,
            (rating) => setState(() => _availability = rating),
            Icons.access_time,
            Colors.green,
          ),
          const SizedBox(height: 20),

          // יחס
          _buildRatingCategory(
            'יחס',
            'איך היה היחס והתקשורת?',
            _attitude,
            (rating) => setState(() => _attitude = rating),
            Icons.people,
            Colors.orange,
          ),
          const SizedBox(height: 20),

          // מחיר הוגן
          _buildRatingCategory(
            'מחיר הוגן',
            'האם המחיר היה הוגן?',
            _fairPrice,
            (rating) => setState(() => _fairPrice = rating),
            Icons.attach_money,
            Colors.purple,
          ),
          const SizedBox(height: 24),

          // דירוג כולל
          if (_getOverallRating() > 0) ...[
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'דירוג כולל: ${_getOverallRating().toStringAsFixed(1)}/5',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // בחירת קטגוריה
          Text(
            'קטגוריית השירות:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory.isNotEmpty ? _selectedCategory : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'בחר קטגוריה',
            ),
            items: [
              DropdownMenuItem(
                value: widget.request.category.name,
                child: Text(widget.request.category.categoryDisplayName),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value ?? widget.request.category.name;
              });
            },
          ),
          const SizedBox(height: 24),

          // הערה
          Text(
            'הערה (אופציונלי):',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'שתף את החוויה שלך...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          // כפתור שמירה
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave() ? _saveRating : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('שמור דירוג מפורט'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCategory(
    String title,
    String subtitle,
    int rating,
    Function(int) onRatingChanged,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${rating}/5',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rating > 0 ? color : Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // כוכבים
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => onRatingChanged(index + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 32,
                      color: index < rating ? color : Colors.grey[400],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  double _getOverallRating() {
    if (_reliability == 0 || _availability == 0 || _attitude == 0 || _fairPrice == 0) {
      return 0;
    }
    return (_reliability + _availability + _attitude + _fairPrice) / 4.0;
  }

  bool _canSave() {
    return _reliability > 0 && _availability > 0 && _attitude > 0 && _fairPrice > 0;
  }

  Future<void> _saveRating() async {
    if (!_canSave()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      // בדיקת נתוני המשתמש
      final helperUid = widget.helper['uid'] as String?;
      final helperDisplayName = widget.helper['displayName'] as String?;
      
      if (helperUid == null || helperUid.isEmpty) {
        debugPrint('❌ Invalid helper UID: $helperUid');
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה: נתוני המשתמש לא תקינים'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('🔍 Saving detailed rating for helper: $helperUid');

      // יצירת דירוג מפורט
      final detailedRating = DetailedRating(
        ratingId: '', // יוגדר אוטומטית על ידי Firestore
        requestId: widget.request.requestId,
        ratedUserId: helperUid,
        raterUserId: user.uid,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : widget.request.category.name,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
        helperDisplayName: helperDisplayName ?? 'משתמש',
        requestTitle: widget.request.title,
        reliability: _reliability,
        availability: _availability,
        attitude: _attitude,
        fairPrice: _fairPrice,
      );

      // שמירת הדירוג המפורט
      await FirebaseFirestore.instance
          .collection('detailed_ratings')
          .add(detailedRating.toFirestore());

      debugPrint('✅ Detailed rating saved successfully');

      // עדכון סטטיסטיקות המשתמש
      await _updateDetailedUserStats(helperUid, detailedRating);

      // שליחת הודעת מערכת לצ'אט של המשתמש הנבחר
      await _sendCompletionSystemMessage(helperUid, helperDisplayName ?? 'משתמש');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הדירוג המפורט נשמר בהצלחה!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // החזרת true שמציינת שהדירוג הושלם
    } catch (e) {
      debugPrint('❌ Error saving detailed rating: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בשמירת הדירוג: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateDetailedUserStats(String userId, DetailedRating rating) async {
    try {
      debugPrint('🔍 Updating detailed user stats for: $userId');
      
      // עדכון סטטיסטיקות מפורטות לפי קטגוריה
      final statsDocRef = FirebaseFirestore.instance
          .collection('detailed_rating_stats')
          .doc('${userId}_${rating.category}');

      final statsDoc = await statsDocRef.get();
      
      if (statsDoc.exists) {
        // עדכון סטטיסטיקות קיימות
        final currentStats = DetailedRatingStats.fromFirestore(statsDoc);
        final newTotalRatings = currentStats.totalRatings + 1;
        
        final newAverageReliability = ((currentStats.averageReliability * currentStats.totalRatings) + rating.reliability) / newTotalRatings;
        final newAverageAvailability = ((currentStats.averageAvailability * currentStats.totalRatings) + rating.availability) / newTotalRatings;
        final newAverageAttitude = ((currentStats.averageAttitude * currentStats.totalRatings) + rating.attitude) / newTotalRatings;
        final newAverageFairPrice = ((currentStats.averageFairPrice * currentStats.totalRatings) + rating.fairPrice) / newTotalRatings;
        final newOverallAverage = (newAverageReliability + newAverageAvailability + newAverageAttitude + newAverageFairPrice) / 4.0;

        await statsDocRef.update({
          'averageReliability': newAverageReliability,
          'averageAvailability': newAverageAvailability,
          'averageAttitude': newAverageAttitude,
          'averageFairPrice': newAverageFairPrice,
          'overallAverage': newOverallAverage,
          'totalRatings': newTotalRatings,
          'lastUpdated': DateTime.now(),
        });
      } else {
        // יצירת סטטיסטיקות חדשות
        final newStats = DetailedRatingStats(
          userId: userId,
          category: rating.category,
          averageReliability: rating.reliability.toDouble(),
          averageAvailability: rating.availability.toDouble(),
          averageAttitude: rating.attitude.toDouble(),
          averageFairPrice: rating.fairPrice.toDouble(),
          overallAverage: rating.overallRating,
          totalRatings: 1,
          lastUpdated: DateTime.now(),
        );

        await statsDocRef.set(newStats.toFirestore());
      }

      // עדכון גם את הדירוג הכללי בפרופיל המשתמש
      await _updateGeneralUserStats(userId, rating.overallRating);
      
      debugPrint('✅ Detailed user stats updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating detailed user stats: $e');
    }
  }

  Future<void> _updateGeneralUserStats(String userId, double rating) async {
    try {
      // עדכון ממוצע הדירוגים הכללי
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final currentRating = (userData['averageRating'] as num?)?.toDouble() ?? 0.0;
        final ratingCount = (userData['ratingCount'] as int?) ?? 0;

        final newRatingCount = ratingCount + 1;
        final newAverage = ((currentRating * ratingCount) + rating) / newRatingCount;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'averageRating': newAverage,
          'ratingCount': newRatingCount,
          'lastRatedAt': DateTime.now(),
        });
        
        debugPrint('✅ General user stats updated successfully');
        
        // בדיקת הגדלת טווח אחרי עדכון דירוג
        await _checkRadiusIncreaseAfterRating(userId, newAverage);
      }
    } catch (e) {
      debugPrint('❌ Error updating general user stats: $e');
    }
  }

  /// בדיקת הגדלת טווח אחרי עדכון דירוג
  Future<void> _checkRadiusIncreaseAfterRating(String userId, double newAverageRating) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String? ?? 'personal';
      final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
      final recommendationsCount = userData['recommendationsCount'] as int? ?? 0;
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      // חישוב הטווח הנוכחי
      final currentRadius = _calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: recommendationsCount,
        averageRating: newAverageRating,
        isAdmin: isAdmin,
      );

      // חישוב הטווח הקודם (ללא הבונוסים הנוכחיים)
      final baseRadius = _calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: 0,
        averageRating: 0.0,
        isAdmin: isAdmin,
      );

      // בדיקה אם יש שינוי משמעותי בטווח
      final radiusIncrease = currentRadius - baseRadius;
      if (radiusIncrease > 0) {
        await _sendRadiusIncreaseNotification(radiusIncrease, recommendationsCount, newAverageRating);
      }
    } catch (e) {
      debugPrint('❌ Error checking radius increase after rating: $e');
    }
  }

  /// חישוב טווח מקסימלי למשתמש
  double _calculateMaxRadiusForUser({
    required String userType,
    required bool isSubscriptionActive,
    required int recommendationsCount,
    required double averageRating,
    required bool isAdmin,
  }) {
    double baseRadius = 1000.0; // טווח בסיסי במטרים (1 ק"מ)

    // טווח לפי סוג משתמש (במטרים)
    switch (userType) {
      case 'personal':
        baseRadius = isSubscriptionActive ? 2000.0 : 1000.0; // 2 ק"מ או 1 ק"מ
        break;
      case 'business':
        baseRadius = isSubscriptionActive ? 3000.0 : 1000.0; // 3 ק"מ או 1 ק"מ
        break;
      case 'admin':
        baseRadius = 50000.0; // 50 ק"מ
        break;
    }

    // בונוס המלצות (200 מטר לכל המלצה)
    final recommendationsBonus = recommendationsCount * 200.0;

    // בונוס דירוג (במטרים)
    double ratingBonus = 0.0;
    if (averageRating >= 4.5) {
      ratingBonus = 1500.0; // 1.5 ק"מ
    } else if (averageRating >= 4.0) {
      ratingBonus = 1000.0; // 1 ק"מ
    } else if (averageRating >= 3.5) {
      ratingBonus = 500.0; // 500 מטר
    }

    return baseRadius + recommendationsBonus + ratingBonus;
  }

  /// שליחת התראה על הגדלת טווח
  Future<void> _sendRadiusIncreaseNotification(
    double radiusIncrease,
    int recommendationsCount,
    double averageRating,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // בדיקה אם כבר נשלחה התראה על הגדלת טווח עם אותם פרמטרים
      final hasBeenSent = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      if (hasBeenSent) {
        debugPrint('Radius increase notification already sent for user: ${user.uid} with same parameters');
        return;
      }

      String message = '';
      String details = '';
      
      if (recommendationsCount > 0) {
        final recommendationsBonus = recommendationsCount * 200.0;
        message += '🎉 תודה על $recommendationsCount המלצות שלך! ';
        details += 'המלצות: +${(recommendationsBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      if (averageRating >= 3.5) {
        double ratingBonus = 0.0;
        if (averageRating >= 4.5) {
          ratingBonus = 1500.0;
        } else if (averageRating >= 4.0) {
          ratingBonus = 1000.0;
        } else if (averageRating >= 3.5) {
          ratingBonus = 500.0;
        }
        message += '⭐ דירוג מעולה של ${averageRating.toStringAsFixed(1)}! ';
        details += 'דירוג גבוה: +${(ratingBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      message += '🚀 הטווח שלך גדל ב-${(radiusIncrease / 1000).toStringAsFixed(1)} ק"מ!';

      // יצירת התראה
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'toUserId': user.uid,
        'title': 'הטווח שלך גדל!',
        'message': message,
        'type': 'radius_increase',
        'data': {
          'radiusIncrease': radiusIncrease,
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating,
          'details': details.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

      // שמירת ההתראה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification);

      // סימון שההתראה נשלחה
      await NotificationTrackingService.markNotificationWithParamsAsSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      debugPrint('✅ Radius increase notification sent: $message');
    } catch (e) {
      debugPrint('❌ Error sending radius increase notification: $e');
    }
  }

  Future<void> _sendCompletionSystemMessage(String helperUid, String helperDisplayName) async {
    try {
      debugPrint('🔍 Sending completion system message to helper: $helperUid');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No current user found');
        return;
      }

      // חיפוש כל הצ'אטים של הבקשה הזו
      final allChatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: widget.request.requestId)
          .get();

      debugPrint('🔍 Found ${allChatsQuery.docs.length} total chats for request ${widget.request.requestId}');

      // סגירת כל הצ'אטים של הבקשה
      for (final chatDoc in allChatsQuery.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);
        final isClosed = chatData['isClosed'] as bool? ?? false;
        
        // אם הצ'אט כבר סגור, דלג עליו
        if (isClosed) {
          debugPrint('🔍 Chat ${chatDoc.id} is already closed, skipping');
          continue;
        }
        
        debugPrint('🔍 Closing chat: ${chatDoc.id} with participants: $participants');
        
        // שליחת הודעת מערכת עם זמן אמיתי
        final completionTime = DateTime.now();
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .add({
          'from': 'system',
          'text': 'הטיפול בבקשה "${widget.request.title}" הסתיים. לא ניתן לשלוח הודעות נוספות בצ\'אט זה.',
          'timestamp': completionTime,
          'isSystemMessage': true,
          'messageType': 'completion',
        });

        // עדכון הצ'אט כסגור
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDoc.id)
            .update({
          'isClosed': true,
          'closedAt': DateTime.now(),
          'closedBy': user.uid,
          'lastMessage': 'הטיפול בבקשה הסתיים',
          'updatedAt': DateTime.now(),
        });

        debugPrint('✅ Chat ${chatDoc.id} closed successfully');
      }
      
      debugPrint('✅ All chats for request ${widget.request.requestId} have been closed');
      
      // עדכון סטטוס הבקשה ל-completed
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.request.requestId)
          .update({
        'status': 'completed',
        'completedAt': DateTime.now(),
        'completedBy': user.uid,
      });
      
      debugPrint('✅ Request ${widget.request.requestId} status updated to completed');
      
      // עדכון ה-UI אם המסך עדיין פעיל
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error sending completion system message: $e');
    }
  }
}
