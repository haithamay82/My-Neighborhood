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
      final currentUserId = _auth.currentUser?.uid;
      
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
          // בדיקה אם הצ'אט נמחק על ידי המשתמש הנוכחי
          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
          final isClosed = chatData['isClosed'] as bool? ?? false;
          
          if (currentUserId != null && deletedBy.contains(currentUserId)) {
            // אם הצ'אט נמחק על ידי המשתמש הנוכחי, נפתח אותו מחדש במקום ליצור צ'אט חדש
            debugPrint('Found existing chat ${doc.id} that was deleted by current user $currentUserId, reopening it...');
            
            // פתיחת הצ'אט מחדש - הסרת המשתמש מ-deletedBy ופתיחת הצ'אט
            await _firestore.collection('chats').doc(doc.id).update({
              'deletedBy': FieldValue.arrayRemove([currentUserId]),
              'isClosed': false, // פתיחת הצ'אט מחדש
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
            
            debugPrint('✅ Reopened chat ${doc.id} for user $currentUserId');
            return doc.id;
          }
          
          // אם הצ'אט סגור אבל לא נמחק על ידי המשתמש הנוכחי, נפתח אותו מחדש
          if (isClosed && currentUserId != null && !deletedBy.contains(currentUserId)) {
            debugPrint('Found closed chat ${doc.id}, reopening it...');
            
            // פתיחת הצ'אט מחדש
            await _firestore.collection('chats').doc(doc.id).update({
              'isClosed': false, // פתיחת הצ'אט מחדש
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
            
            debugPrint('✅ Reopened closed chat ${doc.id}');
            return doc.id;
          }
          
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

  /// שליחת הודעה בצ'אט (תמיכה בהודעות טקסט, קול ותמונה)
  static Future<bool> sendMessage({
    required String chatId,
    required String text,
    String? type, // 'text', 'voice', or 'image'
    String? data, // Base64 string or URL
    int? duration, // Duration in seconds for voice messages
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
      
      // בדיקה אם הצ'אט נמחק על ידי המשתמש הנוכחי
      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
      if (deletedBy.contains(user.uid)) {
        debugPrint('⚠️ Chat $chatId was deleted by current user ${user.uid}, cannot send message');
        return false;
      }
      
      // בדיקה אם הצ'אט סגור - אם כן, נפתח אותו מחדש
      final isClosed = chatData['isClosed'] as bool? ?? false;
      if (isClosed) {
        debugPrint('🔄 Chat $chatId is closed, reopening it...');
        await _firestore.collection('chats').doc(chatId).update({
          'isClosed': false, // פתיחת הצ'אט מחדש
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        debugPrint('✅ Reopened closed chat $chatId');
      }
      
      final participants = List<String>.from(chatData['participants'] ?? []);
      final requestId = chatData['requestId'] as String? ?? '';
      
      // מציאת כל המשתתפים האחרים (לא השולח)
      final otherParticipants = participants.where((id) => id != user.uid).toList();
      
      if (otherParticipants.isEmpty) return false;

      // בדיקה אם זו הודעה ראשונה ממבקש השירות (יוצר הבקשה)
      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי" של נותן השירות
      bool shouldUpdateInterestTime = false;
      String? helperIdForInterestUpdate;
      if (requestId.isNotEmpty) {
        try {
          // קבלת פרטי הבקשה כדי לבדוק מי יוצר הבקשה
          final requestDoc = await _firestore
              .collection('requests')
              .doc(requestId)
              .get();
          
          if (requestDoc.exists) {
            final requestData = requestDoc.data()!;
            final creatorId = requestData['createdBy'] as String?;
            
            // אם השולח הוא יוצר הבקשה (מבקש השירות), נבדוק אם זו הודעה ראשונה ממנו
            if (creatorId == user.uid && otherParticipants.isNotEmpty) {
              // בדיקה אם יש הודעות קודמות ממבקש השירות בצ'אט
              final messagesFromCreatorSnapshot = await _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .where('from', isEqualTo: user.uid)
                  .limit(1)
                  .get();
              
              // אם אין הודעות קודמות ממבקש השירות, זו הודעה ראשונה ממנו
              if (messagesFromCreatorSnapshot.docs.isEmpty) {
                shouldUpdateInterestTime = true;
                helperIdForInterestUpdate = otherParticipants.first; // נותן השירות
                debugPrint('✅ First message from creator $user.uid to helper $helperIdForInterestUpdate in request $requestId');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to check if first message from creator: $e');
          // נמשיך לשלוח את ההודעה גם אם הבדיקה נכשלה
        }
      }

      // Parse message type
      MessageType messageType = MessageType.text;
      if (type != null) {
        switch (type) {
          case 'voice':
            messageType = MessageType.voice;
            break;
          case 'image':
            messageType = MessageType.image;
            break;
          default:
            messageType = MessageType.text;
        }
      }

      final message = Message(
        messageId: '', // יוגדר על ידי Firestore
        from: user.uid,
        text: text,
        sentAt: DateTime.now(),
        isSystemMessage: false,
        type: messageType,
        data: data,
        duration: duration,
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

      // עדכון זמן ההתעניינות ואם מבקש השירות שולח הודעה ראשונה, הוספת נותן השירות ל-helpers
      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי" של נותן השירות
      // רק אם הבקשה היא "בתשלום" ונותן השירות הוא אורח/עסקי מנוי/מנהל
      if (shouldUpdateInterestTime && helperIdForInterestUpdate != null && requestId.isNotEmpty) {
        try {
          // הוספת נותן השירות ל-`helpers` array של הבקשה כדי שהבקשה תופיע אצלו במסך "פניות שלי"
          try {
            final requestRef = _firestore.collection('requests').doc(requestId);
            final requestDoc = await requestRef.get();
            
            if (requestDoc.exists) {
              final requestData = requestDoc.data()!;
              final requestType = requestData['type'] as String?;
              
              // בדיקה אם הבקשה היא "בתשלום"
              if (requestType != 'paid') {
                debugPrint('ℹ️ Request $requestId is not paid, skipping helper addition');
              } else {
                // בדיקה אם נותן השירות הוא אורח/עסקי מנוי/מנהל
                final helperDoc = await _firestore
                    .collection('users')
                    .doc(helperIdForInterestUpdate)
                    .get();
                
                if (!helperDoc.exists) {
                  debugPrint('⚠️ Helper $helperIdForInterestUpdate not found in users collection');
                } else {
                  final helperData = helperDoc.data()!;
                  final helperUserType = helperData['userType'] as String?;
                  final helperIsAdmin = helperData['isAdmin'] as bool? ?? false;
                  final helperEmail = helperData['email'] as String?;
                  
                  // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
                  final isGuest = helperUserType == 'guest';
                  final isBusinessSubscription = helperUserType == 'business' && 
                      (helperData['isSubscriptionActive'] as bool? ?? false);
                  final isAdmin = helperIsAdmin || 
                      helperEmail == 'admin@gmail.com' || 
                      helperEmail == 'haitham.ay82@gmail.com';
                  
                  // מנהלים לא מתווספים ל-helpers array - הם יכולים לראות את כל הבקשות אבל לא מופיעים ב"פניות שלי"
                  if (isAdmin) {
                    debugPrint('ℹ️ Helper $helperIdForInterestUpdate is admin - skipping helper addition (admins can see all requests but do not appear in "My Requests")');
                  } else if (!isGuest && !isBusinessSubscription) {
                    debugPrint('ℹ️ Helper $helperIdForInterestUpdate is not guest/business subscription, skipping helper addition');
                  } else {
                    final helpers = List<String>.from(requestData['helpers'] ?? []);
                    
                    // אם נותן השירות עדיין לא ב-`helpers` array, נוסיף אותו
                    if (!helpers.contains(helperIdForInterestUpdate)) {
                      final currentStatus = requestData['status'] as String?;
                      
                      // עדכון helpers
                      final updateData = <String, dynamic>{
                        'helpers': FieldValue.arrayUnion([helperIdForInterestUpdate]),
                        'helpersCount': FieldValue.increment(1),
                      };
                      
                      // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
                      if (helpers.isEmpty && currentStatus == 'open') {
                        updateData['status'] = 'inProgress';
                        debugPrint('✅ Added helper: Updating status from "open" to "inProgress"');
                      }
                      
                      await requestRef.update(updateData);
                      debugPrint('✅ Added helper $helperIdForInterestUpdate to request $requestId helpers array (first message from creator)');
                    } else {
                      debugPrint('ℹ️ Helper $helperIdForInterestUpdate already in request $requestId helpers array');
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to add helper to request when sending first message: $e');
            // נמשיך גם אם יש שגיאה בהוספת helper
          }
          
          // עדכון זמן ההתעניינות ב-user_interests collection
          await _firestore
              .collection('user_interests')
              .doc('${helperIdForInterestUpdate}_$requestId')
              .set({
            'userId': helperIdForInterestUpdate,
            'requestId': requestId,
            'interestTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          debugPrint('✅ Updated interest time for helper $helperIdForInterestUpdate in request $requestId (first message from creator)');
        } catch (e) {
          debugPrint('⚠️ Failed to update interest time when sending first message: $e');
          // לא נעצור את התהליך בגלל שגיאה בעדכון זמן ההתעניינות
        }
      }

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

  /// שליחת הודעה עם התראות (תמיכה בהודעות טקסט, קול ותמונה)
  static Future<bool> sendMessageWithNotification({
    required String chatId,
    required String text,
    String? type, // 'text', 'voice', or 'image'
    String? data, // Base64 string or URL
    int? duration, // Duration in seconds for voice messages
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
      
      // בדיקה אם הצ'אט נמחק על ידי המשתמש הנוכחי
      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
      if (deletedBy.contains(user.uid)) {
        debugPrint('⚠️ Chat $chatId was deleted by current user ${user.uid}, cannot send message');
        return false;
      }
      
      // בדיקה אם הצ'אט סגור - אם כן, נפתח אותו מחדש
      final isClosed = chatData['isClosed'] as bool? ?? false;
      if (isClosed) {
        debugPrint('🔄 Chat $chatId is closed, reopening it...');
        await _firestore.collection('chats').doc(chatId).update({
          'isClosed': false, // פתיחת הצ'אט מחדש
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        debugPrint('✅ Reopened closed chat $chatId');
      }
      
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // מציאת כל המקבלים (כל המשתתפים חוץ מהשולח)
      final recipients = participants.where((id) => id != user.uid).toList();

      if (recipients.isEmpty) return false;

      final requestId = chatData['requestId'] as String? ?? '';
      
      // בדיקה אם זו הודעה ראשונה ממבקש השירות (יוצר הבקשה)
      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי" של נותן השירות
      bool shouldUpdateInterestTime = false;
      String? helperIdForInterestUpdate;
      if (requestId.isNotEmpty) {
        try {
          // קבלת פרטי הבקשה כדי לבדוק מי יוצר הבקשה
          final requestDoc = await _firestore
              .collection('requests')
              .doc(requestId)
              .get();
          
          if (requestDoc.exists) {
            final requestData = requestDoc.data()!;
            final creatorId = requestData['createdBy'] as String?;
            
            // אם השולח הוא יוצר הבקשה (מבקש השירות), נבדוק אם זו הודעה ראשונה ממנו
            if (creatorId == user.uid && recipients.isNotEmpty) {
              // בדיקה אם יש הודעות קודמות ממבקש השירות בצ'אט
              final messagesFromCreatorSnapshot = await _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .where('from', isEqualTo: user.uid)
                  .limit(1)
                  .get();
              
              // אם אין הודעות קודמות ממבקש השירות, זו הודעה ראשונה ממנו
              if (messagesFromCreatorSnapshot.docs.isEmpty) {
                shouldUpdateInterestTime = true;
                helperIdForInterestUpdate = recipients.first; // נותן השירות
                debugPrint('✅ First message from creator $user.uid to helper $helperIdForInterestUpdate in request $requestId');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to check if first message from creator: $e');
          // נמשיך לשלוח את ההודעה גם אם הבדיקה נכשלה
        }
      }

      // Parse message type
      MessageType messageType = MessageType.text;
      if (type != null) {
        switch (type) {
          case 'voice':
            messageType = MessageType.voice;
            break;
          case 'image':
            messageType = MessageType.image;
            break;
          default:
            messageType = MessageType.text;
        }
      }

      // בדיקת הגבלת 50 הודעות - מחיקת הודעה הישנה ביותר אם יש 50 הודעות
      // נשתמש בשאילתה פשוטה יותר שלא דורשת אינדקס מורכב
      final allMessagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isSystemMessage', isEqualTo: false)
          .get();
      
      // אם יש 50 הודעות או יותר, מחק את הישנה ביותר
      if (allMessagesSnapshot.docs.length >= 50) {
        // מציאת ההודעה הישנה ביותר (ללא orderBy כדי לא לדרוש אינדקס)
        Message? oldestMessage;
        DateTime? oldestDate;
        
        for (var doc in allMessagesSnapshot.docs) {
          final data = doc.data();
          final sentAt = data['sentAt'] as Timestamp?;
          if (sentAt != null) {
            final sentAtDate = sentAt.toDate();
            if (oldestDate == null || sentAtDate.isBefore(oldestDate)) {
              oldestDate = sentAtDate;
              oldestMessage = Message.fromFirestore(doc);
            }
          }
        }
        
        if (oldestMessage != null) {
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(oldestMessage.messageId)
              .delete();
          debugPrint('✅ Deleted oldest message ${oldestMessage.messageId} to maintain 50 message limit');
        }
      }

      // שליחת ההודעה
      final message = Message(
        messageId: '', // יוגדר על ידי Firestore
        from: user.uid,
        text: text,
        sentAt: DateTime.now(),
        isSystemMessage: false,
        type: messageType,
        data: data,
        duration: duration,
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

      // עדכון זמן ההתעניינות ואם מבקש השירות שולח הודעה ראשונה, הוספת נותן השירות ל-helpers
      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי" של נותן השירות
      // רק אם הבקשה היא "בתשלום" ונותן השירות הוא אורח/עסקי מנוי/מנהל
      if (shouldUpdateInterestTime && helperIdForInterestUpdate != null && requestId.isNotEmpty) {
        try {
          // הוספת נותן השירות ל-`helpers` array של הבקשה כדי שהבקשה תופיע אצלו במסך "פניות שלי"
          try {
            final requestRef = _firestore.collection('requests').doc(requestId);
            final requestDoc = await requestRef.get();
            
            if (requestDoc.exists) {
              final requestData = requestDoc.data()!;
              final requestType = requestData['type'] as String?;
              
              // בדיקה אם הבקשה היא "בתשלום"
              if (requestType != 'paid') {
                debugPrint('ℹ️ Request $requestId is not paid, skipping helper addition');
              } else {
                // בדיקה אם נותן השירות הוא אורח/עסקי מנוי/מנהל
                final helperDoc = await _firestore
                    .collection('users')
                    .doc(helperIdForInterestUpdate)
                    .get();
                
                if (!helperDoc.exists) {
                  debugPrint('⚠️ Helper $helperIdForInterestUpdate not found in users collection');
                } else {
                  final helperData = helperDoc.data()!;
                  final helperUserType = helperData['userType'] as String?;
                  final helperIsAdmin = helperData['isAdmin'] as bool? ?? false;
                  final helperEmail = helperData['email'] as String?;
                  
                  // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
                  final isGuest = helperUserType == 'guest';
                  final isBusinessSubscription = helperUserType == 'business' && 
                      (helperData['isSubscriptionActive'] as bool? ?? false);
                  final isAdmin = helperIsAdmin || 
                      helperEmail == 'admin@gmail.com' || 
                      helperEmail == 'haitham.ay82@gmail.com';
                  
                  // מנהלים לא מתווספים ל-helpers array - הם יכולים לראות את כל הבקשות אבל לא מופיעים ב"פניות שלי"
                  if (isAdmin) {
                    debugPrint('ℹ️ Helper $helperIdForInterestUpdate is admin - skipping helper addition (admins can see all requests but do not appear in "My Requests")');
                  } else if (!isGuest && !isBusinessSubscription) {
                    debugPrint('ℹ️ Helper $helperIdForInterestUpdate is not guest/business subscription, skipping helper addition');
                  } else {
                    final helpers = List<String>.from(requestData['helpers'] ?? []);
                    
                    // אם נותן השירות עדיין לא ב-`helpers` array, נוסיף אותו
                    if (!helpers.contains(helperIdForInterestUpdate)) {
                      final currentStatus = requestData['status'] as String?;
                      
                      // עדכון helpers
                      final updateData = <String, dynamic>{
                        'helpers': FieldValue.arrayUnion([helperIdForInterestUpdate]),
                        'helpersCount': FieldValue.increment(1),
                      };
                      
                      // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
                      if (helpers.isEmpty && currentStatus == 'open') {
                        updateData['status'] = 'inProgress';
                        debugPrint('✅ Added helper: Updating status from "open" to "inProgress"');
                      }
                      
                      await requestRef.update(updateData);
                      debugPrint('✅ Added helper $helperIdForInterestUpdate to request $requestId helpers array (first message from creator)');
                    } else {
                      debugPrint('ℹ️ Helper $helperIdForInterestUpdate already in request $requestId helpers array');
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to add helper to request when sending first message: $e');
            // נמשיך גם אם יש שגיאה בהוספת helper
          }
          
          // עדכון זמן ההתעניינות ב-user_interests collection
          await _firestore
              .collection('user_interests')
              .doc('${helperIdForInterestUpdate}_$requestId')
              .set({
            'userId': helperIdForInterestUpdate,
            'requestId': requestId,
            'interestTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          debugPrint('✅ Updated interest time for helper $helperIdForInterestUpdate in request $requestId (first message from creator)');
        } catch (e) {
          debugPrint('⚠️ Failed to update interest time when sending first message: $e');
          // לא נעצור את התהליך בגלל שגיאה בעדכון זמן ההתעניינות
        }
      }

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
        // אם המצב לא עדכני (יותר מ-30 שניות), זה אומר שהאפליקציה כנראה סגורה - נשלח התראה
        if (lastUpdated != null) {
          final timeDiff = DateTime.now().difference(lastUpdated.toDate()).inSeconds;
          if (timeDiff < 30) { // המצב עדכני - המשתמש באפליקציה
            if (isInChat) {
              debugPrint('User $recipientId is in a different chat, will send notification');
            } else {
              debugPrint('User $recipientId is not in any chat, will send notification');
            }
          } else {
            // המצב לא עדכני - האפליקציה כנראה סגורה - נשלח התראה
            debugPrint('User state is outdated ($timeDiff seconds) - app is likely closed, will send notification');
          }
        } else {
          // אין זמן עדכון - נשלח התראה
          debugPrint('No lastUpdated timestamp, will send notification');
        }
      } else {
        // אין מצב משתמש - האפליקציה כנראה סגורה - נשלח התראה
        debugPrint('No user state found for $recipientId - app is likely closed, will send notification');
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
      // קבלת פרטי הבקשה לכותרת
      String requestTitle = 'בקשה';
      try {
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();
        if (chatDoc.exists) {
          final chatData = chatDoc.data()!;
          final requestId = chatData['requestId'] as String?;
          if (requestId != null) {
            final requestDoc = await _firestore.collection('requests').doc(requestId).get();
            if (requestDoc.exists) {
              final requestData = requestDoc.data()!;
              requestTitle = requestData['title'] as String? ?? 'בקשה';
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting request title: $e');
      }
      
      // שליחת push notification דרך push_notifications collection (יש לה Cloud Function)
      await _firestore
          .collection('push_notifications')
          .add({
        'userId': recipientId,
        'title': 'הודעה חדשה בצ\'אט 💬',
        'body': '$senderName: הודעה חדשה',
        'payload': 'chat_message',
        'data': {
          'chatId': chatId,
          'senderName': senderName,
          'requestTitle': requestTitle,
        },
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

  /// מחיקת הודעה (סימון כמחוקה - גם להודעות קוליות)
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

      // כל ההודעות (טקסט וקוליות) - סימון כמחוקה (soft delete)
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

      final messageType = messageData['type'] as String?;
      debugPrint('Message $messageId (type: $messageType) marked as deleted');

      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }
}
