import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/post_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/video_player_widget.dart';
import '../profile/comments_modal.dart';
import '../profile/share_post_modal.dart';
import '../profile/user_profile_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  final PageController _pageController = PageController();
  List<Post> _clips = [];
  bool _isLoading = true;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadClips({bool forceRefresh = false}) async {
    final postService = Provider.of<PostService>(context, listen: false);
    final list = await postService.getZClipsFeed(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _clips = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_clips.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'No Z Clips yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a video post to appear here!',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _loadClips(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _clips.length,
        onPageChanged: (index) {
          if (_activePage != index) setState(() => _activePage = index);
        },
        itemBuilder: (context, index) {
          return _ClipPageItem(
            key: ValueKey(_clips[index].id),
            post: _clips[index],
            isActive: index == _activePage,
            onLikeToggled: (updatedPost) {
              if (mounted) setState(() => _clips[index] = updatedPost);
            },
          );
        },
      ),
    );
  }
}

/// Each clip is its own StatefulWidget with AutomaticKeepAlive so
/// video controllers survive swipes without being disposed & re-created.
class _ClipPageItem extends StatefulWidget {
  final Post post;
  final bool isActive;
  final ValueChanged<Post> onLikeToggled;

  const _ClipPageItem({
    super.key,
    required this.post,
    required this.isActive,
    required this.onLikeToggled,
  });

  @override
  State<_ClipPageItem> createState() => _ClipPageItemState();
}

class _ClipPageItemState extends State<_ClipPageItem>
    with AutomaticKeepAliveClientMixin {
  bool _isMuted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final post = widget.post;
    final author = post.author;
    final videoMedia = post.media.firstWhere(
      (m) => m.isVideo,
      orElse: () => post.media.isNotEmpty
          ? post.media.first
          : PostMedia(
              id: '',
              postId: post.id,
              userId: post.userId,
              objectKey: '',
              mediaUrl: '',
              mediaType: 'video',
              createdAt: DateTime.now(),
            ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        Positioned.fill(
          child: videoMedia.mediaUrl.isNotEmpty
              ? ZVideoPlayerWidget(
                  videoUrl: videoMedia.mediaUrl,
                  thumbnailUrl: videoMedia.thumbnailUrl,
                  autoPlay: widget.isActive,
                  looping: true,
                  isMuted: _isMuted,
                  showControls: true,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white38),
                  ),
                ),
        ),

        // Gradient overlay (IgnorePointer so it doesn't eat taps)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black38, Colors.transparent, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Right action buttons
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (author != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileScreen(user: author)),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: AvatarWidget(
                    displayName: author?.displayName ?? 'User',
                    avatarUrl: author?.avatarUrl,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Like (optimistic)
              _buildActionButton(
                icon: post.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: post.isLikedByMe ? Colors.redAccent : Colors.white,
                label: '${post.likeCount}',
                onTap: () async {
                  final postService = Provider.of<PostService>(context, listen: false);
                  final liked = await postService.toggleLike(
                    post.id,
                    isCurrentlyLiked: post.isLikedByMe,
                    postOwnerId: post.userId,
                  );
                  widget.onLikeToggled(post.copyWith(
                    isLikedByMe: liked,
                    likeCount: liked ? post.likeCount + 1 : (post.likeCount - 1).clamp(0, 999999),
                  ));
                },
              ),
              const SizedBox(height: 16),

              // Comment
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${post.commentsCount}',
                onTap: () => CommentsModal.show(context, postId: post.id, postOwnerId: post.userId),
              ),
              const SizedBox(height: 16),

              // Share
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () => SharePostModal.show(context, post: post),
              ),
              const SizedBox(height: 16),

              // Mute (local to each clip)
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _isMuted = !_isMuted),
              ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          bottom: 30,
          left: 16,
          right: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (author != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileScreen(user: author)),
                    );
                  }
                },
                child: Text(
                  '@${author?.username ?? 'user'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (post.caption != null && post.caption!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
