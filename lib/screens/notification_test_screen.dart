import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_test_service.dart';
import '../services/direct_notification_service.dart';
import '../services/simple_notification_service.dart';
import '../services/direct_fcm_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await NotificationTestService.getUsersWithFCMTokens();
      setState(() => _users = users);
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('אין משתמש מחובר'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // שליחת התראה ישירה
      await DirectNotificationService.sendDirectNotification(
        userId: currentUser.uid,
        title: 'בדיקת התראה 🧪',
        body: 'זוהי התראה לבדיקה - אם אתה רואה את זה, ההתראות עובדות!',
        payload: 'test_notification',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התראה בדיקה נשלחה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת התראה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendDirectNotification() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('אין משתמש מחובר'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // בדיקת FCM token
      final fcmToken = await DirectNotificationService.getUserFCMToken(currentUser.uid);
      if (fcmToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('אין FCM token למשתמש - התראות לא יעבדו'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // שליחת התראה ישירה
      await DirectNotificationService.sendDirectNotification(
        userId: currentUser.uid,
        title: 'בדיקת התראה ישירה 🚀',
        body: 'זוהי התראה ישירה - אם אתה רואה את זה, FCM עובד!',
        payload: 'direct_test',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התראה ישירה נשלחה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת התראה ישירה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSimpleNotification() async {
    try {
      await SimpleNotificationService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התראה פשוטה נשלחה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת התראה פשוטה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendDirectFCMNotification() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('אין משתמש מחובר'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      await DirectFCMService.sendDirectNotification(
        userId: currentUser.uid,
        title: 'בדיקת התראה FCM ישירה 🚀',
        body: 'זוהי התראה ישירה דרך Firestore - אם אתה רואה את זה, FCM עובד!',
        payload: 'direct_fcm_test',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התראה FCM ישירה נשלחה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת התראה FCM: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendTestToUser(String userId) async {
    try {
      await DirectFCMService.sendDirectNotification(
        userId: userId,
        title: 'בדיקת התראה 🧪',
        body: 'זוהי התראה לבדיקה - אם אתה רואה את זה, ההתראות עובדות!',
        payload: 'test_notification',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התראה בדיקה נשלחה למשתמש!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשליחת התראה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('בדיקת התראות'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFFFF9800) // כתום ענתיק
            : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כפתור בדיקה למשתמש הנוכחי
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.blue),
                title: const Text('שלח התראה בדיקה לעצמי'),
                subtitle: Text('משתמש: ${currentUser?.email ?? 'לא מחובר'}'),
                trailing: const Icon(Icons.send),
                onTap: _sendTestNotification,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // כפתור בדיקה ישירה
            Card(
              child: ListTile(
                leading: const Icon(Icons.send_and_archive, color: Colors.green),
                title: const Text('שלח התראה ישירה'),
                subtitle: const Text('שליחה ישירה דרך Firebase (ללא Cloud Functions)'),
                trailing: const Icon(Icons.rocket_launch),
                onTap: _sendDirectNotification,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // כפתור בדיקה פשוטה
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud, color: Colors.blue),
                title: const Text('שלח התראה פשוטה'),
                subtitle: const Text('שליחה דרך Cloud Functions'),
                trailing: const Icon(Icons.cloud_upload),
                onTap: _sendSimpleNotification,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // כפתור בדיקה ישירה FCM
            Card(
              child: ListTile(
                leading: const Icon(Icons.send, color: Colors.purple),
                title: const Text('שלח התראה FCM ישירה'),
                subtitle: const Text('שליחה ישירה דרך Firestore'),
                trailing: const Icon(Icons.send_and_archive),
                onTap: _sendDirectFCMNotification,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // רשימת משתמשים
            const Text(
              'משתמשים עם FCM Tokens:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_users.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info, color: Colors.orange),
                  title: Text('אין משתמשים עם FCM tokens'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            (user['displayName'] as String).isNotEmpty 
                                ? (user['displayName'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user['displayName'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${user['userId']}'),
                            Text(
                              'Token: ${(user['fcmToken'] as String).substring(0, 20)}...',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Colors.green),
                          onPressed: () => _sendTestToUser(user['userId']),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
