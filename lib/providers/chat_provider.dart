import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat.dart';

/// Provider for managing chat messages with 50 message limit
class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final String chatId;
  StreamSubscription<QuerySnapshot>? _subscription;
  static const int maxMessages = 50;

  ChatMessagesNotifier(this.chatId) : super(const AsyncValue.loading()) {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      // Load only the latest 50 messages
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(maxMessages)
          .get();

      final messages = snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();

      // Sort by sentAt ascending (oldest first)
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      state = AsyncValue.data(messages);

      // Listen for new messages (only the latest 50)
      _subscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(maxMessages)
          .snapshots()
          .listen(
        (snapshot) {
          final updatedMessages = snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();

          // Sort by sentAt ascending (oldest first)
          updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

          state = AsyncValue.data(updatedMessages);

          // Check if we need to delete old messages
          if (updatedMessages.length > maxMessages) {
            _deleteOldMessages(updatedMessages);
          }
        },
        onError: (error) {
          state = AsyncValue.error(error, StackTrace.current);
        },
      );
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Delete old messages if count exceeds maxMessages
  Future<void> _deleteOldMessages(List<Message> messages) async {
    if (messages.length <= maxMessages) return;

    // Get messages to delete (oldest ones)
    final messagesToDelete = messages
        .take(messages.length - maxMessages)
        .map((m) => m.messageId)
        .toList();

    if (messagesToDelete.isEmpty) return;

    try {
      // Use batch write for efficiency
      final batch = FirebaseFirestore.instance.batch();

      for (final messageId in messagesToDelete) {
        final messageRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId);

        batch.delete(messageRef);
      }

      await batch.commit();
      debugPrint('✅ Deleted ${messagesToDelete.length} old messages from chat $chatId');
    } catch (e) {
      debugPrint('❌ Error deleting old messages: $e');
    }
  }

  /// Send a new message and ensure message limit
  Future<void> sendMessage({
    required String text,
    MessageType type = MessageType.text,
    String? data,
    int? duration,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check current message count before sending
      final currentMessagesAsync = state;
      if (currentMessagesAsync.hasValue) {
        final currentMessages = currentMessagesAsync.value ?? [];
        
        // If we're at the limit, delete the oldest message first
        if (currentMessages.length >= maxMessages) {
          final oldestMessage = currentMessages.first;
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(oldestMessage.messageId)
              .delete();
        }
      }

      // Add new message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'from': user.uid,
        'text': text,
        'type': type.name,
        'data': data,
        'duration': duration,
        'sentAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'readBy': [],
        'isSystemMessage': false,
      });

      // Update chat's lastMessage and updatedAt
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for chat messages
final chatMessagesProvider =
    StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<Message>>, String>(
  (ref, chatId) => ChatMessagesNotifier(chatId),
);

