import 'package:flutter_test/flutter_test.dart';
import 'package:z_chat/models/models.dart';
import 'package:z_chat/theme/app_theme_data.dart';

void main() {
  group('Social Models Tests', () {
    test('UserProfile serialization & copyWith', () {
      final profile = UserProfile(
        id: 'u1',
        username: 'alice',
        usernameLower: 'alice',
        displayName: 'Alice Cooper',
        isPrivate: true,
        followersCount: 15,
        followingCount: 20,
        postCount: 5,
        createdAt: DateTime.now(),
      );

      expect(profile.isPrivate, isTrue);
      expect(profile.followersCount, 15);
      expect(profile.followingCount, 20);

      final json = profile.toJson();
      expect(json['is_private'], isTrue);
      expect(json['followers_count'], 15);

      final deserialized = UserProfile.fromJson(json);
      expect(deserialized.id, 'u1');
      expect(deserialized.username, 'alice');
      expect(deserialized.isPrivate, isTrue);

      final updated = profile.copyWith(isPrivate: false, followersCount: 16);
      expect(updated.isPrivate, isFalse);
      expect(updated.followersCount, 16);
    });

    test('Post and PostMedia serialization', () {
      final now = DateTime.now();
      final media = PostMedia(
        id: 'm1',
        postId: 'p1',
        userId: 'u1',
        objectKey: 'users/u1/posts/p1/image/abc.jpg',
        mediaUrl: 'https://ik.imagekit.io/zchat/abc.jpg',
        mediaType: 'image',
        createdAt: now,
      );

      expect(media.isImage, isTrue);
      expect(media.isVideo, isFalse);

      final post = Post(
        id: 'p1',
        userId: 'u1',
        caption: 'Hello Z Chat world!',
        visibility: 'public',
        likeCount: 42,
        commentsCount: 3,
        createdAt: now,
        updatedAt: now,
        media: [media],
      );

      expect(post.isPublic, isTrue);
      expect(post.isPrivate, isFalse);
      expect(post.media.length, 1);
      expect(post.likeCount, 42);
      expect(post.commentsCount, 3);
    });

    test('FollowRelationship verification', () {
      final now = DateTime.now();
      final relPending = FollowRelationship(
        id: 'r1',
        followerId: 'u1',
        followingId: 'u2',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      expect(relPending.isPending, isTrue);
      expect(relPending.isAccepted, isFalse);

      final relAccepted = FollowRelationship(
        id: 'r2',
        followerId: 'u1',
        followingId: 'u3',
        status: 'accepted',
        createdAt: now,
        updatedAt: now,
      );
      expect(relAccepted.isAccepted, isTrue);
      expect(relAccepted.isPending, isFalse);
    });

    test('Moment 24h expiration check', () {
      final now = DateTime.now();
      final activeMoment = Moment(
        id: 'mom1',
        userId: 'u1',
        mediaType: 'image',
        mediaUrl: 'https://ik.imagekit.io/zchat/moment.jpg',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      expect(activeMoment.isExpired, isFalse);

      final expiredMoment = Moment(
        id: 'mom2',
        userId: 'u1',
        mediaType: 'image',
        mediaUrl: 'https://ik.imagekit.io/zchat/moment.jpg',
        createdAt: now.subtract(const Duration(hours: 25)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      expect(expiredMoment.isExpired, isTrue);
    });

    test('YouTube video model parsing', () {
      final video = YouTubeVideo(
        id: 'dQw4w9WgXcQ',
        title: 'Rick Astley',
        description: 'Never gonna give you up',
        thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelTitle: 'RickAstleyVEVO',
      );

      expect(video.watchUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(video.id, 'dQw4w9WgXcQ');
    });
  });

  group('Chat Ordering & Conversation Tests', () {
    test('Conversation lastMessageAt deserialization & copyWith', () {
      final t1 = DateTime.parse('2026-09-17T10:00:00Z');
      final conv = Conversation(
        id: 'c1',
        type: 'direct',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        lastMessageAt: t1,
        unreadCount: 3,
      );

      expect(conv.lastMessageAt, t1);
      expect(conv.unreadCount, 3);

      final t2 = DateTime.parse('2026-09-17T11:30:00Z');
      final updated = conv.copyWith(lastMessageAt: t2, unreadCount: 0);
      expect(updated.lastMessageAt, t2);
      expect(updated.unreadCount, 0);
    });

    test('Sorting conversations by latest activity DESC', () {
      final cA = Conversation(
        id: 'cA',
        type: 'direct',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        lastMessageAt: DateTime(2026, 9, 17, 10, 0), // 10:00 AM
      );
      final cB = Conversation(
        id: 'cB',
        type: 'direct',
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
        lastMessageAt: DateTime(2026, 9, 17, 11, 30), // 11:30 AM (newest)
      );
      final cC = Conversation(
        id: 'cC',
        type: 'direct',
        createdAt: DateTime(2026, 1, 3),
        updatedAt: DateTime(2026, 1, 3),
        lastMessageAt: DateTime(2026, 9, 17, 9, 0), // 09:00 AM (oldest)
      );

      final list = [cA, cB, cC];
      list.sort((a, b) {
        final timeA = a.lastMessageAt ?? a.updatedAt;
        final timeB = b.lastMessageAt ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });

      // Expected order: B (11:30), A (10:00), C (9:00)
      expect(list.map((c) => c.id).toList(), ['cB', 'cA', 'cC']);

      // If someone sends a new message in C at 12:00 PM:
      final cCUpdated = cC.copyWith(lastMessageAt: DateTime(2026, 9, 17, 12, 0));
      list[2] = cCUpdated;
      list.sort((a, b) {
        final timeA = a.lastMessageAt ?? a.updatedAt;
        final timeB = b.lastMessageAt ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });

      // Expected new order: C (12:00), B (11:30), A (10:00)
      expect(list.map((c) => c.id).toList(), ['cC', 'cB', 'cA']);
    });
  });

  group('Link Safety Tests', () {
    test('Allow safe web schemes and reject dangerous schemes', () {
      bool isSafeUrl(String rawUrl) {
        var target = rawUrl.trim();
        final schemeCheck = Uri.tryParse(target);
        if (schemeCheck != null && schemeCheck.hasScheme && schemeCheck.scheme != 'http' && schemeCheck.scheme != 'https') {
          return false;
        }
        if (!target.startsWith('http://') && !target.startsWith('https://')) {
          target = 'https://$target';
        }
        final uri = Uri.tryParse(target);
        if (uri == null) return false;
        return uri.scheme == 'http' || uri.scheme == 'https';
      }

      expect(isSafeUrl('https://google.com'), isTrue);
      expect(isSafeUrl('http://example.org/test'), isTrue);
      expect(isSafeUrl('www.youtube.com/watch?v=123'), isTrue);

      // Dangerous schemes
      expect(isSafeUrl('javascript:alert(1)'), isFalse);
      expect(isSafeUrl('data:text/html,<html>bad</html>'), isFalse);
      expect(isSafeUrl('file:///etc/passwd'), isFalse);
    });
  });

  group('Theme Customization & Liquid Glass Tokens Tests', () {
    test('AppThemeData liquid glass tokens and copyWith', () {
      final theme = AppThemeData.midnight;
      expect(theme.glassIntensity, isNotNull);
      expect(theme.glassBlur, isNotNull);

      final custom = theme.copyWith(
        glassIntensity: 0.45,
        glassBlur: 20.0,
        glassTransparency: 0.30,
        glassBorderOpacity: 0.25,
      );

      expect(custom.glassIntensity, 0.45);
      expect(custom.glassBlur, 20.0);
      expect(custom.glassTransparency, 0.30);
      expect(custom.glassBorderOpacity, 0.25);

      final json = custom.toJson();
      expect(json['glass']['intensity'], 0.45);
      expect(json['glass']['blur'], 20.0);

      final restored = AppThemeData.fromJson(json);
      expect(restored.glassIntensity, 0.45);
      expect(restored.glassBlur, 20.0);
    });

    test('All 8 signature presets are valid and accessible', () {
      expect(AppThemeData.getPresetById('midnight').name, 'Midnight Glass');
      expect(AppThemeData.getPresetById('obsidian').name, 'Obsidian');
      expect(AppThemeData.getPresetById('arctic').name, 'Arctic Frost');
      expect(AppThemeData.getPresetById('lavender').name, 'Lavender');
      expect(AppThemeData.getPresetById('graphite').name, 'Graphite Pro');
      expect(AppThemeData.getPresetById('soft_glass').name, 'Soft Glass');
      expect(AppThemeData.getPresetById('minimal_white').name, 'Minimal White');
      expect(AppThemeData.getPresetById('deep_violet').name, 'Deep Violet');
    });
  });
}
