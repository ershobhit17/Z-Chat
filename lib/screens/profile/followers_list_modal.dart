import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/follow_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import 'user_profile_screen.dart';

class FollowersListModal extends StatefulWidget {
  final String userId;
  final String displayName;
  final int initialTabIndex; // 0 for followers, 1 for following

  const FollowersListModal({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTabIndex = 0,
  });

  static void show(
    BuildContext context, {
    required String userId,
    required String displayName,
    int initialTabIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowersListModal(
        userId: userId,
        displayName: displayName,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<FollowersListModal> createState() => _FollowersListModalState();
}

class _FollowersListModalState extends State<FollowersListModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserProfile> _followers = [];
  List<UserProfile> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final followService = Provider.of<FollowService>(context, listen: false);

    followService.getFollowers(widget.userId).then((list) {
      if (mounted) {
        setState(() {
          _followers = list;
          _isLoadingFollowers = false;
        });
      }
    });

    followService.getFollowing(widget.userId).then((list) {
      if (mounted) {
        setState(() {
          _following = list;
          _isLoadingFollowing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: theme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
          const Divider(height: 1),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers, _isLoadingFollowers, 'No followers yet.'),
                _buildUserList(_following, _isLoadingFollowing, "Not following anyone yet."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserProfile> users, bool isLoading, String emptyMessage) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: users.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: AvatarWidget(
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            size: 44,
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            '@${user.username}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          onTap: () {
            Navigator.pop(context); // Close sheet
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(user: user),
              ),
            );
          },
        );
      },
    );
  }
}
