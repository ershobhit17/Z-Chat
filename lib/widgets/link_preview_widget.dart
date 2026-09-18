import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme_data.dart';

class LinkPreviewData {
  final String url;
  final String domain;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;

  const LinkPreviewData({
    required this.url,
    required this.domain,
    this.title,
    this.description,
    this.image,
    this.siteName,
  });

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) {
    return LinkPreviewData(
      url: json['url'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      image: json['image'] as String?,
      siteName: json['siteName'] as String?,
    );
  }
}

class LinkPreviewWidget extends StatefulWidget {
  final String rawUrl;
  final AppThemeData theme;
  final bool isMe;

  const LinkPreviewWidget({
    super.key,
    required this.rawUrl,
    required this.theme,
    required this.isMe,
  });

  @override
  State<LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<LinkPreviewWidget> {
  static final Map<String, LinkPreviewData> _previewCache = {};

  LinkPreviewData? _preview;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant LinkPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl) {
      _loadPreview();
    }
  }

  String _cleanUrl(String input) {
    String trimmed = input.trim();
    while (trimmed.isNotEmpty && (trimmed.endsWith('.') || trimmed.endsWith(',') || trimmed.endsWith(')') || trimmed.endsWith('!'))) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  // Fast offline extraction for YouTube
  LinkPreviewData? _tryExtractKnownService(String normalizedUrl) {
    try {
      final uri = Uri.parse(normalizedUrl);
      final host = uri.host.toLowerCase().replaceFirst('www.', '');

      if (host == 'youtube.com' || host == 'm.youtube.com') {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) {
          return LinkPreviewData(
            url: normalizedUrl,
            domain: 'youtube.com',
            title: 'YouTube Video',
            description: 'Watch on YouTube',
            image: 'https://img.youtube.com/vi/$v/hqdefault.jpg',
            siteName: 'YouTube',
          );
        }
      } else if (host == 'youtu.be') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty && pathSegments.first.isNotEmpty) {
          final v = pathSegments.first;
          return LinkPreviewData(
            url: normalizedUrl,
            domain: 'youtu.be',
            title: 'YouTube Video',
            description: 'Watch on YouTube',
            image: 'https://img.youtube.com/vi/$v/hqdefault.jpg',
            siteName: 'YouTube',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadPreview() async {
    final cleaned = _cleanUrl(widget.rawUrl);

    // 1. Check in-memory cache
    if (_previewCache.containsKey(cleaned)) {
      if (mounted) {
        setState(() {
          _preview = _previewCache[cleaned];
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Instant client extraction for known services
    final localKnown = _tryExtractKnownService(cleaned);
    if (localKnown != null) {
      _previewCache[cleaned] = localKnown;
      if (mounted) {
        setState(() {
          _preview = localKnown;
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Asynchronously fetch from SSRF-safe Edge Function
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final edgeUrl = Uri.parse(
        'https://nmjdkxviodpnnconlygg.supabase.co/functions/v1/fetch-link-preview?url=${Uri.encodeComponent(cleaned)}',
      );

      final resp = await http.get(edgeUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final parsed = LinkPreviewData.fromJson(data);
          _previewCache[cleaned] = parsed;
          if (mounted) {
            setState(() {
              _preview = parsed;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Fallback gracefully to domain preview
    }

    // If edge fetch failed or returned partial, create domain fallback
    try {
      final u = Uri.parse(cleaned);
      final fallback = LinkPreviewData(
        url: cleaned,
        domain: u.host.replaceFirst('www.', ''),
        title: u.host.replaceFirst('www.', ''),
      );
      _previewCache[cleaned] = fallback;
      if (mounted) {
        setState(() {
          _preview = fallback;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _launch() {
    final cleaned = _cleanUrl(widget.rawUrl);
    final uri = Uri.tryParse(cleaned);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    final theme = widget.theme;
    final isDark = theme.isDark;
    final preview = _preview;

    final cardBg = widget.isMe
        ? Colors.black.withValues(alpha: 0.18)
        : (isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05));
    final borderColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.22)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08));
    final textColor = widget.isMe ? widget.theme.bubbleSentText : widget.theme.bubbleReceivedText;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launch,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 270),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview Image
                if (preview?.image != null && preview!.image!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      preview.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Domain Chip / Site Name
                      Row(
                        children: [
                          Icon(Icons.link_rounded, size: 13, color: theme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              preview?.domain ?? widget.rawUrl,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isLoading)
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: theme.primary.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),

                      if (preview?.title != null && preview!.title!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview.title!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      if (preview?.description != null && preview!.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
