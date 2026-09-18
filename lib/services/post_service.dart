import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'media_storage_service.dart';

// Helper to fire-and-forget async calls without lint warnings
void _unawaited(Future<dynamic> future) {
  future.catchError((_) {});
}

class PostService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final MediaStorageService _storageService;
  final Uuid _uuid = const Uuid();

  // ── In-memory feed caches with 60 s TTL ──────────────────────────────────
  List<Post>? _followingFeedCache;
  List<Post>? _exploreFeedCache;
  List<Post>? _clipsFeedCache;
  DateTime? _followingCacheTime;
  DateTime? _exploreCacheTime;
  DateTime? _clipsCacheTime;
  static const _cacheTtl = Duration(seconds: 60);

  bool _followingExpired() =>
      _followingCacheTime == null ||
      DateTime.now().difference(_followingCacheTime!) > _cacheTtl;
  bool _exploreExpired() =>
      _exploreCacheTime == null ||
      DateTime.now().difference(_exploreCacheTime!) > _cacheTtl;
  bool _clipsExpired() =>
      _clipsCacheTime == null ||
      DateTime.now().difference(_clipsCacheTime!) > _cacheTtl;

  /// Invalidate all feed caches (call after create/delete post)
  void invalidateCache() {
    _followingFeedCache = null;
    _exploreFeedCache = null;
    _clipsFeedCache = null;
    _followingCacheTime = null;
    _exploreCacheTime = null;
    _clipsCacheTime = null;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PostService({
    SupabaseClient? supabaseClient,
    MediaStorageService? storageService,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _storageService = storageService ?? ImageKitStorageService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // Helper to attach isLikedByMe and isSavedByMe — runs likes & saves in PARALLEL
  Future<List<Post>> _populateLikesAndSaves(List rawList, String? myUid) async {
    final postIds = rawList.map((e) => e['id'] as String).toList();
    final likedPostIds = <String>{};
    final savedPostIds = <String>{};

    if (myUid != null && postIds.isNotEmpty) {
      final results = await Future.wait([
        _supabase
            .from('post_likes')
            .select('post_id')
            .eq('user_id', myUid)
            .inFilter('post_id', postIds)
            .then((r) => r as List)
            .catchError((_) => <dynamic>[]),
        _supabase
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', myUid)
            .inFilter('post_id', postIds)
            .then((r) => r as List)
            .catchError((_) => <dynamic>[]),
      ]);

      for (final item in results[0]) {
        likedPostIds.add(item['post_id'] as String);
      }
      for (final item in results[1]) {
        savedPostIds.add(item['post_id'] as String);
      }
    }

    return rawList.map((json) {
      final pId = json['id'] as String;
      return Post.fromJson(
        json as Map<String, dynamic>,
        isLikedByMe: likedPostIds.contains(pId),
        isSavedByMe: savedPostIds.contains(pId),
      );
    }).toList();
  }

  // Fetch posts for a specific user
  Future<List<Post>> getPostsForUser(String userId, {bool includePrivate = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final myUid = _currentUserId;
      final isMe = myUid == userId;

      var query = _supabase
          .from('posts')
          .select('*, post_media(*), profiles!user_id(*)')
          .eq('user_id', userId);

      if (!isMe || !includePrivate) {
        query = query.eq('visibility', 'public');
      }

      final response = await query.order('created_at', ascending: false);
      final list = response as List;

      return await _populateLikesAndSaves(list, myUid);
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Alias for fetchUserPosts
  Future<List<Post>> fetchUserPosts({required String userId, bool includePrivate = false}) =>
      getPostsForUser(userId, includePrivate: includePrivate);

  // Social Feed: Following Feed (with 60s in-memory cache)
  Future<List<Post>> getFollowingFeed({int limit = 20, int offset = 0, bool forceRefresh = false}) async {
    final myUid = _currentUserId;
    if (myUid == null) return [];

    if (!forceRefresh && offset == 0 && _followingFeedCache != null && !_followingExpired()) {
      return _followingFeedCache!;
    }

    try {
      final followingRes = await _supabase
          .from('follow_relationships')
          .select('following_id')
          .eq('follower_id', myUid)
          .eq('status', 'accepted');

      final followingIds = (followingRes as List)
          .map((e) => e['following_id'] as String)
          .toList();
      followingIds.add(myUid);

      if (followingIds.isEmpty) return [];

      final res = await _supabase
          .from('posts')
          .select('*, post_media(*), profiles!user_id(*)')
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = await _populateLikesAndSaves(res as List, myUid);
      if (offset == 0) {
        _followingFeedCache = posts;
        _followingCacheTime = DateTime.now();
      }
      return posts;
    } catch (e) {
      debugPrint('Error fetching following feed: $e');
      return _followingFeedCache ?? [];
    }
  }

  // Social Feed: Public / Explore Feed (with 60s in-memory cache)
  Future<List<Post>> getPublicFeed({int limit = 20, int offset = 0, bool forceRefresh = false}) async {
    final myUid = _currentUserId;

    if (!forceRefresh && offset == 0 && _exploreFeedCache != null && !_exploreExpired()) {
      return _exploreFeedCache!;
    }

    try {
      final res = await _supabase
          .from('posts')
          .select('*, post_media(*), profiles!user_id(*)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = await _populateLikesAndSaves(res as List, myUid);
      if (offset == 0) {
        _exploreFeedCache = posts;
        _exploreCacheTime = DateTime.now();
      }
      return posts;
    } catch (e) {
      debugPrint('Error fetching public feed: $e');
      return _exploreFeedCache ?? [];
    }
  }

  // Short-form Video Feed: Z Clips (with 60s in-memory cache)
  Future<List<Post>> getZClipsFeed({int limit = 20, int offset = 0, bool forceRefresh = false}) async {
    final myUid = _currentUserId;

    if (!forceRefresh && offset == 0 && _clipsFeedCache != null && !_clipsExpired()) {
      return _clipsFeedCache!;
    }

    try {
      final res = await _supabase
          .from('posts')
          .select('*, post_media!inner(*), profiles!user_id(*)')
          .eq('visibility', 'public')
          .eq('post_media.media_type', 'video')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = await _populateLikesAndSaves(res as List, myUid);
      if (offset == 0) {
        _clipsFeedCache = posts;
        _clipsCacheTime = DateTime.now();
      }
      return posts;
    } catch (e) {
      debugPrint('Error fetching Z Clips feed: $e');
      return _clipsFeedCache ?? [];
    }
  }

  // Check if current user liked a post
  Future<bool> hasUserLikedPost(String postId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final res = await _supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // Toggle like on a post — OPTIMISTIC: UI updates at 0ms, DB write is fire-and-forget
  Future<bool> toggleLike(String postId, {bool? isCurrentlyLiked, String? postOwnerId}) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    final currentlyLiked = isCurrentlyLiked ?? await hasUserLikedPost(postId);
    final isNowLiked = !currentlyLiked;

    // Instantly update all caches and notify UI
    _updateLikeInCache(postId, isNowLiked);
    notifyListeners();

    // Persist to DB in the background
    _unawaited(_persistLike(postId, uid, currentlyLiked, isNowLiked, postOwnerId));

    return isNowLiked;
  }

  void _updateLikeInCache(String postId, bool isNowLiked) {
    Post updatePost(Post p) {
      if (p.id != postId) return p;
      return p.copyWith(
        isLikedByMe: isNowLiked,
        likeCount: isNowLiked ? p.likeCount + 1 : (p.likeCount - 1).clamp(0, 999999),
      );
    }
    if (_followingFeedCache != null) _followingFeedCache = _followingFeedCache!.map(updatePost).toList();
    if (_exploreFeedCache != null) _exploreFeedCache = _exploreFeedCache!.map(updatePost).toList();
    if (_clipsFeedCache != null) _clipsFeedCache = _clipsFeedCache!.map(updatePost).toList();
  }

  Future<void> _persistLike(String postId, String uid, bool wasLiked, bool isNowLiked, String? postOwnerId) async {
    try {
      if (wasLiked) {
        await _supabase.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
        await _supabase.rpc('decrement_post_likes', params: {'p_post_id': postId}).catchError((_) async {
          final c = await _supabase.from('posts').select('like_count').eq('id', postId).single();
          final val = (c['like_count'] as num?)?.toInt() ?? 1;
          await _supabase.from('posts').update({'like_count': (val - 1).clamp(0, 9999999)}).eq('id', postId);
        });
      } else {
        await _supabase.from('post_likes').insert({'post_id': postId, 'user_id': uid});
        await _supabase.rpc('increment_post_likes', params: {'p_post_id': postId}).catchError((_) async {
          final c = await _supabase.from('posts').select('like_count').eq('id', postId).single();
          final val = (c['like_count'] as num?)?.toInt() ?? 0;
          await _supabase.from('posts').update({'like_count': val + 1}).eq('id', postId);
        });
        if (postOwnerId != null && postOwnerId != uid) {
          _unawaited(_supabase.from('notifications').insert({
            'recipient_id': postOwnerId,
            'sender_id': uid,
            'type': 'like',
            'entity_id': postId,
            'content': 'liked your post',
          }));
        }
      }
    } catch (e) {
      debugPrint('Error persisting like toggle: $e');
      // Rollback cache on failure
      _updateLikeInCache(postId, wasLiked);
      notifyListeners();
    }
  }

  // Check if current user saved a post
  Future<bool> hasUserSavedPost(String postId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final res = await _supabase
          .from('saved_posts')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // Toggle private save bookmark — OPTIMISTIC: UI updates at 0ms
  Future<bool> toggleSave(String postId, {bool? isCurrentlySaved}) async {
    final uid = _currentUserId;
    if (uid == null) return false;

    final currentlySaved = isCurrentlySaved ?? await hasUserSavedPost(postId);
    final isNowSaved = !currentlySaved;

    // Instantly update all caches and notify UI
    _updateSaveInCache(postId, isNowSaved);
    notifyListeners();

    // Persist to DB in the background
    _unawaited(_persistSave(postId, uid, currentlySaved, isNowSaved));

    return isNowSaved;
  }

  void _updateSaveInCache(String postId, bool isNowSaved) {
    Post updatePost(Post p) => p.id != postId ? p : p.copyWith(isSavedByMe: isNowSaved);
    if (_followingFeedCache != null) _followingFeedCache = _followingFeedCache!.map(updatePost).toList();
    if (_exploreFeedCache != null) _exploreFeedCache = _exploreFeedCache!.map(updatePost).toList();
  }

  Future<void> _persistSave(String postId, String uid, bool wasSaved, bool isNowSaved) async {
    try {
      if (wasSaved) {
        await _supabase.from('saved_posts').delete().eq('post_id', postId).eq('user_id', uid);
      } else {
        await _supabase.from('saved_posts').insert({'post_id': postId, 'user_id': uid});
      }
    } catch (e) {
      debugPrint('Error persisting save toggle: $e');
      // Rollback cache on failure
      _updateSaveInCache(postId, wasSaved);
      notifyListeners();
    }
  }

  // Fetch saved posts for the current user
  Future<List<Post>> getSavedPosts() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final res = await _supabase
          .from('saved_posts')
          .select('posts(*, post_media(*), profiles!user_id(*))')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final list = res as List;
      final rawPosts = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item['posts'] != null) {
          rawPosts.add(item['posts'] as Map<String, dynamic>);
        }
      }

      return await _populateLikesAndSaves(rawPosts, uid);
    } catch (e) {
      debugPrint('Error fetching saved posts: $e');
      return [];
    }
  }

  // Fetch comments for a post
  Future<List<PostComment>> getComments(String postId) async {
    try {
      final res = await _supabase
          .from('post_comments')
          .select('*, profiles!user_id(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final list = res as List;
      return list.map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  // Add comment to a post
  Future<PostComment> addComment({
    required String postId,
    required String content,
    String? postOwnerId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final commentId = _uuid.v4();
    final res = await _supabase.from('post_comments').insert({
      'id': commentId,
      'post_id': postId,
      'user_id': uid,
      'content': content.trim(),
    }).select('*, profiles!user_id(*)').single();

    // Trigger notification if commenting on another user's post
    if (postOwnerId != null && postOwnerId != uid) {
      await _supabase.from('notifications').insert({
        'recipient_id': postOwnerId,
        'sender_id': uid,
        'type': 'comment',
        'entity_id': postId,
        'content': 'commented: "${content.trim().length > 30 ? '${content.trim().substring(0, 30)}...' : content.trim()}"',
      }).catchError((_) {});
    }

    notifyListeners();
    return PostComment.fromJson(res);
  }

  // Delete comment
  Future<void> deleteComment({required String commentId, required String postId}) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase
        .from('post_comments')
        .delete()
        .eq('id', commentId);

    notifyListeners();
  }

  // Share post to conversation without duplicating media
  Future<void> sharePostToConversation({
    required Post post,
    required String conversationId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // Prefer stored thumbnail_url (important for video posts);
    // fall back to mediaUrl only for image posts.
    String? mediaThumbnail;
    if (post.media.isNotEmpty) {
      final firstMedia = post.media.first;
      if (firstMedia.isVideo) {
        // Use ImageKit thumbnail transform if no explicit thumbnail stored
        mediaThumbnail = firstMedia.thumbnailUrl?.isNotEmpty == true
            ? firstMedia.thumbnailUrl
            : '${firstMedia.mediaUrl}/ik-thumbnail.jpg';
      } else {
        mediaThumbnail = firstMedia.mediaUrl;
      }
    }

    final payload = jsonEncode({
      'postId': post.id,
      'authorName': post.author?.displayName ?? 'User',
      'authorUsername': post.author?.username ?? 'user',
      'authorAvatar': post.author?.avatarUrl,
      'caption': post.caption ?? '',
      'thumbnailUrl': mediaThumbnail,
      'mediaType': post.media.isNotEmpty ? post.media.first.mediaType : 'text',
    });

    await _supabase.from('messages').insert({
      'id': _uuid.v4(),
      'conversation_id': conversationId,
      'sender_id': uid,
      'message_type': 'shared_post',
      'content': payload,
    });
  }

  // Create a new post with uploaded media
  Future<Post> createPost({
    String? caption,
    String visibility = 'public',
    List<Map<String, dynamic>>? mediaList,
    Uint8List? mediaBytes,
    String? fileName,
    String? mimeType,
    int? width,
    int? height,
    int? duration,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final postId = _uuid.v4();

    // 1. Insert Post record in Supabase
    final postData = await _supabase.from('posts').insert({
      'id': postId,
      'user_id': uid,
      'caption': caption?.trim().isNotEmpty == true ? caption!.trim() : null,
      'visibility': visibility,
      'like_count': 0,
      'comments_count': 0,
    }).select('*, profiles!user_id(*)').single();

    List<PostMedia> postMediaList = [];

    // If pre-uploaded media list is provided
    if (mediaList != null && mediaList.isNotEmpty) {
      for (int i = 0; i < mediaList.length; i++) {
        final item = mediaList[i];
        final mediaId = _uuid.v4();
        final mediaData = await _supabase.from('post_media').insert({
          'id': mediaId,
          'post_id': postId,
          'user_id': uid,
          'object_key': item['object_key'],
          'media_url': item['media_url'],
          'media_type': item['media_type'] ?? 'image',
          'mime_type': item['mime_type'],
          'file_size': item['file_size'],
          'width': item['width'],
          'height': item['height'],
          'duration': item['duration'],
          'sort_order': i,
        }).select().single();
        postMediaList.add(PostMedia.fromJson(mediaData));
      }
    } else if (mediaBytes != null && fileName != null && mimeType != null) {
      final mediaId = _uuid.v4();
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final isVideo = mimeType.startsWith('video/');
      final mediaType = isVideo ? 'video' : 'image';

      final objectKey = _storageService.generateObjectKey(
        userId: uid,
        category: 'posts',
        extension: ext,
        subId: postId,
      );

      final uploadResult = await _storageService.uploadFile(
        objectKey: objectKey,
        bytes: mediaBytes,
        mimeType: mimeType,
        isPublic: visibility == 'public',
      );

      // For video posts, generate a thumbnail URL using ImageKit's built-in
      // thumbnail extraction (appending /ik-thumbnail.jpg to the video URL).
      final String? thumbnailUrl = isVideo
          ? '${uploadResult.publicUrl}/ik-thumbnail.jpg'
          : null;

      final mediaData = await _supabase.from('post_media').insert({
        'id': mediaId,
        'post_id': postId,
        'user_id': uid,
        'object_key': uploadResult.objectKey,
        'media_url': uploadResult.publicUrl,
        'thumbnail_url': thumbnailUrl,
        'media_type': mediaType,
        'mime_type': mimeType,
        'file_size': uploadResult.fileSize,
        'width': width,
        'height': height,
        'duration': duration,
        'sort_order': 0,
      }).select().single();
      postMediaList.add(PostMedia.fromJson(mediaData));
    }

    // Invalidate feed caches so new post appears on next refresh
    invalidateCache();
    final newPost = Post.fromJson(postData).copyWith(media: postMediaList);
    notifyListeners();
    return newPost;
  }

  // Delete a post and its associated storage objects
  Future<void> deletePost(String postId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    // 1. Fetch media object keys for cleanup
    final mediaRes = await _supabase
        .from('post_media')
        .select('object_key')
        .eq('post_id', postId);

    // 2. Delete post row (cascades to post_media, post_likes, saved_posts, post_comments)
    await _supabase.from('posts').delete().eq('id', postId).eq('user_id', uid);

    // 3. Delete files from storage
    final mediaList = mediaRes as List;
    for (final item in mediaList) {
      final key = item['object_key'] as String?;
      if (key != null && key.isNotEmpty) {
        await _storageService.deleteFile(key);
      }
    }

    // Invalidate caches so deleted post disappears on next refresh
    invalidateCache();
    notifyListeners();
  }
}
