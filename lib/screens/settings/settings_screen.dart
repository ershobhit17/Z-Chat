import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../services/in_app_notification_manager.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../appearance_studio_screen.dart';
import '../profile/user_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _onlineStatus = true;
  bool _lastSeen = true;
  bool _readReceipts = true;
  bool _typingIndicator = true;

  // Master & Granular Notification Controls
  bool _masterNotifications = true;
  bool _messageNotifications = true;
  bool _messageRequests = true;
  bool _mentionNotifications = true;
  bool _likesNotifications = true;
  bool _commentsNotifications = true;
  bool _followersNotifications = true;
  bool _systemNotifications = true;
  bool _popupNotification = true;
  bool _vibration = true;

  // SFX & Sound Controls
  bool _sfxSounds = true;
  bool _sentSound = true;
  bool _receivedSound = true;

  @override
  void initState() {
    super.initState();
    _sfxSounds = SoundService.instance.isSoundEnabled;
    _sentSound = SoundService.instance.isSentSoundEnabled;
    _receivedSound = SoundService.instance.isReceivedSoundEnabled;
    _popupNotification = InAppNotificationManager.instance.isPopupEnabled;
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final notif = NotificationService.instance;
    final master = await notif.getMasterNotificationsEnabled();
    final msg = await notif.getMessageNotificationsEnabled();
    final req = await notif.getMessageRequestsEnabled();
    final men = await notif.getMentionsEnabled();
    final likes = await notif.getLikesEnabled();
    final comm = await notif.getCommentsEnabled();
    final foll = await notif.getFollowersEnabled();
    final sys = await notif.getSystemNotificationsEnabled();
    if (mounted) {
      setState(() {
        _masterNotifications = master;
        _messageNotifications = msg;
        _messageRequests = req;
        _mentionNotifications = men;
        _likesNotifications = likes;
        _commentsNotifications = comm;
        _followersNotifications = foll;
        _systemNotifications = sys;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    final auth = context.watch<AuthService>();
    final profile = auth.currentProfile;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text(
          'Settings',
          style: theme.getTextStyle(
            baseSize: 18.0,
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            children: [
              // Profile Card
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: auth.currentUser?.id,
                        userProfile: profile,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        displayName: profile?.displayName ?? 'User',
                        avatarUrl: profile?.avatarUrl,
                        size: 54,
                        isOnline: true,
                        showOnlineIndicator: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Your Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${profile?.username ?? 'username'}',
                              style: TextStyle(fontSize: 13, color: theme.primary, fontWeight: FontWeight.w500),
                            ),
                            if (profile?.bio != null && profile!.bio.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                profile.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: theme.mutedText),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: theme.mutedText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // APPEARANCE STUDIO (Highlight Card)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppearanceStudioScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primary.withValues(alpha: 0.2),
                        theme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.palette_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Appearance Studio',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.text,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'USP',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Themes, fonts, bubbles, wallpapers, density',
                              style: TextStyle(fontSize: 12, color: theme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: theme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // NOTIFICATIONS SECTION (Requirement 11 & 12)
              Text(
                'NOTIFICATIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Notifications (Global)', style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Master toggle to allow or silence all app notifications', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _masterNotifications,
                      activeThumbColor: theme.primary,
                      onChanged: (val) {
                        setState(() => _masterNotifications = val);
                        NotificationService.instance.setMasterNotificationsEnabled(val);
                      },
                    ),
                    if (_masterNotifications) ...[
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Message Notifications', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Receive alerts for new incoming messages', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _messageNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _messageNotifications = val);
                          NotificationService.instance.setMessageNotificationsEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Message Requests', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Alerts when non-contacts request to message', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _messageRequests,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _messageRequests = val);
                          NotificationService.instance.setMessageRequestsEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Mentions', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Notify when @mentioned in chats or comments', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _mentionNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _mentionNotifications = val);
                          NotificationService.instance.setMentionsEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Likes & Reactions', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Notify when someone likes your posts or reacts', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _likesNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _likesNotifications = val);
                          NotificationService.instance.setLikesEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Comments', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Notify on comments to your posts and reels', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _commentsNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _commentsNotifications = val);
                          NotificationService.instance.setCommentsEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Followers', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Notify when someone starts following you', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _followersNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _followersNotifications = val);
                          NotificationService.instance.setFollowersEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('System Notifications', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Security updates, announcements and service alerts', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _systemNotifications,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _systemNotifications = val);
                          NotificationService.instance.setSystemNotificationsEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Popup Notification Preview', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Show animated toast preview when outside chat', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _popupNotification,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _popupNotification = val);
                          NotificationService.instance.setPopupEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Vibration', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Vibrate on incoming alerts', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _vibration,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _vibration = val);
                          NotificationService.instance.setVibrationEnabled(val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SFX & SOUNDS SECTION
              Text(
                'SFX & SOUNDS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('SFX & Sounds (Global)', style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('Master toggle to enable or mute all in-app sounds', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _sfxSounds,
                      activeThumbColor: theme.primary,
                      onChanged: (val) {
                        setState(() => _sfxSounds = val);
                        SoundService.instance.setSoundEnabled(val);
                      },
                    ),
                    if (_sfxSounds) ...[
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Message Sent Sound', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Play subtle pop when you send a message', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _sentSound,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _sentSound = val);
                          SoundService.instance.setSentSoundEnabled(val);
                        },
                      ),
                      Divider(height: 1, color: theme.border),
                      SwitchListTile(
                        title: Text('Message Received Sound', style: TextStyle(color: theme.text, fontSize: 14)),
                        subtitle: Text('Play crystal chime when incoming message arrives', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                        value: _receivedSound,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          setState(() => _receivedSound = val);
                          SoundService.instance.setReceivedSoundEnabled(val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // PRIVACY SECTION
              Text(
                'PRIVACY & PRESENCE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text('Online Status', style: TextStyle(color: theme.text, fontSize: 14)),
                      subtitle: Text('Show when you are active', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _onlineStatus,
                      activeThumbColor: theme.primary,
                      onChanged: (val) => setState(() => _onlineStatus = val),
                    ),
                    Divider(height: 1, color: theme.border),
                    SwitchListTile(
                      title: Text('Last Seen', style: TextStyle(color: theme.text, fontSize: 14)),
                      subtitle: Text('Allow others to see your last seen time', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _lastSeen,
                      activeThumbColor: theme.primary,
                      onChanged: (val) => setState(() => _lastSeen = val),
                    ),
                    Divider(height: 1, color: theme.border),
                    SwitchListTile(
                      title: Text('Read Receipts', style: TextStyle(color: theme.text, fontSize: 14)),
                      subtitle: Text('Show double checkmarks when messages are read', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _readReceipts,
                      activeThumbColor: theme.primary,
                      onChanged: (val) => setState(() => _readReceipts = val),
                    ),
                    Divider(height: 1, color: theme.border),
                    SwitchListTile(
                      title: Text('Typing Indicator', style: TextStyle(color: theme.text, fontSize: 14)),
                      subtitle: Text('Broadcast when you are typing or recording audio', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                      value: _typingIndicator,
                      activeThumbColor: theme.primary,
                      onChanged: (val) => setState(() => _typingIndicator = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ABOUT & APP INFO
              Text(
                'ABOUT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppConstants.appTagline} • Version 1.0.0',
                      style: TextStyle(color: theme.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // LOG OUT BUTTON
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.surface,
                      title: Text('Log out of Z Chat?', style: TextStyle(color: theme.text)),
                      content: Text('You can log back in anytime with your username and password.', style: TextStyle(color: theme.mutedText)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            auth.signOut();
                          },
                          child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
