import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme_data.dart';
export 'app_theme_data.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefThemeKey = 'zchat_user_theme';
  static const String _prefChatThemesKey = 'zchat_chat_themes';

  AppThemeData _currentTheme = AppThemeData.midnight;
  final Map<String, AppThemeData> _chatThemes = {};
  bool _isLoaded = false;

  AppThemeData get theme => _currentTheme;
  AppThemeData get currentTheme => _currentTheme;
  bool get isLoaded => _isLoaded;

  ThemeProvider() {
    _loadFromLocal();
  }

  // Get effective theme for a specific chat (falls back to global theme)
  AppThemeData getThemeForChat(String? conversationId) {
    if (conversationId != null && _chatThemes.containsKey(conversationId)) {
      return _chatThemes[conversationId]!;
    }
    return _currentTheme;
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeJson = prefs.getString(_prefThemeKey);
      if (savedThemeJson != null) {
        final decoded = jsonDecode(savedThemeJson) as Map<String, dynamic>;
        _currentTheme = AppThemeData.fromJson(decoded);
      }

      final savedChatThemesJson = prefs.getString(_prefChatThemesKey);
      if (savedChatThemesJson != null) {
        final decoded = jsonDecode(savedChatThemesJson) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _chatThemes[key] = AppThemeData.fromJson(value);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading theme from prefs: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, jsonEncode(_currentTheme.toJson()));

      final chatMap = _chatThemes.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_prefChatThemesKey, jsonEncode(chatMap));
    } catch (e) {
      debugPrint('Error saving theme locally: $e');
    }
  }

  // Sync settings to Supabase
  Future<void> syncToSupabase() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('user_settings').upsert({
        'user_id': user.id,
        'theme_id': _currentTheme.id,
        'custom_theme': _currentTheme.toJson(),
        'font_family': _currentTheme.fontFamily.name,
        'font_size': _currentTheme.fontSize.name,
        'bubble_style': _currentTheme.bubbleStyle.name,
        'bubble_radius': _currentTheme.bubbleRadius,
        'bubble_sent_color': '#${_currentTheme.bubbleSent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'bubble_received_color': '#${_currentTheme.bubbleReceived.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'chat_background_type': _currentTheme.backgroundType.name,
        'chat_background_value': _currentTheme.backgroundValue,
        'chat_density': _currentTheme.density.name,
        'show_avatars': _currentTheme.showAvatars,
        'show_timestamps': _currentTheme.showTimestamps,
        'notification_style': _currentTheme.notificationStyle.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error syncing theme to Supabase: $e');
    }
  }

  // Load from Supabase on Login
  Future<void> loadFromSupabase() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await client
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && response['custom_theme'] != null) {
        final customThemeData = response['custom_theme'];
        if (customThemeData is Map<String, dynamic> && customThemeData.isNotEmpty) {
          _currentTheme = AppThemeData.fromJson(customThemeData);
          await _saveToLocal();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading user settings from Supabase: $e');
    }
  }

  void setPreset(String presetId) {
    final preset = AppThemeData.getPresetById(presetId);
    _currentTheme = preset;
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateTheme(AppThemeData newTheme) {
    _currentTheme = newTheme;
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateChatAccent(Color color) {
    _currentTheme = _currentTheme.copyWith(
      primary: color,
      bubbleSent: color,
      voiceAccentColor: color,
      typingIndicatorColor: color,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateBubbleStyle(BubbleStyle style) {
    _currentTheme = _currentTheme.copyWith(bubbleStyle: style);
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateBubbleRadius(double radius) {
    _currentTheme = _currentTheme.copyWith(bubbleRadius: radius);
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateGlassSettings({
    double? intensity,
    double? blur,
    double? transparency,
    double? borderOpacity,
    double? shadowIntensity,
    double? surfaceBrightness,
  }) {
    _currentTheme = _currentTheme.copyWith(
      glassIntensity: intensity,
      glassBlur: blur,
      glassTransparency: transparency,
      glassBorderOpacity: borderOpacity,
      glassShadowIntensity: shadowIntensity,
      surfaceBrightness: surfaceBrightness,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateBubbleColors({
    Color? sentColor,
    Color? receivedColor,
    Color? sentTextColor,
    Color? receivedTextColor,
  }) {
    _currentTheme = _currentTheme.copyWith(
      id: 'custom',
      bubbleSent: sentColor,
      bubbleReceived: receivedColor,
      bubbleSentText: sentTextColor,
      bubbleReceivedText: receivedTextColor,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateColors({
    Color? primary,
    Color? background,
    Color? surface,
    Color? text,
    Color? mutedText,
  }) {
    _currentTheme = _currentTheme.copyWith(
      id: 'custom',
      primary: primary,
      background: background,
      surface: surface,
      text: text,
      mutedText: mutedText,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateBackground(ChatBackgroundType type, String value, {double? opacity, double? blur}) {
    _currentTheme = _currentTheme.copyWith(
      backgroundType: type,
      backgroundValue: value,
      wallpaperOpacity: opacity,
      wallpaperBlur: blur,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateTypography({
    FontFamilyOption? fontFamily,
    FontSizeOption? fontSize,
  }) {
    _currentTheme = _currentTheme.copyWith(
      fontFamily: fontFamily,
      fontSize: fontSize,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateDensity(ChatDensity density, {double? bubblePadding, double? messageSpacing}) {
    _currentTheme = _currentTheme.copyWith(
      density: density,
      bubblePadding: bubblePadding,
      messageSpacing: messageSpacing,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateAnimations({
    MessageAnimationStyle? incoming,
    MessageAnimationStyle? outgoing,
    AnimationSpeed? speed,
    AnimationIntensity? intensity,
  }) {
    _currentTheme = _currentTheme.copyWith(
      incomingAnimationStyle: incoming,
      outgoingAnimationStyle: outgoing,
      animationSpeed: speed,
      animationIntensity: intensity,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateAvatarTokens({
    AvatarShape? shape,
    double? size,
    bool? showBorder,
    double? borderWidth,
    Color? borderColor,
    bool? showShadow,
    bool? showAvatars,
  }) {
    _currentTheme = _currentTheme.copyWith(
      avatarShape: shape,
      avatarSize: size,
      showAvatarBorder: showBorder,
      avatarBorderWidth: borderWidth,
      avatarBorderColor: borderColor,
      showAvatarShadow: showShadow,
      showAvatars: showAvatars,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateToggles({bool? showAvatars, bool? showTimestamps}) {
    _currentTheme = _currentTheme.copyWith(
      showAvatars: showAvatars,
      showTimestamps: showTimestamps,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateOnlineIndicator({
    OnlineIndicatorStyle? style,
    Color? color,
    double? size,
  }) {
    _currentTheme = _currentTheme.copyWith(
      onlineIndicatorStyle: style,
      onlineIndicatorColor: color,
      onlineIndicatorSize: size,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateTimestamps({
    TimestampFormat? format,
    TimestampVisibility? visibility,
    TimestampPosition? position,
    double? opacity,
    double? size,
    bool? showTimestamps,
  }) {
    _currentTheme = _currentTheme.copyWith(
      timestampFormat: format,
      timestampVisibility: visibility,
      timestampPosition: position,
      timestampOpacity: opacity,
      timestampSize: size,
      showTimestamps: showTimestamps,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateTypingIndicator({
    TypingIndicatorStyle? style,
    TypingAnimation? animation,
    Color? color,
  }) {
    _currentTheme = _currentTheme.copyWith(
      typingIndicatorStyle: style,
      typingAnimation: animation,
      typingIndicatorColor: color,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateReadReceipts({
    ReadReceiptStyle? style,
    Color? sentColor,
    Color? deliveredColor,
    Color? readColor,
  }) {
    _currentTheme = _currentTheme.copyWith(
      readReceiptStyle: style,
      readReceiptSentColor: sentColor,
      readReceiptDeliveredColor: deliveredColor,
      readReceiptReadColor: readColor,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateVoiceMessage({
    VoiceWaveformStyle? waveformStyle,
    double? thickness,
    Color? accentColor,
    double? playbackSpeed,
  }) {
    _currentTheme = _currentTheme.copyWith(
      voiceWaveformStyle: waveformStyle,
      voiceWaveformThickness: thickness,
      voiceAccentColor: accentColor,
      voicePlaybackSpeed: playbackSpeed,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateMessageEffects({
    bool? enabled,
    MessageEffectType? type,
  }) {
    _currentTheme = _currentTheme.copyWith(
      messageEffectsEnabled: enabled,
      messageEffectType: type,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateSounds({
    SoundPreset? preset,
    String? incoming,
    String? outgoing,
    bool? enabled,
  }) {
    _currentTheme = _currentTheme.copyWith(
      soundPreset: preset,
      incomingSound: incoming,
      outgoingSound: outgoing,
      soundsEnabled: enabled,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateNavigation({
    NavigationStyle? style,
    IconStyleOption? iconStyle,
    bool? showLabels,
  }) {
    _currentTheme = _currentTheme.copyWith(
      navigationStyle: style,
      iconStyle: iconStyle,
      showNavLabels: showLabels,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateLayoutStyles({
    SearchBarStyle? searchBar,
    HomeScreenLayout? homeLayout,
    NotificationStyle? notification,
    AppLockStyle? appLock,
  }) {
    _currentTheme = _currentTheme.copyWith(
      searchBarStyle: searchBar,
      homeLayout: homeLayout,
      notificationStyle: notification,
      appLockStyle: appLock,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void updateMessageAnimations({
    MessageAnimationStyle? incoming,
    MessageAnimationStyle? outgoing,
    AnimationSpeed? speed,
    AnimationIntensity? intensity,
  }) => updateAnimations(incoming: incoming, outgoing: outgoing, speed: speed, intensity: intensity);

  void updateAvatarSettings({
    AvatarShape? shape,
    double? size,
    bool? showBorder,
    double? borderWidth,
    Color? borderColor,
    bool? showShadow,
    bool? showAvatars,
  }) => updateAvatarTokens(
        shape: shape,
        size: size,
        showBorder: showBorder,
        borderWidth: borderWidth,
        borderColor: borderColor,
        showShadow: showShadow,
        showAvatars: showAvatars,
      );

  void updateTimestampSettings({
    TimestampFormat? format,
    TimestampVisibility? visibility,
    TimestampPosition? position,
    double? opacity,
    double? size,
    bool? showTimestamps,
  }) => updateTimestamps(
        format: format,
        visibility: visibility,
        position: position,
        opacity: opacity,
        size: size,
        showTimestamps: showTimestamps,
      );

  void updateNavigationStyle(NavigationStyle style) => updateNavigation(style: style);

  void updateIconStyle(IconStyleOption style) => updateNavigation(iconStyle: style);

  void updateVoiceWaveform({
    VoiceWaveformStyle? style,
    double? thickness,
    Color? accentColor,
    double? playbackSpeed,
  }) => updateVoiceMessage(
        waveformStyle: style,
        thickness: thickness,
        accentColor: accentColor,
        playbackSpeed: playbackSpeed,
      );

  void updateAppLockStyle(AppLockStyle style) => updateLayoutStyles(appLock: style);

  void saveCurrentThemeAs(String name) {
    _currentTheme = _currentTheme.copyWith(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void duplicateTheme() {
    _currentTheme = _currentTheme.copyWith(
      id: 'copy_${DateTime.now().millisecondsSinceEpoch}',
      name: '${_currentTheme.name} (Copy)',
    );
    _saveToLocal();
    syncToSupabase();
    notifyListeners();
  }

  void setPerChatTheme(String conversationId, AppThemeData? chatTheme) {
    if (chatTheme == null) {
      _chatThemes.remove(conversationId);
    } else {
      _chatThemes[conversationId] = chatTheme;
    }
    _saveToLocal();
    notifyListeners();
  }

  String exportThemeJson() {
    return const JsonEncoder.withIndent('  ').convert(_currentTheme.toJson());
  }

  bool importThemeJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _currentTheme = AppThemeData.fromJson(decoded);
      _saveToLocal();
      syncToSupabase();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to parse imported theme JSON: $e');
      return false;
    }
  }
}
