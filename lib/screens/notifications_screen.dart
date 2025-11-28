import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';
import '../l10n/app_localizations.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../services/notification_navigation_service.dart';
import '../services/auto_login_service.dart';
import 'manage_notifications_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  bool _hasNotificationPermission = false;
  final bool _hasShownTutorial = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasShownTutorial) {
      // הודעת הדרכה הוסרה - רק במסך הבית
    }
  }
  
  // הצגת הודעת הדרכה למסך התראות
  // הודעת הדרכה הוסרה - רק במסך הבית
  
  Future<void> _checkNotificationPermission() async {
    final hasPermission = await PermissionService.checkNotificationPermission();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = hasPermission;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.notifications),
        ),
        body: Center(
          child: Text(l10n.userNotConnected),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.notifications,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageNotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: l10n.manageNotifications,
            ),
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: l10n.markAllAsRead,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (!mounted) return;
                
                if (value == 'clear_all') {
                  _showClearAllDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.clear_all, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).clearAllNotifications),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (!_hasNotificationPermission)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_off, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.notificationsBlocked,
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await PermissionService.requestNotificationPermission(context);
                        _checkNotificationPermission();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.enableNotifications),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: NotificationService.getUserNotifications(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(l10n.errorMessage(snapshot.error.toString())),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noNewNotifications,
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.notificationInfo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                  }

                  final notifications = snapshot.data!;

                  return Column(
                    children: [
                      // רשימת ההתראות
                      Expanded(
                        child: ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationCard(notification, l10n);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white 
              : Theme.of(context).colorScheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Theme.of(context).colorScheme.onSurfaceVariant,
            width: 1,
          ),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification.type, notification.read),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: notification.read 
                ? (Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurfaceVariant 
                    : Theme.of(context).colorScheme.onSurfaceVariant) 
                : Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.createdAt),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (notification.type == NotificationType.newRequest && notification.data != null && notification.data!['requestId'] != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final String reqId = notification.data!['requestId'];
                    // נווט דרך שירות הניווט הייעודי
                    NotificationNavigationService.navigateFromNotification(
                      context,
                      'new_request',
                      requestId: reqId,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.openRequest),
                ),
              ),
            // כפתור "הירשם" עבור משתמשים אורחים זמניים
            if (notification.data != null && notification.data!['action'] == 'register')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _performLogoutForRegistration(),
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.register),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        trailing: notification.read
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _markAsRead(notification.notificationId),
        onLongPress: () => _showDeleteNotificationDialog(notification),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.subscriptionApproved:
        return Icons.check_circle;
      case NotificationType.subscriptionRejected:
        return Icons.cancel;
      case NotificationType.chatMessage:
        return Icons.chat;
      case NotificationType.newRequest:
        return Icons.add_circle;
    }
  }

  Color _getNotificationColor(NotificationType type, bool read) {
    if (read) {
      return Theme.of(context).brightness == Brightness.dark 
          ? Theme.of(context).colorScheme.onSurfaceVariant 
          : Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    
    switch (type) {
      case NotificationType.subscriptionApproved:
        return Colors.green;
      case NotificationType.subscriptionRejected:
        return Colors.red;
      case NotificationType.chatMessage:
        return Colors.blue;
      case NotificationType.newRequest:
        return Colors.orange;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorUpdatingNotification(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await NotificationService.markAllAsRead(user.uid);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.allNotificationsMarkedAsRead),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorUpdatingNotifications(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.clearAllNotificationsTitle),
          content: Text(dialogL10n.clearAllNotificationsMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _clearAllNotifications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(dialogL10n.clearAll),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // מחיקת כל ההתראות של המשתמש
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: user.uid)
          .get();

      if (notificationsQuery.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in notificationsQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.allNotificationsDeletedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorDeletingNotifications(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteNotificationDialog(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.deleteNotification),
          content: Text(dialogL10n.deleteNotificationMessage(notification.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteNotification(notification.notificationId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(dialogL10n.delete),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notificationDeletedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorDeletingNotification(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.now;
    } else if (difference.inHours < 1) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// ביצוע התנתקות לצורך הרשמה (למשתמש אורח זמני)
  Future<void> _performLogoutForRegistration() async {
    try {
      // התנתקות מלאה - מוחקת את כל המידע השמור
      await AutoLoginService.logout();
      
      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout for registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתנתקות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
