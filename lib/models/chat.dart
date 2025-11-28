import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String chatId;
  final String requestId;
  final List<String> participants;
  final String? lastMessage;
  final DateTime updatedAt;
  final int messageCount; // מספר הודעות שנשלחו (ללא הודעות מערכת)

  Chat({
    required this.chatId,
    required this.requestId,
    required this.participants,
    this.lastMessage,
    required this.updatedAt,
    this.messageCount = 0,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Chat(
      chatId: doc.id,
      requestId: data['requestId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      messageCount: data['messageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'participants': participants,
      'lastMessage': lastMessage,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'messageCount': messageCount,
    };
  }
}

enum MessageType {
  text,
  voice,
  image,
}

class Message {
  final String messageId;
  final String from;
  final String text;
  final DateTime sentAt;
  final bool isDeleted; // האם ההודעה נמחקה
  final String? deletedBy; // מי מחק את ההודעה
  final DateTime? deletedAt; // מתי נמחקה
  final List<String> readBy; // מי קרא את ההודעה
  final DateTime? editedAt; // מתי נערכה ההודעה
  final bool isSystemMessage; // האם זו הודעת מערכת
  
  // Voice message fields
  final MessageType type; // text, voice, or image
  final String? data; // Base64 string or URL for voice/image
  final int? duration; // Duration in seconds for voice messages

  Message({
    required this.messageId,
    required this.from,
    required this.text,
    required this.sentAt,
    this.isDeleted = false,
    this.deletedBy,
    this.deletedAt,
    this.readBy = const [],
    this.editedAt,
    this.isSystemMessage = false,
    this.type = MessageType.text,
    this.data,
    this.duration,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse message type
    MessageType messageType = MessageType.text;
    final typeString = data['type'] as String?;
    if (typeString != null) {
      switch (typeString) {
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
    
    return Message(
      messageId: doc.id,
      from: data['from'] ?? '',
      text: data['text'] ?? '',
      sentAt: data['sentAt'] != null 
          ? (data['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
      deletedBy: data['deletedBy'],
      deletedAt: data['deletedAt'] != null 
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
      readBy: List<String>.from(data['readBy'] ?? []),
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      isSystemMessage: data['isSystemMessage'] ?? false,
      type: messageType,
      data: data['data'] as String?,
      duration: data['duration'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'from': from,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'readBy': readBy,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isSystemMessage': isSystemMessage,
      'type': type.name, // 'text', 'voice', or 'image'
      'data': data,
      'duration': duration,
    };
  }
}
