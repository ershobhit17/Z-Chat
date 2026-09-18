import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class StorageUploadResult {
  final String objectKey;
  final String publicUrl;
  final int fileSize;
  final String mimeType;

  StorageUploadResult({
    required this.objectKey,
    required this.publicUrl,
    required this.fileSize,
    required this.mimeType,
  });
}

enum MediaCategory {
  avatar,
  banner,
  post,
  message,
  voice,
  wallpaper,
}

abstract class MediaStorageService {
  Future<StorageUploadResult> uploadFile({
    required String objectKey,
    required Uint8List bytes,
    required String mimeType,
    bool isPublic = true,
  });

  Future<StorageUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileExtension,
    required String mimeType,
    required MediaCategory category,
    String? conversationId,
    String? messageId,
    String? postId,
    bool isPublic = true,
  });

  Future<String> getDownloadUrl(String objectKey);

  Future<void> deleteFile(String objectKey);

  Future<void> delete(String objectKey);

  String generateObjectKey({
    required String userId,
    required String category, // 'profile', 'posts', 'messages', 'voice', 'wallpapers'
    required String extension,
    String? subId, // e.g. postId or conversationId
  });
}

class CloudflareR2StorageService implements MediaStorageService {
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  CloudflareR2StorageService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  @override
  String generateObjectKey({
    required String userId,
    required String category,
    required String extension,
    String? subId,
  }) {
    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final fileId = _uuid.v4();

    switch (category) {
      case 'profile':
        return 'users/$userId/profile/avatar_$fileId.$cleanExt';
      case 'posts':
        final postId = subId ?? _uuid.v4();
        final mediaTypeFolder = cleanExt == 'mp4' || cleanExt == 'mov' ? 'video' : 'image';
        return 'users/$userId/posts/$postId/$mediaTypeFolder/$fileId.$cleanExt';
      case 'messages':
        final conversationId = subId ?? 'general';
        return 'users/$userId/messages/$conversationId/$fileId.$cleanExt';
      case 'voice':
        final conversationId = subId ?? 'general';
        return 'users/$userId/voice/$conversationId/$fileId.m4a';
      case 'wallpapers':
        return 'users/$userId/wallpapers/$fileId.$cleanExt';
      default:
        return 'users/$userId/media/$fileId.$cleanExt';
    }
  }

  @override
  Future<void> delete(String objectKey) => deleteFile(objectKey);

