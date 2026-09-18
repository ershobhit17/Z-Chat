import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/sound_service.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_background_container.dart';
import '../widgets/chat_bubble_widget.dart';

class AppearanceStudioScreen extends StatefulWidget {
  final String? perChatConversationId;

  const AppearanceStudioScreen({
    super.key,
    this.perChatConversationId,
  });

  @override
  State<AppearanceStudioScreen> createState() => _AppearanceStudioScreenState();
}

class _AppearanceStudioScreenState extends State<AppearanceStudioScreen> {
  // Progressive disclosure tab: 0 = Simple, 1 = Advanced, 2 = Studio
  int _selectedTabIndex = 0;

  // Curated chat accent colors
  final List<Color> _accentColors = const [
    Color(0xFF7C5CFF), // Purple (Electric Iris)
    Color(0xFF0A84FF), // Blue (Signature Apple)
    Color(0xFF10B981), // Green (Emerald)
    Color(0xFFEA580C), // Orange (Sunset)
    Color(0xFFEC4899), // Pink (Hot Pink)
    Color(0xFF06B6D4), // Cyan (Electric Cyan)
    Color(0xFFEF4444), // Red (Crimson)
    Color(0xFFF3F4F6), // White / Light Silver
  ];

  // Curated received bubble color helpers
  final List<Color> _receivedBubbleColors = const [
    Color(0xFF202334), // Glass / Slate Dark
    Color(0xFF1E1E28), // Midnight Slate
    Color(0xFF132A22), // Deep Emerald
    Color(0xFF2D1628), // Plum Velvet
    Color(0xFF111827), // Deep Navy
    Color(0xFF282834), // Soft Graphite
    Color(0xFFE5E7EB), // Soft Silver
  ];

  // Atmosphere / Wallpaper presets
  final List<Map<String, String>> _atmospherePresets = const [
    {'id': 'ios_mesh', 'name': '🍎 iOS Liquid Mesh', 'desc': 'Apple ambient glow'},
    {'id': 'aurora_mesh', 'name': '🌌 Aurora Glow', 'desc': 'Emerald atmospheric'},
    {'id': 'nebula_mesh', 'name': '✨ Cosmic Nebula', 'desc': 'Violet & magenta'},
    {'id': 'clean_void', 'name': '🖤 Clean Void', 'desc': 'Minimal deep dark'},
    {'id': 'oled_black', 'name': '⬛ OLED Pure', 'desc': 'True black 0% power'},
  ];

