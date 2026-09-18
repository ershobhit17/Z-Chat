import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../theme/app_theme_data.dart';
import '../screens/chat/chat_screen.dart';
import 'in_app_notification_manager.dart';
import 'media_storage_service.dart';
import 'sound_service.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final MediaStorageService _mediaStorage = ImageKitStorageService();

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  RealtimeChannel? _conversationsChannel;

  // In-memory caching for conversations, messages & profiles
  final Map<String, UserProfile> _profileCache = {};
  final Map<String, List<ChatMessage>> _serverMessagesCache = {};
  final Map<String, List<ChatMessage>> _optimisticMessages = {};
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, StreamController<List<ChatMessage>>> _streamControllers = {};
  final Map<String, StreamSubscription> _conversationSubscriptions = {};
  bool _isLoadingOlderMessages = false;

  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;

  ChatService() {
    _init();
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        loadConversations();
        _subscribeToConversations();
      } else {
        _conversations = [];
        _conversationsChannel?.unsubscribe();
        _disposeAllMessageStreams();
        notifyListeners();
      }
    });

    if (_supabase.auth.currentUser != null) {
      loadConversations();
      _subscribeToConversations();
    }
  }

  void _disposeAllMessageStreams() {
    for (final sub in _conversationSubscriptions.values) {
      sub.cancel();
    }
    _conversationSubscriptions.clear();
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _messagesCache.clear();
    _serverMessagesCache.clear();
    _optimisticMessages.clear();
  }

  @override
  void dispose() {
    _conversationsChannel?.unsubscribe();
    _disposeAllMessageStreams();
    super.dispose();
  }

  // Subscribe to real-time conversation member, message, and conversation changes
  void _subscribeToConversations() {
    _conversationsChannel?.unsubscribe();
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _conversationsChannel = _supabase.channel('public:conversations:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          _handleRealtimeMessageEvent(payload);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversations',
        callback: (payload) {
          _handleRealtimeConversationEvent(payload);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_members',
        callback: (payload) {
          loadConversations();
        },
      )
      ..subscribe();
  }

  // Handle realtime conversation update events (e.g. last_message_at updated via DB trigger)
  void _handleRealtimeConversationEvent(PostgresChangePayload payload) {
    try {
      final rec = payload.newRecord;
      if (rec.isEmpty || rec['id'] == null) return;
      final convId = rec['id'] as String;
      final lastMsgAtStr = rec['last_message_at'] as String?;
      if (lastMsgAtStr == null) return;

      final lastMsgAt = DateTime.tryParse(lastMsgAtStr);
      if (lastMsgAt == null) return;

      final idx = _conversations.indexWhere((c) => c.id == convId);
      if (idx != -1) {
        final existing = _conversations[idx];
        _conversations[idx] = existing.copyWith(
          lastMessageAt: lastMsgAt,
          updatedAt: lastMsgAt,
        );
        _reSortConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling realtime conversation event: $e');
    }
  }

  // Fast in-memory handling of incoming realtime messages
  void _handleRealtimeMessageEvent(PostgresChangePayload payload) {
    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;

      final message = ChatMessage.fromJson(newRecord);
      final myUid = _supabase.auth.currentUser?.id;
      final isFromMe = myUid != null && message.senderId == myUid;
      final isActiveChat = InAppNotificationManager.instance.currentActiveConversationId == message.conversationId;
      final shouldIncrementUnread = !isFromMe && !isActiveChat;

      // 1. Update in-memory message cache if conversation is active/cached
      final serverMsgs = _serverMessagesCache[message.conversationId];
      if (serverMsgs != null) {
        final existingIndex = serverMsgs.indexWhere((m) => m.id == message.id);
        if (existingIndex != -1) {
          serverMsgs[existingIndex] = message;
        } else {
          serverMsgs.add(message);
        }
        final optList = _optimisticMessages[message.conversationId];
        if (optList != null && optList.isNotEmpty) {
          optList.removeWhere((opt) =>
              opt.id == message.id ||
              (opt.senderId == message.senderId && opt.content == message.content));
        }
        _emitCombinedMessages(message.conversationId);
      }

      // 2. Update conversation list in-memory without full DB refetch
      _updateConversationLocally(
        conversationId: message.conversationId,
        lastMsg: message,
        updatedAt: message.createdAt,
        incrementUnread: shouldIncrementUnread,
      );

      // 3. Play received sound chime immediately if from other user
      if (shouldIncrementUnread) {
        SoundService.instance.playReceivedSound(conversationId: message.conversationId);
      }

      // 4. Trigger In-App Notification if incoming from someone else
      if (!isFromMe) {
        final sender = _profileCache[message.senderId] ??
            _findMemberProfile(message.conversationId, message.senderId);

        InAppNotificationManager.instance.handleIncomingMessage(
          message: message,
          myUserId: myUid ?? '',
          sender: sender,
          onOpenChat: () {
            final navContext = InAppNotificationManager.instance.navigatorKey.currentContext;
            if (navContext != null && sender != null) {
              markConversationAsRead(message.conversationId);
              Navigator.push(
                navContext,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: message.conversationId,
                    otherUser: sender,
                  ),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error handling realtime message event: $e');
    }
  }

  UserProfile? _findMemberProfile(String conversationId, String userId) {
    for (final conv in _conversations) {
      if (conv.id == conversationId) {
        for (final m in conv.members) {
          if (m.userId == userId && m.profile != null) {
            _profileCache[userId] = m.profile!;
            return m.profile;
          }
        }
      }
    }
    return null;
  }

  void _reSortConversations() {
    _conversations.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final timeA = a.lastMessage?.createdAt ?? a.lastMessageAt ?? a.updatedAt;
      final timeB = b.lastMessage?.createdAt ?? b.lastMessageAt ?? b.updatedAt;
      return timeB.compareTo(timeA);
    });
  }

  void _updateConversationLocally({
    required String conversationId,
    required ChatMessage lastMsg,
    required DateTime updatedAt,
    bool incrementUnread = false,
    bool clearUnread = false,
  }) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final existing = _conversations[index];
      final newUnreadCount = clearUnread
          ? 0
          : (incrementUnread ? existing.unreadCount + 1 : existing.unreadCount);

      final updatedConv = existing.copyWith(
        lastMessage: lastMsg,
        lastMessageAt: updatedAt,
        updatedAt: updatedAt,
        unreadCount: newUnreadCount,
      );
      _conversations.removeAt(index);
      // Pinned conversations stay above non-pinned
      if (updatedConv.isPinned) {
        _conversations.insert(0, updatedConv);
      } else {
        final firstNonPinned = _conversations.indexWhere((c) => !c.isPinned);
        if (firstNonPinned != -1) {
          _conversations.insert(firstNonPinned, updatedConv);
        } else {
          _conversations.add(updatedConv);
        }
      }
      _reSortConversations();
      notifyListeners();
    } else {
      // If conversation is not found in cache, fetch it
      loadConversations();
    }
  }

  // Load all conversations for the current user with parallel fetching & caching
  Future<void> loadConversations() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    if (_conversations.isEmpty) {
      _isLoadingConversations = true;
      notifyListeners();
    }

    try {
      // 1. Fetch conversation_members for current user
      final myMemberRows = await _supabase
          .from('conversation_members')
          .select('conversation_id, is_pinned, is_muted, is_archived, last_read_message_id, chat_theme, chat_wallpaper')
          .eq('user_id', uid);

      if (myMemberRows.isEmpty) {
        _conversations = [];
        _isLoadingConversations = false;
        notifyListeners();
        return;
      }

      final convIds = (myMemberRows as List).map((r) => r['conversation_id'] as String).toList();

      // 2. Parallel fetch conversations, all members, sent message checks, and unread messages
      final results = await Future.wait([
        _supabase
            .from('conversations')
            .select('id, type, created_at, updated_at, last_message_at')
            .inFilter('id', convIds)
            .order('last_message_at', ascending: false),
        _supabase
            .from('conversation_members')
            .select('id, conversation_id, user_id, joined_at, last_read_message_id, is_muted, is_archived, is_pinned, chat_theme, chat_wallpaper')
            .inFilter('conversation_id', convIds),
        _supabase
            .from('messages')
            .select('conversation_id')
            .eq('sender_id', uid)
            .inFilter('conversation_id', convIds),
        _supabase
            .from('messages')
            .select('conversation_id')
            .inFilter('conversation_id', convIds)
            .neq('sender_id', uid)
            .neq('status', 'read'),
      ]);

      final convRows = results[0] as List;
      final allMemberRows = results[1] as List;
      final mySentRows = results[2] as List;
      final unreadRows = results.length > 3 ? (results[3] as List) : [];

      final Set<String> convsWhereISent = {
        for (final r in mySentRows)
          if (r['conversation_id'] != null) r['conversation_id'] as String
      };

      final unreadCounts = <String, int>{};
      for (final r in unreadRows) {
        final cId = r['conversation_id'] as String?;
        if (cId != null) {
          unreadCounts[cId] = (unreadCounts[cId] ?? 0) + 1;
        }
      }

      // 3. Batch-fetch member profiles
      final allUserIds = allMemberRows.map((m) => m['user_id'] as String).toSet().toList();
      final profilesMap = <String, UserProfile>{};
      final missingIds = allUserIds.where((id) => !_profileCache.containsKey(id)).toList();

      if (missingIds.isNotEmpty) {
        try {
          final profileRows = await _supabase
              .from('profiles')
              .select()
              .inFilter('id', missingIds);
          for (final p in profileRows) {
            final profile = UserProfile.fromJson(p);
            _profileCache[profile.id] = profile;
          }
        } catch (profileErr) {
          debugPrint('Error batch-fetching member profiles: $profileErr');
        }
      }

      for (final id in allUserIds) {
        if (_profileCache.containsKey(id)) {
          profilesMap[id] = _profileCache[id]!;
        }
      }

      // 4. Parallel fetch latest message for each conversation
      final lastMsgFutures = convRows.map((convJson) {
        final convId = convJson['id'] as String;
        return _supabase
            .from('messages')
            .select('''
              id, conversation_id, sender_id, message_type, content, reply_to_id, is_edited, is_deleted, deleted_for, created_at,
              message_attachments ( id, message_id, storage_path, file_name, mime_type, file_size, duration, width, height )
            ''')
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .then((rows) {
              final list = rows as List;
              return MapEntry<String, ChatMessage?>(
                convId,
                list.isNotEmpty ? ChatMessage.fromJson(list.first) : null,
              );
            })
            .catchError((e) {
              debugPrint('Error fetching last message for conv $convId: $e');
              return MapEntry<String, ChatMessage?>(convId, null);
            });
      });

      final lastMsgEntries = await Future.wait(lastMsgFutures);
      final lastMsgMap = Map.fromEntries(lastMsgEntries);

      // 5. Group members by conversation_id
      final membersByConv = <String, List<ConversationMember>>{};
      for (final mJson in allMemberRows) {
        final cId = mJson['conversation_id'] as String;
        final uId = mJson['user_id'] as String;
        final profile = profilesMap[uId];
        final member = ConversationMember.fromJson(mJson).copyWith(profile: profile);
        membersByConv.putIfAbsent(cId, () => []).add(member);
      }

      List<Conversation> loaded = [];

      for (final convJson in convRows) {
        final convId = convJson['id'] as String;
        final members = membersByConv[convId] ?? [];
        final myMemberDetails = myMemberRows.firstWhere(
          (m) => m['conversation_id'] == convId,
          orElse: () => {},
        );

        final lastMsg = lastMsgMap[convId];

        AppThemeData? chatCustomTheme;
        if (myMemberDetails['chat_theme'] != null && myMemberDetails['chat_theme'] is Map<String, dynamic>) {
          try {
            chatCustomTheme = AppThemeData.fromJson(myMemberDetails['chat_theme'] as Map<String, dynamic>);
          } catch (_) {}
        }

        final hasSentMessage = convsWhereISent.contains(convId);
        final isRequest = (convJson['type'] == 'direct' || convJson['type'] == null) &&
            lastMsg != null &&
            lastMsg.senderId != uid &&
            !hasSentMessage;

        DateTime? lastMsgAt;
        if (convJson['last_message_at'] != null) {
          lastMsgAt = DateTime.tryParse(convJson['last_message_at'] as String);
        }

        loaded.add(Conversation(
          id: convId,
          type: convJson['type'] as String? ?? 'direct',
          createdAt: DateTime.parse(convJson['created_at'] as String),
          updatedAt: DateTime.parse(convJson['updated_at'] as String),
          lastMessageAt: lastMsgAt ?? lastMsg?.createdAt,
          members: members,
          lastMessage: lastMsg,
          unreadCount: unreadCounts[convId] ?? 0,
          isPinned: myMemberDetails['is_pinned'] as bool? ?? false,
          isMuted: myMemberDetails['is_muted'] as bool? ?? false,
          isArchived: myMemberDetails['is_archived'] as bool? ?? false,
          customTheme: chatCustomTheme,
          isRequest: isRequest,
        ));
      }

      // Sort: pinned chats on top, then by most recent last_message_at / lastMessage / updated_at
      loaded.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final timeA = a.lastMessage?.createdAt ?? a.lastMessageAt ?? a.updatedAt;
        final timeB = b.lastMessage?.createdAt ?? b.lastMessageAt ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });

      _conversations = loaded;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  // Update per-conversation theme
  Future<void> updateChatTheme(String conversationId, AppThemeData theme) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('conversation_members').update({
        'chat_theme': theme.toJson(),
      }).match({'conversation_id': conversationId, 'user_id': uid});
      await loadConversations();
    } catch (e) {
      debugPrint('Error updating chat theme: $e');
    }
  }

  // Update per-conversation wallpaper
  Future<void> updateChatWallpaper(String conversationId, String wallpaper) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('conversation_members').update({
        'chat_wallpaper': wallpaper,
      }).match({'conversation_id': conversationId, 'user_id': uid});
      await loadConversations();
    } catch (e) {
      debugPrint('Error updating chat wallpaper: $e');
    }
  }

  // Delete an entire conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _supabase.rpc('delete_conversation', params: {
        'p_conversation_id': conversationId,
      });
    } catch (e) {
      debugPrint('delete_conversation RPC failed ($e), attempting direct delete');
      await _supabase.from('conversations').delete().eq('id', conversationId);
    }
    _conversations.removeWhere((c) => c.id == conversationId);
    _messagesCache.remove(conversationId);
    _serverMessagesCache.remove(conversationId);
    _optimisticMessages.remove(conversationId);
    _conversationSubscriptions[conversationId]?.cancel();
    _conversationSubscriptions.remove(conversationId);
    _streamControllers[conversationId]?.close();
    _streamControllers.remove(conversationId);
    notifyListeners();
  }

  // Search users by @username
  Future<List<UserProfile>> searchUsers(String query) async {
    final lower = query.trim().toLowerCase().replaceAll('@', '');
    if (lower.isEmpty) return [];

    final currentUid = _supabase.auth.currentUser?.id;

    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .ilike('username_lower', '%$lower%')
          .neq('id', currentUid ?? '')
          .limit(20);

      final users = (res as List).map((p) => UserProfile.fromJson(p as Map<String, dynamic>)).toList();
      for (final u in users) {
        _profileCache[u.id] = u;
      }
      return users;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Get or create direct 1-to-1 conversation
  Future<String> getOrCreateDirectConversation(String otherUserId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    try {
      final convId = await _supabase.rpc('get_or_create_direct_conversation', params: {
        'target_user_id': otherUserId,
      });
      await loadConversations();
      return convId.toString();
    } catch (rpcError) {
      debugPrint('RPC error, falling back to manual create: $rpcError');

      final myConvs = await _supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', uid);

      final otherConvs = await _supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', otherUserId);

      final myIds = (myConvs as List).map((e) => e['conversation_id'] as String).toSet();
      final otherIds = (otherConvs as List).map((e) => e['conversation_id'] as String).toSet();
      final common = myIds.intersection(otherIds);

      if (common.isNotEmpty) {
        await loadConversations();
        return common.first;
      }

      final newConv = await _supabase
          .from('conversations')
          .insert({'type': 'direct'})
          .select('id')
          .single();

      final newId = newConv['id'] as String;

      await _supabase.from('conversation_members').insert([
        {'conversation_id': newId, 'user_id': uid},
        {'conversation_id': newId, 'user_id': otherUserId},
      ]);

      await loadConversations();
      return newId;
    }
  }

  // ==========================================
  // HIGH PERFORMANCE MESSAGE STREAM & CACHING
  // ==========================================

  List<ChatMessage> getCachedMessages(String conversationId) {
    return List.unmodifiable(_messagesCache[conversationId] ?? []);
  }

  void _emitCombinedMessages(String conversationId) {
    final serverMsgs = _serverMessagesCache[conversationId] ?? [];
    final optMsgs = _optimisticMessages[conversationId] ?? [];
    final combined = [...serverMsgs, ...optMsgs];
    _messagesCache[conversationId] = combined;

    final controller = _streamControllers[conversationId];
    if (controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(combined));
    }
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_streamControllers.containsKey(conversationId) || _streamControllers[conversationId]!.isClosed) {
      final controller = StreamController<List<ChatMessage>>.broadcast(
        onListen: () {
          _emitCombinedMessages(conversationId);
        },
      );
      _streamControllers[conversationId] = controller;
      _messagesCache[conversationId] ??= [];

      // Initialize Supabase native realtime stream
      _initConversationStream(conversationId);
    } else {
      // Re-emit immediately to any new listener
      Future.microtask(() => _emitCombinedMessages(conversationId));
    }

    return _streamControllers[conversationId]!.stream;
  }

  void _initConversationStream(String conversationId) {
    _conversationSubscriptions[conversationId]?.cancel();

    _conversationSubscriptions[conversationId] = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .listen(
      (rows) {
        try {
          final myUid = _supabase.auth.currentUser?.id;
          final serverMessages = rows.map((json) {
            final rawMsg = ChatMessage.fromJson(json);
            final isMe = rawMsg.senderId == myUid;

            MessageStatus status = MessageStatus.sent;
            if (json['status'] == 'read') {
              status = MessageStatus.read;
            } else if (isMe) {
              status = MessageStatus.sent;
            }

            return rawMsg.copyWith(status: status);
          }).toList();

          // Filter out messages deleted for current user
          final filtered = serverMessages
              .where((m) => myUid == null || !m.deletedFor.contains(myUid))
              .toList();

          // Reconcile with pending optimistic messages:
          // Remove from _optimisticMessages if server now has this message
          final optList = _optimisticMessages[conversationId];
          if (optList != null && optList.isNotEmpty) {
            optList.removeWhere((opt) {
              return filtered.any((sm) =>
                  sm.id == opt.id ||
                  (sm.senderId == opt.senderId &&
                   sm.content == opt.content &&
                   sm.createdAt.difference(opt.createdAt).abs().inSeconds < 60));
            });
          }

          _serverMessagesCache[conversationId] = filtered;
          _emitCombinedMessages(conversationId);
        } catch (e) {
          debugPrint('Error parsing streamed messages for $conversationId: $e');
        }
      },
      onError: (err) {
        debugPrint('Realtime stream error for conversation $conversationId: $err');
      },
    );
  }

  // Load older messages (cursor-based pagination)
  Future<bool> loadOlderMessages(String conversationId) async {
    final list = _messagesCache[conversationId];
    if (list == null || list.isEmpty || _isLoadingOlderMessages) return false;

    final oldest = list.firstWhere((m) => !m.id.startsWith('temp_'), orElse: () => list.first);
    final oldestTime = oldest.createdAt;

    _isLoadingOlderMessages = true;
    notifyListeners();

    try {
      final olderRows = await _supabase
          .from('messages')
          .select('''
            id, conversation_id, sender_id, message_type, content, reply_to_id, is_edited, is_deleted, deleted_for, created_at, status
          ''')
          .eq('conversation_id', conversationId)
          .lt('created_at', oldestTime.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(30);

      if ((olderRows as List).isEmpty) return false;

      final olderMessages = olderRows.map((r) => ChatMessage.fromJson(r)).toList().reversed.toList();
      final existingIds = list.map((m) => m.id).toSet();
      final toAdd = olderMessages.where((m) => !existingIds.contains(m.id)).toList();

      if (toAdd.isNotEmpty) {
        final serverMsgs = _serverMessagesCache[conversationId] ?? [];
        serverMsgs.insertAll(0, toAdd);
        _serverMessagesCache[conversationId] = serverMsgs;
        _emitCombinedMessages(conversationId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      return false;
    } finally {
      _isLoadingOlderMessages = false;
      notifyListeners();
    }
  }

  // Mark messages as read by current user
  Future<void> markMessagesAsRead(String conversationId, String latestMessageId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || latestMessageId.isEmpty) return;

    try {
      // Local update
      final serverMsgs = _serverMessagesCache[conversationId];
      if (serverMsgs != null) {
        bool changed = false;
        for (int i = 0; i < serverMsgs.length; i++) {
          if (serverMsgs[i].senderId != uid && serverMsgs[i].status != MessageStatus.read) {
            serverMsgs[i] = serverMsgs[i].copyWith(status: MessageStatus.read);
            changed = true;
          }
        }
        if (changed) {
          _emitCombinedMessages(conversationId);
        }
      }

      await _supabase
          .from('conversation_members')
          .update({'last_read_message_id': latestMessageId})
          .match({'conversation_id': conversationId, 'user_id': uid});

      await _supabase
          .from('messages')
          .update({'status': 'read'})
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Mark entire conversation as read by current user (resets unread badge instantly)
  Future<void> markConversationAsRead(String conversationId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // 1. Immediately reset local unread badge
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1 && _conversations[idx].unreadCount > 0) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }

    // 2. Mark in-memory message cache as read
    final serverMsgs = _serverMessagesCache[conversationId];
    String? latestMsgId;
    if (serverMsgs != null && serverMsgs.isNotEmpty) {
      bool changed = false;
      for (int i = 0; i < serverMsgs.length; i++) {
        if (serverMsgs[i].senderId != uid && serverMsgs[i].status != MessageStatus.read) {
          serverMsgs[i] = serverMsgs[i].copyWith(status: MessageStatus.read);
          changed = true;
        }
      }
      latestMsgId = serverMsgs.last.id;
      if (changed) {
        _emitCombinedMessages(conversationId);
      }
    }

    // 3. Persist read status in background
    try {
      if (latestMsgId != null && !latestMsgId.startsWith('temp_')) {
        await _supabase
            .from('conversation_members')
            .update({'last_read_message_id': latestMsgId})
            .match({'conversation_id': conversationId, 'user_id': uid});
      }

      await _supabase
          .from('messages')
          .update({'status': 'read'})
          .eq('conversation_id', conversationId)
          .neq('sender_id', uid);
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  // ==========================================
  // INSTANT OPTIMISTIC MESSAGE SENDING
  // ==========================================

  Future<void> sendMessageOptimistic({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final tempId = 'temp_${_uuid.v4()}';
    final now = DateTime.now();

    final optimisticMsg = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: uid,
      messageType: 'text',
      content: content.trim(),
      replyToId: replyToId,
      isEdited: false,
      isDeleted: false,
      deletedFor: [],
      createdAt: now,
      attachments: [],
      reactions: [],
      status: MessageStatus.sending,
    );

    // 1. Immediately append to _optimisticMessages & emit (0ms UI latency)
    _optimisticMessages.putIfAbsent(conversationId, () => []).add(optimisticMsg);
    _emitCombinedMessages(conversationId);

    // 2. Play sent sound chime immediately
    SoundService.instance.playSentSound();

    // 3. Update conversation in-memory (move to top, set lastMessage)
    _updateConversationLocally(
      conversationId: conversationId,
      lastMsg: optimisticMsg,
      updatedAt: now,
    );

    // 4. Background insert to Supabase with reconciliation
    _executeInsertMessage(conversationId, tempId, optimisticMsg);
  }

  Future<void> _executeInsertMessage(
    String conversationId,
    String tempId,
    ChatMessage optimisticMsg,
  ) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final realId = _uuid.v4();
      final insertData = <String, dynamic>{
        'id': realId,
        'conversation_id': conversationId,
        'sender_id': uid,
        'message_type': 'text',
        'content': optimisticMsg.content,
      };
      if (optimisticMsg.replyToId != null && optimisticMsg.replyToId!.isNotEmpty) {
        insertData['reply_to_id'] = optimisticMsg.replyToId;
      }

      await _supabase.from('messages').insert(insertData);

      // Successfully inserted: update optimistic message in memory
      final optList = _optimisticMessages[conversationId];
      if (optList != null) {
        final idx = optList.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          optList[idx] = optimisticMsg.copyWith(
            id: realId,
            status: MessageStatus.sent,
          );
          _emitCombinedMessages(conversationId);
        }
      }

      // Update conversations.updated_at in background
      try {
        await _supabase
            .from('conversations')
            .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', conversationId);
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to insert message to Supabase: $e');
      final optList = _optimisticMessages[conversationId];
      if (optList != null) {
        final idx = optList.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          optList[idx] = optList[idx].copyWith(status: MessageStatus.failed);
          _emitCombinedMessages(conversationId);
        }
      }
    }
  }

  // Retry sending a failed message safely
  Future<void> retryMessage(ChatMessage message) async {
    final conversationId = message.conversationId;
    final optList = _optimisticMessages[conversationId];
    if (optList == null) return;

    final idx = optList.indexWhere((m) => m.id == message.id);
    if (idx == -1) return;

    final retryingMsg = message.copyWith(status: MessageStatus.sending);
    optList[idx] = retryingMsg;
    _emitCombinedMessages(conversationId);

    _executeInsertMessage(conversationId, message.id, retryingMsg);
  }

  // Wrapper for existing callers
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    await sendMessageOptimistic(
      conversationId: conversationId,
      content: content,
      replyToId: replyToId,
    );
  }

  // Upload attachment & send media message
  Future<void> sendAttachmentMessage({
    required String conversationId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String? caption,
    int? duration,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final msgId = _uuid.v4();
    final ext = fileName.contains('.') ? fileName.split('.').last : '';

    String messageType = 'file';
    if (mimeType.startsWith('image/')) {
      messageType = 'image';
    } else if (mimeType.startsWith('video/')) {
      messageType = 'video';
    } else if (mimeType.startsWith('audio/')) {
      messageType = 'audio';
    }

    final category = (messageType == 'audio' && fileName.toLowerCase().contains('voice'))
        ? MediaCategory.voice
        : MediaCategory.message;

    // Upload via ImageKit MediaStorageService
    final uploadResult = await _mediaStorage.uploadBytes(
      bytes: fileBytes,
      fileExtension: ext,
      mimeType: mimeType,
      category: category,
      conversationId: conversationId,
      messageId: msgId,
    );

    // Insert message
    await _supabase.from('messages').insert({
      'id': msgId,
      'conversation_id': conversationId,
      'sender_id': uid,
      'message_type': messageType,
      'content': caption?.trim().isNotEmpty == true ? caption : uploadResult.publicUrl,
    });

    // Insert attachment record
    await _supabase.from('message_attachments').insert({
      'message_id': msgId,
      'storage_path': uploadResult.publicUrl,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileBytes.length,
      'duration': duration,
    });

    await _supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    SoundService.instance.playSentSound();
  }

  // Add / toggle reaction
  Future<void> toggleReaction(String messageId, String reaction) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final existing = await _supabase
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .eq('reaction', reaction)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('message_reactions').delete().eq('id', existing['id']);
      } else {
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': uid,
          'reaction': reaction,
        });
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  // Edit message
  Future<void> editMessage(String messageId, String newContent) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    await _supabase.from('messages').update({
      'content': newContent.trim(),
      'is_edited': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId).eq('sender_id', uid);
  }

  // Delete message
  Future<void> deleteMessage(String messageId, {bool deleteForEveryone = false}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    if (deleteForEveryone) {
      await _supabase.from('messages').update({
        'content': 'This message was deleted',
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId).eq('sender_id', uid);
    } else {
      final current = await _supabase.from('messages').select('deleted_for').eq('id', messageId).single();
      final currentList = (current['deleted_for'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (!currentList.contains(uid)) {
        currentList.add(uid);
        await _supabase.from('messages').update({'deleted_for': currentList}).eq('id', messageId);
      }
    }
  }

  // Pin/unpin conversation
  Future<void> togglePin(String conversationId, bool isPinned) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    await _supabase.from('conversation_members').update({
      'is_pinned': !isPinned,
    }).eq('conversation_id', conversationId).eq('user_id', uid);

    await loadConversations();
  }
}
