import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';

class AdminGuestManagementScreen extends StatefulWidget {
  const AdminGuestManagementScreen({super.key});

  @override
  State<AdminGuestManagementScreen> createState() => _AdminGuestManagementScreenState();
}

class _AdminGuestManagementScreenState extends State<AdminGuestManagementScreen> {
  String _selectedFilter = 'all'; // all, active, expired, about_to_expire
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ניהול אורחים'),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // סינון וחיפוש
          _buildFilterAndSearch(),
          
          // סטטיסטיקות
          _buildStatsCards(),
          
          // רשימת אורחים
          Expanded(
            child: _buildGuestsList(),
          ),
        ],
      ),
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
          
          // פילטרים
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'כל האורחים'),
                const SizedBox(width: 8),
                _buildFilterChip('active', 'פעילים'),
                const SizedBox(width: 8),
                _buildFilterChip('about_to_expire', 'מסתיימים בקרוב'),
                const SizedBox(width: 8),
                _buildFilterChip('expired', 'פג תוקף'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'פעילים',
              Icons.people,
              Colors.green,
              _getActiveGuestsCount(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'מסתיימים בקרוב',
              Icons.warning,
              Colors.orange,
              _getAboutToExpireGuestsCount(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'פג תוקף',
              Icons.schedule,
              Colors.red,
              _getExpiredGuestsCount(),
            ),
          ),
        ],
      ),
    );
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
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getGuestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('שגיאה בטעינת האורחים: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('אין אורחים להצגה'),
          );
        }

        final guests = snapshot.data!.docs
            .map((doc) => UserProfile.fromFirestore(doc))
            .toList();

        // סינון לפי חיפוש
        final filteredGuests = guests.where((guest) {
          if (_searchQuery.isEmpty) return true;
          return guest.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 guest.email.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGuests.length,
          itemBuilder: (context, index) {
            final guest = filteredGuests[index];
            return _buildGuestCard(guest);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getGuestsStream() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'guest');

    // סינון לפי סטטוס
    switch (_selectedFilter) {
      case 'active':
        query = query.where('guestTrialEndDate', isGreaterThan: Timestamp.fromDate(DateTime.now()));
        break;
      case 'about_to_expire':
        final sevenDaysFromNow = DateTime.now().add(const Duration(days: 7));
        query = query
            .where('guestTrialEndDate', isLessThanOrEqualTo: Timestamp.fromDate(sevenDaysFromNow))
            .where('guestTrialEndDate', isGreaterThan: Timestamp.fromDate(DateTime.now()));
        break;
      case 'expired':
        query = query.where('guestTrialEndDate', isLessThan: Timestamp.fromDate(DateTime.now()));
        break;
    }

    return query.snapshots();
  }

  Widget _buildGuestCard(UserProfile guest) {
    final now = DateTime.now();
    final daysLeft = guest.guestTrialEndDate?.difference(now).inDays ?? 0;
    final isExpired = daysLeft <= 0;
    final isAboutToExpire = daysLeft <= 7 && daysLeft > 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
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
                    guest.displayName.isNotEmpty 
                        ? guest.displayName[0].toUpperCase()
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
                        guest.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        guest.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
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
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'התחיל: ${_formatDate(guest.guestTrialStartDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${guest.businessCategories?.length ?? 0} תחומים',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            
            if (guest.businessCategories?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: guest.businessCategories!.take(3).map((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF03A9F4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.name,
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
            Row(
              children: [
                if (!isExpired) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendReminderNotification(guest),
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
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewGuestDetails(guest),
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
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'לא ידוע';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _sendReminderNotification(UserProfile guest) async {
    try {
      await NotificationService.sendNotification(
        toUserId: guest.userId,
        title: 'תזכורת: תקופת האורח שלך מסתיימת בקרוב',
        message: 'נותרו לך ${guest.guestTrialEndDate?.difference(DateTime.now()).inDays ?? 0} ימים. שדרג עכשיו!',
      );
      
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

  void _viewGuestDetails(UserProfile guest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('פרטי אורח: ${guest.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('אימייל', guest.email),
              _buildDetailRow('תאריך התחלה', _formatDate(guest.guestTrialStartDate)),
              _buildDetailRow('תאריך סיום', _formatDate(guest.guestTrialEndDate)),
              _buildDetailRow('ימים נותרים', '${guest.guestTrialEndDate?.difference(DateTime.now()).inDays ?? 0}'),
              _buildDetailRow('טווח מקסימלי', '${guest.maxRadius} ק"מ'),
              _buildDetailRow('בקשות מקסימליות', '${guest.maxRequestsPerMonth} לחודש'),
              _buildDetailRow('תחומי עיסוק', '${guest.businessCategories?.length ?? 0}'),
              if (guest.businessCategories?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                const Text('תחומים:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...guest.businessCategories!.map((category) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text('• ${category.name}'),
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
        ],
      ),
    );
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

  // פונקציות עזר לספירה
  int _getActiveGuestsCount() {
    // זה יועדכן אוטומטית דרך StreamBuilder
    return 0; // placeholder
  }

  int _getAboutToExpireGuestsCount() {
    // זה יועדכן אוטומטית דרך StreamBuilder
    return 0; // placeholder
  }

  int _getExpiredGuestsCount() {
    // זה יועדכן אוטומטית דרך StreamBuilder
    return 0; // placeholder
  }
}
