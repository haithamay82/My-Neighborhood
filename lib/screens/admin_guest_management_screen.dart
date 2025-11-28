import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../models/request.dart';
import '../services/notification_service.dart';

class AdminGuestManagementScreen extends StatefulWidget {
  const AdminGuestManagementScreen({super.key});

  @override
  State<AdminGuestManagementScreen> createState() => _AdminGuestManagementScreenState();
}

class _AdminGuestManagementScreenState extends State<AdminGuestManagementScreen> {
  String _selectedUserType = 'temporary_guest'; // temporary_guest, registered_guest, private_free, private_subscription, business_subscription
  String _selectedFilter = 'all'; // all, active, expired, about_to_expire
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  // שמירת זמן שליחת תזכורת לכל משתמש (userId -> DateTime)
  final Map<String, DateTime> _reminderSentTimes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ניהול משתמשים'),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // בחירת סוג משתמש
            _buildUserTypeSelector(),
            
            // סינון וחיפוש
            _buildFilterAndSearch(),
            
            // סטטיסטיקות
            _buildStatsCards(),
            
            // רשימת משתמשים
            _buildUsersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'סוג משתמש:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUserTypeChip('temporary_guest', 'אורחים זמניים'),
                const SizedBox(width: 8),
                _buildUserTypeChip('registered_guest', 'אורחים'),
                const SizedBox(width: 8),
                _buildUserTypeChip('private_free', 'פרטי חינם'),
                const SizedBox(width: 8),
                _buildUserTypeChip('private_subscription', 'פרטי מנוי'),
                const SizedBox(width: 8),
                _buildUserTypeChip('business_subscription', 'עסקי מנוי'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeChip(String value, String label) {
    final isSelected = _selectedUserType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedUserType = value;
          _selectedFilter = 'all'; // איפוס הפילטר כשמשנים סוג משתמש
        });
      },
      selectedColor: const Color(0xFF03A9F4),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildFilterAndSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // חיפוש
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'חיפוש לפי שם או אימייל...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // פילטרים - לאורחים זמניים מציגים רק "כל המשתמשים"
          if (_selectedUserType != 'temporary_guest')
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'כל המשתמשים'),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'פעילים'),
                  const SizedBox(width: 8),
                  _buildFilterChip('about_to_expire', 'מסתיימים בקרוב'),
                  const SizedBox(width: 8),
                  _buildFilterChip('expired', 'פג תוקף'),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'כל המשתמשים'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFF03A9F4),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCardWithStream(
              'פעילים',
              Icons.people,
              Colors.green,
              'active',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCardWithStream(
              'מסתיימים בקרוב',
              Icons.warning,
              Colors.orange,
              'about_to_expire',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCardWithStream(
              'פג תוקף',
              Icons.schedule,
              Colors.red,
              'expired',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardWithStream(String title, IconData icon, Color color, String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStreamForFilter(filter),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData && snapshot.data != null) {
          final now = DateTime.now();
          final sevenDaysFromNow = now.add(const Duration(days: 7));
          
          // ספירה לפי פילטר - סינון בהתאם לסוג המשתמש שנבחר
          var filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userType = data['userType'] as String?;
            final isTemporaryGuest = data['isTemporaryGuest'] ?? false;
            final isAdmin = data['isAdmin'] ?? false;
            final isSubscriptionActive = data['isSubscriptionActive'] ?? false;
            
            // סינון לפי סוג המשתמש שנבחר
            if (_selectedUserType == 'temporary_guest') {
              // אורחים זמניים
              return userType == 'guest' && isTemporaryGuest == true;
            } else if (_selectedUserType == 'registered_guest') {
              // אורחים רשומים (לא זמניים, לא מנהל)
              return userType == 'guest' && 
                     (isTemporaryGuest == false || isTemporaryGuest == null) && 
                     isAdmin == false;
            } else if (_selectedUserType == 'private_free') {
              // פרטי חינם
              return userType == 'personal' && isSubscriptionActive == false;
            } else if (_selectedUserType == 'private_subscription') {
              // פרטי מנוי
              return userType == 'personal' && isSubscriptionActive == true;
            } else if (_selectedUserType == 'business_subscription') {
              // עסקי מנוי (לא מנהל) - isAdmin == null נחשב לא מנהל
              return userType == 'business' && 
                     isSubscriptionActive == true && 
                     (isAdmin == false || isAdmin == null);
            }
            
            return false;
          });
          
          // ספירה לפי פילטר
          if (filter == 'active') {
            // עבור "פעילים" - נסנן בצד הלקוח לפי תאריך סיום
            count = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              // לאורחים זמניים - כולם נחשבים פעילים (אין תאריך סיום)
              if (_selectedUserType == 'temporary_guest') {
                return true;
              }
              
              // לאחרים - בדיקה לפי תאריך סיום
              final endDate = _getEndDate(data);
              if (endDate == null) return false;
              
              final endDateTime = endDate.toDate();
              return endDateTime.isAfter(now);
            }).length;
          } else if (filter == 'about_to_expire') {
            // עבור "מסתיימים בקרוב", נסנן בצד הלקוח
            count = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final endDate = _getEndDate(data);
              if (endDate == null) return false;
              
              final endDateTime = endDate.toDate();
              return endDateTime.isAfter(now) && endDateTime.isBefore(sevenDaysFromNow) || 
                     endDateTime.isAtSameMomentAs(sevenDaysFromNow);
            }).length;
          } else if (filter == 'expired') {
            // עבור "פג תוקף" - נסנן בצד הלקוח לפי תאריך סיום
            count = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              // לאורחים זמניים - אין פג תוקף (אין תאריך סיום)
              if (_selectedUserType == 'temporary_guest') {
                return false;
              }
              
              // לאחרים - בדיקה לפי תאריך סיום
              final endDate = _getEndDate(data);
              if (endDate == null) return false;
              
              final endDateTime = endDate.toDate();
              return endDateTime.isBefore(now) || endDateTime.isAtSameMomentAs(now);
            }).length;
          } else {
            // עבור "כל המשתמשים" - השתמש בתוצאות המסוננות
            count = filteredDocs.length;
          }
        }
        
        return _buildStatCard(title, icon, color, count);
      },
    );
  }

  Timestamp? _getEndDate(Map<String, dynamic> data) {
    // עבור אורחים - guestTrialEndDate
    if (_selectedUserType == 'temporary_guest' || _selectedUserType == 'registered_guest') {
      return data['guestTrialEndDate'] as Timestamp?;
    }
    // עבור מנויים - subscriptionExpiry
    return data['subscriptionExpiry'] as Timestamp?;
  }

  Stream<QuerySnapshot> _getUsersStreamForFilter(String filter) {
    Query query = FirebaseFirestore.instance.collection('users');
    
    // סינון לפי סוג משתמש
    if (_selectedUserType == 'temporary_guest') {
      query = query.where('userType', isEqualTo: 'guest')
          .where('isTemporaryGuest', isEqualTo: true);
    } else if (_selectedUserType == 'registered_guest') {
      // אורחים רשומים: isTemporaryGuest הוא false או null (לא מוגדר)
      // Firestore לא תומך ב-whereIn עם null, אז נטען את כל האורחים ונסנן בצד הלקוח
      query = query.where('userType', isEqualTo: 'guest');
    } else if (_selectedUserType == 'private_free') {
      query = query.where('userType', isEqualTo: 'personal')
          .where('isSubscriptionActive', isEqualTo: false);
    } else if (_selectedUserType == 'private_subscription') {
      query = query.where('userType', isEqualTo: 'personal')
          .where('isSubscriptionActive', isEqualTo: true);
    } else if (_selectedUserType == 'business_subscription') {
      // עסקי מנוי: לא מסננים לפי isAdmin ב-Firestore כי isAdmin == null נחשב לא מנהל
      // נסנן בצד הלקוח
      query = query.where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true);
    }

    // סינון לפי תאריך סיום - לאורחים זמניים לא מסננים לפי סטטוס
    if (filter != 'all' && _selectedUserType != 'temporary_guest') {
      final now = DateTime.now();
      final nowTimestamp = Timestamp.fromDate(now);

      switch (filter) {
        case 'active':
          if (_selectedUserType == 'registered_guest') {
            query = query.where('guestTrialEndDate', isGreaterThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isGreaterThan: nowTimestamp);
          }
          break;
        case 'about_to_expire':
          if (_selectedUserType == 'registered_guest') {
            query = query.where('guestTrialEndDate', isGreaterThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isGreaterThan: nowTimestamp);
          }
          break;
        case 'expired':
          if (_selectedUserType == 'registered_guest') {
            query = query.where('guestTrialEndDate', isLessThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isLessThan: nowTimestamp);
          }
          break;
        default:
          // כל המשתמשים
          break;
      }
    }

    return query.snapshots();
  }

  Widget _buildStatCard(String title, IconData icon, Color color, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text('שגיאה בטעינת המשתמשים: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text('אין משתמשים להצגה'),
            ),
          );
        }

        final users = snapshot.data!.docs
            .map((doc) => UserProfile.fromFirestore(doc))
            .toList();

        // הסרת כפילויות לפי userId ואימייל
        // אם יש משתמשים עם אותו userId או אותו אימייל, נשמור רק את הראשון
        final uniqueUsersByUserId = <String, UserProfile>{};
        final uniqueUsersByEmail = <String, UserProfile>{};
        final deduplicatedUsers = <UserProfile>[];
        
        for (final user in users) {
          // בדיקה לפי userId
          if (uniqueUsersByUserId.containsKey(user.userId)) {
            debugPrint('⚠️ Duplicate userId found: ${user.email} (userId: ${user.userId})');
            continue;
          }
          
          // בדיקה לפי אימייל (אם יש אימייל)
          if (user.email.isNotEmpty && uniqueUsersByEmail.containsKey(user.email.toLowerCase())) {
            debugPrint('⚠️ Duplicate email found: ${user.email} (userId: ${user.userId}, existing userId: ${uniqueUsersByEmail[user.email.toLowerCase()]?.userId})');
            continue;
          }
          
          // אם אין כפילות - הוסף לרשימה
          uniqueUsersByUserId[user.userId] = user;
          if (user.email.isNotEmpty) {
            uniqueUsersByEmail[user.email.toLowerCase()] = user;
          }
          deduplicatedUsers.add(user);
        }

        // סינון לפי סוג משתמש (עבור אורחים רשומים ועסקי מנוי - סינון בצד הלקוח)
        var filteredByType = deduplicatedUsers;
        if (_selectedUserType == 'registered_guest') {
          // אורחים רשומים: isTemporaryGuest הוא false או null, לא מנהל
          filteredByType = deduplicatedUsers.where((user) {
            return user.userType == UserType.guest && 
                   (user.isTemporaryGuest == false || user.isTemporaryGuest == null) &&
                   (user.isAdmin == false || user.isAdmin == null);
          }).toList();
        } else if (_selectedUserType == 'temporary_guest') {
          // אורחים זמניים: isTemporaryGuest הוא true
          filteredByType = deduplicatedUsers.where((user) {
            return user.userType == UserType.guest && user.isTemporaryGuest == true;
          }).toList();
        } else if (_selectedUserType == 'business_subscription') {
          // עסקי מנוי: לא מנהל - isAdmin == null נחשב לא מנהל
          filteredByType = deduplicatedUsers.where((user) {
            return user.userType == UserType.business && 
                   user.isSubscriptionActive == true &&
                   (user.isAdmin == false || user.isAdmin == null);
          }).toList();
        }

        // סינון לפי חיפוש
        var filteredUsers = filteredByType.where((user) {
          if (_searchQuery.isEmpty) return true;
          return user.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 user.email.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // סינון לפי "מסתיימים בקרוב" בצד הלקוח (אם נדרש)
        if (_selectedFilter == 'about_to_expire' && 
            _selectedUserType != 'temporary_guest' && 
            _selectedUserType != 'registered_guest') {
          final now = DateTime.now();
          final sevenDaysFromNow = now.add(const Duration(days: 7));
          
          filteredUsers = filteredUsers.where((user) {
            final endDate = user.subscriptionExpiry;
            if (endDate == null) return false;
            
            return endDate.isAfter(now) && 
                   (endDate.isBefore(sevenDaysFromNow) || endDate.isAtSameMomentAs(sevenDaysFromNow));
          }).toList();
        }

        return Column(
          children: [
            ...filteredUsers.map((user) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildUserCard(user),
            )),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _getUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');
    
    // סינון לפי סוג משתמש
    if (_selectedUserType == 'temporary_guest') {
      query = query.where('userType', isEqualTo: 'guest')
          .where('isTemporaryGuest', isEqualTo: true);
    } else if (_selectedUserType == 'registered_guest') {
      // אורחים רשומים: isTemporaryGuest הוא false או null (לא מוגדר)
      // Firestore לא תומך ב-whereIn עם null, אז נטען את כל האורחים ונסנן בצד הלקוח
      query = query.where('userType', isEqualTo: 'guest');
    } else if (_selectedUserType == 'private_free') {
      query = query.where('userType', isEqualTo: 'personal')
          .where('isSubscriptionActive', isEqualTo: false);
    } else if (_selectedUserType == 'private_subscription') {
      query = query.where('userType', isEqualTo: 'personal')
          .where('isSubscriptionActive', isEqualTo: true);
    } else if (_selectedUserType == 'business_subscription') {
      // עסקי מנוי: לא מסננים לפי isAdmin ב-Firestore כי isAdmin == null נחשב לא מנהל
      // נסנן בצד הלקוח
      query = query.where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true);
    }

    // סינון לפי סטטוס - לאורחים זמניים לא מסננים לפי סטטוס
    if (_selectedFilter != 'all' && _selectedUserType != 'temporary_guest') {
      final now = DateTime.now();
      final nowTimestamp = Timestamp.fromDate(now);
      
      switch (_selectedFilter) {
        case 'active':
          if (_selectedUserType == 'registered_guest') {
            query = query.where('guestTrialEndDate', isGreaterThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isGreaterThan: nowTimestamp);
          }
          break;
        case 'about_to_expire':
          if (_selectedUserType == 'registered_guest') {
            // Firestore לא תומך בשני where על אותו שדה, נסנן בצד הלקוח
            query = query.where('guestTrialEndDate', isGreaterThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isGreaterThan: nowTimestamp);
          }
          break;
        case 'expired':
          if (_selectedUserType == 'registered_guest') {
            query = query.where('guestTrialEndDate', isLessThan: nowTimestamp);
          } else {
            query = query.where('subscriptionExpiry', isLessThan: nowTimestamp);
          }
          break;
      }
    }

    return query.snapshots();
  }

  Widget _buildUserCard(UserProfile user) {
    final now = DateTime.now();
    DateTime? endDate;
    int daysLeft = 0;
    
    // לאורחים זמניים - אין תאריך סיום, רק תאריך הצטרפות
    if (user.isTemporaryGuest == true) {
      endDate = null;
      daysLeft = 0;
    } else if (_selectedUserType == 'temporary_guest' || _selectedUserType == 'registered_guest') {
      endDate = user.guestTrialEndDate;
      daysLeft = endDate?.difference(now).inDays ?? 0;
    } else {
      endDate = user.subscriptionExpiry;
      daysLeft = endDate?.difference(now).inDays ?? 0;
    }
    
    final isExpired = daysLeft <= 0 && endDate != null;
    final isAboutToExpire = daysLeft <= 7 && daysLeft > 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    // לאורחים זמניים - הצג סטטוס "פעיל" ללא ימים
    if (user.isTemporaryGuest == true) {
      statusColor = Colors.green;
      statusText = 'פעיל';
      statusIcon = Icons.check_circle;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusText = 'פג תוקף';
      statusIcon = Icons.schedule;
    } else if (isAboutToExpire) {
      statusColor = Colors.orange;
      statusText = 'מסתיים בקרוב ($daysLeft ימים)';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.green;
      statusText = 'פעיל ($daysLeft ימים)';
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF03A9F4),
                  child: Text(
                    user.displayName.isNotEmpty 
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // פרטים נוספים
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  // לאורחים זמניים - הצג תאריך הצטרפות, לאחרים - תאריך סיום
                  user.isTemporaryGuest == true 
                      ? 'תאריך הצטרפות: ${_formatDate(user.createdAt)}'
                      : 'תאריך סיום: ${_formatDate(endDate)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (user.businessCategories?.isNotEmpty == true) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.category, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${user.businessCategories!.length} תחומים',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            
            if (user.businessCategories?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: user.businessCategories!.take(3).map((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03A9F4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.categoryDisplayName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF03A9F4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // כפתורי פעולה
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedUserType == 'temporary_guest' || _selectedUserType == 'registered_guest') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendReminderNotification(user),
                          icon: const Icon(Icons.notifications, size: 16),
                          label: const Text('שלח תזכורת'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _viewUserDetails(user),
                          icon: const Icon(Icons.info, size: 16),
                          label: const Text('פרטים'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03A9F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // הצגת "נשלחה תזכורת" אם נשלחה תזכורת לאורח זמני
                  if (user.isTemporaryGuest == true && _reminderSentTimes.containsKey(user.userId)) ...[
                    const SizedBox(height: 4),
                    Text(
                      'נשלחה תזכורת',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _viewUserDetails(user),
                          icon: const Icon(Icons.info, size: 16),
                          label: const Text('פרטים'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03A9F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'לא ידוע';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _sendReminderNotification(UserProfile user) async {
    try {
      // בדיקה אם המשתמש הוא אורח זמני
      if (user.isTemporaryGuest == true) {
        // שליחת התראה מיוחדת למשתמש אורח זמני
        await NotificationService.sendNotification(
          toUserId: user.userId,
          title: 'שלום אורח',
          message: 'הירשם עכשיו וקבל גישה לכל הפיצ\'רים בשכונתי. בחינם במשך 60 יום!',
          type: 'general',
          data: {
            'action': 'register', // סימון שזה התראה עם כפתור "הירשם"
          },
        );
        
        // שמירת זמן שליחת התזכורת
        setState(() {
          _reminderSentTimes[user.userId] = DateTime.now();
        });
      } else {
        // התראה רגילה למשתמשים אחרים
        final endDate = (_selectedUserType == 'temporary_guest' || _selectedUserType == 'registered_guest')
            ? user.guestTrialEndDate 
            : user.subscriptionExpiry;
        final daysLeft = endDate?.difference(DateTime.now()).inDays ?? 0;
        
        await NotificationService.sendNotification(
          toUserId: user.userId,
          title: 'תזכורת: תקופת המנוי שלך מסתיימת בקרוב',
          message: 'נותרו לך $daysLeft ימים. שדרג עכשיו!',
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('תזכורת נשלחה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת תזכורת: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewUserDetails(UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<int>(
        future: _getUserRequestsCount(user.userId),
        builder: (context, snapshot) {
          final requestsCount = snapshot.data ?? 0;
          
          return AlertDialog(
            title: Text('פרטי משתמש: ${user.displayName}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('אימייל', user.email),
                  _buildDetailRow('סוג משתמש', _getUserTypeDisplayName(user)),
                  if (_selectedUserType == 'temporary_guest' || _selectedUserType == 'registered_guest') ...[
                    if (user.isTemporaryGuest == true) ...[
                      // אורחים זמניים - הצג תאריך הצטרפות
                      _buildDetailRow('תאריך הצטרפות', _formatDate(user.createdAt)),
                    ] else ...[
                      // אורחים רשומים - הצג תאריך התחלה וסיום
                      _buildDetailRow('תאריך התחלה', _formatDate(user.guestTrialStartDate)),
                      _buildDetailRow('תאריך סיום', _formatDate(user.guestTrialEndDate)),
                      _buildDetailRow('ימים נותרים', '${user.guestTrialEndDate?.difference(DateTime.now()).inDays ?? 0}'),
                    ],
                    _buildDetailRow('טווח מקסימלי', '${user.maxRadius} ק"מ'),
                    _buildDetailRow('בקשות מקסימליות', '${user.maxRequestsPerMonth} לחודש'),
                    _buildDetailRow('מספר בקשות שפורסמו', snapshot.connectionState == ConnectionState.waiting 
                        ? 'טוען...' 
                        : '$requestsCount'),
                  ] else ...[
                    _buildDetailRow('תאריך סיום מנוי', _formatDate(user.subscriptionExpiry)),
                    _buildDetailRow('ימים נותרים', '${user.subscriptionExpiry?.difference(DateTime.now()).inDays ?? 0}'),
                    _buildDetailRow('מספר בקשות שפורסמו', snapshot.connectionState == ConnectionState.waiting 
                        ? 'טוען...' 
                        : '$requestsCount'),
                  ],
              if (user.businessCategories?.isNotEmpty == true) ...[
                _buildDetailRow('תחומי עיסוק', '${user.businessCategories!.length}'),
                const SizedBox(height: 8),
                const Text('תחומים:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...user.businessCategories!.map((category) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text('• ${category.categoryDisplayName}'),
                  ),
                ),
              ],
            ],
          ),
        ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('סגור'),
              ),
              ElevatedButton(
                onPressed: () => _deleteUser(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('מחק משתמש'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<int> _getUserRequestsCount(String userId) async {
    try {
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      return requestsQuery.docs.length;
    } catch (e) {
      debugPrint('Error getting user requests count: $e');
      return 0;
    }
  }

  String _getUserTypeDisplayName(UserProfile user) {
    if (user.userType == UserType.guest) {
      return 'אורח';
    } else if (user.userType == UserType.personal) {
      return user.isSubscriptionActive ? 'פרטי מנוי' : 'פרטי חינם';
    } else if (user.userType == UserType.business) {
      return 'עסקי מנוי';
    } else if (user.userType == UserType.admin) {
      return 'מנהל';
    }
    return 'לא ידוע';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserProfile user) async {
    // אישור מחיקה
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת משתמש'),
        content: Text('האם אתה בטוח שברצונך למחוק את המשתמש ${user.displayName}? פעולה זו לא ניתנת לביטול.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // הצגת אינדיקטור טעינה
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('מוחק משתמש...'),
            ],
          ),
        ),
      );
    }

    try {
      // מחיקת נתוני המשתמש מ-Firestore
      await _deleteUserDataFromFirestore(user.userId);
      
      // מחיקת תמונות המשתמש מ-Firebase Storage
      await _deleteUserImagesFromStorage(user.userId);
      
      // מחיקת החשבון מ-Firebase Auth (אם אפשר)
      try {
        // רק מנהל יכול למחוק משתמשים אחרים
        // ננסה למחוק דרך Admin SDK או Cloud Function
        // כאן נמחק רק מ-Firestore
      } catch (e) {
        debugPrint('Error deleting user from Auth: $e');
      }

      // סגירת דיאלוג הטעינה
      if (mounted) {
        Navigator.of(context).pop(); // סגירת דיאלוג הטעינה
        Navigator.of(context).pop(); // סגירת דיאלוג הפרטים
      }

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המשתמש נמחק בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting user: $e');
      
      // סגירת דיאלוג הטעינה אם פתוח
      if (mounted) {
        Navigator.of(context).pop(); // סגירת דיאלוג הטעינה
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת המשתמש: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// מחיקת כל נתוני המשתמש מ-Firestore
  Future<void> _deleteUserDataFromFirestore(String userId) async {
    try {
      // מחיקה מקבילה של כל הנתונים
      await Future.wait([
        // מחיקת פרופיל המשתמש
        FirebaseFirestore.instance.collection('users').doc(userId).delete(),
        
        // מחיקת בקשות שהמשתמש יצר
        _deleteCollectionData('requests', 'createdBy', userId),
        
        // מחיקת צ'אטים של המשתמש
        _deleteCollectionData('chats', 'participants', userId, isArrayContains: true),
        
        // מחיקת הודעות של המשתמש
        _deleteCollectionData('messages', 'from', userId),
        
        // מחיקת דירוגים שהמשתמש נתן
        _deleteCollectionData('ratings', 'raterId', userId),
        
        // מחיקת דירוגים שקיבל המשתמש
        _deleteCollectionData('ratings', 'ratedUserId', userId),
        
        // מחיקת התראות של המשתמש
        _deleteCollectionData('notifications', 'toUserId', userId),
      ]);

      debugPrint('Successfully deleted user data from Firestore');
    } catch (e) {
      debugPrint('Error deleting user data from Firestore: $e');
      rethrow;
    }
  }

  /// פונקציה עזר למחיקת נתונים מקולקציה
  Future<void> _deleteCollectionData(String collection, String field, String value, {bool isArrayContains = false}) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collection);
      
      if (isArrayContains) {
        query = query.where(field, arrayContains: value);
      } else {
        query = query.where(field, isEqualTo: value);
      }
      
      final querySnapshot = await query.get();
      
      // מחיקה מקבילה של כל המסמכים
      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      debugPrint('Deleted ${querySnapshot.docs.length} documents from $collection');
    } catch (e) {
      debugPrint('Error deleting from $collection: $e');
      // לא נזרוק שגיאה כאן כי זה לא קריטי
    }
  }

  /// מחיקת תמונות המשתמש מ-Firebase Storage
  Future<void> _deleteUserImagesFromStorage(String userId) async {
    try {
      final storage = FirebaseStorage.instance;
      final userImagesRef = storage.ref().child('user_images/$userId');
      
      // מחיקת כל התמונות של המשתמש
      final listResult = await userImagesRef.listAll();
      for (var item in listResult.items) {
        await item.delete();
      }

      debugPrint('Successfully deleted user images from Storage');
    } catch (e) {
      debugPrint('Error deleting user images from Storage: $e');
      // לא נזרוק שגיאה כאן כי זה לא קריטי
    }
  }

}
