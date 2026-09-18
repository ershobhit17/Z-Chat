import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/follow_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import 'user_profile_screen.dart';

class FollowRequestsModal extends StatefulWidget {
  const FollowRequestsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FollowRequestsModal(),
    );
  }

  @override
  State<FollowRequestsModal> createState() => _FollowRequestsModalState();
}

class _FollowRequestsModalState extends State<FollowRequestsModal> {
  List<FollowRelationship> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final followService = Provider.of<FollowService>(context, listen: false);
    final reqs = await followService.getPendingFollowRequests();
    if (mounted) {
      setState(() {
        _requests = reqs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAccept(FollowRelationship rel) async {
    final followService = Provider.of<FollowService>(context, listen: false);
    setState(() {
      _requests.removeWhere((r) => r.id == rel.id);
    });
    await followService.acceptFollowRequest(
      relationshipId: rel.id,
      requesterId: rel.followerId,
    );
  }

  Future<void> _handleReject(FollowRelationship rel) async {
    final followService = Provider.of<FollowService>(context, listen: false);
    setState(() {
      _requests.removeWhere((r) => r.id == rel.id);
    });
    await followService.rejectFollowRequest(rel.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Follow Requests',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '${_requests.length}',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending follow requests.',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _requests.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final rel = _requests[index];
                          final user = rel.profile;

                          return ListTile(
                            leading: AvatarWidget(
                              displayName: user?.displayName ?? 'User',
                              avatarUrl: user?.avatarUrl,
                              size: 44,
                            ),
                            title: Text(
                              user?.displayName ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Text(
                              '@${user?.username ?? 'user'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _handleAccept(rel),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text('Confirm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _handleReject(rel),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey,
                                    side: BorderSide(color: Colors.grey.withAlpha(80)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Delete', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (user != null) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(user: user),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
