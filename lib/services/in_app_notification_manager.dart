import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'sound_service.dart';

class InAppNotificationManager {
  static final InAppNotificationManager instance = InAppNotificationManager._internal();
  InAppNotificationManager._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? currentActiveConversationId;
  bool isPopupEnabled = true;
  bool isNotificationsEnabled = true;

  final Set<String> _processedMessageIds = {};
  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  void setActiveConversation(String? conversationId) {
    currentActiveConversationId = conversationId;
  }

  void handleIncomingMessage({
    required ChatMessage message,
    required String myUserId,
    UserProfile? sender,
    VoidCallback? onOpenChat,
  }) {
    // 1. Don't notify for messages sent by the current user
    if (message.senderId == myUserId) return;

    // 2. Deduplicate message IDs
    if (_processedMessageIds.contains(message.id)) return;
    _processedMessageIds.add(message.id);
    if (_processedMessageIds.length > 500) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }

    // 3. Check if chat is muted
    if (SoundService.instance.isMuted(message.conversationId)) return;

    // 4. If notifications globally disabled by user, suppress completely
    if (!isNotificationsEnabled) return;

    // 5. Play sound immediately if enabled
    SoundService.instance.playReceivedSound(conversationId: message.conversationId);

    // 6. If user is currently inside this active conversation, do not show popup
    if (currentActiveConversationId == message.conversationId) return;

    // 7. If popup is disabled by user settings, return
    if (!isPopupEnabled) return;

    // 7. Show in-app animated toast overlay
    _showInAppToast(
      senderName: sender?.displayName ?? 'New Message',
      username: sender?.username,
      avatarUrl: sender?.avatarUrl,
      content: message.content ?? (message.attachments.isNotEmpty ? 'Sent an attachment' : 'New message'),
      onTap: onOpenChat,
    );
  }

  void _showInAppToast({
    required String senderName,
    String? username,
    String? avatarUrl,
    required String content,
    VoidCallback? onTap,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppToastWidget(
        senderName: senderName,
        username: username,
        avatarUrl: avatarUrl,
        content: content,
        onTap: () {
          entry.remove();
          _currentOverlay = null;
          _dismissTimer?.cancel();
          onTap?.call();
        },
        onDismiss: () {
          entry.remove();
          _currentOverlay = null;
          _dismissTimer?.cancel();
        },
      ),
    );

    _currentOverlay = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 3800), () {
      if (_currentOverlay == entry) {
        entry.remove();
        _currentOverlay = null;
      }
    });
  }
}

class _InAppToastWidget extends StatefulWidget {
  final String senderName;
  final String? username;
  final String? avatarUrl;
  final String content;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppToastWidget({
    required this.senderName,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppToastWidget> createState() => _InAppToastWidgetState();
}

class _InAppToastWidgetState extends State<_InAppToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismissWithAnim() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: const Key('in_app_toast'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _dismissWithAnim();
                  widget.onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1D24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.35), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                          border: Border.all(color: const Color(0xFF7C5CFF), width: 1),
                        ),
                        child: ClipOval(
                          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  widget.avatarUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 100,
                                  cacheHeight: 100,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Text(
                                      widget.senderName.isNotEmpty ? widget.senderName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    widget.senderName.isNotEmpty ? widget.senderName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sender and Preview
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.senderName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.username != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '@${widget.username}',
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E9A),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD0D0D8),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Close button
                      GestureDetector(
                        onTap: _dismissWithAnim,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
