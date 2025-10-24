import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppStateService {
  static String? _currentChatId;
  static bool _isInChat = false;
  static BuildContext? _currentContext;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// עדכון המצב הנוכחי - האם המשתמש נמצא בצ'אט
  static Future<void> setChatState(String? chatId) async {
    _currentChatId = chatId;
    _isInChat = chatId != null;
    debugPrint('Chat state updated: $_isInChat, ChatId: $_currentChatId');
    
    // שמירת המצב ב-Firestore
    await _updateUserStateInFirestore(chatId);
  }

  /// כניסה לצ'אט ספציפי
  static Future<void> enterChat(String chatId) async {
    await setChatState(chatId);
    debugPrint('User entered chat: $chatId');
  }


  /// עדכון המצב ב-Firestore
  static Future<void> _updateUserStateInFirestore(String? chatId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('user_states')
          .doc(user.uid)
          .set({
        'currentChatId': chatId,
        'isInChat': chatId != null,
        'lastUpdated': Timestamp.fromDate(DateTime.now()), // שימוש ב-Timestamp מקומי במקום serverTimestamp
      });
      
      debugPrint('User state updated in Firestore: $chatId');
    } catch (e) {
      debugPrint('Error updating user state in Firestore: $e');
    }
  }

  /// בדיקה אם המשתמש נמצא בצ'אט ספציפי
  static bool isInChat(String chatId) {
    return _isInChat && _currentChatId == chatId;
  }

  /// בדיקה אם המשתמש נמצא בכל צ'אט
  static bool isInAnyChat() {
    return _isInChat;
  }

  /// יציאה מכל הצ'אטים
  static Future<void> exitAllChats() async {
    _currentChatId = null;
    _isInChat = false;
    debugPrint('Exited all chats');
    
    // עדכון המצב ב-Firestore
    await _updateUserStateInFirestore(null);
  }

  /// ניקוי המצב כשהמשתמש יוצא מהאפליקציה
  static Future<void> clearUserState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('user_states')
          .doc(user.uid)
          .delete();
      
      debugPrint('User state cleared from Firestore');
    } catch (e) {
      debugPrint('Error clearing user state: $e');
    }
  }

  /// עדכון context נוכחי
  static void setCurrentContext(BuildContext context) {
    _currentContext = context;
  }

  /// קבלת context נוכחי
  static BuildContext? get currentContext => _currentContext;

  /// ניקוי context
  static void clearContext() {
    _currentContext = null;
  }
}