  @override
  Future<StorageUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileExtension,
    required String mimeType,
    required MediaCategory category,
    String? conversationId,
    String? messageId,
    String? postId,
    bool isPublic = true,
  }) async {
    final uid = _supabase.auth.currentUser?.id ?? 'anonymous';
    final categoryString = switch (category) {
      MediaCategory.avatar => 'profile',
      MediaCategory.banner => 'profile',
      MediaCategory.post => 'posts',
      MediaCategory.message => 'messages',
      MediaCategory.voice => 'voice',
      MediaCategory.wallpaper => 'wallpapers',
    };

    final subId = category == MediaCategory.post
        ? postId
        : (category == MediaCategory.message || category == MediaCategory.voice
            ? (messageId != null && conversationId != null ? '$conversationId/$messageId' : conversationId)
            : null);

    final objectKey = generateObjectKey(
      userId: uid,
      category: categoryString,
      extension: fileExtension,
      subId: subId,
    );

    return uploadFile(
      objectKey: objectKey,
      bytes: bytes,
      mimeType: mimeType,
      isPublic: isPublic,
    );
  }

  @override
  Future<StorageUploadResult> uploadFile({
    required String objectKey,
    required Uint8List bytes,
    required String mimeType,
    bool isPublic = true,
  }) async {
    // 1. Try Cloudflare R2 Presigned Upload via Supabase Edge Function
    try {
      final res = await _supabase.functions.invoke(
        'r2-storage',
        body: {
          'action': 'get_upload_url',
          'objectKey': objectKey,
          'contentType': mimeType,
          'isPublic': isPublic,
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : jsonDecode(res.data.toString()) as Map<String, dynamic>;

        final uploadUrl = data['uploadUrl'] as String?;
        final mediaUrl = data['mediaUrl'] as String?;

        if (uploadUrl != null && mediaUrl != null) {
          // Direct client -> Cloudflare R2 upload using presigned PUT
          final r2Response = await http.put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': mimeType},
            body: bytes,
          );

          if (r2Response.statusCode == 200 || r2Response.statusCode == 201) {
            debugPrint('Successfully uploaded to Cloudflare R2: $objectKey');
            return StorageUploadResult(
              objectKey: objectKey,
              publicUrl: mediaUrl,
              fileSize: bytes.length,
              mimeType: mimeType,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('R2 upload skipped/failed ($e), using Supabase Storage fallback');
    }

    // 2. Seamless Fallback to Supabase Storage
    // Ensures app NEVER breaks if R2 credentials are not yet configured in edge function!
    final bucket = objectKey.contains('/profile/')
        ? AppConstants.bucketAvatars
        : objectKey.contains('/voice/')
            ? AppConstants.bucketVoice
            : AppConstants.bucketAttachments;

    final sanitizedPath = objectKey.replaceFirst(RegExp(r'^users/[^/]+/'), '');

    await _supabase.storage.from(bucket).uploadBinary(
          sanitizedPath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    final fallbackUrl = _supabase.storage.from(bucket).getPublicUrl(sanitizedPath);

    return StorageUploadResult(
      objectKey: objectKey,
      publicUrl: fallbackUrl,
      fileSize: bytes.length,
      mimeType: mimeType,
    );
  }

  @override
  Future<String> getDownloadUrl(String objectKey) async {
    try {
      final res = await _supabase.functions.invoke(
        'r2-storage',
        body: {
          'action': 'get_download_url',
          'objectKey': objectKey,
        },
      );

      if (res.status == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic> ? res.data : jsonDecode(res.data);
        return data['downloadUrl'] as String;
      }
    } catch (_) {}

    // Fallback public url
    return objectKey;
  }

  @override
  Future<void> deleteFile(String objectKey) async {
    try {
      await _supabase.functions.invoke(
        'r2-storage',
        body: {
          'action': 'delete_object',
          'objectKey': objectKey,
        },
      );
    } catch (e) {
      debugPrint('Error deleting object from R2: $e');
    }

    // Also attempt cleanup on Supabase storage fallback if applicable
    try {
      final bucket = objectKey.contains('/profile/')
          ? AppConstants.bucketAvatars
          : objectKey.contains('/voice/')
              ? AppConstants.bucketVoice
              : AppConstants.bucketAttachments;
      final sanitizedPath = objectKey.replaceFirst(RegExp(r'^users/[^/]+/'), '');
      await _supabase.storage.from(bucket).remove([sanitizedPath]);
    } catch (_) {}
  }
}

class ImageKitStorageService implements MediaStorageService {
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  // Helper to optimize and resize ImageKit images
  static String getTransformedUrl(
    String? url, {
    int? width,
    int? height,
    int quality = 80,
    bool crop = true,
  }) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (!trimmed.contains('imagekit.io')) return trimmed;

    final parts = <String>[];
    if (width != null) parts.add('w-$width');
    if (height != null) parts.add('h-$height');
    if (crop) parts.add('fo-auto');
    parts.add('q-$quality');

    final transformStr = 'tr=${parts.join(',')}';
    if (trimmed.contains('?')) {
      return '$trimmed&$transformStr';
    } else {
      return '$trimmed?$transformStr';
    }
  }

  ImageKitStorageService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  @override
  String generateObjectKey({
    required String userId,
    required String category,
    required String extension,
    String? subId,
  }) {
    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final fileId = _uuid.v4();
    return '$category-$fileId.$cleanExt';
  }

  @override
  Future<void> delete(String objectKey) => deleteFile(objectKey);

  @override
  Future<StorageUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileExtension,
    required String mimeType,
    required MediaCategory category,
    String? conversationId,
    String? messageId,
    String? postId,
    bool isPublic = true,
  }) async {
    final uid = _supabase.auth.currentUser?.id ?? 'anonymous';
    final categoryFolder = switch (category) {
      MediaCategory.avatar => 'avatars',
      MediaCategory.banner => 'banners',
      MediaCategory.post => 'posts',
      MediaCategory.message => 'messages',
      MediaCategory.voice => 'voice',
      MediaCategory.wallpaper => 'wallpapers',
    };

    final fileName = '${categoryFolder}_${_uuid.v4()}.${fileExtension.replaceAll('.', '')}';

    // 1. Try ImageKit secure upload via Edge Function authentication
    try {
      final authRes = await _supabase.functions.invoke(
        'imagekit-storage',
        body: {'action': 'get_auth_params'},
      );

      if (authRes.status == 200 && authRes.data != null) {
        final authData = authRes.data is Map<String, dynamic>
            ? authRes.data as Map<String, dynamic>
            : jsonDecode(authRes.data.toString()) as Map<String, dynamic>;

        final token = authData['token'] as String;
        final expire = authData['expire'] as String;
        final signature = authData['signature'] as String;
        final publicKey = authData['publicKey'] as String;

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
        );

        request.fields['publicKey'] = publicKey;
        request.fields['signature'] = signature;
        request.fields['expire'] = expire;
        request.fields['token'] = token;
        request.fields['fileName'] = fileName;
        request.fields['folder'] = '/users/$uid/$categoryFolder';
        request.fields['useUniqueFileName'] = 'true';

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

        final streamedRes = await request.send();
        final response = await http.Response.fromStream(streamedRes);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = jsonDecode(response.body) as Map<String, dynamic>;
          final fileId = resData['fileId'] as String;
          final url = resData['url'] as String;
          final size = (resData['size'] as num?)?.toInt() ?? bytes.length;

          debugPrint('Successfully uploaded to ImageKit: $fileId -> $url');
          return StorageUploadResult(
            objectKey: fileId,
            publicUrl: url,
            fileSize: size,
            mimeType: mimeType,
          );
        } else {
          debugPrint('ImageKit upload returned status ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('ImageKit upload skipped/failed ($e), using Supabase fallback');
    }

    // 2. Seamless Fallback to Supabase Storage
    final bucket = category == MediaCategory.avatar
        ? AppConstants.bucketAvatars
        : (category == MediaCategory.voice ? AppConstants.bucketVoice : AppConstants.bucketAttachments);

    final storagePath = '$uid/$categoryFolder/$fileName';

    await _supabase.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    final fallbackUrl = _supabase.storage.from(bucket).getPublicUrl(storagePath);

    return StorageUploadResult(
      objectKey: storagePath,
      publicUrl: fallbackUrl,
      fileSize: bytes.length,
      mimeType: mimeType,
    );
  }

  @override
  Future<StorageUploadResult> uploadFile({
    required String objectKey,
    required Uint8List bytes,
    required String mimeType,
    bool isPublic = true,
  }) {
    final ext = objectKey.contains('.') ? objectKey.split('.').last : 'jpg';
    return uploadBytes(
      bytes: bytes,
      fileExtension: ext,
      mimeType: mimeType,
      category: MediaCategory.post,
      isPublic: isPublic,
    );
  }

  @override
  Future<String> getDownloadUrl(String objectKey) async => objectKey;

  @override
  Future<void> deleteFile(String objectKey) async {
    try {
      await _supabase.functions.invoke(
        'imagekit-storage',
        body: {
          'action': 'delete_file',
          'fileId': objectKey,
        },
      );
    } catch (_) {}
  }
}
