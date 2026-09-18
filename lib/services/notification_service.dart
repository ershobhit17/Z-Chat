import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'in_app_notification_manager.dart';
import 'sound_service.dart';

/// Notification Service for Z Chat.
/// Manages FCM push token registration, notification preferences,
/// in-app notification routing, and background notification hooks.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Preference keys
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyMasterNotificationsEnabled = 'master_notifications_enabled';
  static const String _keyMessageRequestsEnabled = 'notifications_message_requests_enabled';
  static const String _keySoundEnabled = 'notification_sound_enabled';
  static const String _keyPopupEnabled = 'notification_popup_enabled';
  static const String _keyVibrationEnabled = 'notification_vibration_enabled';
  static const String _keyMentionsEnabled = 'notification_mentions_enabled';
  static const String _keyLikesEnabled = 'notifications_likes_enabled';
  static const String _keyCommentsEnabled = 'notifications_comments_enabled';
  static const String _keyFollowersEnabled = 'notifications_followers_enabled';
  static const String _keySystemEnabled = 'notifications_system_enabled';
  static const String _keyCachedFcmToken = 'cached_fcm_token';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes notification preferences and hooks up token syncing.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final masterEnabled = prefs.getBool(_keyMasterNotificationsEnabled) ?? true;
      final notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
      final popupEnabled = prefs.getBool(_keyPopupEnabled) ?? true;

      InAppNotificationManager.instance.isNotificationsEnabled = masterEnabled && notificationsEnabled;
      InAppNotificationManager.instance.isPopupEnabled = popupEnabled;

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  /// Registers or syncs an FCM device token with Supabase profiles table.
  Future<bool> registerDeviceToken(String token) async {
    if (token.isEmpty) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        // Cache token locally so it can be synced on login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyCachedFcmToken, token);
        return false;
      }

      // 1. Check if token already cached to avoid redundant DB writes
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_keyCachedFcmToken);
      if (cachedToken == token) {
        return true;
      }

      // 2. Persist to profiles table via RPC or direct update
      try {
        await _supabase.rpc('update_fcm_token', params: {'new_token': token});
      } catch (_) {
        // Fallback to direct update if RPC is missing
        await _supabase.from('profiles').update({
          'fcm_token': token,
          'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      }

      await prefs.setString(_keyCachedFcmToken, token);
      debugPrint('FCM device token registered for user: $userId');
      return true;
    } catch (e) {
      debugPrint('Failed to register FCM device token: $e');
      return false;
    }
  }

  /// Syncs cached FCM token if one exists when user authenticates.
  Future<void> syncCachedTokenOnLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString(_keyCachedFcmToken);
      if (cachedToken != null && cachedToken.isNotEmpty) {
        await registerDeviceToken(cachedToken);
      }
    } catch (e) {
      debugPrint('Error syncing cached token on login: $e');
    }
  }

  /// Unregisters FCM token on logout.
  Future<void> unregisterDeviceToken() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('profiles').update({
          'fcm_token': null,
          'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedFcmToken);
      debugPrint('FCM device token cleared on logout');
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }
  }

  /// Sends a push notification via Edge Function for a newly created message.
  Future<void> dispatchPushNotification({
    required String conversationId,
    required String senderId,
    String? messageId,
    String? content,
    String? messageType,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_id': messageId,
          'content': content,
          'message_type': messageType ?? 'text',
        },
      );
    } catch (e) {
      // Fire-and-forget: Push failure must NEVER break message sending
      debugPrint('Dispatch push notification failed ($e) — ignored');
    }
  }

  // --- Notification Preferences ---

  Future<bool> getMasterNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMasterNotificationsEnabled) ?? true;
  }

  Future<void> setMasterNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMasterNotificationsEnabled, enabled);
    final msgEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    InAppNotificationManager.instance.isNotificationsEnabled = enabled && msgEnabled;
  }

  Future<bool> getMessageNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final master = prefs.getBool(_keyMasterNotificationsEnabled) ?? true;
    return master && (prefs.getBool(_keyNotificationsEnabled) ?? true);
  }

  Future<void> setMessageNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
    final master = prefs.getBool(_keyMasterNotificationsEnabled) ?? true;
    InAppNotificationManager.instance.isNotificationsEnabled = master && enabled;
  }

  Future<bool> getMessageRequestsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMessageRequestsEnabled) ?? true;
  }

  Future<void> setMessageRequestsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMessageRequestsEnabled, enabled);
  }

  Future<bool> getLikesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLikesEnabled) ?? true;
  }

  Future<void> setLikesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLikesEnabled, enabled);
  }

  Future<bool> getCommentsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCommentsEnabled) ?? true;
  }

  Future<void> setCommentsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCommentsEnabled, enabled);
  }

  Future<bool> getFollowersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFollowersEnabled) ?? true;
  }

  Future<void> setFollowersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFollowersEnabled, enabled);
  }

  Future<bool> getSystemNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySystemEnabled) ?? true;
  }

  Future<void> setSystemNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySystemEnabled, enabled);
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySoundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  Future<bool> getPopupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPopupEnabled) ?? true;
  }

  Future<void> setPopupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPopupEnabled, enabled);
    InAppNotificationManager.instance.isPopupEnabled = enabled;
  }

  Future<bool> getVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibrationEnabled) ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrationEnabled, enabled);
  }

  Future<bool> getMentionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMentionsEnabled) ?? true;
  }

  Future<void> setMentionsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMentionsEnabled, enabled);
  }

  /// Mutes or unmutes a specific conversation
  Future<void> toggleConversationMute(String conversationId) async {
    if (SoundService.instance.isMuted(conversationId)) {
      SoundService.instance.unmute(conversationId);
    } else {
      SoundService.instance.setMuted(conversationId);
    }
  }

  bool isConversationMuted(String conversationId) {
    return SoundService.instance.isMuted(conversationId);
  }
}
