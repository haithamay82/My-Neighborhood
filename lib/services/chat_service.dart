import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';
import 'notification_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// יצירת צ'אט חדש בין מבקש העוזר
  static Future<String?> createChat({
    required String requestId,
    required String creatorId,
    required String helperId,
  }) async {
    try {
      // בדיקה אם כבר קיים צ'אט בין השניים הספציפיים
      final existingChat = await _firestore
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('participants', arrayContains: helperId)
          .get();

      // חיפוש צ'אט ספציפי עם שני המשתתפים
      for (var doc in existingChat.docs) {
        final chatData = doc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);
        if (participants.contains(creatorId) && participants.contains(helperId)) {
          debugPrint('Found existing chat between $creatorId and $helperId: ${doc.id}');
          return doc.id;
        }
      }

      debugPrint('No existing chat found between $creatorId and $helperId, creating new one...');

      // יצירת צ'אט חדש
      final chat = Chat(
        chatId: '', // יוגדר על ידי Firestore
        requestId: requestId,
        participants: [creatorId, helperId],
        lastMessage: null,
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('chats')
          .add(chat.toFirestore());

      return docRef.id;
    } catch (e) {
      debugPrint('שגיאה ביצירת צ\'אט: $e');
      return null;
    }
  }

  /// שליחת הודעה בצ'אט
  static Future<bool> sendMessage({
    required String chatId,
    required String text,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // קבלת פרטי הצ'אט
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();
      
      if (!chatDoc.exists) return false;
      
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);
      final requestId = chatData['requestId'] as String? ?? '';
      
      // מציאת כל המשתתפים האחרים (לא השולח)
      final otherParticipants = participants.where((id) => id != user.uid).toList();
      
      if (otherParticipants.isEmpty) return false;

      final message = Message(
        messageId: '', // יוגדר על ידי Firestore
        from: user.uid,
        text: text,
        sentAt: DateTime.now(),
        isSystemMessage: false,
      );

      // שמירת ההודעה
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toFirestore());

      // עדכון lastMessage ו-updatedAt בצ'אט
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'lastMessage': text,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // שליחת התראה לכל המשתתפים האחרים
      try {
        // קבלת שם המשתמש השולח
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        final userName = userDoc.data()?['displayName'] as String? ?? 'משתמש';
        
        // קבלת כותרת הבקשה
        String requestTitle = 'בקשה';
        if (requestId.isNotEmpty) {
          final requestDoc = await _firestore
              .collection('requests')
              .doc(requestId)
              .get();
          
          if (requestDoc.exists) {
            requestTitle = requestDoc.data()?['title'] as String? ?? 'בקשה';
          }
        }
        
        // שליחת התראה לכל המשתתפים האחרים
        for (final participantId in otherParticipants) {
          await NotificationService.sendChatNotification(
            toUserId: participantId,
            fromUserName: userName,
            requestTitle: requestTitle,
            chatId: chatId,
            messageText: text,
          );
        }
      } catch (e) {
        debugPrint('שגיאה בשליחת התראה: $e');
        // לא נעצור את התהליך בגלל שגיאה בהתראה
      }

      return true;
    } catch (e) {
      debugPrint('שגיאה בשליחת הודעה: $e');
      return false;
    }
  }

  /// קבלת רשימת צ'אטים של משתמש
  static Stream<List<Chat>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Chat.fromFirestore(doc))
            .toList());
  }

  /// קבלת הודעות צ'אט
  static Stream<List<Message>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList());
  }

  /// שליחת הודעה עם התראות
  static Future<bool> sendMessageWithNotification({
    required String chatId,
    required String text,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // קבלת פרטי הצ'אט
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return false;

      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // מציאת כל המקבלים (כל המשתתפים חוץ מהשולח)
      final recipients = participants.where((id) => id != user.uid).toList();

      if (recipients.isEmpty) return false;

      // שליחת ההודעה
      final message = Message(
        messageId: '', // יוגדר על ידי Firestore
        from: user.uid,
        text: text,
        sentAt: DateTime.now(),
        isSystemMessage: false,
      );
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toFirestore());

      // עדכון lastMessage ו-updatedAt
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'lastMessage': text,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'lastMessageFrom': user.uid,
        'unreadFor': recipients, // מי צריך לקרוא - כל המקבלים
      });

      // שליחת התראה לכל המקבלים (לא לשולח)
      for (final recipientId in recipients) {
        await _sendChatNotification(chatId, recipientId, text, user.uid);
      }

      return true;
    } catch (e) {
      debugPrint('Error sending message with notification: $e');
      return false;
    }
  }

  /// שליחת התראה על הודעה חדשה
  static Future<void> _sendChatNotification(
    String chatId,
    String recipientId,
    String message,
    String senderId,
  ) async {
    try {
      // קבלת שם השולח
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();

      String senderName = 'משתמש';
      if (senderDoc.exists) {
        final senderData = senderDoc.data()!;
        senderName = senderData['displayName'] ?? senderData['email']?.split('@')[0] ?? 'משתמש';
      }

      // בדיקה אם המקבל נמצא בצ'אט או באפליקציה
      final shouldSendNotification = await _shouldSendNotification(recipientId, chatId);
      
      debugPrint('Should send notification to $recipientId for chat $chatId: $shouldSendNotification');
      
      if (shouldSendNotification) {
        // שמירת התראה ב-Firestore רק אם צריך לשלוח
        await _firestore
            .collection('notifications')
            .add({
          'toUserId': recipientId,
          'title': 'הודעה חדשה בצ\'אט',
          'message': '$senderName שלח לך הודעה בצ\'אט!',
          'type': 'chat_message',
          'chatId': chatId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });

        await _sendChatNotificationViaCloudFunction(
          recipientId: recipientId,
          senderName: senderName,
          chatId: chatId,
        );
        debugPrint('Sending notification to: $recipientId');
      } else {
        debugPrint('User $recipientId is in chat or app is not active, skipping notification');
      }
    } catch (e) {
      debugPrint('Error sending chat notification: $e');
    }
  }

  /// בדיקה אם צריך לשלוח התראה
  static Future<bool> _shouldSendNotification(String recipientId, String chatId) async {
    try {
      // בדיקה ב-Firestore - מצב המקבל
      final userStateDoc = await _firestore
          .collection('user_states')
          .doc(recipientId)
          .get();
      
      if (userStateDoc.exists) {
        final userState = userStateDoc.data()!;
        final isInChat = userState['isInChat'] ?? false;
        final currentChatId = userState['currentChatId'];
        final lastUpdated = userState['lastUpdated'] as Timestamp?;
        
        debugPrint('User state for $recipientId: isInChat=$isInChat, currentChatId=$currentChatId, lastUpdated=$lastUpdated');
        
        // בדיקה אם המשתמש נמצא בצ'אט הנוכחי
        if (isInChat && currentChatId == chatId) {
          debugPrint('Recipient $recipientId is in the same chat $chatId, no notification needed');
          return false;
        }
        
        // בדיקה אם המצב עדכני (פחות מ-30 שניות)
        if (lastUpdated != null) {
          final timeDiff = DateTime.now().difference(lastUpdated.toDate()).inSeconds;
          if (timeDiff < 30) { // המצב עדכני
            if (isInChat) {
              debugPrint('User $recipientId is in a different chat, will send notification');
            } else {
              debugPrint('User $recipientId is not in any chat, will send notification');
            }
          } else {
            debugPrint('User state is outdated ($timeDiff seconds), will send notification');
          }
        }
      } else {
        debugPrint('No user state found for $recipientId, will send notification');
      }
      
      debugPrint('Recipient $recipientId is not in chat $chatId, notification will be sent');
      return true;
    } catch (e) {
      debugPrint('Error checking notification state: $e');
      // במקרה של שגיאה, שלח התראה (בטוח יותר)
      return true;
    }
  }

  /// שליחת push notification דרך Cloud Function
  static Future<void> _sendChatNotificationViaCloudFunction({
    required String recipientId,
    required String senderName,
    required String chatId,
  }) async {
    try {
      // שליחת push notification דרך Cloud Functions
      await _firestore
          .collection('chat_notifications')
          .add({
        'recipientId': recipientId,
        'senderName': senderName,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Chat notification queued for: $recipientId');
    } catch (e) {
      debugPrint('Error queuing chat notification: $e');
    }
  }


  /// סימון הודעות כנקראות
  static Future<void> markMessagesAsRead(String chatId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // עדכון הצ'אט - הסרת המקבל מרשימת unreadFor
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'unreadFor': FieldValue.delete(),
      });

      // סימון כל ההודעות של המשתמש הנוכחי כנקראות
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('from', isNotEqualTo: user.uid)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in messagesQuery.docs) {
          final messageData = doc.data();
          final readBy = List<String>.from(messageData['readBy'] ?? []);
          
          // הוספת המשתמש הנוכחי לרשימת הקוראים אם לא קיים
          if (!readBy.contains(user.uid)) {
            readBy.add(user.uid);
            batch.update(doc.reference, {'readBy': readBy});
          }
        }
        await batch.commit();
      }

      debugPrint('Messages marked as read for chat: $chatId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// בדיקה אם יש הודעות לא נקראות
  static Future<bool> hasUnreadMessages(String chatId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return false;

      final chatData = chatDoc.data()!;
      final unreadFor = chatData['unreadFor'] as String?;
      
      return unreadFor == user.uid;
    } catch (e) {
      debugPrint('Error checking unread messages: $e');
      return false;
    }
  }

  /// קבלת מספר הודעות לא נקראות לכל הצ'אטים
  static Future<int> getTotalUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .where('unreadFor', isEqualTo: user.uid)
          .get();

      return chatsQuery.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// מחיקת הודעה (סימון כמחוקה)
  static Future<bool> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // בדיקה שההודעה שייכת למשתמש הנוכחי
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return false;

      final messageData = messageDoc.data()!;
      if (messageData['from'] != user.uid) return false;

      // סימון ההודעה כמחוקה
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'deletedBy': user.uid,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Message $messageId deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }
}
