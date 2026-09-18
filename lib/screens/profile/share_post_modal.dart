import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/post_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';

class SharePostModal extends StatefulWidget {
  final Post post;

  const SharePostModal({super.key, required this.post});

  static void show(BuildContext context, {required Post post}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharePostModal(post: post),
    );
  }

  @override
  State<SharePostModal> createState() => _SharePostModalState();
}

class _SharePostModalState extends State<SharePostModal> {
  final Set<String> _sentConversations = {};

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final chatService = Provider.of<ChatService>(context);
    final authService = Provider.of<AuthService>(context);
    final currentUid = authService.currentUser?.id ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final conversations = chatService.conversations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Share Post to Chat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: conversations.isEmpty
                ? const Center(
                    child: Text(
                      'No active conversations found.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final otherUser = conv.getOtherParticipant(currentUid);
                      final isSent = _sentConversations.contains(conv.id);

                      return ListTile(
                        leading: AvatarWidget(
                          displayName: otherUser?.displayName ?? 'User',
                          avatarUrl: otherUser?.avatarUrl,
                          size: 44,
                        ),
                        title: Text(
                          otherUser?.displayName ?? 'Direct Message',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Text(
                          '@${otherUser?.username ?? 'user'}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        trailing: ElevatedButton(
                          onPressed: isSent
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final postService = Provider.of<PostService>(context, listen: false);
                                  await postService.sharePostToConversation(
                                    post: widget.post,
                                    conversationId: conv.id,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _sentConversations.add(conv.id);
                                    });
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Post shared to chat!')),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSent ? Colors.grey : theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(isSent ? 'Sent' : 'Send', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
