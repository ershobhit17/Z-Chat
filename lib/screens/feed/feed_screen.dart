import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/moment_service.dart';
import '../../services/post_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/video_player_widget.dart';
import '../moments/create_moment_modal.dart';
import '../moments/moment_viewer_screen.dart';
import '../profile/comments_modal.dart';
import '../profile/create_post_modal.dart';
import '../profile/post_detail_screen.dart';
import '../profile/share_post_modal.dart';
import '../profile/user_profile_screen.dart';
import '../watch/youtube_watch_screen.dart';
import 'clips_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  int _selectedFeedFilter = 0; // 0 = Following, 1 = Explore

  List<Post> _followingPosts = [];
  List<Post> _explorePosts = [];
  List<UserMomentsGroup> _momentGroups = [];

  bool _isLoadingFollowing = true;
  bool _isLoadingExplore = false; // loaded lazily on first Explore tap

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    // Load moments and following feed in parallel on init
    // Explore feed is loaded lazily when user first taps it
    Future.wait([_loadMoments(), _loadFollowingFeed()]);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  Future<void> _loadMoments() async {
    final momentService = Provider.of<MomentService>(context, listen: false);
    final groups = await momentService.getActiveMomentsGrouped();
    if (mounted) {
      setState(() {
        _momentGroups = groups;
      });
    }
  }

  Future<void> _loadFollowingFeed({bool forceRefresh = false}) async {
    final postService = Provider.of<PostService>(context, listen: false);
    final list = await postService.getFollowingFeed(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _followingPosts = list;
        _isLoadingFollowing = false;
      });
    }
  }

  Future<void> _loadExploreFeed({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoadingExplore = true);
    final postService = Provider.of<PostService>(context, listen: false);
    final list = await postService.getPublicFeed(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _explorePosts = list;
        _isLoadingExplore = false;
      });
    }
  }

  void _openCreatePost() async {
    final newPost = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostModal(),
    );

    if (newPost != null && mounted) {
      _loadFollowingFeed();
      _loadExploreFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1015) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Z Social',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: theme.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Z Clips'),
            Tab(text: 'Watch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          // 1. Social Feed Tab
          _buildFeedView(theme, isDark),

          // 2. Z Clips Tab
          const ClipsScreen(),

          // 3. YouTube Watch Tab
          const YouTubeWatchScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
        label: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFeedView(dynamic theme, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadMoments(),
              _loadFollowingFeed(forceRefresh: true),
              _loadExploreFeed(forceRefresh: true),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              // Moments Tray
              SliverToBoxAdapter(
                child: _buildMomentsTray(theme, isDark),
              ),

              // Sub-Filter Tabs: Following vs Explore
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('Following', 0, theme),
                      const SizedBox(width: 8),
                      _buildFilterChip('Explore', 1, theme),
                    ],
                  ),
                ),
              ),

              // Feed List
              _selectedFeedFilter == 0
                  ? _buildPostList(_followingPosts, _isLoadingFollowing, "Your following feed is quiet.\nFollow more users to see their posts here!", theme, isDark)
                  : _buildPostList(_explorePosts, _isLoadingExplore, "No public posts found.", theme, isDark),

              // Extra bottom padding so Floating 'Post' button & Bottom Navigation Bar never hide posts
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, dynamic theme) {
    final isSelected = _selectedFeedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFeedFilter = index);
          // Lazy-load Explore feed on first tap
          if (index == 1 && _explorePosts.isEmpty && !_isLoadingExplore) {
            _loadExploreFeed();
          }
        }
      },
      selectedColor: theme.primaryColor.withAlpha(35),
      labelStyle: TextStyle(
        color: isSelected ? theme.primaryColor : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : Colors.grey.withAlpha(50),
        ),
      ),
    );
  }

  Widget _buildMomentsTray(dynamic theme, bool isDark) {
    final authService = Provider.of<AuthService>(context);
    final myProfile = authService.currentProfile;
    final myUid = authService.currentUser?.id;

    UserMomentsGroup? myGroup;
    final otherGroups = <UserMomentsGroup>[];

    for (final g in _momentGroups) {
      if (g.user.id == myUid) {
        myGroup = g;
      } else {
        otherGroups.add(g);
      }
    }

    final hasMyMoments = myGroup != null && myGroup.moments.isNotEmpty;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 1 + otherGroups.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            // "Your Story" item
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (hasMyMoments) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MomentViewerScreen(moments: myGroup!.moments),
                              ),
                            );
                            _loadMoments();
                          } else {
                            final created = await CreateMomentModal.show(context);
                            if (created == true) _loadMoments();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasMyMoments
                                ? LinearGradient(
                                    colors: [theme.primaryColor, Colors.orangeAccent, Colors.purpleAccent],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                          ),
                          child: AvatarWidget(
                            displayName: myProfile?.displayName ?? 'You',
                            avatarUrl: myProfile?.avatarUrl,
                            size: 56,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final created = await CreateMomentModal.show(context);
                            if (created == true) _loadMoments();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF0F1015) : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Your Story', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          final group = otherGroups[index - 1];
          final user = group.user;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MomentViewerScreen(moments: group.moments),
                ),
              ).then((_) => _loadMoments());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: group.hasUnviewed
                          ? LinearGradient(
                              colors: [theme.primaryColor, Colors.orangeAccent, Colors.purpleAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: group.hasUnviewed ? null : Border.all(color: Colors.grey.withAlpha(60), width: 1.5),
                    ),
                    child: AvatarWidget(
                      displayName: user.displayName,
                      avatarUrl: user.avatarUrl,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostList(List<Post> posts, bool isLoading, String emptyMsg, dynamic theme, bool isDark) {
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (posts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          return _buildPostCard(post, index, theme, isDark);
        },
        childCount: posts.length,
      ),
    );
  }

  Widget _buildPostCard(Post post, int index, dynamic theme, bool isDark) {
    final author = post.author;
    final firstMedia = post.media.isNotEmpty ? post.media.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withAlpha(30), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Username, More
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
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
                  child: AvatarWidget(
                    displayName: author?.displayName ?? 'User',
                    avatarUrl: author?.avatarUrl,
                    username: author?.username,
                    enablePreviewOnTap: true,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (author != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(user: author)),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author?.displayName ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '@${author?.username ?? 'user'} • ${DateFormat.MMMd().format(post.createdAt.toLocal())}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Media Container (if any)
          if (firstMedia != null && firstMedia.mediaUrl.isNotEmpty) ...[
            if (firstMedia.isVideo)
              ClipRect(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 460, minHeight: 220),
                  width: double.infinity,
                  color: Colors.black,
                  child: ZVideoPlayerWidget(
                    videoUrl: firstMedia.mediaUrl,
                    autoPlay: false,
                    looping: true,
                    showControls: true,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post, author: author),
                    ),
                  );
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    firstMedia.mediaUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.withAlpha(30),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, stackTrace) => Container(
                      color: Colors.grey.withAlpha(30),
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    ),
                  ),
                ),
              ),
          ],

          // Action Buttons: Like, Comment, Share, Bookmark
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : Colors.white,
            ),
            child: Row(
              children: [
                // Like Button
                IconButton(
                  icon: Icon(
                    post.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: post.isLikedByMe ? Colors.redAccent : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    size: 24,
                  ),
                  onPressed: () async {
                    final postService = Provider.of<PostService>(context, listen: false);
                    final liked = await postService.toggleLike(
                      post.id,
                      isCurrentlyLiked: post.isLikedByMe,
                      postOwnerId: post.userId,
                    );
                    // Update local list so this card rebuilds immediately
                    if (mounted) {
                      setState(() {
                        final updated = post.copyWith(
                          isLikedByMe: liked,
                          likeCount: liked ? post.likeCount + 1 : (post.likeCount - 1).clamp(0, 999999),
                        );
                        if (_selectedFeedFilter == 0) {
                          _followingPosts[index] = updated;
                        } else {
                          _explorePosts[index] = updated;
                        }
                      });
                    }
                  },
                ),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 8),

                // Comment Button
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    size: 22,
                  ),
                  onPressed: () {
                    CommentsModal.show(context, postId: post.id, postOwnerId: post.userId);
                  },
                ),
                Text(
                  '${post.commentsCount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 4),

                // Share Button
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    size: 22,
                  ),
                  onPressed: () {
                    SharePostModal.show(context, post: post);
                  },
                ),
                const Spacer(),

                // Save Bookmark
                IconButton(
                  icon: Icon(
                    post.isSavedByMe ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: post.isSavedByMe ? theme.primaryColor : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    size: 24,
                  ),
                  onPressed: () async {
                    final postService = Provider.of<PostService>(context, listen: false);
                    final saved = await postService.toggleSave(
                      post.id,
                      isCurrentlySaved: post.isSavedByMe,
                    );
                    setState(() {
                      final updated = post.copyWith(isSavedByMe: saved);
                      if (_selectedFeedFilter == 0) {
                        _followingPosts[index] = updated;
                      } else {
                        _explorePosts[index] = updated;
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Caption
          if (post.caption != null && post.caption!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${author?.username ?? 'user'} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: post.caption!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
