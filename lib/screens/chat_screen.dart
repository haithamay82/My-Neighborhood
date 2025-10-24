import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/app_state_service.dart';
import '../l10n/app_localizations.dart';
import '../services/tutorial_service.dart';
import '../services/audio_service.dart';
import '../widgets/tutorial_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String requestTitle;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.requestTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<QuerySnapshot> _messagesStream;
  bool _isChatClosed = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots();
    
    debugPrint('ChatScreen initialized for chatId: ${widget.chatId}');
    
    // עדכון המצב - המשתמש נמצא בצ'אט (קודם כל!)
    _enterChat();
    
    // בדיקת סטטוס הצ'אט
    _checkChatStatus();
    
    // בדיקת ההודעות הקיימות
    
    _checkExistingMessages();
    
    // סימון הודעות כנקראות כשנכנסים לצ'אט
    ChatService.markMessagesAsRead(widget.chatId);
    
    // סימון הודעות כנקראות בזמן אמת
    _markMessagesAsRead();
  }
  
  // פונקציה להפעלת צליל לחיצה
  Future<void> playButtonSound() async {
    await AudioService().playSound(AudioEvent.buttonClick);
  }
  
  // סימון הודעות כנקראות בזמן אמת
  void _markMessagesAsRead() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // האזנה לשינויים בהודעות
    _messagesStream.listen((snapshot) {
      // בדיקה שהמשתמש עדיין בצ'אט (לא יצא)
      if (!mounted) return;
      
      // רק אם המשתמש באמת נכנס לצ'אט (המסך פעיל)
      if (ModalRoute.of(context)?.isCurrent == true) {
        for (var doc in snapshot.docs) {
          final message = Message.fromFirestore(doc);
          // אם ההודעה לא נשלחה על ידי המשתמש הנוכחי ולא נקראה על ידו
          if (message.from != user.uid && !message.readBy.contains(user.uid)) {
            _markMessageAsRead(message.messageId, user.uid);
          }
        }
      }
    });
  }

  // סימון הודעה ספציפית כנקראה
  Future<void> _markMessageAsRead(String messageId, String userId) async {
    // בדיקה נוספת שהמשתמש עדיין בצ'אט
    if (!mounted) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
      debugPrint('✅ Message $messageId marked as read by $userId');
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // הודעת הדרכה ספציפית לצ'אט - רק כשצריך
  Future<void> _showChatSpecificTutorial() async {
    // רק אם המשתמש לא ראה את ההדרכה הזו קודם
    final hasSeenTutorial = await TutorialService.hasSeenTutorial('chat_specific_tutorial');
    if (hasSeenTutorial) return;
    
    // רק אם המשתמש חדש (פחות מ-3 ימים)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) return;
    
    final userData = userDoc.data()!;
    final createdAt = userData['createdAt'] as Timestamp?;
    if (createdAt == null) return;
    
    final daysSinceCreation = DateTime.now().difference(createdAt.toDate()).inDays;
    if (daysSinceCreation > 3) return;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TutorialDialog(
        tutorialKey: 'chat_specific_tutorial',
        title: 'תקשורת עם נותן השירות',
        message: 'כאן תוכל לתקשר עם נותן השירות, לשאול שאלות ולתאם את הפרטים.',
        features: [
          '💬 שליחת הודעות טקסט',
          '📞 לחיצה על הטלפון להתקשרות',
          'ℹ️ מידע על הבקשה והמפרסם',
        ],
      ),
    );
  }
  
  Future<void> _enterChat() async {
    await AppStateService.enterChat(widget.chatId);
    debugPrint('User entered chat: ${widget.chatId}');
  }

  Future<void> _checkChatStatus() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final isClosed = chatData['isClosed'] as bool? ?? false;
        
        if (mounted) {
          setState(() {
            _isChatClosed = isClosed;
          });
        }
        
        debugPrint('Chat status: ${isClosed ? "closed" : "open"}');
      }
    } catch (e) {
      debugPrint('Error checking chat status: $e');
    }
  }
  
  Future<void> _checkExistingMessages() async {
    try {
      debugPrint('Checking existing messages for chat: ${widget.chatId}');
      
      // בדיקה אם יש הודעת מערכת על הגבלת הודעות
      final systemMessageSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isSystemMessage', isEqualTo: true)
          .where('text', isEqualTo: 'ניתן לשלוח עד 50 הודעות בצ\'אט זה. הודעות מערכת לא נספרות במגבלה.')
          .get();
      
      // אם אין הודעת מערכת על הגבלת הודעות, נוסיף אותה
      if (systemMessageSnapshot.docs.isEmpty) {
        await _addMessageLimitSystemMessage();
      }
      
      // בדיקה ישירה של ההודעות
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();
      
      debugPrint('Direct query found ${messagesSnapshot.docs.length} messages');
      
      for (var doc in messagesSnapshot.docs) {
        debugPrint('Message ${doc.id}: ${doc.data()}');
        try {
          final message = Message.fromFirestore(doc);
          debugPrint('Parsed message: from=${message.from}, text=${message.text}, sentAt=${message.sentAt}');
        } catch (e) {
          debugPrint('Error parsing message ${doc.id}: $e');
        }
      }
      
      // בדיקה עם orderBy
      final orderedSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .get();
      
      debugPrint('Ordered query found ${orderedSnapshot.docs.length} messages');
      
    } catch (e) {
      debugPrint('Error checking messages: $e');
    }
  }

  // הוספת הודעת מערכת על הגבלת הודעות
  Future<void> _addMessageLimitSystemMessage() async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': 'ניתן לשלוח עד 50 הודעות בצ\'אט זה. הודעות מערכת לא נספרות במגבלה.',
        'sentAt': Timestamp.fromDate(DateTime.now()),
        'isSystemMessage': true,
        'isDeleted': false,
        'readBy': [],
      });
      
      debugPrint('Added message limit system message to chat: ${widget.chatId}');
    } catch (e) {
      debugPrint('Error adding message limit system message: $e');
    }
  }

  @override
  void dispose() {
    // סימון כל ההודעות כנקראות לפני יציאה מהצ'אט
    ChatService.markMessagesAsRead(widget.chatId);
    
    // עדכון המצב - המשתמש יצא מהצ'אט
    AppStateService.exitAllChats();
    
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הצ'אט
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showChatSpecificTutorial();
    });
    final user = FirebaseAuth.instance.currentUser;
    
    return WillPopScope(
      onWillPop: () async {
        // סימון כל ההודעות כנקראות לפני יציאה מהצ'אט
        ChatService.markMessagesAsRead(widget.chatId);
        
        // עדכון המצב כשהמשתמש עוזב את הצ'אט
        AppStateService.exitAllChats();
        return true;
      },
      child: Directionality(
        textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              if (_isChatClosed) ...[
                const Icon(Icons.lock, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.requestTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (!mounted) return;
                
                if (value == 'clear') {
                  _showClearChatDialog(l10n);
                } else if (value == 'close') {
                  _showCloseChatDialog(l10n);
                } else if (value == 'reopen') {
                  _reopenChat();
                }
              },
              itemBuilder: (context) => [
                if (!_isChatClosed) ...[
                  PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('סגור צ\'אט'),
                      ],
                    ),
                  ),
                ] else ...[
                  PopupMenuItem(
                    value: 'reopen',
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('פתח צ\'אט מחדש'),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.clear_all, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.clearChat),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // בדיקת סטטוס הצ'אט בזמן אמת
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, chatStatusSnapshot) {
                if (chatStatusSnapshot.hasData && chatStatusSnapshot.data!.exists) {
                  final chatData = chatStatusSnapshot.data!.data() as Map<String, dynamic>;
                  final isClosed = chatData['isClosed'] as bool? ?? false;
                  
                  // עדכון המצב אם הצ'אט נסגר
                  if (isClosed != _isChatClosed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isChatClosed = isClosed;
                        });
                        debugPrint('🔄 Chat status updated in real-time: ${isClosed ? "closed" : "open"}');
                      }
                    });
                  }
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  debugPrint('StreamBuilder state: ${snapshot.connectionState}');
                  debugPrint('StreamBuilder hasError: ${snapshot.hasError}');
                  debugPrint('StreamBuilder hasData: ${snapshot.hasData}');
                  debugPrint('StreamBuilder docs count: ${snapshot.data?.docs.length ?? 0}');
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'טוען הודעות...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Text('שגיאה: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    debugPrint('No messages found for chat: ${widget.chatId}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noMessages,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs
                      .map((doc) => Message.fromFirestore(doc))
                      .toList();
                  
                  // מיון ידני לפי זמן שליחה (חדשות למטה, הישנות למעלה)
                  messages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
                  
                  debugPrint('Loaded ${messages.length} messages for chat: ${widget.chatId}');

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.from == user?.uid;
                      
                      return _buildMessageBubble(message, isMe, l10n);
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(l10n),
          ],
        ),
      ),
    ),
        ),
    );
  }

  // הצגת דיאלוג אפשרויות הודעה (עריכה ומחיקה)
  void _showMessageOptionsDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אפשרויות הודעה'),
        content: const Text('מה תרצה לעשות עם ההודעה?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditMessageDialog(message);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 4),
                Text('ערוך'),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteMessageDialog(message);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 16, color: Colors.red),
                SizedBox(width: 4),
                Text('מחק', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }

  // הצגת דיאלוג עריכת הודעה
  void _showEditMessageDialog(Message message) {
    final TextEditingController editController = TextEditingController(text: message.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('עריכת הודעה'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'הקלד את ההודעה החדשה...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editMessage(message, editController.text.trim());
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  // עריכת הודעה
  Future<void> _editMessage(Message message, String newText) async {
    if (newText.isEmpty || newText == message.text) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.messageId)
          .update({
        'text': newText,
        'editedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההודעה נערכה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בעריכת ההודעה'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // הצגת דיאלוג מחיקת הודעה
  void _showDeleteMessageDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת הודעה'),
        content: const Text('האם אתה בטוח שברצונך למחוק את ההודעה?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteMessage(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
  }

  // מחיקת הודעה
  Future<void> _deleteMessage(Message message) async {
    try {
      final success = await ChatService.deleteMessage(
        chatId: widget.chatId,
        messageId: message.messageId,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ההודעה נמחקה בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה במחיקת ההודעה'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה במחיקת ההודעה'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(Message message, bool isMe, AppLocalizations l10n) {
    // הצגת הודעות מערכת בצורה מיוחדת
    if (message.isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !message.isDeleted ? () => _showMessageOptionsDialog(message) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
color: message.isDeleted 
                      ? Colors.grey[300]
                      : (isMe 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: _getUserName(message.from),
                      builder: (context, snapshot) {
                        String displayName;
                        if (isMe) {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          displayName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? l10n.you;
                        } else {
                          displayName = snapshot.data ?? l10n.otherUser;
                        }
                        
                        return Text(
                          displayName,
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Colors.grey[500]
                                : (isMe ? Colors.white70 : Colors.grey[600]),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.isDeleted ? 'הודעה נמחקה' : message.text,
                      style: TextStyle(
                        color: message.isDeleted 
                            ? Colors.grey[500]
                            : (isMe ? Colors.white : Colors.black87),
                        fontSize: 16,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Colors.grey[500]
                                : (isMe ? Colors.white70 : Colors.grey[600]),
                            fontSize: 12,
                          ),
                        ),
                        if (isMe && !message.isDeleted) ...[
                          const SizedBox(width: 4),
                          _buildReadIndicator(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // בניית אינדיקציה של הודעות נקראו
  Widget _buildReadIndicator(Message message) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // רק עבור הודעות שנשלחו על ידי המשתמש הנוכחי
    if (message.from != user.uid) return const SizedBox.shrink();

    // קבלת רשימת המשתתפים בצ'אט
    return FutureBuilder<List<String>>(
      future: _getChatParticipants(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final participants = snapshot.data!;
        final otherParticipants = participants.where((p) => p != user.uid).toList();
        
        if (otherParticipants.isEmpty) return const SizedBox.shrink();
        
        // בדיקה אם כל המשתתפים האחרים קראו את ההודעה
        final allOthersRead = otherParticipants.every((p) => message.readBy.contains(p));
        
        if (allOthersRead) {
          // כל המשתתפים האחרים קראו - הצג ✓✓ ירוק-צהוב זוהר
          return ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00FF00), Color(0xFFFFFF00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Icon(
              Icons.done_all,
              size: 18,
              color: Colors.white,
            ),
          );
        } else {
          // לא כל המשתתפים קראו - הצג ✓ אפור
          return Icon(
            Icons.done,
            size: 18,
            color: Colors.grey[600],
          );
        }
      },
    );
  }

  // קבלת רשימת המשתתפים בצ'אט
  Future<List<String>> _getChatParticipants() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        return List<String>.from(data['participants'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting chat participants: $e');
      return [];
    }
  }

  Widget _buildMessageInput(AppLocalizations l10n) {
    if (_isChatClosed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.lock, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'הצ\'אט נסגר - הטיפול בבקשה הסתיים',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await playButtonSound();
                _showDeleteChatDialog(l10n);
              },
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('מחק צ\'אט'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: l10n.sendMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ספירת הודעות (ללא הודעות מערכת)
  Future<int> _getMessageCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isSystemMessage', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting message count: $e');
      return 0;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // בדיקה אם הצ'אט סגור
    if (_isChatClosed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הצ\'אט נסגר - לא ניתן לשלוח הודעות'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // בדיקת הגבלת הודעות
    final messageCount = await _getMessageCount();
    if (messageCount >= 50) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הגעת למגבלת 50 הודעות - לא ניתן לשלוח הודעות נוספות'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // הצגת אזהרה כשהולכים להגיע למגבלה
    if (messageCount >= 45) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('אזהרה: נותרו ${50 - messageCount} הודעות בלבד'),
          backgroundColor: Colors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      // שימוש בפונקציה החדשה עם התראות
      final success = await ChatService.sendMessageWithNotification(
        chatId: widget.chatId,
        text: text,
      );

      if (success) {
        _messageController.clear();
        
        // גלילה למטה
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בשליחת הודעה: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteChatDialog(AppLocalizations l10n) async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת צ\'אט'),
        content: const Text('האם אתה בטוח שברצונך למחוק את הצ\'אט? פעולה זו לא ניתנת לביטול.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              await playButtonSound();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _deleteChat();
    }
  }

  Future<void> _deleteChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // קבלת פרטי הצ'אט
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (!chatDoc.exists) return;
      
      // הוספת המשתמש לרשימת המחיקות
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'deletedBy': FieldValue.arrayUnion([user.uid]),
        'deletedAt': FieldValue.arrayUnion([DateTime.now()]),
        'updatedAt': DateTime.now(),
      });

      debugPrint('✅ Chat ${widget.chatId} marked as deleted by user ${user.uid}');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הצ\'אט נמחק בהצלחה'),
          backgroundColor: Colors.green,
        ),
      );
      
      // חזרה למסך הקודם
      Navigator.of(context).pop();
      
    } catch (e) {
      debugPrint('❌ Error deleting chat: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה במחיקת הצ\'אט: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'משתמש';
      }
      
      // אם לא נמצא במסד הנתונים, ננסה לקבל מ-Firebase Auth
      return 'משתמש';
    } catch (e) {
      return 'משתמש';
    }
  }

  void _showCloseChatDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('סגירת צ\'אט'),
        content: const Text('האם אתה בטוח שברצונך לסגור את הצ\'אט? לאחר הסגירה לא ניתן יהיה לשלוח הודעות נוספות.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _closeChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('סגור צ\'אט'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // שליחת הודעת מערכת
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': 'הצ\'אט נסגר על ידי ${user.displayName ?? user.email?.split('@')[0] ?? 'משתמש'}. לא ניתן לשלוח הודעות נוספות.',
        'sentAt': Timestamp.fromDate(DateTime.now()),
        'isSystemMessage': true,
        'messageType': 'chat_closed',
      });

      // עדכון הצ'אט כסגור
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'isClosed': true,
        'closedAt': Timestamp.fromDate(DateTime.now()),
        'closedBy': user.uid,
        'lastMessage': 'הצ\'אט נסגר',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הצ\'אט נסגר בהצלחה'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error closing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בסגירת הצ\'אט'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reopenChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // עדכון הצ'אט כפתוח
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'isClosed': false,
        'reopenedAt': Timestamp.fromDate(DateTime.now()),
        'reopenedBy': user.uid,
        'lastMessage': 'הצ\'אט נפתח מחדש',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // שליחת הודעת מערכת
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': 'הצ\'אט נפתח מחדש על ידי ${user.displayName ?? user.email?.split('@')[0] ?? 'משתמש'}.',
        'sentAt': Timestamp.fromDate(DateTime.now()),
        'isSystemMessage': true,
        'messageType': 'chat_reopened',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הצ\'אט נפתח מחדש בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error reopening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בפתיחת הצ\'אט מחדש'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearChatDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearChat),
        content: const Text('האם אתה בטוח שברצונך למחוק את ההודעות שלך?\nהמשתמש השני ימשיך לראות את ההודעות שלו.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChat();
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // מחיקת רק ההודעות של המשתמש הנוכחי
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('from', isEqualTo: user.uid) // רק ההודעות של המשתמש הנוכחי
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // עדכון lastMessage בצ'אט הראשי רק אם נמחקו הודעות
      if (messages.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ההודעות שלך נמחקו בהצלחה'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה במחיקת ההודעות: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}