import '../theme/app_theme_data.dart';

class UserProfile {
  final String id;
  final String username;
  final String usernameLower;
  final String displayName;
  final String? avatarUrl;
  final String? avatarObjectKey;
  final String? bannerObjectKey;
  final String bio;
  final String status;
  final bool isOnline;
  final DateTime? lastSeen;
  final int postCount;
  final int followersCount;
  final int followingCount;
  final bool isPrivate;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.usernameLower,
    required this.displayName,
    this.avatarUrl,
    this.avatarObjectKey,
    this.bannerObjectKey,
    this.bio = '',
    this.status = 'Hey there! I am using Z Chat.',
    this.isOnline = false,
    this.lastSeen,
    this.postCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isPrivate = false,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'user',
      usernameLower: json['username_lower'] as String? ?? 'user',
      displayName: json['display_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      avatarObjectKey: json['avatar_object_key'] as String?,
      bannerObjectKey: json['banner_object_key'] as String?,
      bio: json['bio'] as String? ?? '',
      status: json['status'] as String? ?? 'Hey there! I am using Z Chat.',
      isOnline: () {
        final rawOnline = json['is_online'] as bool? ?? false;
        if (!rawOnline) return false;
        if (json['last_seen'] == null) return false;
        try {
          final ls = DateTime.parse(json['last_seen'] as String);
          final diff = DateTime.now().toUtc().difference(ls.toUtc()).inMinutes.abs();
          return diff <= 5;
        } catch (_) {
          return false;
        }
      }(),
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen'] as String) : null,
      postCount: (json['post_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'username_lower': usernameLower,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'avatar_object_key': avatarObjectKey,
      'banner_object_key': bannerObjectKey,
      'bio': bio,
      'status': status,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'post_count': postCount,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_private': isPrivate,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? status,
    String? avatarUrl,
    String? avatarObjectKey,
    String? bannerObjectKey,
    bool? isOnline,
    DateTime? lastSeen,
    int? postCount,
    int? followersCount,
    int? followingCount,
    bool? isPrivate,
  }) {
    return UserProfile(
      id: id,
      username: username,
      usernameLower: usernameLower,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarObjectKey: avatarObjectKey ?? this.avatarObjectKey,
      bannerObjectKey: bannerObjectKey ?? this.bannerObjectKey,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      postCount: postCount ?? this.postCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt,
    );
  }
}

class PostMedia {
  final String id;
  final String postId;
  final String userId;
  final String objectKey;
  final String mediaUrl;
  final String? thumbnailUrl; // Poster frame for videos
  final String mediaType; // 'image' or 'video'
  final String? mimeType;
  final int? fileSize;
  final int? width;
  final int? height;
  final int? duration;
  final int sortOrder;
  final DateTime createdAt;

  PostMedia({
    required this.id,
    required this.postId,
    required this.userId,
    required this.objectKey,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    this.mimeType,
    this.fileSize,
    this.width,
    this.height,
    this.duration,
    this.sortOrder = 0,
    required this.createdAt,
  });

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      objectKey: json['object_key'] as String? ?? '',
      mediaUrl: json['media_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      mediaType: json['media_type'] as String? ?? 'image',
      mimeType: json['mime_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'object_key': objectKey,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType,
      'mime_type': mimeType,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'duration': duration,
      'sort_order': sortOrder,
    };
  }
}

class Post {
  final String id;
  final String userId;
  final String? caption;
  final String visibility; // 'public', 'private', 'followers'
  final int likeCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? author;
  final List<PostMedia> media;

  Post({
    required this.id,
    required this.userId,
    this.caption,
    this.visibility = 'public',
    this.likeCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.media = const [],
  });

  bool get isPublic => visibility == 'public';
  bool get isPrivate => visibility == 'private';

