import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService extends ChangeNotifier {
  final SupabaseClient _supabase;

  BlockService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // Check if target user is blocked by current user or vice versa
  Future<bool> isUserBlocked(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      final res = await _supabase
          .from('blocked_users')
          .select('id')
          .or('and(blocker_id.eq.$uid,blocked_id.eq.$targetUserId),and(blocker_id.eq.$targetUserId,blocked_id.eq.$uid)')
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('Error checking blocked user: $e');
      return false;
    }
  }

  // Block a user
  Future<bool> blockUser(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null || uid == targetUserId) return false;

    try {
      // 1. Insert into blocked_users
      await _supabase.from('blocked_users').upsert({
        'blocker_id': uid,
        'blocked_id': targetUserId,
      });

      // 2. Remove any existing follow relationships between both
      await _supabase
          .from('follow_relationships')
          .delete()
          .or('and(follower_id.eq.$uid,following_id.eq.$targetUserId),and(follower_id.eq.$targetUserId,following_id.eq.$uid)');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  // Unblock a user
  Future<bool> unblockUser(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', targetUserId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }
}
