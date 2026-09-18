import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==============================================================================
// 1. DESIGN TOKEN ENUMS & OPTIONS
// ==============================================================================

enum BubbleStyle {
  classic,
  rounded,
  pill,
  minimal,
  glass,
  sharp,
}

enum ChatBackgroundType {
  solid,
  gradient,
  pattern,
  image,
  mesh,
}

enum ChatDensity {
  compact,
  comfortable,
  spacious,
}

enum FontFamilyOption {
  inter,
  manrope,
  dmSans,
  poppins,
  spaceGrotesk,
  plusJakartaSans,
  system,
}

enum FontSizeOption {
  small,
  medium,
  large,
}

enum NotificationStyle {
  minimal,
  floatingCard,
  compactBubble,
  avatarFocused,
  none,
}

enum MessageAnimationStyle {
  none,
  fade,
  slide,
  pop,
  scale,
  blurClear,
  typewriter,
  elastic,
  softRise,
}

enum AnimationSpeed {
  fast,      // 160ms
  normal,    // 280ms
  smooth,    // 420ms
  cinematic, // 650ms
}

enum AnimationIntensity {
  subtle,
  medium,
  vibrant,
}

enum AvatarShape {
  circle,
  roundedSquare,
  squircle,
  hexagon,
}

enum OnlineIndicatorStyle {
  dot,
  ring,
  pulse,
  glow,
}

enum TimestampFormat {
  standard12,  // 11:48 AM
  standard24,  // 23:48
  timeOnly,    // 11:48
  fullWithDay, // Today, 11:48 AM
  relative,    // 2m ago
}

enum TimestampVisibility {
  always,
  onHover,
  lastMessageOnly,
  never,
}

enum TimestampPosition {
  bottomRight,
  bottomLeft,
  inline,
  belowMessage,
}

enum TypingIndicatorStyle {
  fullText,    // Alex is typing...
  compactDots, // Alex •••
  midlineDots, // Alex ⋯
  largeDots,   // ● ● ●
  writing,     // Writing...
  typing,      // Typing...
}

enum TypingAnimation {
  fade,
  bounce,
  pulse,
  wave,
}

enum ReadReceiptStyle {
  singleCheck,
  doubleCheck,
  dots,
  minimalCheck,
}

enum NavigationStyle {
  bottomNav,
  minimalNav,
  compactNav,
  topNav,
}

enum IconStyleOption {
  outline,
  filled,
  rounded,
  sharp,
  minimal,
}

enum VoiceWaveformStyle {
  wave,
  bars,
  minimalLine,
  dotProgress,
}

enum MessageEffectType {
  none,
  celebration,
  hearts,
  fire,
  sparkles,
  burst,
  snow,
  confetti,
}

enum SoundPreset {
  softPop,
  glass,
  pulse,
  minimal,
  classic,
  softClick,
  none,
}

enum SearchBarStyle {
  pill,
  rounded,
  sharp,
  floating,
  minimal,
}

enum HomeScreenLayout {
  classic,
  minimal,
  large,
  compact,
}

enum AppLockStyle {
  none,
  pin,
  password,
  biometric,
}

// ==============================================================================
// 2. CENTRALIZED DESIGN TOKEN THEME DATA CLASS
// ==============================================================================

class AppThemeData {
  final String id;
  final String name;

  // Core Palette Tokens
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color bubbleSent;
  final Color bubbleReceived;
  final Color bubbleSentText;
  final Color bubbleReceivedText;
  final bool isDark;
  Color get primaryColor => primary;

  // Bubble Studio Tokens
  final BubbleStyle bubbleStyle;
  final double bubbleRadius;

  // Atmosphere & Wallpaper Tokens
  final ChatBackgroundType backgroundType;
  final String backgroundValue; // Hex, preset id (e.g. 'ios_mesh', 'aurora_mesh') or URL
  final double wallpaperOpacity;
  final double wallpaperBlur;

  // Typography Tokens
  final FontFamilyOption fontFamily;
  final FontSizeOption fontSize;

  // Density & Layout Tokens
  final ChatDensity density;
  final double bubblePadding;
  final double messageSpacing;

  // Message Animation Studio Tokens
  final MessageAnimationStyle incomingAnimationStyle;
  final MessageAnimationStyle outgoingAnimationStyle;
  final AnimationSpeed animationSpeed;
  final AnimationIntensity animationIntensity;

  // Avatar Studio Tokens
  final AvatarShape avatarShape;
  final double avatarSize;
  final bool showAvatarBorder;
  final double avatarBorderWidth;
  final Color avatarBorderColor;
  final bool showAvatarShadow;
  final bool showAvatars;

  // Online Indicator Tokens
  final OnlineIndicatorStyle onlineIndicatorStyle;
  final Color onlineIndicatorColor;
  final double onlineIndicatorSize;

  // Timestamp Studio Tokens
  final TimestampFormat timestampFormat;
  final TimestampVisibility timestampVisibility;
  final TimestampPosition timestampPosition;
  final double timestampOpacity;
  final double timestampSize;
  final bool showTimestamps;

  // Typing Indicator Tokens
  final TypingIndicatorStyle typingIndicatorStyle;
  final TypingAnimation typingAnimation;
  final Color typingIndicatorColor;

  // Read Receipt Tokens
  final ReadReceiptStyle readReceiptStyle;
  final Color readReceiptSentColor;
  final Color readReceiptDeliveredColor;
  final Color readReceiptReadColor;

  // Navigation & Icon Tokens
  final NavigationStyle navigationStyle;
  final IconStyleOption iconStyle;
  final bool showNavLabels;

  // Voice Message Tokens
  final VoiceWaveformStyle voiceWaveformStyle;
  final double voiceWaveformThickness;
  final Color voiceAccentColor;
  final double voicePlaybackSpeed;

  // Message Effects Tokens
  final bool messageEffectsEnabled;
  final MessageEffectType messageEffectType;

  // Sound Studio Tokens
  final SoundPreset soundPreset;
  final String incomingSound;
  final String outgoingSound;
  final bool soundsEnabled;

  // Notification & App Lock Tokens
  final NotificationStyle notificationStyle;
  final SearchBarStyle searchBarStyle;
  final HomeScreenLayout homeLayout;
  final AppLockStyle appLockStyle;

  // Liquid Glass Studio Tokens
  final double glassIntensity;       // 0.0 - 1.0
  final double glassBlur;            // 0.0 - 30.0
  final double glassTransparency;    // 0.0 - 1.0
  final double glassBorderOpacity;   // 0.0 - 1.0
  final double glassShadowIntensity; // 0.0 - 1.0
  final double surfaceBrightness;    // 0.0 - 1.0

