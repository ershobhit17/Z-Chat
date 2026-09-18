import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme_data.dart';

class ChatBackgroundContainer extends StatelessWidget {
  final AppThemeData theme;
  final Widget child;

  const ChatBackgroundContainer({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bgVal = theme.backgroundValue;
    final isGlass = theme.bubbleStyle == BubbleStyle.glass;

    // Check if background is an atmospheric preset or glass mode
    final isMesh = theme.backgroundType == ChatBackgroundType.mesh ||
        isGlass ||
        bgVal.startsWith('ios_') ||
        bgVal.startsWith('mesh_') ||
        bgVal.startsWith('aurora_') ||
        bgVal.startsWith('nebula_');

    Widget backgroundWidget;

    if (theme.backgroundType == ChatBackgroundType.gradient) {
      backgroundWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primary.withValues(alpha: theme.isDark ? 0.22 : 0.12),
              theme.background,
              theme.secondary.withValues(alpha: theme.isDark ? 0.18 : 0.10),
            ],
          ),
        ),
      );
    } else if (theme.backgroundType == ChatBackgroundType.image && bgVal.isNotEmpty) {
      final isNet = bgVal.startsWith('http') || bgVal.startsWith('data:');
      final isLocal = !isNet && !kIsWeb && io.File(bgVal).existsSync();

      Widget img;
      if (isNet) {
        img = Image.network(
          bgVal,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: theme.background),
        );
      } else if (isLocal) {
        img = Image.file(
          io.File(bgVal),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: theme.background),
        );
      } else {
        img = Container(color: theme.background);
      }

      backgroundWidget = Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: theme.wallpaperOpacity.clamp(0.1, 1.0),
              child: img,
            ),
          ),
          if (theme.wallpaperBlur > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: theme.wallpaperBlur,
                  sigmaY: theme.wallpaperBlur,
                ),
                child: Container(color: Colors.transparent),
              ),
            ),
          // Contrast overlay for text readability
          Positioned.fill(
            child: Container(
              color: theme.background.withValues(
                alpha: theme.isDark ? 0.45 : 0.25,
              ),
            ),
          ),
        ],
      );
    } else if (theme.backgroundType == ChatBackgroundType.pattern) {
      backgroundWidget = CustomPaint(
        painter: _DotPatternPainter(
          color: theme.text.withValues(alpha: theme.isDark ? 0.08 : 0.05),
        ),
      );
    } else if (isMesh) {
      backgroundWidget = CustomPaint(
        painter: _AmbientGlowPainter(
          preset: bgVal,
          isDark: theme.isDark,
          primaryColor: theme.primary,
          bubbleSentColor: theme.bubbleSent,
        ),
      );
    } else {
      backgroundWidget = Container(color: theme.background);
    }

    return Container(
      color: theme.background,
      child: Stack(
        children: [
          Positioned.fill(child: backgroundWidget),
          child,
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final Color color;
  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 24.0;
    const radius = 1.2;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) => oldDelegate.color != color;
}

class _AmbientGlowPainter extends CustomPainter {
  final String preset;
  final bool isDark;
  final Color primaryColor;
  final Color bubbleSentColor;

  _AmbientGlowPainter({
    required this.preset,
    required this.isDark,
    required this.primaryColor,
    required this.bubbleSentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (preset.contains('aurora')) {
      // Emerald & Teal Aurora Glows
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.85, size.height * 0.25),
        radius: size.width * 0.75,
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12),
      );
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.15, size.height * 0.65),
        radius: size.width * 0.85,
        color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.20 : 0.14),
      );
    } else if (preset.contains('nebula') || preset.contains('cyber')) {
      // Purple & Magenta Nebula
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.8, size.height * 0.3),
        radius: size.width * 0.8,
        color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.16 : 0.10),
      );
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.2, size.height * 0.7),
        radius: size.width * 0.85,
        color: const Color(0xFF7C5CFF).withValues(alpha: isDark ? 0.22 : 0.14),
      );
    } else {
      // Default Signature iOS Liquid Glass Mesh (Cobalt Blue + Electric Iris)
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.85, size.height * 0.2),
        radius: math.max(size.width * 0.8, 220),
        color: bubbleSentColor.withValues(alpha: isDark ? 0.22 : 0.14),
      );
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.1, size.height * 0.6),
        radius: math.max(size.width * 0.9, 250),
        color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.18 : 0.12),
      );
      _drawGlowOrb(
        canvas,
        center: Offset(size.width * 0.9, size.height * 0.85),
        radius: math.max(size.width * 0.7, 180),
        color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.10),
      );
    }
  }

  void _drawGlowOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) {
    return oldDelegate.preset != preset ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.bubbleSentColor != bubbleSentColor;
  }
}
