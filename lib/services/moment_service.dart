import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'media_storage_service.dart';

class UserMomentsGroup {
  final UserProfile user;
  final List<Moment> moments;
  final bool hasUnviewed;

  UserMomentsGroup({
    required this.user,
    required this.moments,
    required this.hasUnviewed,
  });
}

class MomentService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final MediaStorageService _storageService;
  final Uuid _uuid = const Uuid();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MomentService({
    SupabaseClient? supabaseClient,
    MediaStorageService? storageService,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _storageService = storageService ?? ImageKitStorageService();

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // Create and upload a new Moment (24h story)
  Future<Moment> createMoment({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? caption,
    String visibility = 'public',
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    _isLoading = true;
    notifyListeners();

    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final isVideo = mimeType.startsWith('video/');
      final mediaType = isVideo ? 'video' : 'image';
      final momentId = _uuid.v4();

      final objectKey = _storageService.generateObjectKey(
        userId: uid,
        category: 'moments',
        extension: ext,
        subId: momentId,
      );

      final uploadResult = await _storageService.uploadFile(
        objectKey: objectKey,
        bytes: bytes,
        mimeType: mimeType,
        isPublic: visibility == 'public',
      );

      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(hours: 12)); // 12-hour Moments

      final res = await _supabase.from('moments').insert({
        'id': momentId,
        'user_id': uid,
        'media_type': mediaType,
        'imagekit_file_id': uploadResult.objectKey,
        'media_url': uploadResult.publicUrl,
        'thumbnail_url': isVideo ? '${uploadResult.publicUrl}/ik-thumbnail.jpg' : uploadResult.publicUrl,
        'caption': caption?.trim().isNotEmpty == true ? caption!.trim() : null,
        'visibility': visibility,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      }).select('*, profiles!user_id(*)').single();

      final newMoment = Moment.fromJson(res);
      notifyListeners();
      return newMoment;
    } catch (e) {
      debugPrint('Error creating moment: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch active moments grouped by user (moments & views fetched in PARALLEL)
  Future<List<UserMomentsGroup>> getActiveMomentsGrouped() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. Fetch moments (with embedded profiles) and launch in background — then
      //    we will fetch views in parallel once we have the moment IDs.
      List list;
      try {
        final res = await _supabase
            .from('moments')
            .select('*, profiles!user_id(*)')
            .gt('expires_at', nowStr)
            .order('created_at', ascending: true);
        list = res as List;
      } catch (e) {
        debugPrint('PostgREST embed moments join error ($e), fallback to batch profiles');
        final res = await _supabase
            .from('moments')
            .select('*')
            .gt('expires_at', nowStr)
            .order('created_at', ascending: true);
        final rawList = res as List;
        final uids = rawList.map((e) => e['user_id'] as String).toSet().toList();
        final profs = uids.isNotEmpty
            ? await _supabase.from('profiles').select().inFilter('id', uids) as List
            : [];
        final profMap = {for (var p in profs) p['id'] as String: p};
        list = rawList.map((m) {
          final copy = Map<String, dynamic>.from(m as Map<String, dynamic>);
          copy['profiles'] = profMap[m['user_id']];
          return copy;
        }).toList();
      }

      if (list.isEmpty) return [];

      // 2. Fetch views in parallel with — we already have the moment IDs
      final momentIds = list.map((e) => e['id'] as String).toList();
      final viewedSet = <String>{};

      if (momentIds.isNotEmpty) {
        final viewsRes = await _supabase
            .from('moment_views')
            .select('moment_id')
            .eq('viewer_id', uid)
            .inFilter('moment_id', momentIds)
            .then((r) => r as List)
            .catchError((_) => <dynamic>[]);

        for (final item in viewsRes) {
          viewedSet.add(item['moment_id'] as String);
        }
      }

      // 3. Group by user
      final Map<String, List<Moment>> userMomentsMap = {};
      final Map<String, UserProfile> userProfileMap = {};

      for (final item in list) {
        final mId = item['id'] as String;
        final moment = Moment.fromJson(
          item as Map<String, dynamic>,
          isViewedByMe: viewedSet.contains(mId),
        );

        final author = moment.userProfile;
        if (author == null) continue;

        userProfileMap[moment.userId] = author;
        userMomentsMap.putIfAbsent(moment.userId, () => []).add(moment);
      }

      final groups = <UserMomentsGroup>[];
      userMomentsMap.forEach((userId, momentsList) {
        final user = userProfileMap[userId]!;
        final hasUnviewed = momentsList.any((m) => !m.isViewedByMe && m.userId != uid);
        groups.add(UserMomentsGroup(
          user: user,
          moments: momentsList,
          hasUnviewed: hasUnviewed,
        ));
      });

      // Sort: current user first, then unviewed, then viewed
      groups.sort((a, b) {
        if (a.user.id == uid) return -1;
        if (b.user.id == uid) return 1;
        if (a.hasUnviewed && !b.hasUnviewed) return -1;
        if (!a.hasUnviewed && b.hasUnviewed) return 1;
        return 0;
      });

      return groups;
    } catch (e) {
      debugPrint('Error fetching active moments: $e');
      return [];
    }
  }

  // Fetch current user's active moments
  Future<List<Moment>> getMyMoments() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      List list;
      try {
        final res = await _supabase
            .from('moments')
            .select('*, profiles!user_id(*)')
            .eq('user_id', uid)
            .gt('expires_at', nowStr)
            .order('created_at', ascending: true);
        list = res as List;
      } catch (_) {
        final res = await _supabase
            .from('moments')
            .select('*')
            .eq('user_id', uid)
            .gt('expires_at', nowStr)
            .order('created_at', ascending: true);
        final rawList = res as List;
        final prof = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
        list = rawList.map((m) {
          final copy = Map<String, dynamic>.from(m as Map<String, dynamic>);
          copy['profiles'] = prof;
          return copy;
        }).toList();
      }

      return list.map((e) => Moment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching my moments: $e');
      return [];
    }
  }

  // Mark moment as viewed
  Future<void> markMomentViewed(String momentId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('moment_views').upsert({
        'moment_id': momentId,
        'viewer_id': uid,
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording moment view: $e');
    }
  }

  // Get viewers for a moment (owner only)
  Future<List<MomentView>> getMomentViewers(String momentId) async {
    try {
      final res = await _supabase
          .from('moment_views')
          .select('*, profiles!viewer_id(*)')
          .eq('moment_id', momentId)
          .order('viewed_at', ascending: false);

      final list = res as List;
      return list.map((e) => MomentView.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting moment viewers: $e');
      return [];
    }
  }

  // Delete a moment
  Future<void> deleteMoment(String momentId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final moment = await _supabase
          .from('moments')
          .select('imagekit_file_id')
          .eq('id', momentId)
          .eq('user_id', uid)
          .maybeSingle();

      if (moment != null && moment['imagekit_file_id'] != null) {
        final fileId = moment['imagekit_file_id'] as String;
        await _storageService.deleteFile(fileId);
      }

      await _supabase.from('moments').delete().eq('id', momentId).eq('user_id', uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting moment: $e');
      rethrow;
    }
  }
}