  const AppThemeData({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.bubbleSent,
    required this.bubbleReceived,
    required this.bubbleSentText,
    required this.bubbleReceivedText,
    this.isDark = true,
    this.bubbleStyle = BubbleStyle.rounded,
    this.bubbleRadius = 16.0,
    this.backgroundType = ChatBackgroundType.solid,
    this.backgroundValue = '#0B0B0F',
    this.wallpaperOpacity = 1.0,
    this.wallpaperBlur = 0.0,
    this.fontFamily = FontFamilyOption.inter,
    this.fontSize = FontSizeOption.medium,
    this.density = ChatDensity.comfortable,
    this.bubblePadding = 12.0,
    this.messageSpacing = 8.0,
    this.incomingAnimationStyle = MessageAnimationStyle.fade,
    this.outgoingAnimationStyle = MessageAnimationStyle.softRise,
    this.animationSpeed = AnimationSpeed.normal,
    this.animationIntensity = AnimationIntensity.subtle,
    this.avatarShape = AvatarShape.circle,
    this.avatarSize = 42.0,
    this.showAvatarBorder = false,
    this.avatarBorderWidth = 1.5,
    this.avatarBorderColor = const Color(0xFF7C5CFF),
    this.showAvatarShadow = false,
    this.showAvatars = true,
    this.onlineIndicatorStyle = OnlineIndicatorStyle.dot,
    this.onlineIndicatorColor = const Color(0xFF10B981),
    this.onlineIndicatorSize = 10.0,
    this.timestampFormat = TimestampFormat.standard12,
    this.timestampVisibility = TimestampVisibility.always,
    this.timestampPosition = TimestampPosition.bottomRight,
    this.timestampOpacity = 0.65,
    this.timestampSize = 11.0,
    this.showTimestamps = true,
    this.typingIndicatorStyle = TypingIndicatorStyle.compactDots,
    this.typingAnimation = TypingAnimation.bounce,
    this.typingIndicatorColor = const Color(0xFF7C5CFF),
    this.readReceiptStyle = ReadReceiptStyle.doubleCheck,
    this.readReceiptSentColor = const Color(0xFF8E8E9A),
    this.readReceiptDeliveredColor = const Color(0xFF8E8E9A),
    this.readReceiptReadColor = const Color(0xFF0A84FF),
    this.navigationStyle = NavigationStyle.bottomNav,
    this.iconStyle = IconStyleOption.rounded,
    this.showNavLabels = true,
    this.voiceWaveformStyle = VoiceWaveformStyle.wave,
    this.voiceWaveformThickness = 3.0,
    this.voiceAccentColor = const Color(0xFF7C5CFF),
    this.voicePlaybackSpeed = 1.0,
    this.messageEffectsEnabled = true,
    this.messageEffectType = MessageEffectType.celebration,
    this.soundPreset = SoundPreset.softPop,
    this.incomingSound = 'pop',
    this.outgoingSound = 'swoosh',
    this.soundsEnabled = true,
    this.notificationStyle = NotificationStyle.floatingCard,
    this.searchBarStyle = SearchBarStyle.rounded,
    this.homeLayout = HomeScreenLayout.classic,
    this.appLockStyle = AppLockStyle.none,
    this.glassIntensity = 0.20,
    this.glassBlur = 16.0,
    this.glassTransparency = 0.30,
    this.glassBorderOpacity = 0.25,
    this.glassShadowIntensity = 0.20,
    this.surfaceBrightness = 0.50,
  });

  // ============================================================================
  // 3. 10 CURATED THEME PRESETS (PREMIUM, MINIMAL, REFINED)
  // ============================================================================

