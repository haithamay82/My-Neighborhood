import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/request.dart';
import '../l10n/app_localizations.dart';

class RateUserScreen extends StatefulWidget {
  final Request request;
  final Map<String, dynamic> helper;

  const RateUserScreen({
    super.key,
    required this.request,
    required this.helper,
  });

  @override
  State<RateUserScreen> createState() => _RateUserScreenState();
}

class _RateUserScreenState extends State<RateUserScreen> {
  int _rating = 0;
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
    debugPrint('🔍 RateUserScreen build called');
    debugPrint('🔍 Helper UID: ${widget.helper['uid']}');
    debugPrint('🔍 Helper name: ${widget.helper['displayName']}');
    debugPrint('🔍 Request ID: ${widget.request.requestId}');
    debugPrint('🔍 Selected category: $_selectedCategory');
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('דרג משתמש'),
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
                    backgroundColor: Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFFFF9800) // כתום ענתיק
    : Theme.of(context).colorScheme.primary,
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

          // דירוג
          Text(
            'דרג את השירות שקיבלת:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // כוכבים
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: index < _rating ? Colors.amber : Colors.grey[400],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          
          // תיאור הדירוג
          Center(
            child: Text(
              _getRatingDescription(_rating),
              style: TextStyle(
                color: _rating > 0 ? Colors.grey[700] : Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),

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
              // אפשר להוסיף עוד קטגוריות כאן
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
              onPressed: _rating > 0 ? _saveRating : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFFFF9800) // כתום ענתיק
    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('שמור דירוג'),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'מאוד לא מרוצה';
      case 2:
        return 'לא מרוצה';
      case 3:
        return 'בסדר';
      case 4:
        return 'מרוצה';
      case 5:
        return 'מאוד מרוצה';
      default:
        return 'לחץ על הכוכבים לדירוג';
    }
  }

  Future<void> _saveRating() async {
    if (_rating == 0) return;

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

      debugPrint('🔍 Saving rating for helper: $helperUid, rating: $_rating');

      // שמירת הדירוג
      await FirebaseFirestore.instance.collection('ratings').add({
        'requestId': widget.request.requestId,
        'ratedUserId': helperUid,
        'raterUserId': user.uid,
        'rating': _rating,
        'category': _selectedCategory.isNotEmpty ? _selectedCategory : widget.request.category.name,
        'comment': _commentController.text.trim(),
        'createdAt': DateTime.now(),
        'helperDisplayName': helperDisplayName ?? 'משתמש',
        'requestTitle': widget.request.title,
      });

      debugPrint('✅ Rating saved successfully');

      // עדכון סטטיסטיקות המשתמש
      await _updateUserStats(helperUid, _rating);

      // שליחת הודעת מערכת לצ'אט של המשתמש הנבחר
      await _sendCompletionSystemMessage(helperUid, helperDisplayName ?? 'משתמש');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הדירוג נשמר בהצלחה!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // החזרת true שמציינת שהדירוג הושלם
    } catch (e) {
      debugPrint('❌ Error saving rating: $e');
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

  Future<void> _updateUserStats(String userId, int rating) async {
    try {
      debugPrint('🔍 Updating user stats for: $userId, rating: $rating');
      
      // עדכון ממוצע הדירוגים
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

        debugPrint('🔍 Current rating: $currentRating, count: $ratingCount');
        debugPrint('🔍 New average: $newAverage, new count: $newRatingCount');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'averageRating': newAverage,
          'ratingCount': newRatingCount,
          'lastRatedAt': DateTime.now(),
        });
        
        debugPrint('✅ User stats updated successfully');
      } else {
        debugPrint('⚠️ User document not found: $userId');
      }
    } catch (e) {
      // לא נעצור את התהליך בגלל שגיאה בעדכון סטטיסטיקות
      debugPrint('❌ Error updating user stats: $e');
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
      // לא נעצור את התהליך בגלל שגיאה בשליחת הודעת מערכת
    }
  }
}
