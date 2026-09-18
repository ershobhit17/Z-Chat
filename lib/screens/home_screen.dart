import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/theme_provider.dart';
import '../widgets/avatar_widget.dart';
import 'appearance_studio_screen.dart';
import 'chat/chat_screen.dart';
import 'feed/feed_screen.dart';
import 'profile/user_profile_screen.dart';
import 'search/user_search_modal.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  int _chatSectionIndex = 0; // 0 = Chats, 1 = Requests
  String? _selectedConversationId;
  UserProfile? _selectedOtherUser;
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _openSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserSearchModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: theme.background,
      body: isDesktop
          ? _buildDesktopLayout(theme)
          : _buildMobileLayout(theme),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(theme),
      floatingActionButton: isDesktop
          ? null
          : _currentNavIndex == 0
              ? FloatingActionButton(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  onPressed: _openSearchModal,
                  child: const Icon(Icons.edit_rounded),
                )
              : null,
    );
  }

  // DESKTOP / WEB RESPONSIVE LAYOUT (Dual-pane)
  Widget _buildDesktopLayout(AppThemeData theme) {
    final chatService = context.watch<ChatService>();
    final authService = context.watch<AuthService>();
    final myUid = authService.currentUser?.id ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth >= 1200 ? 380.0 : (screenWidth * 0.38).clamp(280.0, 380.0);

    return Row(
      children: [
        // Left Column: Navigation + Chats Sidebar
        Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(right: BorderSide(color: theme.border, width: 1)),
          ),
          child: Column(
            children: [
              // Top App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppConstants.appName,
                      style: theme.getTextStyle(
                        baseSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    const Spacer(),
                    // Social Feed quick button
                    IconButton(
                      tooltip: 'Social Feed & Moments',
                      icon: Icon(Icons.explore_outlined, color: theme.primary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FeedScreen()),
                        );
                      },
                    ),
                    // Appearance Studio quick button
                    IconButton(
                      tooltip: 'Appearance Studio',
                      icon: Icon(Icons.palette_outlined, color: theme.mutedText),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AppearanceStudioScreen()),
                        );
                      },
                    ),
                    // Settings quick button
                    IconButton(
                      tooltip: 'Settings',
                      icon: Icon(Icons.settings_outlined, color: theme.mutedText),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    // Profile quick button
                    IconButton(
                      tooltip: 'My Profile',
                      icon: AvatarWidget(
                        displayName: authService.currentProfile?.displayName ?? 'Me',
                        avatarUrl: authService.currentProfile?.avatarUrl,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: myUid,
                              userProfile: authService.currentProfile,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Search & New Chat Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        onChanged: (v) => setState(() => _filterText = v.trim().toLowerCase()),
                        style: TextStyle(color: theme.text, fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded, color: theme.mutedText, size: 18),
                          hintText: 'Search chats...',
                          hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6), fontSize: 13),
                          filled: true,
                          fillColor: theme.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'New Chat by @username',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _openSearchModal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Conversation List
              Expanded(
                child: _buildConversationList(theme, chatService, myUid, isDesktop: true),
              ),
            ],
          ),
        ),

        // Right Column: Active Conversation (or Empty State)
        Expanded(
          child: _selectedConversationId != null && _selectedOtherUser != null
              ? ChatScreen(
                  key: ValueKey(_selectedConversationId),
                  conversationId: _selectedConversationId!,
                  otherUser: _selectedOtherUser!,
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 36, color: theme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a conversation',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Or find someone by @username to start messaging',
                        style: TextStyle(color: theme.mutedText, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Find People'),
                        onPressed: _openSearchModal,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // MOBILE LAYOUT
  Widget _buildMobileLayout(AppThemeData theme) {
    if (_currentNavIndex == 1) {
      return const FeedScreen();
    } else if (_currentNavIndex == 2) {
      return const AppearanceStudioScreen();
    } else if (_currentNavIndex == 3) {
      return const SettingsScreen();
    }

    final chatService = context.watch<ChatService>();
    final authService = context.watch<AuthService>();
    final myUid = authService.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: theme.getTextStyle(
                baseSize: 18.0,
                fontWeight: FontWeight.bold,
                color: theme.text,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: theme.text),
            onPressed: _openSearchModal,
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: AvatarWidget(
              displayName: authService.currentProfile?.displayName ?? 'Me',
              avatarUrl: authService.currentProfile?.avatarUrl,
              size: 26,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: myUid,
                    userProfile: authService.currentProfile,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildConversationList(theme, chatService, myUid, isDesktop: false),
    );
  }

  Widget _buildConversationList(AppThemeData theme, ChatService chatService, String myUid, {required bool isDesktop}) {
    if (chatService.isLoadingConversations) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    final allConversations = chatService.conversations;
    final mainConversations = allConversations.where((c) => !c.isRequest).toList();
    final requestConversations = allConversations.where((c) => c.isRequest).toList();

    final activeSectionList = _chatSectionIndex == 0 ? mainConversations : requestConversations;

    final conversations = _filterText.isEmpty
        ? activeSectionList
        : activeSectionList.where((c) {
            final other = c.getOtherParticipant(myUid);
            if (other == null) return false;
            return other.displayName.toLowerCase().contains(_filterText.toLowerCase()) ||
                other.username.toLowerCase().contains(_filterText.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Dual Section Segmented Tabs (Chats / Requests)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _chatSectionIndex = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _chatSectionIndex == 0 ? theme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Chats (${mainConversations.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _chatSectionIndex == 0 ? Colors.white : theme.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _chatSectionIndex = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _chatSectionIndex == 1 ? theme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Requests',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _chatSectionIndex == 1 ? Colors.white : theme.mutedText,
                            ),
                          ),
                          if (requestConversations.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _chatSectionIndex == 1 ? Colors.white : theme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${requestConversations.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _chatSectionIndex == 1 ? theme.primary : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // List View or Empty State
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _chatSectionIndex == 1
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mark_email_read_outlined, size: 52, color: theme.mutedText.withValues(alpha: 0.4)),
                              const SizedBox(height: 14),
                              Text(
                                'No message requests',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.text),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When people you haven\'t chatted with message you for the first time, they\'ll appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.mutedText, fontSize: 13),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mark_chat_unread_outlined, size: 54, color: theme.mutedText.withValues(alpha: 0.4)),
                              const SizedBox(height: 14),
                              Text(
                                'Your inbox is empty',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.text),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Find someone by @username and start a conversation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.mutedText, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: theme.primary),
                                  foregroundColor: theme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 18),
                                label: const Text('Find People'),
                                onPressed: _openSearchModal,
                              ),
                            ],
                          ),
                  ),
                )
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.border.withValues(alpha: 0.5), indent: 70),
                  itemBuilder: (ctx, index) {
                    final conv = conversations[index];
                    final other = conv.getOtherParticipant(myUid);
                    if (other == null) return const SizedBox.shrink();

                    final isSelected = isDesktop && _selectedConversationId == conv.id;
                    final hasUnread = conv.unreadCount > 0;
                    final lastMsg = conv.lastMessage;
                    final lastMsgTime = lastMsg != null
                        ? _formatTime(lastMsg.createdAt)
                        : (conv.lastMessageAt != null ? _formatTime(conv.lastMessageAt!) : _formatTime(conv.updatedAt));

                    String snippet = 'No messages yet';
                    if (lastMsg != null) {
                      if (lastMsg.isText) {
                        final content = lastMsg.content ?? '';
                        final urlMatch = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)', caseSensitive: false).firstMatch(content);
                        if (urlMatch != null) {
                          final rawUrl = urlMatch.group(0)!;
                          try {
                            final uri = Uri.parse(rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl');
                            final host = uri.host.replaceFirst('www.', '');
                            snippet = '🔗 $host${content.length > rawUrl.length ? ' • ${content.replaceAll(rawUrl, '').trim()}' : ''}';
                          } catch (_) {
                            snippet = '🔗 Link';
                          }
                        } else {
                          snippet = content;
                        }
                      } else if (lastMsg.isImage) {
                        snippet = '📷 Photo';
                      } else if (lastMsg.isVideo) {
                        snippet = '🎥 Video';
                      } else if (lastMsg.isAudio) {
                        snippet = '🎵 Voice message';
                      } else if (lastMsg.isFile) {
                        snippet = '📎 File';
                      } else if (lastMsg.isYouTube) {
                        snippet = '▶ YouTube Video';
                      } else if (lastMsg.isSharedPost) {
                        snippet = '📸 Shared post';
                      }
                    }

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: theme.primary.withValues(alpha: 0.10),
                      shape: isDesktop
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: isSelected
                                  ? BorderSide(color: theme.primary.withValues(alpha: 0.35), width: 1)
                                  : BorderSide.none,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: AvatarWidget(
                        displayName: other.displayName,
                        avatarUrl: other.avatarUrl,
                        size: theme.avatarSize,
                        isOnline: other.isOnline,
                        showOnlineIndicator: true,
                        theme: theme,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              other.displayName,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 15,
                                color: theme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.isPinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Icon(Icons.push_pin_rounded, size: 14, color: theme.primary),
                            ),
                          Text(
                            lastMsgTime,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              color: hasUnread ? theme.primary : theme.mutedText,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                snippet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                  color: hasUnread ? theme.text : theme.mutedText,
                                ),
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: theme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primary.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      onLongPress: () => _showConversationOptions(context, conv, other, chatService, theme),
                      onTap: () {
                        chatService.markConversationAsRead(conv.id);
                        if (isDesktop) {
                          setState(() {
                            _selectedConversationId = conv.id;
                            _selectedOtherUser = other;
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: conv.id,
                                otherUser: other,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showConversationOptions(
    BuildContext context,
    Conversation conv,
    UserProfile other,
    ChatService chatService,
    AppThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    AvatarWidget(
                      displayName: other.displayName,
                      avatarUrl: other.avatarUrl,
                      size: 40,
                      isOnline: other.isOnline,
                      showOnlineIndicator: true,
                      theme: theme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            other.displayName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.text),
                          ),
                          Text(
                            '@${other.username}',
                            style: TextStyle(fontSize: 12, color: theme.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_outline_rounded, color: theme.text),
                title: Text('View Profile', style: TextStyle(color: theme.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: other.id, userProfile: other),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: theme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Conversation?', style: TextStyle(color: theme.text)),
                      content: Text(
                        'This will delete the conversation with ${other.displayName}. This action cannot be undone.',
                        style: TextStyle(color: theme.mutedText),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: Text('Cancel', style: TextStyle(color: theme.mutedText)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await chatService.deleteConversation(conv.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conversation deleted')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting chat: $e')),
                        );
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar(AppThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        backgroundColor: theme.surface,
        selectedItemColor: theme.primary,
        unselectedItemColor: theme.mutedText,
        showSelectedLabels: theme.showNavLabels,
        showUnselectedLabels: theme.showNavLabels,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => setState(() => _currentNavIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore_rounded),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.palette_outlined),
            activeIcon: Icon(Icons.palette_rounded),
            label: 'Appearance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      return DateFormat('hh:mm a').format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(time);
    }
    return DateFormat('dd/MM/yy').format(time);
  }
}
