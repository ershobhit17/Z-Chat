import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

enum FollowState {
  self,
  none,
  pending,
  following,
  blocked,
}

class FollowService extends ChangeNotifier {
  final SupabaseClient _supabase;

  FollowService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // Check follow status between current user and target user
  Future<FollowState> getFollowStatus(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return FollowState.none;
    if (uid == targetUserId) return FollowState.self;

    try {
      // 1. Check if blocked
      final blocked = await _supabase
          .from('blocked_users')
          .select('id')
          .or('and(blocker_id.eq.$uid,blocked_id.eq.$targetUserId),and(blocker_id.eq.$targetUserId,blocked_id.eq.$uid)')
          .maybeSingle();

      if (blocked != null) {
        return FollowState.blocked;
      }

      // 2. Check follow relationship
      final res = await _supabase
          .from('follow_relationships')
          .select('status')
          .eq('follower_id', uid)
          .eq('following_id', targetUserId)
          .maybeSingle();

      if (res == null) return FollowState.none;

      final status = res['status'] as String?;
      if (status == 'accepted') return FollowState.following;
      if (status == 'pending') return FollowState.pending;
      return FollowState.none;
    } catch (e) {
      debugPrint('Error getting follow status: $e');
      return FollowState.none;
    }
  }

  // Follow a user (auto-accepted if target is public, pending if target is private)
  Future<FollowState> followUser({
    required String targetUserId,
    required bool isTargetPrivate,
  }) async {
    final uid = _currentUserId;
    if (uid == null || uid == targetUserId) return FollowState.none;

    final initialStatus = isTargetPrivate ? 'pending' : 'accepted';

    try {
      await _supabase.from('follow_relationships').upsert({
        'follower_id': uid,
        'following_id': targetUserId,
        'status': initialStatus,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert notification
      await _supabase.from('notifications').insert({
        'recipient_id': targetUserId,
        'sender_id': uid,
        'type': isTargetPrivate ? 'follow_request' : 'new_follower',
        'content': isTargetPrivate
            ? 'requested to follow you'
            : 'started following you',
      }).catchError((_) {});

      notifyListeners();
      return isTargetPrivate ? FollowState.pending : FollowState.following;
    } catch (e) {
      debugPrint('Error following user: $e');
      return FollowState.none;
    }
  }

  // Unfollow or cancel a pending follow request
  Future<bool> unfollowUser(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('follow_relationships')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', targetUserId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      return false;
    }
  }

  // Fetch pending follow requests for the current user
  Future<List<FollowRelationship>> getPendingFollowRequests() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final res = await _supabase
          .from('follow_relationships')
          .select('*, profiles!follower_id(*)')
          .eq('following_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final list = res as List;
      return list.map((e) => FollowRelationship.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching pending follow requests: $e');
      return [];
    }
  }

  // Accept a follow request
  Future<bool> acceptFollowRequest({
    required String relationshipId,
    required String requesterId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('follow_relationships')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', relationshipId)
          .eq('following_id', uid);

      // Notification to requester
      await _supabase.from('notifications').insert({
        'recipient_id': requesterId,
        'sender_id': uid,
        'type': 'follow_accept',
        'content': 'accepted your follow request',
      }).catchError((_) {});

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting follow request: $e');
      return false;
    }
  }

  // Reject / Remove a follow request
  Future<bool> rejectFollowRequest(String relationshipId) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    try {
      await _supabase
          .from('follow_relationships')
          .delete()
          .eq('id', relationshipId)
          .eq('following_id', uid);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error rejecting follow request: $e');
      return false;
    }
  }

  // Fetch followers list for a user (accepted only)
  Future<List<UserProfile>> getFollowers(String userId, {int limit = 50, int offset = 0}) async {
    try {
      final res = await _supabase
          .from('follow_relationships')
          .select('profiles!follower_id(*)')
          .eq('following_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = res as List;
      final profiles = <UserProfile>[];
      for (final item in list) {
        if (item['profiles'] != null) {
          profiles.add(UserProfile.fromJson(item['profiles'] as Map<String, dynamic>));
        }
      }
      return profiles;
    } catch (e) {
      debugPrint('Error fetching followers: $e');
      return [];
    }
  }

  // Fetch following list for a user (accepted only)
  Future<List<UserProfile>> getFollowing(String userId, {int limit = 50, int offset = 0}) async {
    try {
      final res = await _supabase
          .from('follow_relationships')
          .select('profiles!following_id(*)')
          .eq('follower_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = res as List;
      final profiles = <UserProfile>[];
      for (final item in list) {
        if (item['profiles'] != null) {
          profiles.add(UserProfile.fromJson(item['profiles'] as Map<String, dynamic>));
        }
      }
      return profiles;
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return [];
    }
  }
}