  void _showImportExportModal(BuildContext context, ThemeProvider provider) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: provider.theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: provider.theme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AppIcon(Icons.share_rounded, color: provider.theme.primary, size: 20, theme: provider.theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme Studio — Import / Export',
                          style: provider.theme.getTextStyle(
                            baseSize: 17.0,
                            fontWeight: FontWeight.bold,
                            color: provider.theme.text,
                          ),
                        ),
                        Text(
                          'Share your custom style or load a friend\'s theme',
                          style: TextStyle(color: provider.theme.mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: provider.theme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: provider.theme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(Icons.lightbulb_outline_rounded, color: provider.theme.primary, size: 18, theme: provider.theme),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Theme Export/Import se aap apna custom styling code dosto ke sath share kar sakte hain! JSON code copy karke share karein ya kisi aur ka code yahan paste karein.',
                        style: TextStyle(color: provider.theme.text, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.theme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Export & Copy Theme JSON', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        final jsonStr = provider.exportThemeJson();
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Theme JSON copied to clipboard!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                style: TextStyle(color: provider.theme.text, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Paste a theme JSON code here...',
                  hintStyle: TextStyle(color: provider.theme.mutedText),
                  filled: true,
                  fillColor: provider.theme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: provider.theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: provider.theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: provider.theme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: provider.theme.primary),
                    foregroundColor: provider.theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;
                    final success = provider.importThemeJson(text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Theme applied successfully! ✨' : 'Invalid theme JSON.'),
                      ),
                    );
                  },
                  child: const Text('Apply Imported Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomColorPicker(BuildContext context, ThemeProvider provider, bool isSent) {
    final hexController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.theme.surface,
        title: Text('Custom Hex Color', style: TextStyle(color: provider.theme.text, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hexController,
              autofocus: true,
              style: TextStyle(color: provider.theme.text),
              decoration: InputDecoration(
                hintText: '#7C5CFF or 7C5CFF',
                hintStyle: TextStyle(color: provider.theme.mutedText),
                filled: true,
                fillColor: provider.theme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: provider.theme.primary),
            onPressed: () {
              var hex = hexController.text.trim().replaceAll('#', '');
              if (hex.length == 6) {
                hex = 'FF$hex';
              }
              final val = int.tryParse(hex, radix: 16);
              if (val != null) {
                final col = Color(val);
                if (isSent) {
                  provider.updateChatAccent(col);
                } else {
                  provider.updateBubbleColors(
                    receivedColor: col,
                    receivedTextColor: col.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                  );
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final activeTheme = widget.perChatConversationId != null
        ? themeProvider.getThemeForChat(widget.perChatConversationId)
        : themeProvider.theme;

    return Scaffold(
      backgroundColor: activeTheme.background,
      appBar: AppBar(
        backgroundColor: activeTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: activeTheme.text, size: 18),
          onPressed: () {
            // Fix: sync system UI before pop to prevent black flash
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: activeTheme.isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: activeTheme.background,
              systemNavigationBarIconBrightness: activeTheme.isDark ? Brightness.light : Brightness.dark,
            ));
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.perChatConversationId != null ? 'Chat Appearance' : 'Appearance Studio',
          style: activeTheme.getTextStyle(
            baseSize: 17.0,
            fontWeight: FontWeight.w600,
            color: activeTheme.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share / Import Theme',
            icon: AppIcon(Icons.code_rounded, color: activeTheme.primary, theme: activeTheme),
            onPressed: () => _showImportExportModal(context, themeProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. LIVE PREVIEW PANEL
          _buildLivePreviewCard(activeTheme),

          // 2. PROGRESSIVE DISCLOSURE TABS: [ SIMPLE | ADVANCED | STUDIO ]
          _buildTabSelector(activeTheme),

          // 3. TAB CONTENT
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildSimpleTab(themeProvider, activeTheme),
                _buildAdvancedTab(themeProvider, activeTheme),
                _buildStudioTab(themeProvider, activeTheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(AppThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          _buildTabButton(0, '✨ Simple', theme),
          _buildTabButton(1, '⚙️ Advanced', theme),
          _buildTabButton(2, '🎨 Studio', theme),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, AppThemeData theme) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : theme.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================================
  // 1. LIVE PREVIEW CARD
  // ==============================================================================
  Widget _buildLivePreviewCard(AppThemeData theme) {
    final mockOtherUser = UserProfile(
      id: 'mock_alex',
      username: 'alex',
      usernameLower: 'alex',
      displayName: 'Alex',
      createdAt: DateTime.now(),
      isOnline: true,
    );

    final mockIncoming = ChatMessage(
      id: 'mock_1',
      conversationId: 'mock_c',
      senderId: 'mock_alex',
      messageType: 'text',
      content: 'Hey! Look at this, it updates instantly in real-time. 🔥',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      reactions: [
        MessageReaction(id: 'r1', messageId: 'mock_1', userId: 'me', reaction: '🔥'),
      ],
      senderProfile: mockOtherUser,
    );

    final mockOutgoing = ChatMessage(
      id: 'mock_2',
      conversationId: 'mock_c',
      senderId: 'me',
      messageType: 'text',
      content: 'Clean, minimal, and fully personalized. Love this vibe! ✨',
      createdAt: DateTime.now(),
      status: MessageStatus.read,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border, width: 1)),
      ),
      child: ChatBackgroundContainer(
        theme: theme,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LIVE PREVIEW',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.primary,
                      ),
                    ),
                  ),
                  Text(
                    theme.name,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Incoming message
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (theme.showAvatars)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0, right: 6.0),
                      child: AvatarWidget(
                        displayName: 'Alex',
                        size: theme.avatarSize,
                        isOnline: true,
                        theme: theme,
                      ),
                    ),
                  Expanded(
                    child: ChatBubbleWidget(
                      message: mockIncoming,
                      isMe: false,
                      theme: theme,
                    ),
                  ),
                ],
              ),

              // Outgoing message
              ChatBubbleWidget(
                message: mockOutgoing,
                isMe: true,
                theme: theme,
              ),

              // Typing Indicator Preview
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: _buildTypingIndicatorPreview(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicatorPreview(AppThemeData theme) {
    final text = switch (theme.typingIndicatorStyle) {
      TypingIndicatorStyle.fullText => 'Alex is typing...',
      TypingIndicatorStyle.compactDots => 'Alex •••',
      TypingIndicatorStyle.midlineDots => 'Alex ⋯',
      TypingIndicatorStyle.largeDots => '● ● ●',
      TypingIndicatorStyle.writing => 'Writing...',
      TypingIndicatorStyle.typing => 'Typing...',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: theme.typingIndicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: theme.mutedText,
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 1: SIMPLE
  // ==============================================================================
  Widget _buildSimpleTab(ThemeProvider provider, AppThemeData activeTheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      children: [
        // Quick Presets
        _buildSectionHeader(activeTheme, 'Theme Presets', '26 curated one-tap aesthetic styles'),
        const SizedBox(height: 10),
        _buildPresetsRow(provider, activeTheme),

        const SizedBox(height: 24),
        // Chat Accent System
        _buildSectionHeader(activeTheme, 'Chat Accent', 'Primary color token for messages, badges & highlights'),
        const SizedBox(height: 10),
        _buildChatAccentPicker(provider, activeTheme),

        const SizedBox(height: 24),
        // Chat Atmosphere & Wallpaper
        _buildSectionHeader(activeTheme, 'Chat Atmosphere', 'Ambient mesh glow behind frosted glass'),
        const SizedBox(height: 10),
        _buildAtmosphereSelector(provider, activeTheme),

        const SizedBox(height: 24),
        // Message Bubble Studio
        _buildSectionHeader(activeTheme, 'Message Bubble Studio', 'Liquid Glass, Pill, Rounded shapes'),
        const SizedBox(height: 12),
        _buildBubbleStyleSelector(provider, activeTheme),
        const SizedBox(height: 16),
        _buildBubbleRadiusSlider(provider, activeTheme),
        const SizedBox(height: 16),
        _buildSentBubbleColorPicker(provider, activeTheme),
        const SizedBox(height: 16),
        _buildReceivedBubbleColorPicker(provider, activeTheme),
        const SizedBox(height: 16),
        _buildBubbleShadowDepthSlider(provider, activeTheme),
        const SizedBox(height: 16),
        _buildFullLiquidGlassPreset(provider, activeTheme),

        const SizedBox(height: 24),
        // Liquid Glass Studio
        _buildSectionHeader(activeTheme, 'Liquid Glass Studio', 'Specular blur, depth, opacity and ambient borders'),
        const SizedBox(height: 12),
        _buildLiquidGlassStudio(provider, activeTheme),

        const SizedBox(height: 32),
      ],
    );
  }

  // ==============================================================================
  // TAB 2: ADVANCED
  // ==============================================================================
  Widget _buildAdvancedTab(ThemeProvider provider, AppThemeData activeTheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      children: [
        // Message Animation Studio
        _buildSectionHeader(activeTheme, 'Message Animation Studio', 'Control how messages appear and move'),
        const SizedBox(height: 12),
        _buildAnimationControls(provider, activeTheme),

        const SizedBox(height: 24),
        // Typography
        _buildSectionHeader(activeTheme, 'Typography', 'Font family and text sizing'),
        const SizedBox(height: 12),
        _buildFontFamilySelector(provider, activeTheme),
        const SizedBox(height: 12),
        _buildFontSizeSelector(provider, activeTheme),

        const SizedBox(height: 24),
        // Layout & Density
        _buildSectionHeader(activeTheme, 'Layout & Density', 'Control spacing and density presets'),
        const SizedBox(height: 12),
        _buildDensitySelector(provider, activeTheme),
        const SizedBox(height: 12),
        _buildToggles(provider, activeTheme),

        const SizedBox(height: 24),
        // Avatar Studio
        _buildSectionHeader(activeTheme, 'Avatar Studio', 'Shapes, sizes, borders and shadows'),
        const SizedBox(height: 12),
        _buildAvatarStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Online Indicator Studio
        _buildSectionHeader(activeTheme, 'Online Indicator Studio', 'Dot, Ring, Pulse, Glow'),
        const SizedBox(height: 12),
        _buildOnlineIndicatorStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Timestamp Studio
        _buildSectionHeader(activeTheme, 'Timestamp Studio', 'Formats, positions, and opacity'),
        const SizedBox(height: 12),
        _buildTimestampStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Typing Indicator Studio
        _buildSectionHeader(activeTheme, 'Typing Indicator Studio', 'Text styles and wave animations'),
        const SizedBox(height: 12),
        _buildTypingIndicatorStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Read Receipt Studio
        _buildSectionHeader(activeTheme, 'Read Receipt Studio', 'Checkmarks, dots, and receipt colors'),
        const SizedBox(height: 12),
        _buildReadReceiptStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Navigation & Icon Style
        _buildSectionHeader(activeTheme, 'Navigation & Icon System', 'Navigation bars and unified icon styling'),
        const SizedBox(height: 12),
        _buildNavigationAndIcons(provider, activeTheme),

        const SizedBox(height: 32),
      ],
    );
  }

  // ==============================================================================
  // TAB 3: STUDIO
  // ==============================================================================
  Widget _buildStudioTab(ThemeProvider provider, AppThemeData activeTheme) {
    final promptController = TextEditingController();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      children: [
        // Liquid Glass Studio
        _buildSectionHeader(activeTheme, 'Liquid Glass Studio', 'Fine-tune blur, transparency, depth, borders & brightness'),
        const SizedBox(height: 12),
        _buildLiquidGlassStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Sound Studio
        _buildSectionHeader(activeTheme, 'Sound Studio', 'Message chimes and notification audio presets'),
        const SizedBox(height: 12),
        _buildSoundStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Voice Message Appearance
        _buildSectionHeader(activeTheme, 'Voice Message Style', 'Waveforms, thickness, and accent colors'),
        const SizedBox(height: 12),
        _buildVoiceMessageStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Message Effects
        _buildSectionHeader(activeTheme, 'Message Effects', 'Celebration, hearts, fire, and sparkles'),
        const SizedBox(height: 12),
        _buildMessageEffectsStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // App Lock Preview
        _buildSectionHeader(activeTheme, 'App Lock & Security', 'Biometric, PIN, and password lock screen'),
        const SizedBox(height: 12),
        _buildAppLockStudio(provider, activeTheme),

        const SizedBox(height: 24),
        // Theme Studio (Actions)
        _buildSectionHeader(activeTheme, 'Theme Studio Actions', 'Save, duplicate, import & export themes'),
        const SizedBox(height: 12),
        _buildThemeActions(provider, activeTheme),

        const SizedBox(height: 24),
        // AI Theme Generator (Architecture Ready)
        _buildSectionHeader(activeTheme, 'AI Theme Generator', 'Prompt-driven aesthetic generator (Architecture Ready)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: activeTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activeTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(Icons.auto_awesome_rounded, color: activeTheme.primary, size: 20, theme: activeTheme),
                  const SizedBox(width: 8),
                  Text(
                    'AI Aesthetic Engine',
                    style: TextStyle(color: activeTheme.text, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Type a prompt describing the visual vibe you want. The AI engine parses colors, density, glass blur, and typography tokens.',
                style: TextStyle(color: activeTheme.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptController,
                style: TextStyle(color: activeTheme.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., "Create a dark luxury theme with orange accents"',
                  hintStyle: TextStyle(color: activeTheme.mutedText),
                  filled: true,
                  fillColor: activeTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: activeTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: activeTheme.border)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Generate Theme Structure', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    final p = promptController.text.trim().toLowerCase();
                    if (p.isEmpty) return;

                    // Architecture ready: smart token derivation
                    if (p.contains('orange') || p.contains('sunset')) {
                      provider.setPreset('sunset_velvet');
                    } else if (p.contains('ocean') || p.contains('blue')) {
                      provider.setPreset('ocean_breeze');
                    } else if (p.contains('oled') || p.contains('black')) {
                      provider.setPreset('oled_minimal');
                    } else if (p.contains('cream') || p.contains('light')) {
                      provider.setPreset('cream_studio');
                    } else if (p.contains('cyber') || p.contains('neon')) {
                      provider.setPreset('cyber_neon');
                    } else {
                      provider.setPreset('midnight_glass');
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Theme generated & applied to preview! ✨')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ==============================================================================
  // SECTION COMPONENTS
  // ==============================================================================
  Widget _buildSectionHeader(AppThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.getTextStyle(
            baseSize: 15.0,
            fontWeight: FontWeight.w700,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: theme.mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPresetsRow(ThemeProvider provider, AppThemeData activeTheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppThemeData.presets.map((preset) {
          final isSelected = activeTheme.id == preset.id;
          return GestureDetector(
            onTap: () => provider.setPreset(preset.id),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: preset.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? preset.primary : activeTheme.border,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: preset.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: preset.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatAccentPicker(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ..._accentColors.map((col) {
            final isSelected = activeTheme.primary.toARGB32() == col.toARGB32();
            return GestureDetector(
              onTap: () => provider.updateChatAccent(col),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: activeTheme.text, width: 2.5)
                      : Border.all(color: Colors.white24, width: 0.8),
                ),
              ),
            );
          }),
          // Custom color picker button
          GestureDetector(
            onTap: () => _showCustomColorPicker(context, provider, true),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: activeTheme.background,
                shape: BoxShape.circle,
                border: Border.all(color: activeTheme.border, width: 1.5),
              ),
              child: AppIcon(Icons.colorize_rounded, size: 16, color: activeTheme.primary, theme: activeTheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphereSelector(ThemeProvider provider, AppThemeData activeTheme) {
    final isCustomImage = activeTheme.backgroundType == ChatBackgroundType.image;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Custom Gallery Wallpaper Action Chip
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  avatar: Icon(Icons.add_photo_alternate_rounded, size: 16, color: activeTheme.primary),
                  label: const Text('Phone Photo'),
                  backgroundColor: isCustomImage ? activeTheme.primary.withValues(alpha: 0.25) : activeTheme.surface,
                  side: BorderSide(
                    color: isCustomImage ? activeTheme.primary : activeTheme.border,
                    width: isCustomImage ? 1.5 : 1.0,
                  ),
                  labelStyle: TextStyle(
                    color: isCustomImage ? activeTheme.primary : activeTheme.text,
                    fontSize: 11.5,
                    fontWeight: isCustomImage ? FontWeight.bold : FontWeight.w600,
                  ),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                    if (picked != null) {
                      provider.updateBackground(ChatBackgroundType.image, picked.path);
                    }
                  },
                ),
              ),
              ..._atmospherePresets.map((atm) {
                final isSelected = !isCustomImage && activeTheme.backgroundValue == atm['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(atm['name']!),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.surface,
                    side: BorderSide(
                      color: isSelected ? activeTheme.primary : activeTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? activeTheme.primary : activeTheme.text,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      provider.updateBackground(ChatBackgroundType.mesh, atm['id']!);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        if (isCustomImage) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: activeTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wallpaper Opacity: ${(activeTheme.wallpaperOpacity * 100).toInt()}%',
                      style: TextStyle(color: activeTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Change Photo', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                        if (picked != null) {
                          provider.updateBackground(ChatBackgroundType.image, picked.path);
                        }
                      },
                    ),
                  ],
                ),
                Slider(
                  value: activeTheme.wallpaperOpacity.clamp(0.1, 1.0),
                  min: 0.1,
                  max: 1.0,
                  activeColor: activeTheme.primary,
                  onChanged: (val) {
                    provider.updateBackground(
                      ChatBackgroundType.image,
                      activeTheme.backgroundValue,
                      opacity: val,
                      blur: activeTheme.wallpaperBlur,
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Wallpaper Blur: ${activeTheme.wallpaperBlur.toStringAsFixed(1)}px',
                  style: TextStyle(color: activeTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: activeTheme.wallpaperBlur.clamp(0.0, 20.0),
                  min: 0.0,
                  max: 20.0,
                  activeColor: activeTheme.primary,
                  onChanged: (val) {
                    provider.updateBackground(
                      ChatBackgroundType.image,
                      activeTheme.backgroundValue,
                      opacity: activeTheme.wallpaperOpacity,
                      blur: val,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBubbleStyleSelector(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = BubbleStyle.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: styles.map((style) {
        final isSelected = activeTheme.bubbleStyle == style;
        final label = style == BubbleStyle.glass ? '🍎 LIQUID GLASS' : style.name.toUpperCase();
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          selectedColor: activeTheme.primary.withValues(alpha: 0.25),
          backgroundColor: activeTheme.surface,
          side: BorderSide(
            color: isSelected ? activeTheme.primary : activeTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          labelStyle: TextStyle(
            color: isSelected ? activeTheme.primary : activeTheme.text,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          onSelected: (_) => provider.updateBubbleStyle(style),
        );
      }).toList(),
    );
  }

  Widget _buildBubbleRadiusSlider(ThemeProvider provider, AppThemeData activeTheme) {
    final presets = [
      {'name': 'Sharp', 'val': 4.0},
      {'name': 'Soft', 'val': 12.0},
      {'name': 'Rounded', 'val': 16.0},
      {'name': 'Pill', 'val': 28.0},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bubble Corner Radius', style: TextStyle(fontSize: 13, color: activeTheme.text, fontWeight: FontWeight.w500)),
              Text('${activeTheme.bubbleRadius.toInt()} px', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: activeTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: presets.map((p) {
              final isSel = (activeTheme.bubbleRadius - (p['val'] as double)).abs() < 1.5;
              return ChoiceChip(
                label: Text('${p['name']} (${(p['val'] as double).toInt()}px)'),
                selected: isSel,
                selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                backgroundColor: activeTheme.background,
                side: BorderSide(
                  color: isSel ? activeTheme.primary : activeTheme.border,
                  width: isSel ? 1.5 : 1.0,
                ),
                labelStyle: TextStyle(
                  color: isSel ? activeTheme.primary : activeTheme.text,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => provider.updateBubbleRadius(p['val'] as double),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Slider(
            value: activeTheme.bubbleRadius.clamp(0.0, 32.0),
            min: 0,
            max: 32,
            divisions: 16,
            activeColor: activeTheme.primary,
            inactiveColor: activeTheme.border,
            onChanged: (val) => provider.updateBubbleRadius(val),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // BUBBLE STUDIO: Shadow Depth Slider
  // ==============================================================================
  Widget _buildBubbleShadowDepthSlider(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(Icons.layers_rounded, size: 16, color: activeTheme.primary, theme: activeTheme),
              const SizedBox(width: 6),
              Text('Bubble Shadow Depth', style: TextStyle(fontSize: 13, color: activeTheme.text, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(activeTheme.glassShadowIntensity * 100).round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: activeTheme.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Controls how deep / elevated bubbles appear', style: TextStyle(fontSize: 11, color: activeTheme.mutedText)),
          Slider(
            value: activeTheme.glassShadowIntensity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: activeTheme.primary,
            inactiveColor: activeTheme.border,
            onChanged: (val) => provider.updateGlassSettings(shadowIntensity: val),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // BUBBLE STUDIO: Full Liquid Glass Preset (complete one-tap)
  // ==============================================================================
  Widget _buildFullLiquidGlassPreset(ThemeProvider provider, AppThemeData activeTheme) {
    final isFullLiquid = activeTheme.bubbleStyle == BubbleStyle.glass &&
        activeTheme.glassBlur >= 20.0 &&
        activeTheme.glassIntensity >= 0.35;

    return GestureDetector(
      onTap: () {
        // Apply glass bubble style + max glass settings in one tap
        provider.updateBubbleStyle(BubbleStyle.glass);
        provider.updateGlassSettings(
          intensity: 0.55,
          blur: 24.0,
          transparency: 0.45,
          borderOpacity: 0.38,
          shadowIntensity: 0.30,
          surfaceBrightness: 1.08,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ Full Liquid Glass activated!'),
            backgroundColor: activeTheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeTheme.primary.withValues(alpha: 0.20),
              activeTheme.secondary.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFullLiquid ? activeTheme.primary : activeTheme.border,
            width: isFullLiquid ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activeTheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(Icons.water_drop_rounded, color: activeTheme.primary, size: 20, theme: activeTheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '✦ Complete Liquid Glass',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: activeTheme.primary,
                        ),
                      ),
                      if (isFullLiquid) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeTheme.primary.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: activeTheme.primary, letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'One tap — applies glass style + 24px blur + 55% intensity + specular borders',
                    style: TextStyle(fontSize: 11, color: activeTheme.mutedText),
                  ),
                ],
              ),
            ),
            AppIcon(Icons.chevron_right_rounded, color: activeTheme.primary.withValues(alpha: 0.6), theme: activeTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidGlassStudio(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Glass Intensity Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: activeTheme.mutedText)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGlassPresetChip(provider, activeTheme, 'Subtle (Default)', 0.15, 12.0, 0.20, 0.20, 0.10, 1.0),
                const SizedBox(width: 8),
                _buildGlassPresetChip(provider, activeTheme, 'Liquid Glass', 0.35, 18.0, 0.35, 0.28, 0.20, 1.05),
                const SizedBox(width: 8),
                _buildGlassPresetChip(provider, activeTheme, 'Frosted Ice', 0.50, 24.0, 0.45, 0.35, 0.15, 1.15),
                const SizedBox(width: 8),
                _buildGlassPresetChip(provider, activeTheme, 'Minimal OLED', 0.08, 6.0, 0.10, 0.15, 0.05, 0.95),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Glass Intensity (0-100)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Glass Intensity',
            valueText: '${(activeTheme.glassIntensity * 100).round()}%',
            value: activeTheme.glassIntensity,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => provider.updateGlassSettings(intensity: val),
          ),
          const SizedBox(height: 12),

          // 2. Blur (0-30)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Blur Radius',
            valueText: '${activeTheme.glassBlur.toStringAsFixed(1)} px',
            value: activeTheme.glassBlur,
            min: 0.0,
            max: 30.0,
            onChanged: (val) => provider.updateGlassSettings(blur: val),
          ),
          const SizedBox(height: 12),

          // 3. Transparency (0-100)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Transparency',
            valueText: '${(activeTheme.glassTransparency * 100).round()}%',
            value: activeTheme.glassTransparency,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => provider.updateGlassSettings(transparency: val),
          ),
          const SizedBox(height: 12),

          // 4. Border Opacity (0-100)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Border Opacity',
            valueText: '${(activeTheme.glassBorderOpacity * 100).round()}%',
            value: activeTheme.glassBorderOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => provider.updateGlassSettings(borderOpacity: val),
          ),
          const SizedBox(height: 12),

          // 5. Shadow Intensity (0-100)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Shadow Intensity',
            valueText: '${(activeTheme.glassShadowIntensity * 100).round()}%',
            value: activeTheme.glassShadowIntensity,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => provider.updateGlassSettings(shadowIntensity: val),
          ),
          const SizedBox(height: 12),

          // 6. Surface Brightness (0-100)
          _buildGlassSliderRow(
            theme: activeTheme,
            label: 'Surface Brightness',
            valueText: '${(activeTheme.surfaceBrightness * 100).round()}%',
            value: activeTheme.surfaceBrightness,
            min: 0.0,
            max: 2.0,
            onChanged: (val) => provider.updateGlassSettings(surfaceBrightness: val),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPresetChip(
    ThemeProvider provider,
    AppThemeData activeTheme,
    String name,
    double intensity,
    double blur,
    double transparency,
    double border,
    double shadow,
    double brightness,
  ) {
    final isSel = (activeTheme.glassIntensity - intensity).abs() < 0.05 &&
        (activeTheme.glassBlur - blur).abs() < 1.0;
    return ChoiceChip(
      label: Text(name),
      selected: isSel,
      selectedColor: activeTheme.primary.withValues(alpha: 0.25),
      backgroundColor: activeTheme.background,
      side: BorderSide(
        color: isSel ? activeTheme.primary : activeTheme.border,
        width: isSel ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        color: isSel ? activeTheme.primary : activeTheme.text,
        fontSize: 11,
        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
      ),
      onSelected: (_) => provider.updateGlassSettings(
        intensity: intensity,
        blur: blur,
        transparency: transparency,
        borderOpacity: border,
        shadowIntensity: shadow,
        surfaceBrightness: brightness,
      ),
    );
  }

  Widget _buildGlassSliderRow({
    required AppThemeData theme,
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: theme.text, fontSize: 12.5, fontWeight: FontWeight.w500)),
            Text(valueText, style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: theme.primary,
          inactiveColor: theme.border,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSentBubbleColorPicker(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(Icons.arrow_upward_rounded, size: 16, color: activeTheme.primary, theme: activeTheme),
              const SizedBox(width: 6),
              Text('Sent Bubble Accent', style: TextStyle(fontSize: 13, color: activeTheme.text, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _accentColors.map((col) {
              final isSelected = activeTheme.bubbleSent.toARGB32() == col.toARGB32();
              return GestureDetector(
                onTap: () => provider.updateBubbleColors(
                  sentColor: col,
                  sentTextColor: col.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: activeTheme.text, width: 2.5) : Border.all(color: Colors.white24, width: 0.8),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedBubbleColorPicker(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(Icons.arrow_downward_rounded, size: 16, color: activeTheme.mutedText, theme: activeTheme),
              const SizedBox(width: 6),
              Text('Received Bubble Tint', style: TextStyle(fontSize: 13, color: activeTheme.text, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _receivedBubbleColors.map((col) {
              final isSelected = activeTheme.bubbleReceived.toARGB32() == col.toARGB32();
              return GestureDetector(
                onTap: () => provider.updateBubbleColors(
                  receivedColor: col,
                  receivedTextColor: col.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: activeTheme.text, width: 2.5) : Border.all(color: Colors.white24, width: 0.8),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationControls(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = MessageAnimationStyle.values;
    final speeds = AnimationSpeed.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incoming Message Animation', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: styles.map((s) {
                final isSelected = activeTheme.incomingAnimationStyle == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(s.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateMessageAnimations(incoming: s),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text('Outgoing Message Animation', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: styles.map((s) {
                final isSelected = activeTheme.outgoingAnimationStyle == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(s.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateMessageAnimations(outgoing: s),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text('Animation Speed', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: speeds.map((sp) {
              final isSelected = activeTheme.animationSpeed == sp;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ChoiceChip(
                    label: Center(child: Text(sp.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateMessageAnimations(speed: sp),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilySelector(ThemeProvider provider, AppThemeData activeTheme) {
    final families = FontFamilyOption.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: families.map((fam) {
          final isSelected = activeTheme.fontFamily == fam;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(_formatFontName(fam)),
              selected: isSelected,
              selectedColor: activeTheme.primary.withValues(alpha: 0.25),
              backgroundColor: activeTheme.surface,
              side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
              labelStyle: TextStyle(
                color: isSelected ? activeTheme.primary : activeTheme.text,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => provider.updateTypography(fontFamily: fam),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatFontName(FontFamilyOption f) {
    return switch (f) {
      FontFamilyOption.inter => 'Inter',
      FontFamilyOption.manrope => 'Manrope',
      FontFamilyOption.dmSans => 'DM Sans',
      FontFamilyOption.poppins => 'Poppins',
      FontFamilyOption.spaceGrotesk => 'Space Grotesk',
      FontFamilyOption.plusJakartaSans => 'Jakarta Sans',
      FontFamilyOption.system => 'System Default',
    };
  }

  Widget _buildFontSizeSelector(ThemeProvider provider, AppThemeData activeTheme) {
    final sizes = FontSizeOption.values;
    return Row(
      children: sizes.map((s) {
        final isSelected = activeTheme.fontSize == s;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Center(child: Text(s.name.toUpperCase())),
              selected: isSelected,
              selectedColor: activeTheme.primary.withValues(alpha: 0.25),
              backgroundColor: activeTheme.surface,
              side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
              labelStyle: TextStyle(
                color: isSelected ? activeTheme.primary : activeTheme.text,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => provider.updateTypography(fontSize: s),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDensitySelector(ThemeProvider provider, AppThemeData activeTheme) {
    final densities = ChatDensity.values;
    return Row(
      children: densities.map((d) {
        final isSelected = activeTheme.density == d;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Center(child: Text(d.name.toUpperCase())),
              selected: isSelected,
              selectedColor: activeTheme.primary.withValues(alpha: 0.25),
              backgroundColor: activeTheme.surface,
              side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
              labelStyle: TextStyle(
                color: isSelected ? activeTheme.primary : activeTheme.text,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => provider.updateDensity(d),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggles(ThemeProvider provider, AppThemeData activeTheme) {
    return Container(
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Show Avatars in Chat', style: TextStyle(color: activeTheme.text, fontSize: 13)),
            value: activeTheme.showAvatars,
            activeThumbColor: activeTheme.primary,
            onChanged: (val) => provider.updateToggles(showAvatars: val),
          ),
          Divider(height: 1, color: activeTheme.border.withValues(alpha: 0.5)),
          SwitchListTile(
            title: Text('Show Message Timestamps', style: TextStyle(color: activeTheme.text, fontSize: 13)),
            value: activeTheme.showTimestamps,
            activeThumbColor: activeTheme.primary,
            onChanged: (val) => provider.updateToggles(showTimestamps: val),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final shapes = AvatarShape.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Avatar Shape', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: shapes.map((sh) {
              final isSelected = activeTheme.avatarShape == sh;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ChoiceChip(
                    label: Center(child: Text(sh.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 9.5),
                    onSelected: (_) => provider.updateAvatarSettings(shape: sh),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Avatar Size', style: TextStyle(color: activeTheme.text, fontSize: 13)),
              Text('${activeTheme.avatarSize.toInt()} px', style: TextStyle(color: activeTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: activeTheme.avatarSize,
            min: 24,
            max: 48,
            divisions: 6,
            activeColor: activeTheme.primary,
            onChanged: (val) => provider.updateAvatarSettings(size: val),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineIndicatorStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = OnlineIndicatorStyle.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Indicator Style', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: styles.map((st) {
              final isSelected = activeTheme.onlineIndicatorStyle == st;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: ChoiceChip(
                    label: Center(child: Text(st.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateOnlineIndicator(style: st),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final formats = TimestampFormat.values;
    final positions = TimestampPosition.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timestamp Format', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: formats.map((f) {
                final isSelected = activeTheme.timestampFormat == f;
                final label = switch (f) {
                  TimestampFormat.standard12 => '11:48 AM',
                  TimestampFormat.standard24 => '23:48',
                  TimestampFormat.timeOnly => '11:48',
                  TimestampFormat.fullWithDay => 'Today, 11:48 AM',
                  TimestampFormat.relative => '2m ago',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateTimestampSettings(format: f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Position', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: positions.map((p) {
              final isSelected = activeTheme.timestampPosition == p;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(p.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 8.5),
                    onSelected: (_) => provider.updateTimestampSettings(position: p),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicatorStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = TypingIndicatorStyle.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Indicator Style', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: styles.map((st) {
              final isSelected = activeTheme.typingIndicatorStyle == st;
              final label = switch (st) {
                TypingIndicatorStyle.fullText => 'Alex is typing...',
                TypingIndicatorStyle.compactDots => 'Alex •••',
                TypingIndicatorStyle.midlineDots => 'Alex ⋯',
                TypingIndicatorStyle.largeDots => '● ● ●',
                TypingIndicatorStyle.writing => 'Writing...',
                TypingIndicatorStyle.typing => 'Typing...',
              };
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                backgroundColor: activeTheme.background,
                side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                onSelected: (_) => provider.updateTypingIndicator(style: st),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadReceiptStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = ReadReceiptStyle.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Receipt Style', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: styles.map((st) {
              final isSelected = activeTheme.readReceiptStyle == st;
              final label = switch (st) {
                ReadReceiptStyle.singleCheck => 'Single',
                ReadReceiptStyle.doubleCheck => 'Double',
                ReadReceiptStyle.dots => 'Dots',
                ReadReceiptStyle.minimalCheck => 'Minimal',
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(label)),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateReadReceipts(style: st),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationAndIcons(ThemeProvider provider, AppThemeData activeTheme) {
    final navStyles = NavigationStyle.values;
    final iconStyles = IconStyleOption.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Navigation Layout', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: navStyles.map((ns) {
              final isSelected = activeTheme.navigationStyle == ns;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(ns.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 9),
                    onSelected: (_) => provider.updateNavigationStyle(ns),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text('Global Icon Style', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: iconStyles.map((ic) {
              final isSelected = activeTheme.iconStyle == ic;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(ic.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 9),
                    onSelected: (_) => provider.updateIconStyle(ic),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final presets = SoundPreset.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Message Sounds', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
              Switch(
                value: activeTheme.soundsEnabled,
                activeThumbColor: activeTheme.primary,
                onChanged: (val) => provider.updateSounds(enabled: val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((snd) {
                final isSelected = activeTheme.soundPreset == snd;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(snd.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateSounds(preset: snd),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: activeTheme.primary),
              foregroundColor: activeTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.volume_up_rounded, size: 16),
            label: const Text('Preview Sound Chime', style: TextStyle(fontSize: 12)),
            onPressed: () {
              SoundService.instance.playPreset(activeTheme.soundPreset, enabled: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing chime: ${activeTheme.soundPreset.name}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessageStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final styles = VoiceWaveformStyle.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waveform Style', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: styles.map((ws) {
              final isSelected = activeTheme.voiceWaveformStyle == ws;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(ws.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 9.5),
                    onSelected: (_) => provider.updateVoiceWaveform(style: ws),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Waveform Thickness', style: TextStyle(color: activeTheme.text, fontSize: 13)),
              Text('${activeTheme.voiceWaveformThickness.toStringAsFixed(1)} px', style: TextStyle(color: activeTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: activeTheme.voiceWaveformThickness,
            min: 1.0,
            max: 5.0,
            divisions: 8,
            activeColor: activeTheme.primary,
            onChanged: (val) => provider.updateVoiceWaveform(thickness: val),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageEffectsStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final effects = MessageEffectType.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Message Effects', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
              Switch(
                value: activeTheme.messageEffectsEnabled,
                activeThumbColor: activeTheme.primary,
                onChanged: (val) => provider.updateMessageEffects(enabled: val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: effects.map((ef) {
                final isSelected = activeTheme.messageEffectType == ef;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(ef.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 10),
                    onSelected: (_) => provider.updateMessageEffects(type: ef),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockStudio(ThemeProvider provider, AppThemeData activeTheme) {
    final lockStyles = AppLockStyle.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lock Screen Method', style: TextStyle(color: activeTheme.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: lockStyles.map((ls) {
              final isSelected = activeTheme.appLockStyle == ls;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Center(child: Text(ls.name.toUpperCase())),
                    selected: isSelected,
                    selectedColor: activeTheme.primary.withValues(alpha: 0.25),
                    backgroundColor: activeTheme.background,
                    side: BorderSide(color: isSelected ? activeTheme.primary : activeTheme.border),
                    labelStyle: TextStyle(color: isSelected ? activeTheme.primary : activeTheme.text, fontSize: 9),
                    onSelected: (_) => provider.updateAppLockStyle(ls),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeActions(ThemeProvider provider, AppThemeData activeTheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: activeTheme.primary),
                  foregroundColor: activeTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: const Text('Save Theme'),
                onPressed: () {
                  provider.saveCurrentThemeAs('${activeTheme.name} (Custom)');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme saved to your account!')),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: activeTheme.border),
                  foregroundColor: activeTheme.text,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Duplicate'),
                onPressed: () {
                  provider.duplicateTheme();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme duplicated!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
