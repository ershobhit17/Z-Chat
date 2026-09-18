import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/youtube_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/youtube_in_app_player.dart';

class YouTubeWatchScreen extends StatefulWidget {
  const YouTubeWatchScreen({super.key});

  @override
  State<YouTubeWatchScreen> createState() => _YouTubeWatchScreenState();
}

class _YouTubeWatchScreenState extends State<YouTubeWatchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<YouTubeVideo> _videos = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performSearch('Flutter tutorial');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().length >= 2) {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final ytService = Provider.of<YouTubeService>(context, listen: false);
    final results = await ytService.searchVideos(query);
    if (mounted) {
      setState(() {
        _videos = results;
        _isLoading = false;
      });
    }
  }

  void _shareVideoToChat(YouTubeVideo video) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUid = authService.currentUser?.id ?? '';
    final conversations = chatService.conversations;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
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
                'Share Video to Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversations.isEmpty
                  ? const Center(child: Text('No conversations found', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, index) {
                        final conv = conversations[index];
                        final otherUser = conv.getOtherParticipant(currentUid);

                        return ListTile(
                          leading: AvatarWidget(
                            displayName: otherUser?.displayName ?? 'User',
                            avatarUrl: otherUser?.avatarUrl,
                            size: 40,
                          ),
                          title: Text(otherUser?.displayName ?? 'Direct Message', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('@${otherUser?.username ?? 'user'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);
                              final ytService = Provider.of<YouTubeService>(context, listen: false);
                              await ytService.shareVideoToConversation(
                                video: video,
                                conversationId: conv.id,
                              );
                              if (mounted) {
                                nav.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Video shared to chat!')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1015) : const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  _performSearch(query.trim());
                }
              },
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search YouTube videos...',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.grey),
                  onPressed: () {
                    if (_searchController.text.trim().isNotEmpty) {
                      _performSearch(_searchController.text.trim());
                    }
                  },
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('Flutter tutorial');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _videos.isEmpty
                    ? const Center(
                        child: Text('No videos found.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF181A20) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail with Play button overlay
                                GestureDetector(
                                  onTap: () {
                                    YouTubeInAppPlayer.show(context, video: video);
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            video.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              color: Colors.black,
                                              child: const Center(
                                                child: Icon(Icons.video_library_rounded, color: Colors.white54, size: 48),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                      ),
                                      if (video.duration != null && video.duration!.isNotEmpty)
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              video.duration!,
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                 // Video Details
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => YouTubeInAppPlayer.show(context, video: video),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                video.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                video.channelTitle,
                                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.share_outlined, color: theme.primaryColor, size: 20),
                                        tooltip: 'Share to Z Chat',
                                        onPressed: () => _shareVideoToChat(video),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