  factory Post.fromJson(
    Map<String, dynamic> json, {
    UserProfile? author,
    bool isLikedByMe = false,
    bool isSavedByMe = false,
  }) {
    List<PostMedia> mediaList = [];
    if (json['post_media'] != null && json['post_media'] is List) {
      final list = json['post_media'] as List;
      mediaList = list.map((e) => PostMedia.fromJson(e as Map<String, dynamic>)).toList();
      mediaList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      caption: json['caption'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      isLikedByMe: isLikedByMe,
      isSavedByMe: isSavedByMe,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      author: author ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
      media: mediaList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'caption': caption,
      'visibility': visibility,
      'like_count': likeCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Post copyWith({
    int? likeCount,
    int? commentsCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
    String? caption,
    List<PostMedia>? media,
  }) {
    return Post(
      id: id,
      userId: userId,
      caption: caption ?? this.caption,
      visibility: visibility,
      likeCount: likeCount ?? this.likeCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      media: media ?? this.media,
    );
  }
}

class MessageAttachment {
  final String id;
  final String messageId;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final int? duration;
  final int? width;
  final int? height;

  MessageAttachment({
    required this.id,
    required this.messageId,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    this.duration,
    this.width,
    this.height,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String? ?? 'attachment',
      mimeType: json['mime_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }
}

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String reaction;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reaction,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      reaction: json['reaction'] as String,
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String messageType; // 'text', 'image', 'video', 'audio', 'file', 'system'
  final String? content;
  final String? replyToId;
  final ChatMessage? replyMessage;
  final bool isEdited;
  final bool isDeleted;
  final List<String> deletedFor;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;
  final List<MessageReaction> reactions;
  final UserProfile? senderProfile;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.content,
    this.replyToId,
    this.replyMessage,
    this.isEdited = false,
    this.isDeleted = false,
    this.deletedFor = const [],
    required this.createdAt,
    this.attachments = const [],
    this.reactions = const [],
    this.senderProfile,
    this.status = MessageStatus.read,
  });

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isVideo => messageType == 'video';
  bool get isAudio => messageType == 'audio';
  bool get isFile => messageType == 'file';
  bool get isSystem => messageType == 'system';
  bool get isSharedPost => messageType == 'shared_post';
  bool get isYouTube => messageType == 'youtube';
  bool get isSending => status == MessageStatus.sending;
  bool get isFailed => status == MessageStatus.failed;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? messageType,
    String? content,
    String? replyToId,
    ChatMessage? replyMessage,
    bool? isEdited,
    bool? isDeleted,
    List<String>? deletedFor,
    DateTime? createdAt,
    List<MessageAttachment>? attachments,
    List<MessageReaction>? reactions,
    UserProfile? senderProfile,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      replyToId: replyToId ?? this.replyToId,
      replyMessage: replyMessage ?? this.replyMessage,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedFor: deletedFor ?? this.deletedFor,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      senderProfile: senderProfile ?? this.senderProfile,
      status: status ?? this.status,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {UserProfile? senderProfile}) {
    List<MessageAttachment> attachmentsList = [];
    if (json['message_attachments'] != null) {
      final list = json['message_attachments'] as List;
      attachmentsList = list.map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>)).toList();
    }

    List<MessageReaction> reactionsList = [];
    if (json['message_reactions'] != null) {
      final list = json['message_reactions'] as List;
      reactionsList = list.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>)).toList();
    }

    ChatMessage? replyMsg;
    if (json['reply_message'] != null && json['reply_message'] is Map<String, dynamic>) {
      replyMsg = ChatMessage.fromJson(json['reply_message'] as Map<String, dynamic>);
    }

    MessageStatus parsedStatus = MessageStatus.sent;
    if (json['status'] == 'sending') {
      parsedStatus = MessageStatus.sending;
    } else if (json['status'] == 'failed') {
      parsedStatus = MessageStatus.failed;
    } else if (json['status'] == 'delivered') {
      parsedStatus = MessageStatus.delivered;
    } else if (json['status'] == 'read') {
      parsedStatus = MessageStatus.read;
    }

    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String?,
      replyToId: json['reply_to_id'] as String?,
      replyMessage: replyMsg,
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedFor: (json['deleted_for'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      attachments: attachmentsList,
      reactions: reactionsList,
      senderProfile: senderProfile ?? (json['sender_profile'] != null ? UserProfile.fromJson(json['sender_profile']) : null),
      status: parsedStatus,
    );
  }
}

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime joinedAt;
  final String? lastReadMessageId;
  final bool isMuted;
  final bool isArchived;
  final bool isPinned;
  final AppThemeData? chatTheme;
  final String? chatWallpaper;
  final UserProfile? profile;

  ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.joinedAt,
    this.lastReadMessageId,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.chatTheme,
    this.chatWallpaper,
    this.profile,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    AppThemeData? theme;
    if (json['chat_theme'] != null && json['chat_theme'] is Map<String, dynamic>) {
      theme = AppThemeData.fromJson(json['chat_theme'] as Map<String, dynamic>);
    }

    UserProfile? userProfile;
    if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      userProfile = UserProfile.fromJson(json['profiles'] as Map<String, dynamic>);
    }

    return ConversationMember(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'] as String) : DateTime.now(),
      lastReadMessageId: json['last_read_message_id'] as String?,
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      chatTheme: theme,
      chatWallpaper: json['chat_wallpaper'] as String?,
      profile: userProfile,
    );
  }

  ConversationMember copyWith({
    String? id,
    String? conversationId,
    String? userId,
    DateTime? joinedAt,
    String? lastReadMessageId,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
    AppThemeData? chatTheme,
    String? chatWallpaper,
    UserProfile? profile,
  }) {
    return ConversationMember(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      chatTheme: chatTheme ?? this.chatTheme,
      chatWallpaper: chatWallpaper ?? this.chatWallpaper,
      profile: profile ?? this.profile,
    );
  }
}

class Conversation {
  final String id;
  final String type; // 'direct', 'group'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final List<ConversationMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final AppThemeData? customTheme;
  final bool isRequest;

  Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.customTheme,
    this.isRequest = false,
  });

  // Get the other user's profile in a direct chat
  UserProfile? getOtherParticipant(String currentUserId) {
    for (final member in members) {
      if (member.userId != currentUserId && member.profile != null) {
        return member.profile;
      }
    }
    return null;
  }

  Conversation copyWith({
    String? id,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    List<ConversationMember>? members,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    AppThemeData? customTheme,
    bool? isRequest,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      customTheme: customTheme ?? this.customTheme,
      isRequest: isRequest ?? this.isRequest,
    );
  }
}

