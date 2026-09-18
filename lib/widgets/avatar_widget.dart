import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/media_storage_service.dart';
import '../theme/theme_provider.dart';
import 'profile_picture_viewer.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double? size;
  final bool isOnline;
  final bool showOnlineIndicator;
  final Color? backgroundColor;
  final AvatarShape? overrideShape;
  final OnlineIndicatorStyle? overrideIndicatorStyle;
  final AppThemeData? theme;
  final VoidCallback? onTap;
  final bool enablePreviewOnTap;
  final String? username;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.displayName,
    this.size,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.backgroundColor,
    this.overrideShape,
    this.overrideIndicatorStyle,
    this.theme,
    this.onTap,
    this.enablePreviewOnTap = false,
    this.username,
  });

  String _getInitials() {
    if (displayName.trim().isEmpty) return '?';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.trim().substring(0, displayName.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  BorderRadius _getBorderRadius(AvatarShape shape, double effectiveSize) {
    return switch (shape) {
      AvatarShape.circle => BorderRadius.circular(effectiveSize / 2),
      AvatarShape.roundedSquare => BorderRadius.circular(effectiveSize * 0.22),
      AvatarShape.squircle => BorderRadius.circular(effectiveSize * 0.38),
      AvatarShape.hexagon => BorderRadius.circular(effectiveSize * 0.28),
    };
  }

  @override
  Widget build(BuildContext context) {
    AppThemeData activeTheme;
    if (theme != null) {
      activeTheme = theme!;
    } else {
      try {
        final provider = Provider.of<ThemeProvider?>(context);
        activeTheme = provider?.theme ?? AppThemeData.midnight;
      } catch (_) {
        activeTheme = AppThemeData.midnight;
      }
    }
    final effectiveSize = size ?? activeTheme.avatarSize;
    final shape = overrideShape ?? activeTheme.avatarShape;
    final indicatorStyle = overrideIndicatorStyle ?? activeTheme.onlineIndicatorStyle;
    final fallbackColor = backgroundColor ?? activeTheme.primary.withValues(alpha: 0.18);
    final textColor = activeTheme.primary;
    final borderRadius = _getBorderRadius(shape, effectiveSize);

    Widget avatarContent = Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: borderRadius,
        border: activeTheme.showAvatarBorder
            ? Border.all(
                color: activeTheme.avatarBorderColor,
                width: activeTheme.avatarBorderWidth,
              )
            : null,
        boxShadow: activeTheme.showAvatarShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                ImageKitStorageService.getTransformedUrl(
                  avatarUrl,
                  width: (effectiveSize * 2.5).toInt().clamp(64, 300),
                  height: (effectiveSize * 2.5).toInt().clamp(64, 300),
                ),
                fit: BoxFit.cover,
                cacheWidth: (effectiveSize * 2.5).toInt().clamp(64, 300),
                cacheHeight: (effectiveSize * 2.5).toInt().clamp(64, 300),
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      fontSize: effectiveSize * 0.38,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _getInitials(),
                  style: TextStyle(
                    fontSize: effectiveSize * 0.38,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
      ),
    );

    final result = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildOnlineIndicator(activeTheme, indicatorStyle, effectiveSize),
          ),
      ],
    );

    if (onTap != null || enablePreviewOnTap) {
      return GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else if (enablePreviewOnTap) {
            showProfilePictureViewer(
              context,
              avatarUrl: avatarUrl,
              displayName: displayName,
              username: username,
            );
          }
        },
        child: result,
      );
    }

    return result;
  }

  Widget _buildOnlineIndicator(AppThemeData theme, OnlineIndicatorStyle style, double effectiveSize) {
    final dotSize = theme.onlineIndicatorSize.clamp(8.0, 16.0);
    final color = theme.onlineIndicatorColor;

    switch (style) {
      case OnlineIndicatorStyle.dot:
        return Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.background,
              width: 1.8,
            ),
          ),
        );

      case OnlineIndicatorStyle.ring:
        return Container(
          width: dotSize + 2,
          height: dotSize + 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.background,
            border: Border.all(
              color: color,
              width: 2.2,
            ),
          ),
          child: Center(
            child: Container(
              width: dotSize * 0.45,
              height: dotSize * 0.45,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

      case OnlineIndicatorStyle.pulse:
      case OnlineIndicatorStyle.glow:
        return Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.background,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1.5,
              ),
            ],
          ),
        );
    }
  }
}

