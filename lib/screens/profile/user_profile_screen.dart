import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/chat_service.dart';
import '../../services/follow_service.dart';
import '../../services/post_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../chat/chat_screen.dart';
import '../settings/profile_screen.dart';
import 'create_post_modal.dart';
import 'follow_requests_modal.dart';
import 'followers_list_modal.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId;
  final UserProfile? user;
  final UserProfile? userProfile;
  final String? conversationId;

  const UserProfileScreen({
    super.key,
    this.userId,
    this.user,
    this.userProfile,
    this.conversationId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  UserProfile? _profile;
  bool _isLoadingProfile = false;
  List<Post> _posts = [];
  List<Post> _savedPosts = [];
  bool _isLoadingPosts = true;
  bool _isLoadingSaved = false;

  FollowState _followState = FollowState.none;
  bool _isTogglingFollow = false;
  int _pendingRequestsCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _profile = widget.user ?? widget.userProfile;
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _targetUserId {
    if (_profile != null) return _profile!.id;
    if (widget.userId != null) return widget.userId!;
    return context.read<AuthService>().currentUser?.id ?? '';
  }

  bool get _isSelf {
    final myUid = context.read<AuthService>().currentUser?.id;
    return myUid != null && myUid == _targetUserId;
  }

  Future<void> _loadAll() async {
    final targetId = _targetUserId;
    if (targetId.isEmpty) return;

    final followService = context.read<FollowService>();

    // 1. Fetch profile if not loaded or refresh for latest stats
    setState(() => _isLoadingProfile = _profile == null);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', targetId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _profile = UserProfile.fromJson(res);
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }

    // 2. Fetch follow state if other user
    if (!_isSelf) {
      final state = await followService.getFollowStatus(targetId);
      if (mounted) {
        setState(() => _followState = state);
      }
    } else {
      // If self and private account, check pending follow requests
      if (_profile?.isPrivate == true) {
        final reqs = await followService.getPendingFollowRequests();
        if (mounted) {
          setState(() => _pendingRequestsCount = reqs.length);
        }
      }
    }

    // 3. Load posts
    _loadPosts();
    if (_isSelf) {
      _loadSavedPosts();
    }
  }

  Future<void> _loadPosts() async {
    final targetId = _targetUserId;
    if (targetId.isEmpty) return;

    // If private account and not self and not following, do not fetch private posts
    if (!_isSelf && _profile?.isPrivate == true && _followState != FollowState.following) {
      setState(() {
        _posts = [];
        _isLoadingPosts = false;
      });
      return;
    }

    setState(() => _isLoadingPosts = true);
    try {
      final postService = context.read<PostService>();
      final posts = await postService.fetchUserPosts(
        userId: targetId,
        includePrivate: _isSelf,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoadingSaved = true);
    try {
      final postService = context.read<PostService>();
      final saved = await postService.getSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = saved;
          _isLoadingSaved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profile == null || _isTogglingFollow) return;
    final followService = context.read<FollowService>();
    setState(() => _isTogglingFollow = true);

    try {
      if (_followState == FollowState.following || _followState == FollowState.pending) {
        final ok = await followService.unfollowUser(_profile!.id);
        if (ok && mounted) {
          setState(() {
            _followState = FollowState.none;
            _profile = _profile!.copyWith(
              followersCount: (_profile!.followersCount - 1).clamp(0, 9999999),
            );
          });
          _loadPosts();
        }
      } else if (_followState == FollowState.none) {
        final newState = await followService.followUser(
          targetUserId: _profile!.id,
          isTargetPrivate: _profile!.isPrivate,
        );
        if (mounted) {
          setState(() {
            _followState = newState;
            if (newState == FollowState.following) {
              _profile = _profile!.copyWith(
                followersCount: _profile!.followersCount + 1,
              );
            }
          });
          _loadPosts();
        }
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  void _handleMessageAction() async {
    if (widget.conversationId != null) {
      Navigator.pop(context);
      return;
    }

    if (_profile == null) return;
    try {
      final chatService = context.read<ChatService>();
      final convId = await chatService.getOrCreateDirectConversation(_profile!.id);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              otherUser: _profile!,
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

  void _openFollowersModal(int initialIndex) {
    if (_profile == null) return;
    FollowersListModal.show(
      context,
      userId: _profile!.id,
      displayName: _profile!.displayName,
      initialTabIndex: initialIndex,
    );
  }

  void _openPostDetail(Post post) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          author: _profile,
        ),
      ),
    );

    if (deleted == true && mounted) {
      _loadPosts();
      if (_isSelf) _loadSavedPosts();
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
      _loadPosts();
      _loadAll();
    }
  }

  void _toggleAccountPrivacy(bool isPrivate) async {
    final authService = context.read<AuthService>();
    await authService.updateProfile(isPrivate: isPrivate);
    if (mounted) {
      setState(() {
        _profile = _profile?.copyWith(isPrivate: isPrivate);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPrivate ? 'Account set to Private' : 'Account set to Public'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(elevation: 0),
        body: const Center(child: Text('Profile not found.')),
      );
    }

    final profile = _profile!;
    final isLockedPrivate = !_isSelf && profile.isPrivate && _followState != FollowState.following;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1015) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          '@${profile.username}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (_isSelf && profile.isPrivate && _pendingRequestsCount > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add_rounded),
                  tooltip: 'Follow Requests',
                  onPressed: () {
                    FollowRequestsModal.show(context);
                    setState(() => _pendingRequestsCount = 0);
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_pendingRequestsCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          if (!_isSelf)
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'block') {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  final blockService = context.read<BlockService>();
                  final ok = await blockService.blockUser(profile.id);
                  if (ok && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Blocked @${profile.username}')),
                    );
                    nav.pop();
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block User', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar & Stats Row
                      Row(
                        children: [
                          AvatarWidget(
                            displayName: profile.displayName,
                            avatarUrl: profile.avatarUrl,
                            size: 80,
                            isOnline: profile.isOnline,
                            enablePreviewOnTap: true,
                            username: profile.username,
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem('Posts', profile.postCount),
                                GestureDetector(
                                  onTap: () => _openFollowersModal(0),
                                  child: _buildStatItem('Followers', profile.followersCount),
                                ),
                                GestureDetector(
                                  onTap: () => _openFollowersModal(1),
                                  child: _buildStatItem('Following', profile.followingCount),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Display Name & Privacy Badge
                      Row(
                        children: [
                          Text(
                            profile.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          if (profile.isPrivate) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey.shade500),
                          ],
                        ],
                      ),

                      // Bio
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.bio,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action Buttons
                      if (_isSelf) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                  );
                                  _loadAll();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openCreatePost,
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                          label: const Text('New Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Privacy Switch Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                profile.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                                size: 18,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                profile.isPrivate ? 'Private Account' : 'Public Account',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: profile.isPrivate,
                            activeTrackColor: theme.primaryColor,
                            onChanged: _toggleAccountPrivacy,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildFollowButton(theme),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleMessageAction,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text('Message', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_isSelf)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: theme.primaryColor,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded), text: 'Posts'),
                    Tab(icon: Icon(Icons.bookmark_outline_rounded), text: 'Saved'),
                  ],
                ),
                isDark: isDark,
              ),
            ),
        ],
        body: isLockedPrivate
            ? _buildPrivateAccountPlaceholder(theme)
            : _isSelf
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsGrid(_posts, _isLoadingPosts, 'No posts yet.'),
                      _buildPostsGrid(_savedPosts, _isLoadingSaved, 'No saved posts yet.'),
                    ],
                  )
                : _buildPostsGrid(_posts, _isLoadingPosts, 'No posts yet.'),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFollowButton(dynamic theme) {
    String label = 'Follow';
    Color btnColor = theme.primaryColor;
    Color txtColor = Colors.white;
    bool isOutlined = false;

    switch (_followState) {
      case FollowState.following:
        label = 'Following';
        isOutlined = true;
        break;
      case FollowState.pending:
        label = 'Requested';
        isOutlined = true;
        break;
      case FollowState.blocked:
        label = 'Blocked';
        btnColor = Colors.red;
        break;
      case FollowState.none:
        label = _profile?.isPrivate == true ? 'Follow Request' : 'Follow';
        break;
      case FollowState.self:
        break;
    }

    if (isOutlined) {
      return OutlinedButton(
        onPressed: _isTogglingFollow ? null : _handleFollowToggle,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isTogglingFollow
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    return ElevatedButton(
      onPressed: _isTogglingFollow ? null : _handleFollowToggle,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: txtColor,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isTogglingFollow
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPrivateAccountPlaceholder(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withAlpha(20),
              ),
              child: Icon(Icons.lock_outline_rounded, size: 48, color: theme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              'This Account is Private',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow this account to see their photos and videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid(List<Post> postsList, bool isLoading, String emptyText) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (postsList.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: postsList.length,
      itemBuilder: (context, index) {
        final post = postsList[index];
        final firstMedia = post.media.isNotEmpty ? post.media.first : null;
        final hasVideo = post.media.any((m) => m.isVideo);

        return GestureDetector(
          onTap: () => _openPostDetail(post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (firstMedia != null && firstMedia.mediaUrl.isNotEmpty)
                Image.network(
                  firstMedia.mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey.withAlpha(30),
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                )
              else
                Container(
                  color: Colors.grey.withAlpha(30),
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      post.caption ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              if (hasVideo)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.play_circle_fill_rounded, size: 20, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _SliverTabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0F1015) : const Color(0xFFF9FAFB),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
