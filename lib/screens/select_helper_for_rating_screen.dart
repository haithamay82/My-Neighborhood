import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/request.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';
import 'detailed_rating_screen.dart';

class SelectHelperForRatingScreen extends StatefulWidget {
  final Request request;

  const SelectHelperForRatingScreen({
    super.key,
    required this.request,
  });

  @override
  State<SelectHelperForRatingScreen> createState() => _SelectHelperForRatingScreenState();
}

class _SelectHelperForRatingScreenState extends State<SelectHelperForRatingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _helpers = [];
  Set<String> _usersWithChats = {}; // משתמשים שיש ביניהם צ'אטים

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 SelectHelperForRatingScreen initState called');
    debugPrint('🔍 Request ID: ${widget.request.requestId}');
    debugPrint('🔍 Request helpers: ${widget.request.helpers}');
    _loadHelpers();
  }

  Future<void> _loadHelpers() async {
    try {
      debugPrint('🔍 Loading helpers for request: ${widget.request.requestId}');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // טעינת משתמשים שיש ביניהם צ'אטים
      await _loadUsersWithChats(user.uid);

      final allHelpers = <Map<String, dynamic>>[];

      // 1. טעינת עוזרים (helpers) - אלה שלחצו "אני מעוניין"
      if (widget.request.helpers.isNotEmpty) {
      debugPrint('🔍 Querying users collection for helpers...');
      final helpersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: widget.request.helpers)
          .get();

      final helpers = helpersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'displayName': data['displayName'] ?? 'משתמש',
          'email': data['email'] ?? '',
          'userType': data['userType'] ?? 'personal',
            'hasChat': _usersWithChats.contains(doc.id),
            'source': 'helper', // מקור: עוזר
        };
      }).toList();

        allHelpers.addAll(helpers);
      }

      // 2. טעינת נותני שירות זמינים במפה (רק לבקשות בתשלום)
      if (widget.request.type == RequestType.paid &&
          widget.request.latitude != null &&
          widget.request.longitude != null &&
          widget.request.exposureRadius != null) {
        debugPrint('🔍 Loading map helpers for paid request...');
        final mapHelpers = await _loadMapHelpers();
        allHelpers.addAll(mapHelpers);
      }

      // 3. מיון: קודם אלה שיש ביניהם צ'אטים, אחר כך כל השאר
      allHelpers.sort((a, b) {
        final aHasChat = a['hasChat'] == true;
        final bHasChat = b['hasChat'] == true;
        if (aHasChat && !bHasChat) return -1;
        if (!aHasChat && bHasChat) return 1;
        return 0;
      });

      // 4. הסרת כפילויות (לפי uid)
      final uniqueHelpers = <String, Map<String, dynamic>>{};
      for (var helper in allHelpers) {
        final uid = helper['uid'] as String;
        if (!uniqueHelpers.containsKey(uid)) {
          uniqueHelpers[uid] = helper;
        } else {
          // אם יש כפילות, שמור את זה שיש ביניהם צ'אט
          if (helper['hasChat'] == true) {
            uniqueHelpers[uid] = helper;
          }
        }
      }

      debugPrint('🔍 Processed ${uniqueHelpers.length} unique helpers');
      setState(() {
        _helpers = uniqueHelpers.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading helpers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בטעינת המשתמשים: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // טעינת משתמשים שיש ביניהם צ'אטים
  Future<void> _loadUsersWithChats(String currentUserId) async {
    try {
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: widget.request.requestId)
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);
        for (var participantId in participants) {
          if (participantId != currentUserId) {
            _usersWithChats.add(participantId);
          }
        }
      }

      debugPrint('🔍 Found ${_usersWithChats.length} users with chats');
    } catch (e) {
      debugPrint('❌ Error loading users with chats: $e');
    }
  }

  // טעינת נותני שירות זמינים במפה
  Future<List<Map<String, dynamic>>> _loadMapHelpers() async {
    try {
      final request = widget.request;
      final helperLocations = <Map<String, dynamic>>[];

      // טעינת כל המשתמשים עם תחומי עיסוק מתאימים
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return [];

      for (var userDoc in usersQuery.docs) {
        if (userDoc.id == currentUserId) continue; // דלג על המשתמש הנוכחי

        final userProfile = UserProfile.fromFirestore(userDoc);

        // בדיקה אם המשתמש רלוונטי (עסקי מנוי או אורח עם תחומי עיסוק מתאימים)
        bool isRelevant = false;
        if (userProfile.userType == UserType.business && userProfile.isSubscriptionActive == true) {
          // עסקי מנוי - בדוק אם יש תחומי עיסוק מתאימים
          if (userProfile.businessCategories != null &&
              userProfile.businessCategories!.isNotEmpty) {
            final hasMatchingCategory = userProfile.businessCategories!.any(
              (cat) => cat.name == request.category.name,
            );
            if (hasMatchingCategory) {
              isRelevant = true;
            }
          }
        } else if (userProfile.userType == UserType.guest) {
          // אורח - בדוק אם יש תחומי עיסוק מתאימים
          if (userProfile.businessCategories != null &&
              userProfile.businessCategories!.isNotEmpty) {
            final hasMatchingCategory = userProfile.businessCategories!.any(
              (cat) => cat.name == request.category.name,
            );
            if (hasMatchingCategory) {
              isRelevant = true;
            }
          }
        }

        if (!isRelevant) continue;

        // בדיקת מיקום בטווח
        bool inRange = false;
        if (request.latitude != null && request.longitude != null && request.exposureRadius != null) {
          // בדיקת מיקום קבוע
          if (userProfile.latitude != null && userProfile.longitude != null) {
            final distance = Geolocator.distanceBetween(
              request.latitude!,
              request.longitude!,
              userProfile.latitude!,
              userProfile.longitude!,
            ) / 1000; // המרה לקילומטרים
            if (distance <= request.exposureRadius!) {
              inRange = true;
            }
          }

          // בדיקת מיקום נייד
          if (!inRange && userProfile.mobileLatitude != null && userProfile.mobileLongitude != null) {
            final distance = Geolocator.distanceBetween(
              request.latitude!,
              request.longitude!,
              userProfile.mobileLatitude!,
              userProfile.mobileLongitude!,
            ) / 1000; // המרה לקילומטרים
            if (distance <= request.exposureRadius!) {
              inRange = true;
            }
          }
        }

        if (inRange) {
          helperLocations.add({
            'uid': userDoc.id,
            'displayName': userProfile.displayName,
            'email': userProfile.email,
            'userType': userProfile.userType.name,
            'hasChat': _usersWithChats.contains(userDoc.id),
            'source': 'map', // מקור: מפה
          });
        }
      }

      debugPrint('🔍 Found ${helperLocations.length} map helpers');
      return helperLocations;
    } catch (e) {
      debugPrint('❌ Error loading map helpers: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('בחר מי עזר לך'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
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
    if (_helpers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'אין משתמשים שעזרו לך',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'אף משתמש לא לחץ "אני מעוניין" על בקשה זו',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('חזור'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'בחר את המשתמש שעזר לך בפועל כדי לדרג אותו',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'בחר מי מהמשתמשים עזר לך בבקשת:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _helpers.length,
              itemBuilder: (context, index) {
                final helper = _helpers[index];
                return _buildHelperCard(helper);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperCard(Map<String, dynamic> helper) {
    final hasChat = helper['hasChat'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: hasChat ? Theme.of(context).colorScheme.primaryContainer : null, // הדגשה למשתמשים שיש ביניהם צ'אטים
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            helper['displayName'][0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
            if (hasChat)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.chat,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
          helper['displayName'],
          style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (hasChat)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'יש צ\'אט',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(helper['email']),
            const SizedBox(height: 4),
            Row(
              children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: helper['userType'] == 'business' 
                    ? Theme.of(context).colorScheme.tertiaryContainer 
                        : helper['userType'] == 'guest'
                            ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                    helper['userType'] == 'business' || helper['userType'] == 'guest'
                        ? 'עסקי' 
                        : 'פרטי',
                style: TextStyle(
                  fontSize: 12,
                  color: helper['userType'] == 'business' 
                      ? Theme.of(context).colorScheme.onTertiaryContainer 
                          : helper['userType'] == 'guest'
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
                ),
                if (helper['source'] == 'map') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'במפה',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _navigateToRating(helper),
          icon: const Icon(Icons.star),
          label: const Text('דרג'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _navigateToRating(Map<String, dynamic> helper) {
    debugPrint('🔍 Navigating to rating screen for helper: ${helper['uid']}');
    debugPrint('🔍 Helper data: $helper');
    
    // בדיקת נתוני המשתמש
    if (helper['uid'] == null || helper['uid'].toString().isEmpty) {
      debugPrint('❌ Invalid helper UID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('שגיאה: נתוני המשתמש לא תקינים'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedRatingScreen(
          request: widget.request,
          helper: helper,
        ),
      ),
    ).then((ratingCompleted) {
      debugPrint('🔄 Returned from rating screen, rating completed: $ratingCompleted');
      // Guard context usage after async gap
      if (!mounted) return;
      // אחרי הדירוג, חזור למסך הקודם עם הערך שחוזר
      Navigator.pop(context, ratingCompleted);
    }).catchError((error) {
      debugPrint('❌ Error in rating screen: $error');
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
}
