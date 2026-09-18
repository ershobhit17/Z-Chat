import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/video_player_widget.dart';
import 'comments_modal.dart';
import 'share_post_modal.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final UserProfile? author;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.author,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isDeleting = false;

  bool _isSaved = false;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _likeCount = _post.likeCount;
    _isSaved = _post.isSavedByMe;
    _commentCount = _post.commentsCount;
    _checkLikeStatus();
    _checkSaveStatus();
  }

  void _checkLikeStatus() async {
    final postService = context.read<PostService>();
    final liked = await postService.hasUserLikedPost(_post.id);
    if (mounted) {
      setState(() => _isLiked = liked);
    }
  }

  void _checkSaveStatus() async {
    final postService = context.read<PostService>();
    final saved = await postService.hasUserSavedPost(_post.id);
    if (mounted) {
      setState(() => _isSaved = saved);
    }
  }

  void _toggleSave() async {
    final postService = context.read<PostService>();
    setState(() => _isSaved = !_isSaved);
    try {
      final isNowSaved = await postService.toggleSave(_post.id, isCurrentlySaved: !_isSaved);
      if (mounted) setState(() => _isSaved = isNowSaved);
    } catch (_) {
      _checkSaveStatus();
    }
  }

  void _openComments() async {
    await CommentsModal.show(context, postId: _post.id);
    if (mounted) {
      final postService = context.read<PostService>();
      final comments = await postService.getComments(_post.id);
      if (mounted) {
        setState(() => _commentCount = comments.length);
      }
    }
  }

  void _openShare() {
    SharePostModal.show(context, post: _post);
  }

  void _toggleLike() async {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount = (_likeCount > 0) ? _likeCount - 1 : 0;
      } else {
        _isLiked = true;
        _likeCount += 1;
      }
    });

    try {
      final postService = context.read<PostService>();
      final isNowLiked = await postService.toggleLike(_post.id);
      if (mounted && isNowLiked != _isLiked) {
        setState(() => _isLiked = isNowLiked);
      }
    } catch (e) {
      // Revert if error
      _checkLikeStatus();
    }
  }

  Future<void> _confirmDelete() async {
    final theme = context.read<ThemeProvider>().theme;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'This post and its associated media will be permanently deleted.',
          style: TextStyle(color: theme.mutedText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: theme.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        final postService = context.read<PostService>();
        await postService.deletePost(_post.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted.')),
          );
          Navigator.pop(context, true); // Return true so parent knows post was deleted
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: $e')),
          );
        }
      }
    }
  }

  void _openMediaUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    final currentUid = context.read<AuthService>().currentUser?.id;
    final isAuthor = currentUid == _post.userId;

    final primaryMedia = _post.media.isNotEmpty ? _post.media.first : null;
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(_post.createdAt);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post',
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isAuthor)
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  AvatarWidget(
                    avatarUrl: widget.author?.avatarUrl,
                    displayName: widget.author?.displayName ?? 'User',
                    username: widget.author?.username,
                    enablePreviewOnTap: true,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.author?.displayName ?? 'User',
                          style: TextStyle(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '@${widget.author?.username ?? 'user'}',
                          style: TextStyle(
                            color: theme.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_post.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('Draft', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Media Preview (Photo or Video)
            if (primaryMedia != null) ...[
              if (primaryMedia.isImage)
                GestureDetector(
                  onTap: () => _openMediaUrl(primaryMedia.mediaUrl),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 480),
                    width: double.infinity,
                    color: Colors.black12,
                    child: Image.network(
                      primaryMedia.mediaUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 280,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: theme.primary,
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        color: theme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 36, color: theme.mutedText),
                            const SizedBox(height: 6),
                            Text('Unable to load photo', style: TextStyle(color: theme.mutedText, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (primaryMedia.isVideo)
                Container(
                  constraints: const BoxConstraints(maxHeight: 520),
                  width: double.infinity,
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ZVideoPlayerWidget(
                      videoUrl: primaryMedia.mediaUrl,
                      autoPlay: true,
                      looping: true,
                      showControls: true,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],

            // Caption Section
            if (_post.caption != null && _post.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  _post.caption!,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),

            // Actions (Like, Comment, Share, Save, Date)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Like
                      InkWell(
                        onTap: _toggleLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 22,
                                color: _isLiked ? Colors.redAccent : theme.mutedText,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  color: _isLiked ? Colors.redAccent : theme.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Comment
                      InkWell(
                        onTap: _openComments,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 21, color: theme.mutedText),
                              const SizedBox(width: 5),
                              Text(
                                '$_commentCount',
                                style: TextStyle(color: theme.text, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Share
                      IconButton(
                        icon: Icon(Icons.send_outlined, size: 21, color: theme.mutedText),
                        onPressed: _openShare,
                        tooltip: 'Share to Chat',
                      ),

                      const Spacer(),

                      // Bookmark / Save
                      IconButton(
                        icon: Icon(
                          _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 22,
                          color: _isSaved ? theme.primary : theme.mutedText,
                        ),
                        onPressed: _toggleSave,
                        tooltip: _isSaved ? 'Unsave' : 'Save post',
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4),
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        color: theme.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
