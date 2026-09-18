import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _presenceChannel;
  final Map<String, String> _typingStatuses = {}; // userId -> status ('typing', 'recording', or null)
  Timer? _typingDebounceTimer;

  Map<String, String> get typingStatuses => _typingStatuses;

  String? getStatusForUser(String userId) => _typingStatuses[userId];

  void joinChatRoom(String conversationId) {
    leaveChatRoom();
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _presenceChannel = _supabase.channel('presence:room:$conversationId');

    _presenceChannel?.onPresenceSync((payload) {
      final state = _presenceChannel?.presenceState();
      if (state != null) {
        _typingStatuses.clear();
        for (final single in state) {
          for (final presence in single.presences) {
            final p = presence.payload;
            final userId = p['user_id'] as String?;
            final status = p['status'] as String?;
            if (userId != null && userId != uid && status != null) {
              _typingStatuses[userId] = status;
            }
          }
        }
        notifyListeners();
      }
    });

    _presenceChannel?.subscribe((status, err) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel?.track({
          'user_id': uid,
          'status': 'active',
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void reportTyping(String conversationId, {bool isRecording = false}) {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || _presenceChannel == null) return;

    _presenceChannel?.track({
      'user_id': uid,
      'status': isRecording ? 'recording' : 'typing',
      'updated_at': DateTime.now().toIso8601String(),
    });

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
      _presenceChannel?.track({
        'user_id': uid,
        'status': 'idle',
      });
    });
  }

  void leaveChatRoom() {
    _typingDebounceTimer?.cancel();
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    _typingStatuses.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    leaveChatRoom();
    super.dispose();
  }
}