class FollowRelationship {
  final String id;
  final String followerId;
  final String followingId;
  final String status; // 'pending', 'accepted'
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? profile;

  FollowRelationship({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.profile,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  factory FollowRelationship.fromJson(Map<String, dynamic> json, {UserProfile? profile}) {
    return FollowRelationship(
      id: json['id'] as String,
      followerId: json['follower_id'] as String,
      followingId: json['following_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      profile: profile ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
    );
  }
}

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? author;

  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory PostComment.fromJson(Map<String, dynamic> json, {UserProfile? author}) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      author: author ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
    );
  }
}

class SavedPost {
  final String id;
  final String postId;
  final String userId;
  final DateTime createdAt;
  final Post? post;

  SavedPost({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
    this.post,
  });

  factory SavedPost.fromJson(Map<String, dynamic> json, {Post? post}) {
    return SavedPost(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      post: post ?? (json['posts'] != null ? Post.fromJson(json['posts'] as Map<String, dynamic>) : null),
    );
  }
}

class Moment {
  final String id;
  final String userId;
  final String mediaType; // 'image', 'video'
  final String? imagekitFileId;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String visibility;
  final DateTime createdAt;
  final DateTime expiresAt;
  final UserProfile? userProfile;
  final bool isViewedByMe;
  final int viewsCount;

  Moment({
    required this.id,
    required this.userId,
    required this.mediaType,
    this.imagekitFileId,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    this.visibility = 'public',
    required this.createdAt,
    required this.expiresAt,
    this.userProfile,
    this.isViewedByMe = false,
    this.viewsCount = 0,
  });

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Moment.fromJson(Map<String, dynamic> json, {UserProfile? userProfile, bool isViewedByMe = false, int viewsCount = 0}) {
    return Moment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      imagekitFileId: json['imagekit_file_id'] as String?,
      mediaUrl: json['media_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : DateTime.now().add(const Duration(hours: 24)),
      userProfile: userProfile ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
      isViewedByMe: isViewedByMe,
      viewsCount: viewsCount,
    );
  }

  Moment copyWith({
    bool? isViewedByMe,
    int? viewsCount,
  }) {
    return Moment(
      id: id,
      userId: userId,
      mediaType: mediaType,
      imagekitFileId: imagekitFileId,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      visibility: visibility,
      createdAt: createdAt,
      expiresAt: expiresAt,
      userProfile: userProfile,
      isViewedByMe: isViewedByMe ?? this.isViewedByMe,
      viewsCount: viewsCount ?? this.viewsCount,
    );
  }
}

class MomentView {
  final String id;
  final String momentId;
  final String viewerId;
  final DateTime viewedAt;
  final UserProfile? viewerProfile;

  MomentView({
    required this.id,
    required this.momentId,
    required this.viewerId,
    required this.viewedAt,
    this.viewerProfile,
  });

  factory MomentView.fromJson(Map<String, dynamic> json, {UserProfile? viewerProfile}) {
    return MomentView(
      id: json['id'] as String,
      momentId: json['moment_id'] as String,
      viewerId: json['viewer_id'] as String,
      viewedAt: json['viewed_at'] != null ? DateTime.parse(json['viewed_at'] as String) : DateTime.now(),
      viewerProfile: viewerProfile ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
    );
  }
}

class SocialNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String type; // 'follow_request', 'follow_accept', 'new_follower', 'like', 'comment', 'share', 'mention'
  final String? entityId;
  final String? content;
  final bool isRead;
  final DateTime createdAt;
  final UserProfile? senderProfile;

  SocialNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.type,
    this.entityId,
    this.content,
    this.isRead = false,
    required this.createdAt,
    this.senderProfile,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json, {UserProfile? senderProfile}) {
    return SocialNotification(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      senderId: json['sender_id'] as String,
      type: json['type'] as String? ?? 'new_follower',
      entityId: json['entity_id'] as String?,
      content: json['content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      senderProfile: senderProfile ?? (json['profiles'] != null ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>) : null),
    );
  }
}

class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String? duration;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    this.duration,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? {};
    final idMap = json['id'] as Map<String, dynamic>? ?? {};
    final videoId = idMap['videoId'] as String? ?? json['id'] as String? ?? '';
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    final high = thumbnails['high'] as Map<String, dynamic>? ?? thumbnails['medium'] as Map<String, dynamic>? ?? thumbnails['default'] as Map<String, dynamic>? ?? {};

    return YouTubeVideo(
      id: videoId,
      title: snippet['title'] as String? ?? 'YouTube Video',
      description: snippet['description'] as String? ?? '',
      thumbnailUrl: high['url'] as String? ?? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      channelTitle: snippet['channelTitle'] as String? ?? '',
    );
  }

  String get watchUrl => 'https://www.youtube.com/watch?v=$id';
}