  // 1. Midnight Glass (Signature Z Chat Aesthetic)
  static const AppThemeData midnightGlass = AppThemeData(
    id: 'midnight_glass',
    name: 'Midnight Glass',
    background: Color(0xFF0B0B0F),
    surface: Color(0xFF14141A),
    primary: Color(0xFF7C5CFF),
    secondary: Color(0xFF987DFF),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF8E8E9A),
    border: Color(0xFF22222C),
    bubbleSent: Color(0xFF7C5CFF),
    bubbleReceived: Color(0xFF1E1E28),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE8E8EE),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'nebula_mesh',
    incomingAnimationStyle: MessageAnimationStyle.fade,
    outgoingAnimationStyle: MessageAnimationStyle.softRise,
  );

  // 2. iOS Liquid Glass (Apple Frosted Aesthetic)
  static const AppThemeData iosLiquidGlass = AppThemeData(
    id: 'ios_liquid_glass',
    name: 'iOS Liquid Glass',
    background: Color(0xFF090A12),
    surface: Color(0xFF131522),
    primary: Color(0xFF0A84FF),
    secondary: Color(0xFF5E5CE6),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF8E8E93),
    border: Color(0xFF282A3A),
    bubbleSent: Color(0xFF0A84FF),
    bubbleReceived: Color(0xFF202334),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFFFFFF),
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'ios_mesh',
    avatarShape: AvatarShape.squircle,
    isDark: true,
  );

  // 3. OLED Minimal (Pure Absolute Black)
  static const AppThemeData oledMinimal = AppThemeData(
    id: 'oled_minimal',
    name: 'OLED Minimal',
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0C),
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF60A5FA),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF737373),
    border: Color(0xFF18181B),
    bubbleSent: Color(0xFF2563EB),
    bubbleReceived: Color(0xFF121215),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE5E5E5),
    bubbleStyle: BubbleStyle.minimal,
    bubbleRadius: 12.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#000000',
    isDark: true,
  );

  // 4. Cream Studio (Warm Editorial Paper)
  static const AppThemeData creamStudio = AppThemeData(
    id: 'cream_studio',
    name: 'Cream Studio',
    background: Color(0xFFF7F3EA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFD97745),
    secondary: Color(0xFFE58F63),
    text: Color(0xFF1C1917),
    mutedText: Color(0xFF78716C),
    border: Color(0xFFE7E0D3),
    bubbleSent: Color(0xFFD97745),
    bubbleReceived: Color(0xFFEDE6DA),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF1C1917),
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#F7F3EA',
    isDark: false,
  );

  // 5. Ocean Breeze (Deep Maritime Teal)
  static const AppThemeData oceanBreeze = AppThemeData(
    id: 'ocean_breeze',
    name: 'Ocean Breeze',
    background: Color(0xFFF4FAFC),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF147D92),
    secondary: Color(0xFF38A3B8),
    text: Color(0xFF172126),
    mutedText: Color(0xFF718087),
    border: Color(0xFFDCE9ED),
    bubbleSent: Color(0xFF147D92),
    bubbleReceived: Color(0xFFE3F0F4),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF172126),
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#F4FAFC',
    isDark: false,
  );

  // 6. Soft Mono (Minimalist Swiss Editorial)
  static const AppThemeData softMono = AppThemeData(
    id: 'soft_mono',
    name: 'Soft Mono',
    background: Color(0xFF111113),
    surface: Color(0xFF18181B),
    primary: Color(0xFFE4E4E7),
    secondary: Color(0xFFA1A1AA),
    text: Color(0xFFF4F4F5),
    mutedText: Color(0xFF71717A),
    border: Color(0xFF27272A),
    bubbleSent: Color(0xFF27272A),
    bubbleReceived: Color(0xFF18181B),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE4E4E7),
    bubbleStyle: BubbleStyle.minimal,
    bubbleRadius: 10.0,
    isDark: true,
  );

  // 7. Sunset Velvet (Warm Amber & Plum)
  static const AppThemeData sunsetVelvet = AppThemeData(
    id: 'sunset_velvet',
    name: 'Sunset Velvet',
    background: Color(0xFF120C12),
    surface: Color(0xFF1E141E),
    primary: Color(0xFFF97316),
    secondary: Color(0xFFFB923C),
    text: Color(0xFFFFF7ED),
    mutedText: Color(0xFFFDBA74),
    border: Color(0xFF382333),
    bubbleSent: Color(0xFFEA580C),
    bubbleReceived: Color(0xFF2A1B28),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFFEDD5),
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'sunset_mesh',
    isDark: true,
  );

  // ============================================================================
  // NEW AESTHETIC PRESETS (13 DISTINCT DESIGN STYLES)
  // ============================================================================

  // N1. Minimalist Flat (Clean, pure, no noise)
  static const AppThemeData minimalistFlat = AppThemeData(
    id: 'minimalist_flat',
    name: 'Minimal Flat',
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF1A1A1A),
    secondary: Color(0xFF555555),
    text: Color(0xFF111111),
    mutedText: Color(0xFF888888),
    border: Color(0xFFE8E8E8),
    bubbleSent: Color(0xFF1A1A1A),
    bubbleReceived: Color(0xFFF0F0F0),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF111111),
    isDark: false,
    bubbleStyle: BubbleStyle.minimal,
    bubbleRadius: 8.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#FAFAFA',
    glassIntensity: 0.05,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 0.08,
    fontFamily: FontFamilyOption.inter,
  );

  // N2. Material You (Google M3 dynamic color)
  static const AppThemeData materialYou = AppThemeData(
    id: 'material_you',
    name: 'Material You',
    background: Color(0xFFFEF7FF),
    surface: Color(0xFFF3EDF7),
    primary: Color(0xFF6750A4),
    secondary: Color(0xFF625B71),
    text: Color(0xFF1C1B1F),
    mutedText: Color(0xFF49454F),
    border: Color(0xFFCAC4D0),
    bubbleSent: Color(0xFF6750A4),
    bubbleReceived: Color(0xFFE8DEF8),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF1C1B1F),
    isDark: false,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#FEF7FF',
    glassIntensity: 0.10,
    glassBlur: 8.0,
    glassTransparency: 0.15,
    glassBorderOpacity: 0.20,
    fontFamily: FontFamilyOption.plusJakartaSans,
    avatarShape: AvatarShape.squircle,
  );

  // N3. iOS Native (HIG — Human Interface Guidelines light)
  static const AppThemeData iosNative = AppThemeData(
    id: 'ios_native',
    name: 'iOS Native',
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF007AFF),
    secondary: Color(0xFF34C759),
    text: Color(0xFF000000),
    mutedText: Color(0xFF8E8E93),
    border: Color(0xFFC6C6C8),
    bubbleSent: Color(0xFF007AFF),
    bubbleReceived: Color(0xFFE9E9EB),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF000000),
    isDark: false,
    bubbleStyle: BubbleStyle.classic,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#F2F2F7',
    glassIntensity: 0.12,
    glassBlur: 20.0,
    glassTransparency: 0.18,
    glassBorderOpacity: 0.15,
    avatarShape: AvatarShape.squircle,
    fontFamily: FontFamilyOption.inter,
    readReceiptReadColor: Color(0xFF007AFF),
  );

  // N4. Neumorphism (Soft UI, raised surfaces, inner shadows)
  static const AppThemeData neumorphism = AppThemeData(
    id: 'neumorphism',
    name: 'Neumorphism',
    background: Color(0xFFE0E5EC),
    surface: Color(0xFFE8EDF4),
    primary: Color(0xFF4A90D9),
    secondary: Color(0xFF6BA8E5),
    text: Color(0xFF2D3748),
    mutedText: Color(0xFF718096),
    border: Color(0xFFCDD5DF),
    bubbleSent: Color(0xFF4A90D9),
    bubbleReceived: Color(0xFFDDE3EE),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF2D3748),
    isDark: false,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#E0E5EC',
    glassIntensity: 0.08,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 0.05,
    glassShadowIntensity: 0.30,
  );

  // N5. Glassmorphism (Frosted panels with vivid gradient background)
  static const AppThemeData glassmorphism = AppThemeData(
    id: 'glassmorphism',
    name: 'Glassmorphism',
    background: Color(0xFF1A0533),
    surface: Color(0xFF2A1550),
    primary: Color(0xFF9F7AEA),
    secondary: Color(0xFF76E4F7),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFFB794F4),
    border: Color(0xFF553C9A),
    bubbleSent: Color(0xFF9F7AEA),
    bubbleReceived: Color(0xFF2D1B69),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE9D8FD),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 20.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'nebula_mesh',
    glassIntensity: 0.60,
    glassBlur: 28.0,
    glassTransparency: 0.50,
    glassBorderOpacity: 0.40,
    glassShadowIntensity: 0.30,
    surfaceBrightness: 1.10,
  );

  // N6. Gamified Habit XP (Progress, XP bars, vibrant gaming UI)
  static const AppThemeData gamifiedHabit = AppThemeData(
    id: 'gamified_habit',
    name: 'Habit XP',
    background: Color(0xFF0F1923),
    surface: Color(0xFF1A2535),
    primary: Color(0xFF00D2FF),
    secondary: Color(0xFFFFD700),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF7FDBCA),
    border: Color(0xFF2A3D52),
    bubbleSent: Color(0xFF00B4CC),
    bubbleReceived: Color(0xFF1F3148),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFCCF5FF),
    isDark: true,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 12.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'aurora_mesh',
    glassIntensity: 0.20,
    glassBlur: 10.0,
    glassTransparency: 0.25,
    glassBorderOpacity: 0.30,
    onlineIndicatorColor: Color(0xFFFFD700),
    onlineIndicatorStyle: OnlineIndicatorStyle.glow,
    fontFamily: FontFamilyOption.spaceGrotesk,
  );

  // N7. Skeuomorphism (Leather texture, real-world material feel)
  static const AppThemeData skeuomorphism = AppThemeData(
    id: 'skeuomorphism',
    name: 'Leather Craft',
    background: Color(0xFF3B2314),
    surface: Color(0xFF4D2E18),
    primary: Color(0xFFD4A853),
    secondary: Color(0xFFE8C270),
    text: Color(0xFFFFF8E7),
    mutedText: Color(0xFFC4A882),
    border: Color(0xFF6B3F22),
    bubbleSent: Color(0xFFD4A853),
    bubbleReceived: Color(0xFF5C3A20),
    bubbleSentText: Color(0xFF3B2314),
    bubbleReceivedText: Color(0xFFFFF8E7),
    isDark: true,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 14.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#3B2314',
    glassIntensity: 0.05,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 0.40,
    glassShadowIntensity: 0.50,
  );

  // N8. Neo-Brutalism (Raw, bold, high-contrast black borders)
  static const AppThemeData neoBrutalism = AppThemeData(
    id: 'neo_brutalism',
    name: 'Neo Brutalism',
    background: Color(0xFFFFFF00),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF000000),
    secondary: Color(0xFFFF3D00),
    text: Color(0xFF000000),
    mutedText: Color(0xFF333333),
    border: Color(0xFF000000),
    bubbleSent: Color(0xFF000000),
    bubbleReceived: Color(0xFFFF3D00),
    bubbleSentText: Color(0xFFFFFF00),
    bubbleReceivedText: Color(0xFFFFFFFF),
    isDark: false,
    bubbleStyle: BubbleStyle.sharp,
    bubbleRadius: 0.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#FFFF00',
    glassIntensity: 0.0,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 1.0,
    fontFamily: FontFamilyOption.spaceGrotesk,
  );

  // N9. Cyberpunk Neon (Electric neon on pitch black)
  static const AppThemeData cyberpunkNeon = AppThemeData(
    id: 'cyberpunk_neon',
    name: 'Cyberpunk Neon',
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    primary: Color(0xFF00FF41),
    secondary: Color(0xFFFF006E),
    text: Color(0xFF00FF41),
    mutedText: Color(0xFF00B32D),
    border: Color(0xFF1A1A1A),
    bubbleSent: Color(0xFFFF006E),
    bubbleReceived: Color(0xFF0D1A0D),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF00FF41),
    isDark: true,
    bubbleStyle: BubbleStyle.sharp,
    bubbleRadius: 2.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#000000',
    glassIntensity: 0.15,
    glassBlur: 8.0,
    glassTransparency: 0.20,
    glassBorderOpacity: 0.60,
    onlineIndicatorColor: Color(0xFF00FF41),
    onlineIndicatorStyle: OnlineIndicatorStyle.glow,
    fontFamily: FontFamilyOption.spaceGrotesk,
  );

  // N10. Claymorphism (Soft 3D clay, pastel pops, inflated UI)
  static const AppThemeData claymorphism = AppThemeData(
    id: 'claymorphism',
    name: 'Clay Pastel',
    background: Color(0xFFF9F0FF),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFBB6BD9),
    secondary: Color(0xFF56CCF2),
    text: Color(0xFF2D1B33),
    mutedText: Color(0xFF9B7BB0),
    border: Color(0xFFE8D5F5),
    bubbleSent: Color(0xFFBB6BD9),
    bubbleReceived: Color(0xFFEEE0FF),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF2D1B33),
    isDark: false,
    bubbleStyle: BubbleStyle.pill,
    bubbleRadius: 28.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#F9F0FF',
    glassIntensity: 0.10,
    glassBlur: 4.0,
    glassTransparency: 0.05,
    glassBorderOpacity: 0.12,
    glassShadowIntensity: 0.35,
    avatarShape: AvatarShape.squircle,
    fontFamily: FontFamilyOption.poppins,
  );

  // N11. Retro 8-Bit Pixel (Pixel art, monochrome CRT)
  static const AppThemeData retroPixel = AppThemeData(
    id: 'retro_pixel',
    name: 'Retro 8-Bit',
    background: Color(0xFF0F0F23),
    surface: Color(0xFF1A1A3E),
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFAAAAAA),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF8888AA),
    border: Color(0xFF3333AA),
    bubbleSent: Color(0xFF3333AA),
    bubbleReceived: Color(0xFF1A1A3E),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFCCCCFF),
    isDark: true,
    bubbleStyle: BubbleStyle.sharp,
    bubbleRadius: 0.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#0F0F23',
    glassIntensity: 0.0,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 1.0,
    avatarShape: AvatarShape.roundedSquare,
    fontFamily: FontFamilyOption.spaceGrotesk,
  );

  // N12. Aurora Abstract (Gradient mesh, northern lights vibes)
  static const AppThemeData auroraAbstract = AppThemeData(
    id: 'aurora_abstract',
    name: 'Aurora Abstract',
    background: Color(0xFF071420),
    surface: Color(0xFF0C1F30),
    primary: Color(0xFF00F5A0),
    secondary: Color(0xFF00D9F5),
    text: Color(0xFFE0FFFC),
    mutedText: Color(0xFF7ECDC4),
    border: Color(0xFF1A3A4A),
    bubbleSent: Color(0xFF00C896),
    bubbleReceived: Color(0xFF0E2636),
    bubbleSentText: Color(0xFF071420),
    bubbleReceivedText: Color(0xFFE0FFFC),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'aurora_mesh',
    glassIntensity: 0.40,
    glassBlur: 20.0,
    glassTransparency: 0.38,
    glassBorderOpacity: 0.30,
    glassShadowIntensity: 0.20,
    onlineIndicatorColor: Color(0xFF00F5A0),
    onlineIndicatorStyle: OnlineIndicatorStyle.pulse,
    fontFamily: FontFamilyOption.manrope,
  );

  // N13. Hacker Terminal (Matrix green on black)
  static const AppThemeData hackerTerminal = AppThemeData(
    id: 'hacker_terminal',
    name: 'Hacker Terminal',
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    primary: Color(0xFF00FF00),
    secondary: Color(0xFF00CC00),
    text: Color(0xFF00FF00),
    mutedText: Color(0xFF008800),
    border: Color(0xFF003300),
    bubbleSent: Color(0xFF003300),
    bubbleReceived: Color(0xFF001100),
    bubbleSentText: Color(0xFF00FF00),
    bubbleReceivedText: Color(0xFF00CC00),
    isDark: true,
    bubbleStyle: BubbleStyle.sharp,
    bubbleRadius: 0.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#000000',
    glassIntensity: 0.0,
    glassBlur: 0.0,
    glassTransparency: 0.0,
    glassBorderOpacity: 0.80,
    onlineIndicatorColor: Color(0xFF00FF00),
    onlineIndicatorStyle: OnlineIndicatorStyle.pulse,
    fontFamily: FontFamilyOption.spaceGrotesk,
    avatarShape: AvatarShape.roundedSquare,
  );

  // 8. Arctic Frost (Ice Blue & Specular Frost)
  static const AppThemeData arcticFrost = AppThemeData(
    id: 'arctic_frost',
    name: 'Arctic Frost',
    background: Color(0xFF080E14),
    surface: Color(0xFF0F1822),
    primary: Color(0xFF38BDF8),
    secondary: Color(0xFF7DD3FC),
    text: Color(0xFFF0F9FF),
    mutedText: Color(0xFF94A3B8),
    border: Color(0xFF1E293B),
    bubbleSent: Color(0xFF0284C7),
    bubbleReceived: Color(0xFF131D2A),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE0F2FE),
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 16.0,
    isDark: true,
  );

  // 9. Graphite Pro (Industrial Dark Charcoal)
  static const AppThemeData graphitePro = AppThemeData(
    id: 'graphite_pro',
    name: 'Graphite Pro',
    background: Color(0xFF121214),
    surface: Color(0xFF1B1B1E),
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFFBBF24),
    text: Color(0xFFF5F5F7),
    mutedText: Color(0xFF9E9EA7),
    border: Color(0xFF2A2A30),
    bubbleSent: Color(0xFFD97706),
    bubbleReceived: Color(0xFF232328),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFF5F5F7),
    bubbleStyle: BubbleStyle.sharp,
    bubbleRadius: 8.0,
    isDark: true,
  );

  // 10. Cyber Neon (Futuristic Electric Violet)
  static const AppThemeData cyberNeon = AppThemeData(
    id: 'cyber_neon',
    name: 'Cyber Neon',
    background: Color(0xFF0B0614),
    surface: Color(0xFF160E24),
    primary: Color(0xFFD946EF),
    secondary: Color(0xFFE879F9),
    text: Color(0xFFFDF4FF),
    mutedText: Color(0xFFC084FC),
    border: Color(0xFF3B1D56),
    bubbleSent: Color(0xFFC026D3),
    bubbleReceived: Color(0xFF231438),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFAE8FF),
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 20.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'nebula_mesh',
    isDark: true,
  );

  // ============================================================================
  // PRESET DEFINITIONS (8 SIGNATURE PRESETS AS SPECIFIED IN USER REQUIREMENTS)
  // ============================================================================

  // 1. Midnight (Signature Z Chat Aesthetic)
  static const AppThemeData midnight = midnightGlass;

  // 2. Obsidian (Matte Charcoal with Soft Red/Coral Accent)
  static const AppThemeData obsidian = AppThemeData(
    id: 'obsidian',
    name: 'Obsidian',
    background: Color(0xFF101114),
    surface: Color(0xFF18191E),
    primary: Color(0xFFFF453A),
    secondary: Color(0xFFFF6961),
    text: Color(0xFFF2F2F7),
    mutedText: Color(0xFF8E8E93),
    border: Color(0xFF2C2C34),
    bubbleSent: Color(0xFFE03E36),
    bubbleReceived: Color(0xFF22232A),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFF2F2F7),
    isDark: true,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#101114',
    glassIntensity: 0.15,
    glassBlur: 12.0,
    glassTransparency: 0.20,
    glassBorderOpacity: 0.22,
  );

  // 3. Arctic (Icy Specular Frost)
  static const AppThemeData arctic = arcticFrost;

  // 4. Lavender (Dreamy Purple & Frosted Glass)
  static const AppThemeData lavender = AppThemeData(
    id: 'lavender',
    name: 'Lavender',
    background: Color(0xFF110C1E),
    surface: Color(0xFF1B1430),
    primary: Color(0xFFA855F7),
    secondary: Color(0xFFC084FC),
    text: Color(0xFFFAF5FF),
    mutedText: Color(0xFFA8A29E),
    border: Color(0xFF322352),
    bubbleSent: Color(0xFF9333EA),
    bubbleReceived: Color(0xFF241A40),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFAF5FF),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'nebula_mesh',
    glassIntensity: 0.30,
    glassBlur: 18.0,
    glassTransparency: 0.35,
    glassBorderOpacity: 0.30,
  );

  // 5. Graphite (Industrial Dark Charcoal)
  static const AppThemeData graphite = graphitePro;

  // 6. Soft Glass (Refined Liquid Frosted Glass)
  static const AppThemeData softGlass = AppThemeData(
    id: 'soft_glass',
    name: 'Soft Glass',
    background: Color(0xFF090A12),
    surface: Color(0xFF131522),
    primary: Color(0xFF0A84FF),
    secondary: Color(0xFF5E5CE6),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xFF8E8E93),
    border: Color(0xFF282A3A),
    bubbleSent: Color(0xFF0A84FF),
    bubbleReceived: Color(0xFF202334),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFFFFFF),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 18.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'ios_mesh',
    avatarShape: AvatarShape.squircle,
    glassIntensity: 0.45,
    glassBlur: 22.0,
    glassTransparency: 0.40,
    glassBorderOpacity: 0.35,
  );

  // 7. Minimal White (Crisp Modern Light Surface)
  static const AppThemeData minimalWhite = AppThemeData(
    id: 'minimal_white',
    name: 'Minimal White',
    background: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF3B82F6),
    text: Color(0xFF111827),
    mutedText: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    bubbleSent: Color(0xFF2563EB),
    bubbleReceived: Color(0xFFF1F4F9),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFF111827),
    isDark: false,
    bubbleStyle: BubbleStyle.rounded,
    bubbleRadius: 16.0,
    backgroundType: ChatBackgroundType.solid,
    backgroundValue: '#F8F9FB',
    glassIntensity: 0.12,
    glassBlur: 10.0,
    glassTransparency: 0.20,
    glassBorderOpacity: 0.18,
  );

  // 8. Deep Violet (Electric Violet Glow)
  static const AppThemeData deepViolet = AppThemeData(
    id: 'deep_violet',
    name: 'Deep Violet',
    background: Color(0xFF0D0618),
    surface: Color(0xFF190C2E),
    primary: Color(0xFFD946EF),
    secondary: Color(0xFFE879F9),
    text: Color(0xFFFDF4FF),
    mutedText: Color(0xFFD8B4FE),
    border: Color(0xFF3B1B66),
    bubbleSent: Color(0xFFC026D3),
    bubbleReceived: Color(0xFF281247),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFFAE8FF),
    isDark: true,
    bubbleStyle: BubbleStyle.glass,
    bubbleRadius: 20.0,
    backgroundType: ChatBackgroundType.gradient,
    backgroundValue: 'nebula_mesh',
    glassIntensity: 0.40,
    glassBlur: 20.0,
    glassTransparency: 0.40,
    glassBorderOpacity: 0.35,
  );

  // List of all core presets + 13 new aesthetic styles
  static const List<AppThemeData> curatedPresets = [
    midnight,
    obsidian,
    arctic,
    lavender,
    graphite,
    softGlass,
    minimalWhite,
    deepViolet,
    oledMinimal,
    creamStudio,
    oceanBreeze,
    softMono,
    sunsetVelvet,
    // 13 New Aesthetic Presets
    minimalistFlat,
    materialYou,
    iosNative,
    neumorphism,
    glassmorphism,
    gamifiedHabit,
    skeuomorphism,
    neoBrutalism,
    cyberpunkNeon,
    claymorphism,
    retroPixel,
    auroraAbstract,
    hackerTerminal,
  ];

  static List<AppThemeData> get presets => curatedPresets;

  static AppThemeData getPresetById(String id) {
    if (id == 'midnight_glass' || id == 'midnight') return midnight;
    if (id == 'obsidian') return obsidian;
    if (id == 'arctic_frost' || id == 'arctic') return arctic;
    if (id == 'lavender') return lavender;
    if (id == 'graphite_pro' || id == 'graphite') return graphite;
    if (id == 'ios_liquid_glass' || id == 'ios_glass' || id == 'soft_glass') return softGlass;
    if (id == 'minimal_white') return minimalWhite;
    if (id == 'deep_violet' || id == 'cyber_neon') return deepViolet;
    // New aesthetic presets
    if (id == 'minimalist_flat') return minimalistFlat;
    if (id == 'material_you') return materialYou;
    if (id == 'ios_native') return iosNative;
    if (id == 'neumorphism') return neumorphism;
    if (id == 'glassmorphism') return glassmorphism;
    if (id == 'gamified_habit') return gamifiedHabit;
    if (id == 'skeuomorphism') return skeuomorphism;
    if (id == 'neo_brutalism') return neoBrutalism;
    if (id == 'cyberpunk_neon') return cyberpunkNeon;
    if (id == 'claymorphism') return claymorphism;
    if (id == 'retro_pixel') return retroPixel;
    if (id == 'aurora_abstract') return auroraAbstract;
    if (id == 'hacker_terminal') return hackerTerminal;
    return curatedPresets.firstWhere(
      (theme) => theme.id == id,
      orElse: () => midnight,
    );
  }

  // ============================================================================
  // 4. COPYWITH (FOR PROGRESSIVE LIVE UPDATES)
  // ============================================================================

  AppThemeData copyWith({
    String? id,
    String? name,
    Color? background,
    Color? surface,
    Color? primary,
    Color? secondary,
    Color? text,
    Color? mutedText,
    Color? border,
    Color? bubbleSent,
    Color? bubbleReceived,
    Color? bubbleSentText,
    Color? bubbleReceivedText,
    bool? isDark,
    BubbleStyle? bubbleStyle,
    double? bubbleRadius,
    ChatBackgroundType? backgroundType,
    String? backgroundValue,
    double? wallpaperOpacity,
    double? wallpaperBlur,
    FontFamilyOption? fontFamily,
    FontSizeOption? fontSize,
    ChatDensity? density,
    double? bubblePadding,
    double? messageSpacing,
    MessageAnimationStyle? incomingAnimationStyle,
    MessageAnimationStyle? outgoingAnimationStyle,
    AnimationSpeed? animationSpeed,
    AnimationIntensity? animationIntensity,
    AvatarShape? avatarShape,
    double? avatarSize,
    bool? showAvatarBorder,
    double? avatarBorderWidth,
    Color? avatarBorderColor,
    bool? showAvatarShadow,
    bool? showAvatars,
    OnlineIndicatorStyle? onlineIndicatorStyle,
    Color? onlineIndicatorColor,
    double? onlineIndicatorSize,
    TimestampFormat? timestampFormat,
    TimestampVisibility? timestampVisibility,
    TimestampPosition? timestampPosition,
    double? timestampOpacity,
    double? timestampSize,
    bool? showTimestamps,
    TypingIndicatorStyle? typingIndicatorStyle,
    TypingAnimation? typingAnimation,
    Color? typingIndicatorColor,
    ReadReceiptStyle? readReceiptStyle,
    Color? readReceiptSentColor,
    Color? readReceiptDeliveredColor,
    Color? readReceiptReadColor,
    NavigationStyle? navigationStyle,
    IconStyleOption? iconStyle,
    bool? showNavLabels,
    VoiceWaveformStyle? voiceWaveformStyle,
    double? voiceWaveformThickness,
    Color? voiceAccentColor,
    double? voicePlaybackSpeed,
    bool? messageEffectsEnabled,
    MessageEffectType? messageEffectType,
    SoundPreset? soundPreset,
    String? incomingSound,
    String? outgoingSound,
    bool? soundsEnabled,
    NotificationStyle? notificationStyle,
    SearchBarStyle? searchBarStyle,
    HomeScreenLayout? homeLayout,
    AppLockStyle? appLockStyle,
    double? glassIntensity,
    double? glassBlur,
    double? glassTransparency,
    double? glassBorderOpacity,
    double? glassShadowIntensity,
    double? surfaceBrightness,
  }) {
    return AppThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      bubbleSent: bubbleSent ?? this.bubbleSent,
      bubbleReceived: bubbleReceived ?? this.bubbleReceived,
      bubbleSentText: bubbleSentText ?? this.bubbleSentText,
      bubbleReceivedText: bubbleReceivedText ?? this.bubbleReceivedText,
      isDark: isDark ?? this.isDark,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundValue: backgroundValue ?? this.backgroundValue,
      wallpaperOpacity: wallpaperOpacity ?? this.wallpaperOpacity,
      wallpaperBlur: wallpaperBlur ?? this.wallpaperBlur,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      density: density ?? this.density,
      bubblePadding: bubblePadding ?? this.bubblePadding,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      incomingAnimationStyle: incomingAnimationStyle ?? this.incomingAnimationStyle,
      outgoingAnimationStyle: outgoingAnimationStyle ?? this.outgoingAnimationStyle,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      animationIntensity: animationIntensity ?? this.animationIntensity,
      avatarShape: avatarShape ?? this.avatarShape,
      avatarSize: avatarSize ?? this.avatarSize,
      showAvatarBorder: showAvatarBorder ?? this.showAvatarBorder,
      avatarBorderWidth: avatarBorderWidth ?? this.avatarBorderWidth,
      avatarBorderColor: avatarBorderColor ?? this.avatarBorderColor,
      showAvatarShadow: showAvatarShadow ?? this.showAvatarShadow,
      showAvatars: showAvatars ?? this.showAvatars,
      onlineIndicatorStyle: onlineIndicatorStyle ?? this.onlineIndicatorStyle,
      onlineIndicatorColor: onlineIndicatorColor ?? this.onlineIndicatorColor,
      onlineIndicatorSize: onlineIndicatorSize ?? this.onlineIndicatorSize,
      timestampFormat: timestampFormat ?? this.timestampFormat,
      timestampVisibility: timestampVisibility ?? this.timestampVisibility,
      timestampPosition: timestampPosition ?? this.timestampPosition,
      timestampOpacity: timestampOpacity ?? this.timestampOpacity,
      timestampSize: timestampSize ?? this.timestampSize,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      typingIndicatorStyle: typingIndicatorStyle ?? this.typingIndicatorStyle,
      typingAnimation: typingAnimation ?? this.typingAnimation,
      typingIndicatorColor: typingIndicatorColor ?? this.typingIndicatorColor,
      readReceiptStyle: readReceiptStyle ?? this.readReceiptStyle,
      readReceiptSentColor: readReceiptSentColor ?? this.readReceiptSentColor,
      readReceiptDeliveredColor: readReceiptDeliveredColor ?? this.readReceiptDeliveredColor,
      readReceiptReadColor: readReceiptReadColor ?? this.readReceiptReadColor,
      navigationStyle: navigationStyle ?? this.navigationStyle,
      iconStyle: iconStyle ?? this.iconStyle,
      showNavLabels: showNavLabels ?? this.showNavLabels,
      voiceWaveformStyle: voiceWaveformStyle ?? this.voiceWaveformStyle,
      voiceWaveformThickness: voiceWaveformThickness ?? this.voiceWaveformThickness,
      voiceAccentColor: voiceAccentColor ?? this.voiceAccentColor,
      voicePlaybackSpeed: voicePlaybackSpeed ?? this.voicePlaybackSpeed,
      messageEffectsEnabled: messageEffectsEnabled ?? this.messageEffectsEnabled,
      messageEffectType: messageEffectType ?? this.messageEffectType,
      soundPreset: soundPreset ?? this.soundPreset,
      incomingSound: incomingSound ?? this.incomingSound,
      outgoingSound: outgoingSound ?? this.outgoingSound,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      notificationStyle: notificationStyle ?? this.notificationStyle,
      searchBarStyle: searchBarStyle ?? this.searchBarStyle,
      homeLayout: homeLayout ?? this.homeLayout,
      appLockStyle: appLockStyle ?? this.appLockStyle,
      glassIntensity: glassIntensity ?? this.glassIntensity,
      glassBlur: glassBlur ?? this.glassBlur,
      glassTransparency: glassTransparency ?? this.glassTransparency,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      glassShadowIntensity: glassShadowIntensity ?? this.glassShadowIntensity,
      surfaceBrightness: surfaceBrightness ?? this.surfaceBrightness,
    );
  }

  // ============================================================================
  // 5. TYPOGRAPHY HELPER
  // ============================================================================

  TextStyle getTextStyle({
    num? baseSize,
    FontWeight? fontWeight,
    Color? color,
    num? height,
    TextDecoration? decoration,
  }) {
    double sizeMultiplier = switch (fontSize) {
      FontSizeOption.small => 0.88,
      FontSizeOption.medium => 1.0,
      FontSizeOption.large => 1.15,
    };

    final effectiveSize = ((baseSize?.toDouble()) ?? 14.0) * sizeMultiplier;
    final effectiveColor = color ?? text;
    final effectiveHeight = height?.toDouble();

    return switch (fontFamily) {
      FontFamilyOption.inter => GoogleFonts.inter(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.manrope => GoogleFonts.manrope(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.dmSans => GoogleFonts.dmSans(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.poppins => GoogleFonts.poppins(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.spaceGrotesk => GoogleFonts.spaceGrotesk(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.plusJakartaSans => GoogleFonts.plusJakartaSans(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
      FontFamilyOption.system => TextStyle(
          fontSize: effectiveSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: effectiveColor,
          height: effectiveHeight,
          decoration: decoration,
        ),
    };
  }

  // ============================================================================
  // 6. JSON SERIALIZATION (STANDARDIZED V1 THEME FORMAT, NO INTERNAL DB IDS)
  // ============================================================================

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
  }

  static Color _parseColor(dynamic val, Color fallback) {
    if (val == null) return fallback;
    if (val is int) return Color(val);
    if (val is String) {
      String hex = val.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'id': id,
      'name': name,
      'isDark': isDark,
      'colors': {
        'background': _colorToHex(background),
        'surface': _colorToHex(surface),
        'primary': _colorToHex(primary),
        'secondary': _colorToHex(secondary),
        'text': _colorToHex(text),
        'mutedText': _colorToHex(mutedText),
        'border': _colorToHex(border),
        'bubbleSent': _colorToHex(bubbleSent),
        'bubbleReceived': _colorToHex(bubbleReceived),
        'bubbleSentText': _colorToHex(bubbleSentText),
        'bubbleReceivedText': _colorToHex(bubbleReceivedText),
      },
      'bubbles': {
        'style': bubbleStyle.name,
        'radius': bubbleRadius,
        'padding': bubblePadding,
        'messageSpacing': messageSpacing,
      },
      'background': {
        'type': backgroundType.name,
        'value': backgroundValue,
        'opacity': wallpaperOpacity,
        'blur': wallpaperBlur,
      },
      'typography': {
        'family': fontFamily.name,
        'size': fontSize.name,
      },
      'animations': {
        'incoming': incomingAnimationStyle.name,
        'outgoing': outgoingAnimationStyle.name,
        'speed': animationSpeed.name,
        'intensity': animationIntensity.name,
      },
      'avatar': {
        'shape': avatarShape.name,
        'size': avatarSize,
        'border': showAvatarBorder,
        'borderWidth': avatarBorderWidth,
        'borderColor': _colorToHex(avatarBorderColor),
        'shadow': showAvatarShadow,
        'visible': showAvatars,
      },
      'onlineIndicator': {
        'style': onlineIndicatorStyle.name,
        'color': _colorToHex(onlineIndicatorColor),
        'size': onlineIndicatorSize,
      },
      'timestamps': {
        'format': timestampFormat.name,
        'visibility': timestampVisibility.name,
        'position': timestampPosition.name,
        'opacity': timestampOpacity,
        'size': timestampSize,
        'visible': showTimestamps,
      },
      'typingIndicator': {
        'style': typingIndicatorStyle.name,
        'animation': typingAnimation.name,
        'color': _colorToHex(typingIndicatorColor),
      },
      'readReceipts': {
        'style': readReceiptStyle.name,
        'sentColor': _colorToHex(readReceiptSentColor),
        'deliveredColor': _colorToHex(readReceiptDeliveredColor),
        'readColor': _colorToHex(readReceiptReadColor),
      },
      'navigation': {
        'style': navigationStyle.name,
        'iconStyle': iconStyle.name,
        'showLabels': showNavLabels,
      },
      'voice': {
        'waveformStyle': voiceWaveformStyle.name,
        'thickness': voiceWaveformThickness,
        'accentColor': _colorToHex(voiceAccentColor),
        'playbackSpeed': voicePlaybackSpeed,
      },
      'effects': {
        'enabled': messageEffectsEnabled,
        'type': messageEffectType.name,
      },
      'sound': {
        'preset': soundPreset.name,
        'incoming': incomingSound,
        'outgoing': outgoingSound,
        'enabled': soundsEnabled,
      },
      'layout': {
        'density': density.name,
        'searchBar': searchBarStyle.name,
        'homeLayout': homeLayout.name,
        'notification': notificationStyle.name,
        'appLock': appLockStyle.name,
      },
      'glass': {
        'intensity': glassIntensity,
        'blur': glassBlur,
        'transparency': glassTransparency,
        'borderOpacity': glassBorderOpacity,
        'shadowIntensity': glassShadowIntensity,
        'surfaceBrightness': surfaceBrightness,
      },
    };
  }

  factory AppThemeData.fromJson(Map<String, dynamic> json) {
    // Support flat backwards-compatible map or structured v1 map
    final colors = (json['colors'] as Map<String, dynamic>?) ?? json;
    final bubbles = (json['bubbles'] as Map<String, dynamic>?) ?? json;
    final bg = (json['background'] as Map<String, dynamic>?) ?? json;
    final typo = (json['typography'] as Map<String, dynamic>?) ?? json;
    final anim = (json['animations'] as Map<String, dynamic>?) ?? json;
    final av = (json['avatar'] as Map<String, dynamic>?) ?? json;
    final online = (json['onlineIndicator'] as Map<String, dynamic>?) ?? json;
    final ts = (json['timestamps'] as Map<String, dynamic>?) ?? json;
    final typing = (json['typingIndicator'] as Map<String, dynamic>?) ?? json;
    final rr = (json['readReceipts'] as Map<String, dynamic>?) ?? json;
    final nav = (json['navigation'] as Map<String, dynamic>?) ?? json;
    final voice = (json['voice'] as Map<String, dynamic>?) ?? json;
    final fx = (json['effects'] as Map<String, dynamic>?) ?? json;
    final snd = (json['sound'] as Map<String, dynamic>?) ?? json;
    final layout = (json['layout'] as Map<String, dynamic>?) ?? json;
    final glass = (json['glass'] as Map<String, dynamic>?) ?? json;

    return AppThemeData(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom Theme',
      isDark: json['isDark'] as bool? ?? true,
      background: _parseColor(colors['background'], const Color(0xFF0B0B0F)),
      surface: _parseColor(colors['surface'], const Color(0xFF141419)),
      primary: _parseColor(colors['primary'], const Color(0xFF7C5CFF)),
      secondary: _parseColor(colors['secondary'], const Color(0xFF987DFF)),
      text: _parseColor(colors['text'], const Color(0xFFFFFFFF)),
      mutedText: _parseColor(colors['mutedText'], const Color(0xFF8E8E99)),
      border: _parseColor(colors['border'], const Color(0xFF24242C)),
      bubbleSent: _parseColor(colors['bubbleSent'], const Color(0xFF7C5CFF)),
      bubbleReceived: _parseColor(colors['bubbleReceived'], const Color(0xFF1E1E28)),
      bubbleSentText: _parseColor(colors['bubbleSentText'], const Color(0xFFFFFFFF)),
      bubbleReceivedText: _parseColor(colors['bubbleReceivedText'], const Color(0xFFE8E8EE)),
      bubbleStyle: BubbleStyle.values.firstWhere(
        (e) => e.name == bubbles['style'] || e.name == json['bubbleStyle'],
        orElse: () => BubbleStyle.rounded,
      ),
      bubbleRadius: (bubbles['radius'] as num?)?.toDouble() ?? (json['bubbleRadius'] as num?)?.toDouble() ?? 16.0,
      bubblePadding: (bubbles['padding'] as num?)?.toDouble() ?? 12.0,
      messageSpacing: (bubbles['messageSpacing'] as num?)?.toDouble() ?? 8.0,
      backgroundType: ChatBackgroundType.values.firstWhere(
        (e) => e.name == bg['type'] || e.name == json['backgroundType'],
        orElse: () => ChatBackgroundType.solid,
      ),
      backgroundValue: (bg['value'] as String?) ?? (json['backgroundValue'] as String?) ?? '#0B0B0F',
      wallpaperOpacity: (bg['opacity'] as num?)?.toDouble() ?? 1.0,
      wallpaperBlur: (bg['blur'] as num?)?.toDouble() ?? 0.0,
      fontFamily: FontFamilyOption.values.firstWhere(
        (e) => e.name == typo['family'] || e.name == json['fontFamily'],
        orElse: () => FontFamilyOption.inter,
      ),
      fontSize: FontSizeOption.values.firstWhere(
        (e) => e.name == typo['size'] || e.name == json['fontSize'],
        orElse: () => FontSizeOption.medium,
      ),
      density: ChatDensity.values.firstWhere(
        (e) => e.name == layout['density'] || e.name == json['density'],
        orElse: () => ChatDensity.comfortable,
      ),
      incomingAnimationStyle: MessageAnimationStyle.values.firstWhere(
        (e) => e.name == anim['incoming'],
        orElse: () => MessageAnimationStyle.fade,
      ),
      outgoingAnimationStyle: MessageAnimationStyle.values.firstWhere(
        (e) => e.name == anim['outgoing'],
        orElse: () => MessageAnimationStyle.softRise,
      ),
      animationSpeed: AnimationSpeed.values.firstWhere(
        (e) => e.name == anim['speed'],
        orElse: () => AnimationSpeed.normal,
      ),
      animationIntensity: AnimationIntensity.values.firstWhere(
        (e) => e.name == anim['intensity'],
        orElse: () => AnimationIntensity.subtle,
      ),
      avatarShape: AvatarShape.values.firstWhere(
        (e) => e.name == av['shape'],
        orElse: () => AvatarShape.circle,
      ),
      avatarSize: (av['size'] as num?)?.toDouble() ?? 42.0,
      showAvatarBorder: av['border'] as bool? ?? false,
      avatarBorderWidth: (av['borderWidth'] as num?)?.toDouble() ?? 1.5,
      avatarBorderColor: _parseColor(av['borderColor'], const Color(0xFF7C5CFF)),
      showAvatarShadow: av['shadow'] as bool? ?? false,
      showAvatars: av['visible'] as bool? ?? json['showAvatars'] as bool? ?? true,
      onlineIndicatorStyle: OnlineIndicatorStyle.values.firstWhere(
        (e) => e.name == online['style'],
        orElse: () => OnlineIndicatorStyle.dot,
      ),
      onlineIndicatorColor: _parseColor(online['color'], const Color(0xFF10B981)),
      onlineIndicatorSize: (online['size'] as num?)?.toDouble() ?? 10.0,
      timestampFormat: TimestampFormat.values.firstWhere(
        (e) => e.name == ts['format'],
        orElse: () => TimestampFormat.standard12,
      ),
      timestampVisibility: TimestampVisibility.values.firstWhere(
        (e) => e.name == ts['visibility'],
        orElse: () => TimestampVisibility.always,
      ),
      timestampPosition: TimestampPosition.values.firstWhere(
        (e) => e.name == ts['position'],
        orElse: () => TimestampPosition.bottomRight,
      ),
      timestampOpacity: (ts['opacity'] as num?)?.toDouble() ?? 0.65,
      timestampSize: (ts['size'] as num?)?.toDouble() ?? 11.0,
      showTimestamps: ts['visible'] as bool? ?? json['showTimestamps'] as bool? ?? true,
      typingIndicatorStyle: TypingIndicatorStyle.values.firstWhere(
        (e) => e.name == typing['style'],
        orElse: () => TypingIndicatorStyle.compactDots,
      ),
      typingAnimation: TypingAnimation.values.firstWhere(
        (e) => e.name == typing['animation'],
        orElse: () => TypingAnimation.bounce,
      ),
      typingIndicatorColor: _parseColor(typing['color'], const Color(0xFF7C5CFF)),
      readReceiptStyle: ReadReceiptStyle.values.firstWhere(
        (e) => e.name == rr['style'],
        orElse: () => ReadReceiptStyle.doubleCheck,
      ),
      readReceiptSentColor: _parseColor(rr['sentColor'], const Color(0xFF8E8E9A)),
      readReceiptDeliveredColor: _parseColor(rr['deliveredColor'], const Color(0xFF8E8E9A)),
      readReceiptReadColor: _parseColor(rr['readColor'], const Color(0xFF0A84FF)),
      navigationStyle: NavigationStyle.values.firstWhere(
        (e) => e.name == nav['style'],
        orElse: () => NavigationStyle.bottomNav,
      ),
      iconStyle: IconStyleOption.values.firstWhere(
        (e) => e.name == nav['iconStyle'],
        orElse: () => IconStyleOption.rounded,
      ),
      showNavLabels: nav['showLabels'] as bool? ?? true,
      voiceWaveformStyle: VoiceWaveformStyle.values.firstWhere(
        (e) => e.name == voice['waveformStyle'],
        orElse: () => VoiceWaveformStyle.wave,
      ),
      voiceWaveformThickness: (voice['thickness'] as num?)?.toDouble() ?? 3.0,
      voiceAccentColor: _parseColor(voice['accentColor'], const Color(0xFF7C5CFF)),
      voicePlaybackSpeed: (voice['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      messageEffectsEnabled: fx['enabled'] as bool? ?? true,
      messageEffectType: MessageEffectType.values.firstWhere(
        (e) => e.name == fx['type'],
        orElse: () => MessageEffectType.celebration,
      ),
      soundPreset: SoundPreset.values.firstWhere(
        (e) => e.name == snd['preset'],
        orElse: () => SoundPreset.softPop,
      ),
      incomingSound: snd['incoming'] as String? ?? 'pop',
      outgoingSound: snd['outgoing'] as String? ?? 'swoosh',
      soundsEnabled: snd['enabled'] as bool? ?? true,
      notificationStyle: NotificationStyle.values.firstWhere(
        (e) => e.name == layout['notification'] || e.name == json['notificationStyle'],
        orElse: () => NotificationStyle.floatingCard,
      ),
      searchBarStyle: SearchBarStyle.values.firstWhere(
        (e) => e.name == layout['searchBar'],
        orElse: () => SearchBarStyle.rounded,
      ),
      homeLayout: HomeScreenLayout.values.firstWhere(
        (e) => e.name == layout['homeLayout'],
        orElse: () => HomeScreenLayout.classic,
      ),
      appLockStyle: AppLockStyle.values.firstWhere(
        (e) => e.name == layout['appLock'],
        orElse: () => AppLockStyle.none,
      ),
      glassIntensity: (glass['intensity'] as num?)?.toDouble() ?? (json['glassIntensity'] as num?)?.toDouble() ?? 0.20,
      glassBlur: (glass['blur'] as num?)?.toDouble() ?? (json['glassBlur'] as num?)?.toDouble() ?? 16.0,
      glassTransparency: (glass['transparency'] as num?)?.toDouble() ?? (json['glassTransparency'] as num?)?.toDouble() ?? 0.30,
      glassBorderOpacity: (glass['borderOpacity'] as num?)?.toDouble() ?? (json['glassBorderOpacity'] as num?)?.toDouble() ?? 0.25,
      glassShadowIntensity: (glass['shadowIntensity'] as num?)?.toDouble() ?? (json['glassShadowIntensity'] as num?)?.toDouble() ?? 0.20,
      surfaceBrightness: (glass['surfaceBrightness'] as num?)?.toDouble() ?? (json['surfaceBrightness'] as num?)?.toDouble() ?? 0.50,
    );
  }
}
