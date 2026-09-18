import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// YouTube service — uses a secure Supabase Edge Function as backend proxy.
/// The YouTube API key is stored as a Supabase secret and NEVER included
/// in the Flutter client bundle.
class YouTubeService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  // In-memory cache: query → (results, timestamp)
  final Map<String, _SearchCacheEntry> _searchCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  YouTubeService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  // Extract YouTube video ID from various link formats
  static String? extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/|youtube\.com\/shorts\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  /// Search YouTube videos via the secure Edge Function backend.
  /// Falls back to curated videos if the Edge Function is unavailable.
  Future<List<YouTubeVideo>> searchVideos(String query, {String? pageToken}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // Check in-memory cache
    final cacheKey = '$cleanQuery::${pageToken ?? ''}';
    final cached = _searchCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.results;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _supabase.functions.invoke(
        'youtube-search',
        body: {
          'query': cleanQuery,
          'max_results': 20,
          'page_token': ?pageToken,
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : jsonDecode(res.data.toString()) as Map<String, dynamic>;

        final rawResults = data['results'] as List<dynamic>? ?? [];
        final results = rawResults
            .cast<Map<String, dynamic>>()
            .map(_videoFromEdgeFunctionJson)
            .toList();

        if (results.isNotEmpty) {
          _searchCache[cacheKey] = _SearchCacheEntry(
            results: results,
            timestamp: DateTime.now(),
            nextPageToken: data['next_page_token'] as String?,
          );
          return results;
        }
      }

      // Edge Function returned an error or empty — use curated fallback
      debugPrint('YouTube Edge Function returned no results, using curated fallback');
      return _getCuratedVideos(cleanQuery);
    } catch (e) {
      debugPrint('YouTube Edge Function error: $e');
      return _getCuratedVideos(cleanQuery);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get the next-page token for the last cached result of a query
  String? getNextPageToken(String query) {
    final cacheKey = '$query::';
    return _searchCache[cacheKey]?.nextPageToken;
  }

  YouTubeVideo _videoFromEdgeFunctionJson(Map<String, dynamic> json) {
    final videoId = json['video_id'] as String? ?? '';
    return YouTubeVideo(
      id: videoId,
      title: json['title'] as String? ?? 'YouTube Video',
      description: '',
      thumbnailUrl: json['thumbnail_url'] as String? ??
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      channelTitle: json['channel_title'] as String? ?? '',
      duration: json['duration'] as String?,
    );
  }

  /// Curated fallback videos shown when the Edge Function is unavailable.
  List<YouTubeVideo> _getCuratedVideos(String query) {
    final q = query.toLowerCase();
    final curated = [
      YouTubeVideo(
        id: 'rfscVS0vtbw',
        title: 'Python for Beginners - Full Course',
        description: 'Learn Python programming',
        thumbnailUrl: 'https://img.youtube.com/vi/rfscVS0vtbw/hqdefault.jpg',
        channelTitle: 'freeCodeCamp.org',
        duration: '4:26:52',
      ),
      YouTubeVideo(
        id: 'VPvVD8t02U8',
        title: 'Flutter in 100 Seconds',
        description: 'What is Flutter?',
        thumbnailUrl: 'https://img.youtube.com/vi/VPvVD8t02U8/hqdefault.jpg',
        channelTitle: 'Fireship',
        duration: '2:18',
      ),
      YouTubeVideo(
        id: 'aircAruvnKk',
        title: 'Neural Networks from Scratch',
        description: 'Build neural networks from math',
        thumbnailUrl: 'https://img.youtube.com/vi/aircAruvnKk/hqdefault.jpg',
        channelTitle: '3Blue1Brown',
        duration: '19:13',
      ),
      YouTubeVideo(
        id: 'W6NZfCO5SIk',
        title: 'JavaScript Tutorial for Beginners',
        description: 'Learn JavaScript',
        thumbnailUrl: 'https://img.youtube.com/vi/W6NZfCO5SIk/hqdefault.jpg',
        channelTitle: 'Programming with Mosh',
        duration: '1:00:33',
      ),
      YouTubeVideo(
        id: 'jS4aFq5-91M',
        title: 'Java Tutorial for Beginners',
        description: 'Learn Java programming',
        thumbnailUrl: 'https://img.youtube.com/vi/jS4aFq5-91M/hqdefault.jpg',
        channelTitle: 'Programming with Mosh',
        duration: '2:30:29',
      ),
    ];

    final matched = curated
        .where((v) =>
            v.title.toLowerCase().contains(q) ||
            v.channelTitle.toLowerCase().contains(q))
        .toList();

    return matched.isNotEmpty ? matched : curated;
  }

  /// Play YouTube video using native YouTube app or browser fallback.
  Future<void> playVideo(String videoId) async {
    final appUrl = Uri.parse('vnd.youtube:$videoId');
    final webUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(webUrl, mode: LaunchMode.platformDefault);
    }
  }

  /// Share YouTube video directly into a Z Chat conversation.
  Future<void> shareVideoToConversation({
    required YouTubeVideo video,
    required String conversationId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    final payload = jsonEncode({
      'videoId': video.id,
      'title': video.title,
      'channelTitle': video.channelTitle,
      'thumbnailUrl': video.thumbnailUrl,
      'watchUrl': video.watchUrl,
    });

    await _supabase.from('messages').insert({
      'id': _uuid.v4(),
      'conversation_id': conversationId,
      'sender_id': uid,
      'message_type': 'youtube',
      'content': payload,
    });
  }

  /// Clear local search cache (e.g., on logout).
  void clearCache() {
    _searchCache.clear();
  }
}

class _SearchCacheEntry {
  final List<YouTubeVideo> results;
  final DateTime timestamp;
  final String? nextPageToken;

  _SearchCacheEntry({
    required this.results,
    required this.timestamp,
    this.nextPageToken,
  });
}
