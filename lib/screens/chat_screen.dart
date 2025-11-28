import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/app_state_service.dart';
import '../l10n/app_localizations.dart';
import '../services/tutorial_service.dart';
import '../services/audio_service.dart';
import '../services/voice_message_service.dart';
import '../widgets/tutorial_dialog.dart';
import '../widgets/voice_message_widget.dart';
import '../widgets/voice_recorder_widget.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String requestTitle;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.requestTitle,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceMessageService _voiceService = VoiceMessageService();
  bool _isChatClosed = false;
  bool _isDeletedByRequestCreator = false; // האם הצ'אט נמחק על ידי מבקש השירות
  bool _isDeletedByServiceProvider = false; // האם הצ'אט נמחק על ידי נותן השירות
  bool _isCurrentUserRequestCreator = false; // האם המשתמש הנוכחי הוא מבקש השירות
  bool _isRequestCompleted = false; // האם הבקשה במצב "טופל"
  StreamSubscription<DocumentSnapshot>? _chatStatusSubscription;
  bool _chatTutorialShown = false; // האם הדיאלוג "תקשורת עם נותן שירות" כבר הוצג
  bool _isRecordingVoice = false; // האם מקליטים הודעה קולית
  bool _showVoiceRecorder = false; // האם להציג את ה-voice recorder

  @override
  void initState() {
    super.initState();
    
    debugPrint('ChatScreen initialized for chatId: ${widget.chatId}');
    
    // עדכון המצב - המשתמש נמצא בצ'אט (קודם כל!)
    _enterChat();
    
    // בדיקת סטטוס הצ'אט והאזנה לשינויים בזמן אמת
    _checkChatStatus();
    _listenToChatStatus();
    
    // בדיקת ההודעות הקיימות
    _checkExistingMessages();
    
    // סימון הודעות כנקראות כשנכנסים לצ'אט
    ChatService.markMessagesAsRead(widget.chatId);
    
    // סימון הודעות כנקראות בזמן אמת - נעשה ב-build method
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הצ'אט (רק פעם אחת)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showChatSpecificTutorial();
    });
  }

  
  // פונקציה להפעלת צליל לחיצה
  Future<void> playButtonSound() async {
    await AudioService().playSound(AudioEvent.buttonClick);
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
    // בדיקה אם הדיאלוג כבר הוצג במהלך הפעלה זו
    if (_chatTutorialShown) {
      debugPrint('💬 Chat tutorial already shown in this session, returning');
      return;
    }
    
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
    
    // סמן שהדיאלוג הוצג
    _chatTutorialShown = true;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TutorialDialog(
        tutorialKey: 'chat_specific_tutorial',
        title: AppLocalizations.of(context).communicationWithServiceProvider,
        message: AppLocalizations.of(context).communicationWithServiceProviderMessage,
        features: [
          '💬 שליחת הודעות טקסט',
          '💬 לדבר על הבקשה לקבל/לתת מידע נוסף',
          '🤝 לסגור עסקה בין מבקש השירות לנותן השירות',
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final isClosed = chatData['isClosed'] as bool? ?? false;
        final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
        final requestId = chatData['requestId'] as String?;
        
        // בדיקה אם הצ'אט נמחק על ידי מבקש השירות או נותן השירות
        bool isDeletedByRequestCreator = false;
        bool isDeletedByServiceProvider = false;
        if (requestId != null && deletedBy.isNotEmpty) {
          try {
            final requestDoc = await FirebaseFirestore.instance
                .collection('requests')
                .doc(requestId)
                .get();
            
            if (requestDoc.exists) {
              final requestData = requestDoc.data()!;
              final createdBy = requestData['createdBy'] as String?;
              
              // אם יוצר הבקשה מחק את הצ'אט, נותן השירות לא יכול לפתוח אותו מחדש
              if (createdBy != null && deletedBy.contains(createdBy) && createdBy != user.uid) {
                isDeletedByRequestCreator = true;
                debugPrint('⚠️ Chat was deleted by request creator $createdBy, cannot reopen');
              }
              
              // אם נותן השירות מחק את הצ'אט, מבקש השירות לא יכול לפתוח אותו מחדש
              if (createdBy == user.uid) {
                // המשתמש הנוכחי הוא מבקש השירות
                isDeletedByServiceProvider = false; // נבדוק מחדש
                for (final deletedByUid in deletedBy) {
                  if (deletedByUid != user.uid) {
                    // מישהו אחר מחק את הצ'אט - זה נותן השירות
                    isDeletedByServiceProvider = true;
                    debugPrint('⚠️ Chat was deleted by service provider $deletedByUid, cannot reopen');
                    break;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error checking request creator: $e');
          }
        }
        
        // בדיקה אם המשתמש הנוכחי הוא מבקש השירות ואם הבקשה במצב "טופל"
        bool isCurrentUserRequestCreator = false;
        bool isRequestCompleted = false;
        if (requestId != null) {
          try {
            final requestDoc = await FirebaseFirestore.instance
                .collection('requests')
                .doc(requestId)
                .get();
            
            if (requestDoc.exists) {
              final requestData = requestDoc.data()!;
              final createdBy = requestData['createdBy'] as String?;
              final status = requestData['status'] as String?;
              isCurrentUserRequestCreator = createdBy == user.uid;
              isRequestCompleted = status == 'completed';
            }
          } catch (e) {
            debugPrint('Error checking if current user is request creator: $e');
          }
        }
        
        if (mounted) {
          setState(() {
            _isChatClosed = isClosed;
            _isDeletedByRequestCreator = isDeletedByRequestCreator;
            _isDeletedByServiceProvider = isDeletedByServiceProvider;
            _isCurrentUserRequestCreator = isCurrentUserRequestCreator;
            _isRequestCompleted = isRequestCompleted;
          });
        }
        
        debugPrint('Chat status: ${isClosed ? "closed" : "open"}, deleted by request creator: $isDeletedByRequestCreator, deleted by service provider: $isDeletedByServiceProvider');
      }
    } catch (e) {
      debugPrint('Error checking chat status: $e');
    }
  }
  
  void _listenToChatStatus() {
    _chatStatusSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final chatData = snapshot.data()!;
        final isClosed = chatData['isClosed'] as bool? ?? false;
        final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
        final requestId = chatData['requestId'] as String?;
        
        // בדיקה אם הצ'אט נמחק על ידי מבקש השירות או נותן השירות (ללא async)
        if (requestId != null && deletedBy.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // נבדוק את זה באופן אסינכרוני בנפרד
            _checkIfDeletedByRequestCreator(requestId, deletedBy, user.uid).then((result) {
              if (mounted) {
                setState(() {
                  _isDeletedByRequestCreator = result;
                });
              }
            });
            
            // בדיקה אם נותן השירות מחק את הצ'אט
            _checkIfDeletedByServiceProvider(requestId, deletedBy, user.uid).then((result) {
              if (mounted) {
                setState(() {
                  _isDeletedByServiceProvider = result;
                });
              }
            });
            
            // בדיקה אם המשתמש הנוכחי הוא מבקש השירות
            _checkIfCurrentUserIsRequestCreator(requestId, user.uid).then((result) {
              if (mounted) {
                setState(() {
                  _isCurrentUserRequestCreator = result;
                });
              }
            });
            
            // בדיקה אם הבקשה במצב "טופל"
            _checkIfRequestCompleted(requestId).then((result) {
              if (mounted) {
                setState(() {
                  _isRequestCompleted = result;
                });
              }
            });
          }
        }
        
        if (mounted) {
          setState(() {
            _isChatClosed = isClosed;
          });
        }
        
        debugPrint('🔄 Chat status updated in real-time: ${isClosed ? "closed" : "open"}');
      }
    });
  }
  
  Future<bool> _checkIfDeletedByRequestCreator(String requestId, List<String> deletedBy, String currentUserId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final createdBy = requestData['createdBy'] as String?;
        
        // אם יוצר הבקשה מחק את הצ'אט, נותן השירות לא יכול לפתוח אותו מחדש
        if (createdBy != null && deletedBy.contains(createdBy) && createdBy != currentUserId) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking request creator in listener: $e');
    }
    return false;
  }
  
  Future<bool> _checkIfDeletedByServiceProvider(String requestId, List<String> deletedBy, String currentUserId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final createdBy = requestData['createdBy'] as String?;
        
        // אם המשתמש הנוכחי הוא מבקש השירות, נבדוק אם נותן השירות מחק את הצ'אט
        if (createdBy == currentUserId) {
          for (final deletedByUid in deletedBy) {
            if (deletedByUid != currentUserId) {
              // מישהו אחר מחק את הצ'אט - זה נותן השירות
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking service provider in listener: $e');
    }
    return false;
  }
  
  Future<bool> _checkIfCurrentUserIsRequestCreator(String requestId, String currentUserId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final createdBy = requestData['createdBy'] as String?;
        return createdBy == currentUserId;
      }
    } catch (e) {
      debugPrint('Error checking if current user is request creator: $e');
    }
    return false;
  }
  
  Future<bool> _checkIfRequestCompleted(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final status = requestData['status'] as String?;
        return status == 'completed';
      }
    } catch (e) {
      debugPrint('Error checking if request is completed: $e');
    }
    return false;
  }
  
  Future<void> _checkExistingMessages() async {
    try {
      debugPrint('Checking existing messages for chat: ${widget.chatId}');
      
      final l10n = AppLocalizations.of(context);
      
      // בדיקה אם יש הודעת מערכת על הגבלת הודעות (כל שפה)
      // חיפוש לפי isSystemMessage בלבד, לא לפי טקסט
      final systemMessageSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isSystemMessage', isEqualTo: true)
          .get();
      
      // בדיקה אם יש הודעת הגבלת הודעות (כל שפה)
      bool hasLimitMessage = false;
      for (var doc in systemMessageSnapshot.docs) {
        final text = doc.data()['text'] as String? ?? '';
        if (text.contains('ניתן לשלוח עד 50') || 
            text.contains('يمكن إرسال ما يصل إلى 50') ||
            text.contains('You can send up to 50')) {
          hasLimitMessage = true;
          break;
        }
      }
      
      // אם אין הודעת מערכת על הגבלת הודעות, נוסיף אותה
      if (!hasLimitMessage) {
        await _addMessageLimitSystemMessage(l10n);
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
  Future<void> _addMessageLimitSystemMessage(AppLocalizations l10n) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': l10n.canSendUpTo50Messages,
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
    
    _chatStatusSubscription?.cancel();
    _voiceService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        // סימון כל ההודעות כנקראות לפני יציאה מהצ'אט
        ChatService.markMessagesAsRead(widget.chatId);
        
        // עדכון המצב כשהמשתמש עוזב את הצ'אט
        AppStateService.exitAllChats();
        Navigator.of(context).pop();
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
              ? const Color(0xFF9C27B0) // סגול יפה
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
                        Text(l10n.closeChat),
                      ],
                    ),
                  ),
                ] else ...[
                  // הצגת "פתח צ'אט סגור" רק אם הצ'אט לא נמחק על ידי מבקש השירות או נותן השירות
                  // ולא אם הבקשה במצב "טופל"
                  if (!_isDeletedByRequestCreator && !_isDeletedByServiceProvider && !_isRequestCompleted)
                    PopupMenuItem(
                      value: 'reopen',
                      child: Row(
                        children: [
                          const Icon(Icons.lock_open, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(l10n.reopenChat),
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
                  .snapshots()
                  .handleError((error) {
                    debugPrint('❌ Error in chat status stream: $error');
                    // Log error and continue - StreamBuilder will handle error state
                  }),
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
              child: Consumer(
                builder: (context, ref, child) {
                  final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
                  
                  // האזנה לשינויים בהודעות דרך provider - סימון הודעות כנקראות
                  ref.listen<AsyncValue<List<Message>>>(
                    chatMessagesProvider(widget.chatId),
                    (previous, next) {
                      if (!mounted) return;
                      
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      
                      // רק אם המשתמש באמת נכנס לצ'אט (המסך פעיל)
                      if (ModalRoute.of(context)?.isCurrent == true) {
                        next.whenData((messages) {
                          for (final message in messages) {
                            // אם ההודעה לא נשלחה על ידי המשתמש הנוכחי ולא נקראה על ידו
                            if (message.from != user.uid && !message.readBy.contains(user.uid)) {
                              _markMessageAsRead(message.messageId, user.uid);
                            }
                          }
                          
                          // גלילה למטה כשההודעות נטענות או מתעדכנות
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        });
                      }
                    },
                  );
                  
                  return messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                    return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noMessages,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      debugPrint('Loaded ${messages.length} messages for chat: ${widget.chatId}');

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: false, // הודעות חדשות למטה כמו WhatsApp
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.from == user?.uid;
                          
                          return _buildMessageBubble(message, isMe, l10n);
                        },
                      );
                    },
                    loading: () => Center(
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
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                  l10n.loadingMessages,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    error: (error, stack) {
                      debugPrint('Error loading messages: $error');
                    return Center(
                        child: Text(l10n.errorLoadingMessages(error.toString())),
                    );
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
    // הודעות קוליות לא ניתן לערוך
    final canEdit = message.type != MessageType.voice;
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.messageOptions),
        content: Text(l10n.whatDoYouWantToDoWithMessage),
        actions: [
          // כפתור עריכה - רק אם ההודעה לא קולית
          if (canEdit)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditMessageDialog(message);
            },
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 4),
                  Text(l10n.edit),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteMessageDialog(message);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 16, color: Colors.red),
                SizedBox(width: 4),
                Text(l10n.delete, style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  // הצגת דיאלוג עריכת הודעה
  void _showEditMessageDialog(Message message) {
    final TextEditingController editController = TextEditingController(text: message.text);
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editMessage),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: l10n.typeNewMessage,
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editMessage(message, editController.text.trim());
            },
            child: Text(l10n.save),
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.messageEditedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorEditingMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // הצגת דיאלוג מחיקת הודעה
  void _showDeleteMessageDialog(Message message) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessageTitle),
        content: Text(l10n.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
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
      final l10n = AppLocalizations.of(context);
      final success = await ChatService.deleteMessage(
        chatId: widget.chatId,
        messageId: message.messageId,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.messageDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorDeletingMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(Message message, bool isMe, AppLocalizations l10n) {
    // הצגת הודעות מערכת בצורה מיוחדת
    if (message.isSystemMessage) {
      // אם זו הודעת הגבלת הודעות, הצג בשפה הנוכחית
      String displayText = message.text;
      if (message.text.contains('ניתן לשלוח עד 50') || 
          message.text.contains('يمكن إرسال ما يصل إلى 50') ||
          message.text.contains('You can send up to 50')) {
        displayText = l10n.canSendUpTo50Messages;
      }
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
              ? const Color(0xFF9C27B0) // סגול יפה
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
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : (isMe 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainer),
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
                        // תמיד נציג את השם מהמסד הנתונים, גם אם זו ההודעה שלי
                        String displayName = snapshot.data ?? l10n.otherUser;
                        
                        // אם זו ההודעה שלי ולא קיבלנו שם מהמסד הנתונים, ננסה לקבל מ-Firebase Auth
                        if (isMe && (snapshot.data == null || snapshot.data == l10n.otherUser)) {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          displayName = currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? l10n.you;
                        }
                        
                        return Text(
                          displayName,
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : (isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _getUserName(message.from),
                      builder: (context, userNameSnapshot) {
                        final currentL10n = AppLocalizations.of(context);
                        String displayText = message.isDeleted ? currentL10n.messageDeleted : message.text;
                        
                        // אם זו הודעת "שלום! אני.." - הצג בשפה הנוכחית
                        if (!message.isDeleted && !message.isSystemMessage) {
                          // בדיקה אם זו הודעת "שלום! אני.." (כל שפה)
                          if (message.text.contains('שלום! אני') || 
                              message.text.contains('Hello! I am') ||
                              message.text.contains('مرحباً! أنا')) {
                            // קבלת שם המשתמש מהפרופיל
                            final userName = userNameSnapshot.data ?? message.from;
                            
                            if (userName.isNotEmpty && userName != message.from) {
                              // חילוץ קטגוריה ודירוג מההודעה המקורית
                              String? category;
                              bool hasRating = false;
                              String? ratingPart;
                              
                              // חילוץ מההודעה המקורית - כל שפה
                              if (message.text.contains('⭐')) {
                                hasRating = true;
                                final ratingMatch = RegExp(r'\(([^)]+⭐[^)]+)\)').firstMatch(message.text);
                                if (ratingMatch != null) {
                                  ratingPart = ratingMatch.group(1);
                                }
                              } else {
                                // חילוץ קטגוריה
                                if (message.text.contains('מתחום')) {
                                  final categoryMatch = RegExp(r'מתחום\s+([^\s]+)').firstMatch(message.text);
                                  if (categoryMatch != null) {
                                    category = categoryMatch.group(1)?.trim();
                                  }
                                } else if (message.text.contains('from field')) {
                                  final categoryMatch = RegExp(r'from field\s+([^\s]+)').firstMatch(message.text);
                                  if (categoryMatch != null) {
                                    category = categoryMatch.group(1)?.trim();
                                  }
                                } else if (message.text.contains('من مجال')) {
                                  final categoryMatch = RegExp(r'من مجال\s+([^\s]+)').firstMatch(message.text);
                                  if (categoryMatch != null) {
                                    category = categoryMatch.group(1)?.trim();
                                  }
                                }
                              }
                              
                              // חילוץ badge אם קיים
                              String badge = '';
                              if (message.text.contains('🏆 מומחה') || 
                                  message.text.contains('🏆') ||
                                  message.text.contains('خبير')) {
                                badge = ' 🏆 מומחה'; // נשתמש באותה badge לכל השפות
                              }
                              
                              // בניית ההודעה בשפה הנוכחית
                              displayText = currentL10n.helloIAm(userName, badge);
                              
                              // הוספת חלק הדירוג או "חדש בתחום"
                              if (hasRating && ratingPart != null) {
                                displayText += ' ($ratingPart)';
                              } else if (category != null && category.isNotEmpty) {
                                displayText += ' ${currentL10n.newInField(category)}';
                              }
                              
                              // הוספת "מעוניין לעזור"
                              displayText += ' ${currentL10n.interestedInHelping}';
                            }
                          }
                        }
                        
                        // Check if this is a voice message
                        if (message.type == MessageType.voice) {
                          // אם ההודעה הקולית נמחקה, הצג "הודעה נמחקה" (גם למשתמש השני)
                          if (message.isDeleted) {
                            return Text(
                              currentL10n.messageDeleted,
                              style: TextStyle(
                                color: isMe ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            );
                          }
                          // אחרת, הצג את ה-VoiceMessageWidget
                          return VoiceMessageWidget(
                            data: message.data, // Can be Base64 or URL
                            duration: message.duration,
                            isMe: isMe,
                          );
                        }
                        
                        return Text(
                          displayText,
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : (isMe 
                                    ? Colors.white 
                                    : Theme.of(context).colorScheme.onSurface),
                            fontSize: 16,
                            fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            color: message.isDeleted 
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : (isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
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
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.surfaceContainer,
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
            Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'הצ\'אט נסגר - הטיפול בבקשה הסתיים',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              label: Text(l10n.deleteChat),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // הודעה שהצ'אט סגור (אם הצ'אט סגור)
          if (_isChatClosed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Theme.of(context).colorScheme.tertiary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'הצ\'אט סגור - ניתן לצפות בהיסטוריית השיחה בלבד',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Voice recorder widget
          if (_showVoiceRecorder)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VoiceRecorderWidget(
                onRecordingComplete: (filePath) async {
                  if (filePath != null) {
                    await _sendVoiceMessage(filePath);
                  }
                  setState(() {
                    _showVoiceRecorder = false;
                    _isRecordingVoice = false;
                  });
                },
                onCancel: () {
                  setState(() {
                    _showVoiceRecorder = false;
                    _isRecordingVoice = false;
                  });
                },
              ),
            ),
          Row(
            children: [
              // Microphone button for voice messages
              if (!_isChatClosed && 
                  !(_isCurrentUserRequestCreator && _isDeletedByServiceProvider) &&
                  !(!_isCurrentUserRequestCreator && _isDeletedByRequestCreator))
                GestureDetector(
                  onLongPressStart: (_) {
                    setState(() {
                      _showVoiceRecorder = true;
                      _isRecordingVoice = true;
                    });
                  },
                  onLongPressEnd: (_) {
                    // Recording will be stopped by VoiceRecorderWidget
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isRecordingVoice ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: _isRecordingVoice ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (!_isChatClosed && 
                  !(_isCurrentUserRequestCreator && _isDeletedByServiceProvider) &&
                  !(!_isCurrentUserRequestCreator && _isDeletedByRequestCreator))
                const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isChatClosed && 
                      !(_isCurrentUserRequestCreator && _isDeletedByServiceProvider) &&
                      !(!_isCurrentUserRequestCreator && _isDeletedByRequestCreator), // disabled כאשר הצ'אט סגור או נמחק על ידי המשתמש השני
                  decoration: InputDecoration(
                    hintText: _getChatDisabledHint(l10n),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: _isChatClosed || 
                        (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) ||
                        (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator),
                    fillColor: (_isChatClosed || 
                        (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) ||
                        (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator)) 
                        ? Theme.of(context).colorScheme.surfaceContainer 
                        : null,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_isChatClosed || 
                      (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) ||
                      (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator)) 
                      ? null 
                      : (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: (_isChatClosed || 
                    (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) ||
                    (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator)) 
                    ? null 
                    : _sendMessage, // disabled כאשר הצ'אט סגור או נמחק על ידי המשתמש השני
                mini: true,
                backgroundColor: (_isChatClosed || 
                    (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) ||
                    (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator))
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : (Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF9C27B0) // סגול יפה
                      : Theme.of(context).colorScheme.primary),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getChatDisabledHint(AppLocalizations l10n) {
    if (_isChatClosed) {
      return 'הצ\'אט סגור - לא ניתן לשלוח הודעות';
    } else if (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) {
      return 'הצ\'אט נמחק על ידי נותן השירות - לא ניתן לשלוח הודעות';
    } else if (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator) {
      return 'הצ\'אט נמחק על ידי מבקש השירות - לא ניתן לשלוח הודעות';
    }
    return l10n.sendMessage;
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

  /// Send voice message
  Future<void> _sendVoiceMessage(String filePath) async {
    try {
      // Process voice message (convert to Base64 or upload to file.io)
      final processed = await _voiceService.processVoiceMessage(filePath);
      
      // Determine if we should use data (Base64) or url (file.io)
      final voiceData = processed['data'] as String?;
      final voiceUrl = processed['url'] as String?;
      final voiceDataOrUrl = voiceData ?? voiceUrl; // Use Base64 if available, otherwise URL
      
      // Send voice message via ChatService (includes notification and message creation)
      await ChatService.sendMessageWithNotification(
        chatId: widget.chatId,
        text: '🎤 הודעה קולית',
        type: 'voice',
        data: voiceDataOrUrl,
        duration: processed['duration'] as int?,
      );
      
      if (mounted) {
        // Scroll to bottom (new messages at bottom)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error sending voice message: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSendingVoiceMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // בדיקה אם הצ'אט נמחק על ידי המשתמש השני
    // אם מבקש השירות מחק את הצ'אט, נותן השירות לא יוכל לשלוח הודעות
    // אם נותן השירות מחק את הצ'אט, מבקש השירות לא יוכל לשלוח הודעות
    bool cannotSendMessage = false;
    String? reasonMessage;
    
    if (_isChatClosed) {
      cannotSendMessage = true;
      reasonMessage = l10n.chatClosedCannotSend;
    } else {
      // בדיקה אם המשתמש השני מחק את הצ'אט
      // אם המשתמש הנוכחי הוא מבקש השירות והצ'אט נמחק על ידי נותן השירות
      if (_isCurrentUserRequestCreator && _isDeletedByServiceProvider) {
        cannotSendMessage = true;
        reasonMessage = 'לא ניתן לשלוח הודעות - הצ\'אט נמחק על ידי נותן השירות';
      }
      // אם המשתמש הנוכחי הוא נותן השירות והצ'אט נמחק על ידי מבקש השירות
      else if (!_isCurrentUserRequestCreator && _isDeletedByRequestCreator) {
        cannotSendMessage = true;
        reasonMessage = 'לא ניתן לשלוח הודעות - הצ\'אט נמחק על ידי מבקש השירות';
      }
    }
    
    if (cannotSendMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reasonMessage ?? l10n.chatClosedCannotSend),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // בדיקת הגבלת הודעות
    final messageCount = await _getMessageCount();
    if (messageCount >= 50) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reached50MessageLimit),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // הצגת אזהרה כשהולכים להגיע למגבלה
    if (messageCount >= 45) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.warningMessagesRemaining(50 - messageCount)),
          backgroundColor: Colors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      // Send message via ChatService (includes notification, message creation, and 50 message limit check)
      final success = await ChatService.sendMessageWithNotification(
        chatId: widget.chatId,
        text: text,
        type: 'text',
      );

      if (success) {
        _messageController.clear();
        
        // גלילה למטה (הודעות חדשות למטה)
        WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        });
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorSendingMessage(e.toString())),
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
        title: Text(l10n.deleteChatTitle),
        content: Text(l10n.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await playButtonSound();
              // Guard context usage after async gap - check context.mounted for builder context
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
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
      
      final chatData = chatDoc.data()!;
      final requestId = chatData['requestId'] as String?;
      
      // קבלת פרטי הבקשה כדי לבדוק מי יוצר הבקשה
      final requestDoc = requestId != null 
          ? await FirebaseFirestore.instance
              .collection('requests')
              .doc(requestId)
              .get()
          : null;
      
      final createdBy = requestDoc?.exists == true 
          ? requestDoc!.data()!['createdBy'] as String?
          : null;
      
      final isRequestCreator = createdBy == user.uid;
      final isServiceProvider = !isRequestCreator;
      
      // הוספת המשתמש לרשימת המחיקות
      // אם מבקש השירות מוחק את הצ'אט, נסמן אותו כ"סגור" אצל נותן השירות
      // אם נותן השירות מוחק את הצ'אט, לא נסמן אותו כ"סגור" (מבקש השירות עדיין יכול לראות אותו)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'deletedBy': FieldValue.arrayUnion([user.uid]),
        'deletedAt': FieldValue.arrayUnion([DateTime.now()]),
        'isClosed': isRequestCreator, // סגירת הצ'אט רק אם מבקש השירות מוחק אותו
        'updatedAt': DateTime.now(),
      });

      if (isRequestCreator) {
        debugPrint('✅ Chat ${widget.chatId} marked as deleted by request creator ${user.uid} and closed for service provider');
      } else {
        debugPrint('✅ Chat ${widget.chatId} marked as deleted by service provider ${user.uid} - request will remain in "My Inquiries"');
      }
      
      // אם יש requestId, עדכן את הבקשה
      // אם נותן השירות מוחק את הצ'אט, הבקשה תישאר ב"פניות שלי" שלו (לא נסיר אותו מ-helpers)
      // אם מבקש השירות מוחק את הצ'אט, הבקשה תישאר ב"פניות שלי" של נותן השירות (לא נסיר אותו מ-helpers)
      if (requestId != null && requestDoc?.exists == true) {
        try {
          // לא נסיר את נותן השירות מ-helpers גם אם הוא מוחק את הצ'אט
          // הבקשה תישאר ב"פניות שלי" שלו
          if (isServiceProvider) {
            debugPrint('ℹ️ Service provider deleted chat - request will remain in "My Inquiries" for service provider');
          } else {
            debugPrint('ℹ️ Request creator deleted chat - request will remain in "My Inquiries" for service provider');
          }
        } catch (e) {
          debugPrint('❌ Error updating request after chat deletion: $e');
          // נמשיך גם אם יש שגיאה בעדכון הבקשה
        }
      }
      
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.chatDeletedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
      
      // חזרה למסך הקודם
      Navigator.of(context).pop();
      
    } catch (e) {
      debugPrint('❌ Error deleting chat: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorDeletingChat(e.toString())),
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
        title: Text(l10n.closeChatTitle),
        content: Text(l10n.closeChatMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _closeChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.closeChat),
          ),
        ],
      ),
    );
  }

  Future<void> _closeChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final l10n = AppLocalizations.of(context);
      final userName = user.displayName ?? user.email?.split('@')[0] ?? l10n.otherUser;
      
      // שליחת הודעת מערכת
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': l10n.chatClosedBy(userName),
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
        'lastMessage': l10n.chatClosedStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatClosedSuccessfully),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error closing chat: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorClosingChat),
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

      final l10n = AppLocalizations.of(context);
      
      // בדיקה אם הצ'אט נמחק על ידי מבקש השירות או נותן השירות
      if (_isDeletedByRequestCreator) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.cannotReopenChatDeletedByRequester),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      if (_isDeletedByServiceProvider) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.cannotReopenChatDeletedByProvider),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final userName = user.displayName ?? user.email?.split('@')[0] ?? l10n.otherUser;
      
      // עדכון הצ'אט כפתוח
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'isClosed': false,
        'reopenedAt': Timestamp.fromDate(DateTime.now()),
        'reopenedBy': user.uid,
        'lastMessage': l10n.chatReopened,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // שליחת הודעת מערכת
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'from': 'system',
        'text': l10n.chatReopenedBy(userName),
        'sentAt': Timestamp.fromDate(DateTime.now()),
        'isSystemMessage': true,
        'messageType': 'chat_reopened',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatReopened),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error reopening chat: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorGeneral(e.toString())),
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
        content: Text(l10n.deleteMyMessagesConfirm),
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.myMessagesDeletedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorDeletingMyMessages(e.toString())),
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