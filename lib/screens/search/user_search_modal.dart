import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../chat/chat_screen.dart';
import '../profile/user_profile_screen.dart';

class UserSearchModal extends StatefulWidget {
  const UserSearchModal({super.key});

  @override
  State<UserSearchModal> createState() => _UserSearchModalState();
}

class _UserSearchModalState extends State<UserSearchModal> {
  final _searchController = TextEditingController();
  List<UserProfile> _results = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _openProfile(UserProfile user) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userProfile: user),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final chatService = context.read<ChatService>();
      final users = await chatService.searchUsers(trimmed);
      if (mounted) {
        setState(() {
          _results = users;
          _isSearching = false;
        });
      }
    });
  }

  void _startChatWith(UserProfile user) async {
    final chatService = context.read<ChatService>();
    try {
      final convId = await chatService.getOrCreateDirectConversation(user.id);
      if (mounted) {
        Navigator.pop(context); // Close search modal
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              otherUser: user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Find People by @username',
            style: theme.getTextStyle(
              baseSize: 18.0,
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            style: TextStyle(color: theme.text),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: theme.mutedText),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              hintText: 'Search username...',
              hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6)),
              filled: true,
              fillColor: theme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: theme.mutedText.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty ? 'Type a username to find anyone on Z Chat' : 'No users found matching "@${_searchController.text}"',
                          style: TextStyle(color: theme.mutedText, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: theme.border.withValues(alpha: 0.4)),
                    itemBuilder: (ctx, index) {
                      final user = _results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        leading: AvatarWidget(
                          displayName: user.displayName,
                          avatarUrl: user.avatarUrl,
                          size: 42,
                          isOnline: user.isOnline,
                          showOnlineIndicator: true,
                        ),
                        title: Text(
                          user.displayName,
                          style: TextStyle(fontWeight: FontWeight.w600, color: theme.text, fontSize: 15),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          ),
                          onPressed: () => _startChatWith(user),
                          child: Text(
                            'Chat',
                            style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        onTap: () => _openProfile(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
