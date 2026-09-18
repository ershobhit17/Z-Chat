import 'dart:convert';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../screens/profile/post_detail_screen.dart';
import '../theme/app_theme_data.dart';
import 'app_icon.dart';
import 'link_preview_widget.dart';

class ChatBubbleWidget extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final AppThemeData theme;
  final Function(ChatMessage)? onReply;
  final Function(String, String)? onReact;
  final Function(ChatMessage)? onEdit;
  final Function(ChatMessage, bool)? onDelete;
  final Function(ChatMessage)? onRetry;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.theme,
    this.onReply,
    this.onReact,
    this.onEdit,
    this.onDelete,
    this.onRetry,
  });

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double _playbackSpeed = 1.0;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Configure audio
    if (widget.message.isAudio) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = state == PlayerState.playing;
          });
        }
      });
      _audioPlayer.onPositionChanged.listen((pos) {
        if (mounted) {
          setState(() {
            _audioPosition = pos;
          });
        }
      });
      _audioPlayer.onDurationChanged.listen((dur) {
        if (mounted) {
          setState(() {
            _audioDuration = dur;
          });
        }
      });
    }

    // Animation Duration based on token
    final durationMs = switch (widget.theme.animationSpeed) {
      AnimationSpeed.fast => 180,
      AnimationSpeed.normal => 280,
      AnimationSpeed.smooth => 420,
      AnimationSpeed.cinematic => 650,
    };

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    final intensityFactor = switch (widget.theme.animationIntensity) {
      AnimationIntensity.subtle => 0.5,
      AnimationIntensity.medium => 1.0,
      AnimationIntensity.vibrant => 1.5,
    };

    final animStyle = widget.isMe
        ? widget.theme.outgoingAnimationStyle
        : widget.theme.incomingAnimationStyle;

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    final slideX = widget.isMe ? 0.2 * intensityFactor : -0.2 * intensityFactor;
    final slideY = animStyle == MessageAnimationStyle.softRise ? 0.3 * intensityFactor : 0.0;

    _slideAnimation = Tween<Offset>(
      begin: Offset(slideX, slideY),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: animStyle == MessageAnimationStyle.elastic
            ? Curves.elasticOut
            : Curves.easeOutCubic,
      ),
    );

    final scaleStart = animStyle == MessageAnimationStyle.pop ? 0.6 : 0.9;
    _scaleAnimation = Tween<double>(begin: scaleStart, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: animStyle == MessageAnimationStyle.elastic
            ? Curves.elasticOut
            : Curves.easeOutBack,
      ),
    );

    if (animStyle != MessageAnimationStyle.none) {
      _animController.forward();
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 0.5;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _toggleAudioPlay() async {
    final path = widget.message.attachments.isNotEmpty
        ? widget.message.attachments.first.storagePath
        : widget.message.content;

    if (path == null || path.isEmpty) return;

    if (_isPlayingAudio) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(path));
    }
  }

  String? _getMediaUrl() {
    if (widget.message.attachments.isNotEmpty) {
      return widget.message.attachments.first.storagePath;
    }
    return widget.message.content;
  }

  void _downloadMedia({String? customUrl}) async {
    final url = customUrl ?? _getMediaUrl();
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening file for download / viewing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download file: $e')),
        );
      }
    }
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Reactions Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: widget.theme.background,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: widget.theme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['❤️', '👍', '😂', '🔥', '😮', '😢'].map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onReact?.call(widget.message.id, emoji);
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: AppIcon(Icons.reply_rounded, color: widget.theme.text, theme: widget.theme),
                  title: Text('Reply', style: TextStyle(color: widget.theme.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onReply?.call(widget.message);
                  },
                ),
                if (widget.message.content != null && widget.message.isText)
                  ListTile(
                    leading: AppIcon(Icons.copy_rounded, color: widget.theme.text, theme: widget.theme),
                    title: Text('Copy Text', style: TextStyle(color: widget.theme.text)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.message.content!));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                if (!widget.message.isText && _getMediaUrl() != null)
                  ListTile(
                    leading: Icon(Icons.file_download_rounded, color: widget.theme.primary),
                    title: Text('Download / Save', style: TextStyle(color: widget.theme.text, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _downloadMedia();
                    },
                  ),
                if (widget.isMe && widget.message.isText)
                  ListTile(
                    leading: AppIcon(Icons.edit_rounded, color: widget.theme.text, theme: widget.theme),
                    title: Text('Edit Message', style: TextStyle(color: widget.theme.text)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onEdit?.call(widget.message);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.surface,
        title: Text('Delete message?', style: TextStyle(color: widget.theme.text)),
        content: Text('Choose how you want to delete this message.', style: TextStyle(color: widget.theme.mutedText)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete?.call(widget.message, false);
            },
            child: const Text('Delete for me'),
          ),
          if (widget.isMe)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDelete?.call(widget.message, true);
              },
              child: const Text('Delete for everyone', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  BorderRadius _getBubbleBorderRadius() {
    final r = widget.theme.bubbleRadius;
    switch (widget.theme.bubbleStyle) {
      case BubbleStyle.pill:
        return BorderRadius.circular(28);
      case BubbleStyle.sharp:
        return BorderRadius.circular(4);
      case BubbleStyle.classic:
        return BorderRadius.only(
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
          bottomLeft: widget.isMe ? Radius.circular(r) : const Radius.circular(2),
          bottomRight: widget.isMe ? const Radius.circular(2) : Radius.circular(r),
        );
      case BubbleStyle.glass:
        return BorderRadius.only(
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
          bottomLeft: widget.isMe ? Radius.circular(r) : const Radius.circular(6),
          bottomRight: widget.isMe ? const Radius.circular(6) : Radius.circular(r),
        );
      case BubbleStyle.minimal:
      case BubbleStyle.rounded:
        return BorderRadius.circular(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isMe = widget.isMe;

    if (widget.message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border.withValues(alpha: 0.5)),
            ),
            child: Text(
              '🚫 This message was deleted',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.mutedText,
              ),
            ),
          ),
        ),
      );
    }

    final bubbleBg = isMe ? theme.bubbleSent : theme.bubbleReceived;
    final bubbleTextColor = isMe ? theme.bubbleSentText : theme.bubbleReceivedText;

    // Density padding
    final verticalPadding = switch (theme.density) {
      ChatDensity.compact => 2.0,
      ChatDensity.comfortable => 5.0,
      ChatDensity.spacious => 9.0,
    };

    final contentPadding = switch (theme.density) {
      ChatDensity.compact => const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ChatDensity.comfortable => const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ChatDensity.spacious => const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    };

    final animStyle = isMe ? theme.outgoingAnimationStyle : theme.incomingAnimationStyle;
    final bool disableAnim = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget bubbleWidget = Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bubble Container
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActionsMenu(context),
              onSecondaryTap: () => _showActionsMenu(context),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _buildBubbleBody(
                    context: context,
                    bubbleBg: bubbleBg,
                    bubbleTextColor: bubbleTextColor,
                    contentPadding: contentPadding,
                    isMe: isMe,
                  ),

                  // Message Reactions Row
                  if (widget.message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Wrap(
                        spacing: 4,
                        children: _buildReactionBadges(theme),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (disableAnim || animStyle == MessageAnimationStyle.none) {
      return bubbleWidget;
    }

    // Apply animation transitions
    switch (animStyle) {
      case MessageAnimationStyle.fade:
        return FadeTransition(opacity: _fadeAnimation, child: bubbleWidget);
      case MessageAnimationStyle.slide:
      case MessageAnimationStyle.softRise:
      case MessageAnimationStyle.elastic:
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(opacity: _fadeAnimation, child: bubbleWidget),
        );
      case MessageAnimationStyle.scale:
      case MessageAnimationStyle.pop:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(opacity: _fadeAnimation, child: bubbleWidget),
        );
      case MessageAnimationStyle.blurClear:
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Opacity(
              opacity: _animController.value.clamp(0.0, 1.0),
              child: child,
            );
          },
          child: bubbleWidget,
        );
      default:
        return FadeTransition(opacity: _fadeAnimation, child: bubbleWidget);
    }
  }

  Widget _buildBubbleBody({
    required BuildContext context,
    required Color bubbleBg,
    required Color bubbleTextColor,
    required EdgeInsets contentPadding,
    required bool isMe,
  }) {
    final theme = widget.theme;

    // Minimal style has no background card, just clean text with an accent line
    if (theme.bubbleStyle == BubbleStyle.minimal) {
      return Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: contentPadding,
        decoration: BoxDecoration(
          border: Border(
            left: !isMe ? BorderSide(color: theme.primary, width: 3) : BorderSide.none,
            right: isMe ? BorderSide(color: theme.primary, width: 3) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildReplyPreview(bubbleTextColor),
            _buildMessageContent(bubbleTextColor),
            if (theme.timestampPosition != TimestampPosition.belowMessage)
              _buildTimestamp(bubbleTextColor),
          ],
        ),
      );
    }

    // Real iPhone iOS Liquid Frosted Glass style
    if (theme.bubbleStyle == BubbleStyle.glass) {
      // Use theme glass tokens so Liquid Glass Studio sliders actually work
      final blurSigma = theme.glassBlur.clamp(0.5, 40.0);
      final glassAlpha = (theme.glassIntensity * 0.8).clamp(0.05, 0.90);
      final transparencyAlpha = (theme.glassTransparency).clamp(0.05, 0.95);
      final borderAlpha = (theme.glassBorderOpacity).clamp(0.05, 0.95);

      final glassBg = isMe
          ? bubbleBg.withValues(alpha: glassAlpha)
          : (theme.isDark
              ? Colors.white.withValues(alpha: (glassAlpha * 0.28).clamp(0.05, 0.50))
              : Colors.white.withValues(alpha: (transparencyAlpha * 1.5).clamp(0.30, 0.95)));

      final glassBorderColor = isMe
          ? Colors.white.withValues(alpha: (borderAlpha * 0.8).clamp(0.05, 0.70))
          : (theme.isDark
              ? Colors.white.withValues(alpha: (borderAlpha * 0.45).clamp(0.05, 0.60))
              : Colors.black.withValues(alpha: (borderAlpha * 0.20).clamp(0.02, 0.30)));

      final highlightAlpha = isMe
          ? (glassAlpha * 0.65).clamp(0.05, 0.70)
          : (theme.isDark ? (glassAlpha * 0.35).clamp(0.05, 0.50) : (transparencyAlpha * 0.80).clamp(0.10, 0.80));

      return ClipRRect(
        borderRadius: _getBubbleBorderRadius(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
            padding: contentPadding,
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: _getBubbleBorderRadius(),
              border: Border.all(
                color: glassBorderColor,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? bubbleBg.withValues(alpha: (theme.glassShadowIntensity * 0.5).clamp(0.05, 0.40))
                      : Colors.black.withValues(alpha: (theme.glassShadowIntensity * 0.35).clamp(0.05, 0.35)),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: highlightAlpha),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildReplyPreview(bubbleTextColor),
                _buildMessageContent(bubbleTextColor),
                if (theme.timestampPosition != TimestampPosition.belowMessage)
                  _buildTimestamp(bubbleTextColor),
              ],
            ),
          ),
        ),
      );
    }

    // Classic, Rounded, Pill, Sharp
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
      padding: contentPadding,
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: _getBubbleBorderRadius(),
        border: Border.all(
          color: theme.isDark ? theme.border.withValues(alpha: 0.4) : Colors.transparent,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildReplyPreview(bubbleTextColor),
          _buildMessageContent(bubbleTextColor),
          if (theme.timestampPosition != TimestampPosition.belowMessage)
            _buildTimestamp(bubbleTextColor),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(Color textColor) {
    final reply = widget.message.replyMessage;
    if (reply == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: widget.theme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderProfile?.displayName ?? 'Original Message',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.theme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.content ?? 'Attachment',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Color textColor) {
    if (widget.message.isImage) {
      final imgUrl = widget.message.attachments.isNotEmpty
          ? widget.message.attachments.first.storagePath
          : widget.message.content;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imgUrl != null)
            GestureDetector(
              onTap: () => _showFullScreenImage(context, imgUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 150,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Center(child: Icon(Icons.broken_image_rounded)),
                  ),
                ),
              ),
            ),
          if (widget.message.content != null && widget.message.content != imgUrl)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                widget.message.content!,
                style: widget.theme.getTextStyle(color: textColor, baseSize: 15.0),
              ),
            ),
        ],
      );
    }

    if (widget.message.isVideo) {
      final videoUrl = widget.message.attachments.isNotEmpty
          ? widget.message.attachments.first.storagePath
          : widget.message.content;
      final attachment = widget.message.attachments.isNotEmpty ? widget.message.attachments.first : null;
      final fileName = attachment?.fileName ?? 'Video attachment';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              if (videoUrl != null && videoUrl.isNotEmpty) {
                launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 250,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1B1B26),
                          widget.theme.primary.withValues(alpha: 0.25),
                          const Color(0xFF0D0D14),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_rounded, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  fileName,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (attachment?.fileSize != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _formatFileSize(attachment!.fileSize),
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _downloadMedia(customUrl: videoUrl),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.file_download_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.message.content != null && widget.message.content != videoUrl)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                widget.message.content!,
                style: widget.theme.getTextStyle(color: textColor, baseSize: 15.0),
              ),
            ),
        ],
      );
    }

    if (widget.message.isAudio) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                size: 36,
                color: widget.theme.voiceAccentColor.toARGB32() != widget.theme.primary.toARGB32()
                    ? widget.theme.voiceAccentColor
                    : textColor,
              ),
              onPressed: _toggleAudioPlay,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWaveform(textColor),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_audioPosition),
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _cyclePlaybackSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.message.isFile) {
      final attachment = widget.message.attachments.isNotEmpty ? widget.message.attachments.first : null;
      final fileUrl = attachment?.storagePath ?? widget.message.content;

      return InkWell(
        onTap: () {
          if (fileUrl != null && fileUrl.isNotEmpty) {
            launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.insert_drive_file_rounded, color: textColor),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment?.fileName ?? 'File attachment',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(attachment?.fileSize),
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download_rounded, size: 16, color: textColor),
            ),
          ],
        ),
      );
    }

    if (widget.message.isSharedPost) {
      Map<String, dynamic> data = {};
      try {
        if (widget.message.content != null) {
          data = jsonDecode(widget.message.content!);
        }
      } catch (_) {}

      final authorName = data['authorName'] as String? ?? 'User';
      final caption = data['caption'] as String? ?? '';
      final thumbnailUrl = data['thumbnailUrl'] as String?;
      final postId = data['postId'] as String? ?? '';

      return InkWell(
        onTap: () {
          if (postId.isNotEmpty) {
            final mockPost = Post(
              id: postId,
              userId: '',
              caption: caption,
              createdAt: widget.message.createdAt,
              updatedAt: widget.message.createdAt,
              media: thumbnailUrl != null
                  ? [
                      PostMedia(
                        id: '',
                        postId: postId,
                        userId: '',
                        objectKey: '',
                        mediaUrl: thumbnailUrl,
                        mediaType: (data['mediaType'] as String?) ?? 'image',
                        createdAt: widget.message.createdAt,
                      )
                    ]
                  : [],
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: mockPost)),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withAlpha(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.withAlpha(30),
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                        // Show play icon for video shared posts
                        if ((data['mediaType'] as String?) == 'video')
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.share_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Shared post by $authorName',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: textColor.withAlpha(200)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.message.isYouTube) {
      Map<String, dynamic> data = {};
      try {
        if (widget.message.content != null) {
          data = jsonDecode(widget.message.content!);
        }
      } catch (_) {}

      final title = data['title'] as String? ?? 'YouTube Video';
      final channelTitle = data['channelTitle'] as String? ?? '';
      final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
      final watchUrl = data['watchUrl'] as String? ?? '';

      return InkWell(
        onTap: () {
          if (watchUrl.isNotEmpty) {
            launchUrl(Uri.parse(watchUrl), mode: LaunchMode.inAppBrowserView);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnailUrl.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(Icons.video_library_rounded, color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('YouTube', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        if (channelTitle.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              channelTitle,
                              style: TextStyle(fontSize: 11, color: textColor.withAlpha(180)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildTextMessage(widget.message.content ?? '', textColor);
  }

  Widget _buildTextMessage(String content, Color textColor) {
    if (content.isEmpty) return const SizedBox.shrink();

    final urlRegex = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)', caseSensitive: false);
    final matches = urlRegex.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: widget.theme.getTextStyle(color: textColor, baseSize: 15.0),
      );
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;
    String? firstUrl;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: content.substring(currentIndex, match.start),
          style: widget.theme.getTextStyle(color: textColor, baseSize: 15.0),
        ));
      }

      final rawUrl = match.group(0)!;
      firstUrl ??= rawUrl;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () {
              String target = rawUrl;
              while (target.isNotEmpty &&
                  (target.endsWith('.') || target.endsWith(',') || target.endsWith(')') || target.endsWith('!'))) {
                target = target.substring(0, target.length - 1);
              }
              final schemeCheck = Uri.tryParse(target);
              if (schemeCheck != null && schemeCheck.hasScheme && schemeCheck.scheme != 'http' && schemeCheck.scheme != 'https') {
                return;
              }
              if (!target.startsWith('http://') && !target.startsWith('https://')) {
                target = 'https://$target';
              }
              final uri = Uri.tryParse(target);
              if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              rawUrl,
              style: widget.theme.getTextStyle(
                color: widget.isMe ? Colors.white : widget.theme.primary,
                baseSize: 15.0,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: widget.theme.getTextStyle(color: textColor, baseSize: 15.0),
      ));
    }

    return Column(
      crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(TextSpan(children: spans)),
        if (firstUrl != null)
          LinkPreviewWidget(
            rawUrl: firstUrl,
            theme: widget.theme,
            isMe: widget.isMe,
          ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 40,
              right: 76,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Save / Download Image',
                  icon: const Icon(Icons.file_download_rounded, color: Colors.white),
                  onPressed: () => _downloadMedia(customUrl: imageUrl),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaveform(Color textColor) {
    final progress = _audioDuration.inMilliseconds > 0
        ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final accent = widget.theme.voiceAccentColor;
    final thickness = widget.theme.voiceWaveformThickness;

    switch (widget.theme.voiceWaveformStyle) {
      case VoiceWaveformStyle.bars:
        // Render 16 vertical soundwave bars
        return SizedBox(
          width: 130,
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(16, (index) {
              final barProgress = index / 16.0;
              final isPlayed = barProgress <= progress;
              // Procedural harmonic heights
              final heights = [10.0, 16.0, 22.0, 14.0, 8.0, 18.0, 24.0, 12.0, 16.0, 20.0, 10.0, 14.0, 18.0, 8.0, 12.0, 6.0];
              final barHeight = heights[index % heights.length];

              return Container(
                width: thickness * 1.2,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isPlayed ? accent : textColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(thickness),
                ),
              );
            }),
          ),
        );

      case VoiceWaveformStyle.dotProgress:
        return SizedBox(
          width: 130,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (index) {
              final dotProgress = index / 12.0;
              final isPlayed = dotProgress <= progress;
              return Container(
                width: thickness * 2.0,
                height: thickness * 2.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlayed ? accent : textColor.withValues(alpha: 0.25),
                ),
              );
            }),
          ),
        );

      case VoiceWaveformStyle.minimalLine:
      case VoiceWaveformStyle.wave:
        return Container(
          width: 130,
          height: thickness * 2.0,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(thickness),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(thickness),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildTimestamp(Color textColor) {
    if (!widget.theme.showTimestamps) return const SizedBox.shrink();

    final timeStr = _formatTimestamp(widget.message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: widget.theme.timestampPosition == TimestampPosition.bottomLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (widget.message.isEdited)
            Text(
              'edited • ',
              style: TextStyle(
                fontSize: widget.theme.timestampSize - 2,
                fontStyle: FontStyle.italic,
                color: textColor.withValues(alpha: widget.theme.timestampOpacity * 0.7),
              ),
            ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: widget.theme.timestampSize,
              color: textColor.withValues(alpha: widget.theme.timestampOpacity),
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 4),
            _buildReadReceiptIcon(textColor),
          ],
        ],
      ),
    );
  }

  Widget _buildReadReceiptIcon(Color textColor) {
    final status = widget.message.status;

    if (status == MessageStatus.sending) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: textColor.withValues(alpha: 0.6),
        ),
      );
    }

    if (status == MessageStatus.failed) {
      return InkWell(
        onTap: () => widget.onRetry?.call(widget.message),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 13, color: Colors.redAccent),
            const SizedBox(width: 3),
            Text(
              'Retry',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: (widget.theme.timestampSize - 1).clamp(9.0, 13.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    Color iconColor;

    if (status == MessageStatus.read) {
      iconColor = widget.theme.readReceiptReadColor;
    } else if (status == MessageStatus.delivered) {
      iconColor = widget.theme.readReceiptDeliveredColor;
    } else {
      iconColor = widget.theme.readReceiptSentColor;
    }

    switch (widget.theme.readReceiptStyle) {
      case ReadReceiptStyle.doubleCheck:
      case ReadReceiptStyle.singleCheck:
        final iconData = status == MessageStatus.sent
            ? Icons.done_rounded
            : Icons.done_all_rounded;
        return Icon(iconData, size: 14, color: iconColor);
      case ReadReceiptStyle.dots:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            ),
            if (status != MessageStatus.sent) ...[
              const SizedBox(width: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              ),
            ],
          ],
        );
      case ReadReceiptStyle.minimalCheck:
        return Icon(
          status == MessageStatus.read
              ? Icons.check_circle_rounded
              : (status == MessageStatus.delivered ? Icons.done_all_rounded : Icons.done_rounded),
          size: 13,
          color: iconColor,
        );
    }
  }

  String _formatTimestamp(DateTime dt) {
    // Supabase stores all timestamps in UTC. Convert to local time for display.
    final local = dt.isUtc ? dt.toLocal() : dt;
    switch (widget.theme.timestampFormat) {
      case TimestampFormat.standard24:
        return DateFormat('HH:mm').format(local);
      case TimestampFormat.timeOnly:
        return DateFormat('h:mm').format(local);
      case TimestampFormat.fullWithDay:
        return DateFormat('E, h:mm a').format(local);
      case TimestampFormat.relative:
        final diff = DateTime.now().difference(local);
        if (diff.inMinutes < 1) return 'now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        return DateFormat('MMM d').format(local);
      case TimestampFormat.standard12:
        return DateFormat('h:mm a').format(local);
    }
  }

  List<Widget> _buildReactionBadges(AppThemeData theme) {
    final Map<String, int> counts = {};
    for (final r in widget.message.reactions) {
      counts[r.reaction] = (counts[r.reaction] ?? 0) + 1;
    }

    return counts.entries.map((e) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Text(
          '${e.key} ${e.value}',
          style: const TextStyle(fontSize: 11),
        ),
      );
    }).toList();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
