import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/in_app_notification_manager.dart';
import '../../services/presence_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/chat_background_container.dart';
import '../../widgets/chat_bubble_widget.dart';
import '../appearance_studio_screen.dart';
import '../profile/user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final UserProfile otherUser;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  ChatMessage? _replyingTo;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Stream<List<ChatMessage>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    InAppNotificationManager.instance.setActiveConversation(widget.conversationId);
    _messagesStream = context.read<ChatService>().streamMessages(widget.conversationId);

    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels <= _scrollController.position.minScrollExtent + 60) {
        context.read<ChatService>().loadOlderMessages(widget.conversationId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PresenceService>().joinChatRoom(widget.conversationId);
    });
  }

  @override
  void dispose() {
    InAppNotificationManager.instance.setActiveConversation(null);
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatService = context.read<ChatService>();
    final replyId = _replyingTo?.id;

    _textController.clear();
    setState(() {
      _replyingTo = null;
    });

    // 0ms delay optimistic send: UI renders bubble immediately, sound plays instantly
    chatService.sendMessageOptimistic(
      conversationId: widget.conversationId,
      content: text,
      replyToId: replyId,
    );

    _scrollToBottom();
  }

  void _pickAndSendMedia(String type) async {
    final chatService = context.read<ChatService>();

    try {
      if (type == 'photo') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          await chatService.sendAttachmentMessage(
            conversationId: widget.conversationId,
            fileBytes: bytes,
            fileName: picked.name,
            mimeType: 'image/jpeg',
          );
          _scrollToBottom();
        }
      } else if (type == 'camera') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          await chatService.sendAttachmentMessage(
            conversationId: widget.conversationId,
            fileBytes: bytes,
            fileName: picked.name,
            mimeType: 'image/jpeg',
          );
          _scrollToBottom();
        }
      } else if (type == 'video') {
        final picker = ImagePicker();
        final picked = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          // Check 25MB limit to preserve 500MB free tier storage
          if (bytes.length > 25 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video is ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB. Max allowed size is 25MB to preserve storage.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
          final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'mp4';
          final mime = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
          await chatService.sendAttachmentMessage(
            conversationId: widget.conversationId,
            fileBytes: bytes,
            fileName: picked.name,
            mimeType: mime,
          );
          _scrollToBottom();
        }
      } else if (type == 'audio') {
        final result = await FilePicker.pickFiles(type: FileType.audio);
        if (result.isNotEmpty) {
          final file = result.first;
          final bytes = await file.xFile.readAsBytes();
          if (bytes.length > 25 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audio file exceeds 25MB limit.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
          final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'mp3';
          final mime = ext == 'mp3' ? 'audio/mpeg' : (ext == 'wav' ? 'audio/wav' : 'audio/m4a');
          await chatService.sendAttachmentMessage(
            conversationId: widget.conversationId,
            fileBytes: bytes,
            fileName: file.name,
            mimeType: mime,
          );
          _scrollToBottom();
        }
      } else if (type == 'file') {
        final result = await FilePicker.pickFiles();
        if (result.isNotEmpty) {
          final file = result.first;
          final bytes = await file.xFile.readAsBytes();
          if (bytes.length > 25 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File exceeds 25MB limit.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
          await chatService.sendAttachmentMessage(
            conversationId: widget.conversationId,
            fileBytes: bytes,
            fileName: file.name,
            mimeType: 'application/octet-stream',
          );
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment error: $e')),
        );
      }
    }
  }

  void _startVoiceRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final presence = context.read<PresenceService>();
    presence.reportTyping(widget.conversationId, isRecording: true);

    String recordPath = '';
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      recordPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: recordPath,
    );

    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  void _stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    final duration = _recordingSeconds;

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });

    if (duration < 1) return; // Discard too short recordings

    if (path != null && mounted) {
      try {
        final chatService = context.read<ChatService>();
        final xfile = XFile(path);
        final bytes = await xfile.readAsBytes();

        await chatService.sendAttachmentMessage(
          conversationId: widget.conversationId,
          fileBytes: bytes,
          fileName: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
          mimeType: 'audio/m4a',
          duration: duration,
        );
        _scrollToBottom();
      } catch (e) {
        debugPrint('Voice note upload error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice send error: $e')),
          );
        }
      }
    }
  }

  void _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  void _showAttachmentOptions(BuildContext context, Color surface) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAttachmentOption(
                    ctx,
                    Icons.photo_library_rounded,
                    'Gallery',
                    const Color(0xFF3897F0),
                    () => _pickAndSendMedia('photo'),
                  ),
                  const SizedBox(width: 14),
                  _buildAttachmentOption(
                    ctx,
                    Icons.camera_alt_rounded,
                    'Camera',
                    const Color(0xFF9B51E0),
                    () => _pickAndSendMedia('camera'),
                  ),
                  const SizedBox(width: 14),
                  _buildAttachmentOption(
                    ctx,
                    Icons.videocam_rounded,
                    'Video',
                    const Color(0xFFF2994A),
                    () => _pickAndSendMedia('video'),
                  ),
                  const SizedBox(width: 14),
                  _buildAttachmentOption(
                    ctx,
                    Icons.headphones_rounded,
                    'Audio',
                    const Color(0xFF27AE60),
                    () => _pickAndSendMedia('audio'),
                  ),
                  const SizedBox(width: 14),
                  _buildAttachmentOption(
                    ctx,
                    Icons.insert_drive_file_rounded,
                    'Document',
                    const Color(0xFF2D9CDB),
                    () => _pickAndSendMedia('file'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteChat() async {
    final theme = context.read<ThemeProvider>().getThemeForChat(widget.conversationId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Chat?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete this conversation and all its messages. This action cannot be undone.',
          style: TextStyle(color: theme.mutedText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: theme.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final chatService = context.read<ChatService>();
      await chatService.deleteConversation(widget.conversationId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted.')),
        );
      }
    }
  }

  Widget _buildAttachmentOption(
    BuildContext ctx,
    IconData icon,
    String label,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.getThemeForChat(widget.conversationId);
    final authService = context.watch<AuthService>();
    final myUid = authService.currentUser?.id ?? '';
    final chatService = context.read<ChatService>();
    final presenceService = context.watch<PresenceService>();
    final partnerStatus = presenceService.getStatusForUser(widget.otherUser.id);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        titleSpacing: (MediaQuery.of(context).size.width >= 768) ? 16 : 0,
        automaticallyImplyLeading: false,
        leading: (MediaQuery.of(context).size.width < 768 && Navigator.canPop(context))
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.text, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userProfile: widget.otherUser,
                  conversationId: widget.conversationId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                AvatarWidget(
                  displayName: widget.otherUser.displayName,
                  avatarUrl: widget.otherUser.avatarUrl,
                  size: 38,
                  isOnline: widget.otherUser.isOnline,
                  showOnlineIndicator: true,
                  theme: theme,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUser.displayName,
                        style: theme.getTextStyle(
                          baseSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        partnerStatus == 'typing'
                            ? 'typing...'
                            : partnerStatus == 'recording'
                                ? 'recording audio...'
                                : widget.otherUser.isOnline
                                    ? 'Online'
                                    : '@${widget.otherUser.username}',
                        style: TextStyle(
                          fontSize: 11,
                          color: partnerStatus != null || widget.otherUser.isOnline
                              ? theme.primary
                              : theme.mutedText,
                          fontWeight: partnerStatus != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Per-chat Theme Studio button!
          IconButton(
            tooltip: 'Customize this chat',
            icon: Icon(Icons.palette_outlined, color: theme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppearanceStudioScreen(perChatConversationId: widget.conversationId),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.text),
            color: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userProfile: widget.otherUser,
                      conversationId: widget.conversationId,
                    ),
                  ),
                );
              } else if (val == 'delete') {
                _confirmDeleteChat();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: theme.text, size: 18),
                    const SizedBox(width: 10),
                    Text('View Profile', style: TextStyle(color: theme.text, fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Chat', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ChatBackgroundContainer(
        theme: theme,
        child: Column(
          children: [
            // Message stream list
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messagesStream,
                initialData: context.read<ChatService>().getCachedMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: theme.primary),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  // Mark incoming messages as read so the sender gets the blue tick
                  if (messages.isNotEmpty) {
                    final latest = messages.last;
                    if (latest.senderId != myUid) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        chatService.markMessagesAsRead(widget.conversationId, latest.id);
                      });
                    }
                  }

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarWidget(
                            displayName: widget.otherUser.displayName,
                            avatarUrl: widget.otherUser.avatarUrl,
                            size: 64,
                            isOnline: widget.otherUser.isOnline,
                            theme: theme,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.otherUser.displayName,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${widget.otherUser.username}',
                            style: TextStyle(color: theme.primary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.border),
                            ),
                            child: Text(
                              'Say hello and start the conversation 👋',
                              style: TextStyle(color: theme.mutedText, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    itemCount: messages.length,
                    itemBuilder: (ctx, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == myUid;

                      return ChatBubbleWidget(
                        message: msg,
                        isMe: isMe,
                        theme: theme,
                        onReply: (m) => setState(() => _replyingTo = m),
                        onReact: (mId, emoji) => chatService.toggleReaction(mId, emoji),
                        onEdit: (m) => _showEditDialog(m, chatService, theme),
                        onDelete: (m, forEveryone) => chatService.deleteMessage(m.id, deleteForEveryone: forEveryone),
                        onRetry: (m) => chatService.retryMessage(m),
                      );
                    },
                  );
                },
              ),
            ),

            // Reply snippet banner
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.surface,
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, color: theme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Replying to message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.primary)),
                          Text(_replyingTo!.content ?? 'Attachment', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.mutedText)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.mutedText),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),

            // Message Request Acceptance Banner (if incoming request)
            Consumer<ChatService>(
              builder: (ctx, chatService, _) {
                final conv = chatService.conversations
                    .where((c) => c.id == widget.conversationId)
                    .firstOrNull;
                final isReq = conv?.isRequest ?? false;
                if (!isReq) return const SizedBox.shrink();

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.otherUser.displayName} sent you a message request.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reply or tap Accept to move this chat to your main inbox.',
                        style: TextStyle(fontSize: 11.5, color: theme.mutedText),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: _confirmDeleteChat,
                              child: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () {
                                _textController.text = '👋 Hello!';
                                _handleSendText();
                              },
                              child: const Text('Accept 👋', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Composer Bar
            _buildComposerBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerBar(AppThemeData theme) {
    if (_isRecordingVoice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: theme.surface,
        child: Row(
          children: [
            const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              'Recording ${_recordingSeconds}s...',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: _cancelVoiceRecording,
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: theme.primary),
              onPressed: _stopAndSendVoiceRecording,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.8)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment Button
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: theme.mutedText, size: 26),
              onPressed: () => _showAttachmentOptions(context, theme.surface),
            ),

            // Text Input Field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.border),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.getTextStyle(color: theme.text, baseSize: 15.0),
                  onChanged: (val) {
                    setState(() {});
                    context.read<PresenceService>().reportTyping(widget.conversationId);
                  },
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Send / Voice Record Button
            _textController.text.trim().isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.arrow_upward_rounded, color: theme.primary, size: 26),
                    onPressed: _handleSendText,
                  )
                : IconButton(
                    icon: Icon(Icons.mic_none_rounded, color: theme.mutedText, size: 24),
                    onPressed: _startVoiceRecording,
                  ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage message, ChatService chatService, AppThemeData theme) {
    final editController = TextEditingController(text: message.content ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Edit Message', style: TextStyle(color: theme.text)),
        content: TextField(
          controller: editController,
          autofocus: true,
          style: TextStyle(color: theme.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
            onPressed: () {
              chatService.editMessage(message.id, editController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
