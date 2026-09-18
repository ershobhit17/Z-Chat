import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/media_storage_service.dart';
import '../../services/post_service.dart';
import '../../theme/theme_provider.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedMediaBytes;
  String? _selectedMediaName;
  String? _selectedMediaType; // 'image' or 'video'
  String _visibility = 'public'; // 'public' or 'private'
  bool _isUploading = false;
  String? _uploadStatusText;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedMediaBytes = bytes;
          _selectedMediaName = picked.name;
          _selectedMediaType = 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        // Check 100MB limit
        if (bytes.length > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video exceeds 100MB limit.')),
            );
          }
          return;
        }

        setState(() {
          _selectedMediaBytes = bytes;
          _selectedMediaName = picked.name;
          _selectedMediaType = 'video';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  void _removeSelectedMedia() {
    setState(() {
      _selectedMediaBytes = null;
      _selectedMediaName = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedMediaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo, video, or caption to post.')),
      );
      return;
    }

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Creating post...';
    });

    try {
      final postService = context.read<PostService>();
      final storage = context.read<MediaStorageService>();

      List<Map<String, dynamic>> mediaItems = [];

      if (_selectedMediaBytes != null && _selectedMediaType != null) {
        setState(() => _uploadStatusText = 'Uploading media to secure storage...');

        final ext = _selectedMediaName?.contains('.') == true
            ? _selectedMediaName!.split('.').last.toLowerCase()
            : (_selectedMediaType == 'video' ? 'mp4' : 'jpg');

        final mime = _selectedMediaType == 'video' ? 'video/$ext' : 'image/$ext';

        // Upload media via MediaStorageService (Cloudflare R2 with fallback)
        final uploadResult = await storage.uploadBytes(
          bytes: _selectedMediaBytes!,
          fileExtension: ext,
          mimeType: mime,
          category: MediaCategory.post,
        );

        mediaItems.add({
          'object_key': uploadResult.objectKey,
          'media_url': uploadResult.publicUrl,
          'media_type': _selectedMediaType!,
          'mime_type': mime,
          'file_size': _selectedMediaBytes!.length,
          'sort_order': 0,
        });
      }

      setState(() => _uploadStatusText = 'Publishing...');

      final newPost = await postService.createPost(
        caption: caption.isNotEmpty ? caption : null,
        visibility: _visibility,
        mediaList: mediaItems,
      );

      if (mounted) {
        Navigator.pop(context, newPost);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_visibility == 'public' ? 'Post published!' : 'Draft saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal handle & title
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Post',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Visibility selector badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _visibility,
                      dropdownColor: theme.surface,
                      isDense: true,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      icon: Icon(Icons.arrow_drop_down, color: theme.mutedText, size: 18),
                      items: const [
                        DropdownMenuItem(
                          value: 'public',
                          child: Row(
                            children: [
                              Icon(Icons.public_rounded, size: 14, color: Colors.green),
                              SizedBox(width: 6),
                              Text('Public'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 14, color: Colors.orange),
                              SizedBox(width: 6),
                              Text('Private Draft'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _isUploading
                          ? null
                          : (val) {
                              if (val != null) setState(() => _visibility = val);
                            },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Caption input
            Container(
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                enabled: !_isUploading,
                style: TextStyle(color: theme.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(color: theme.mutedText),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Media Preview if selected
            if (_selectedMediaBytes != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.black12,
                      child: _selectedMediaType == 'image'
                          ? Image.memory(
                              _selectedMediaBytes!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.black87,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_circle_fill_rounded, size: 48, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedMediaName ?? 'Selected Video',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _isUploading ? null : _removeSelectedMedia,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ] else ...[
              // Media pick buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: theme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isUploading ? null : _pickImage,
                      icon: Icon(Icons.photo_library_outlined, size: 18, color: theme.primary),
                      label: Text('Photo', style: TextStyle(color: theme.text, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: theme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isUploading ? null : _pickVideo,
                      icon: Icon(Icons.videocam_outlined, size: 20, color: theme.primary),
                      label: Text('Video', style: TextStyle(color: theme.text, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Submit Button or Loading State
            if (_isUploading) ...[
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5, color: theme.primary),
                    const SizedBox(height: 10),
                    Text(
                      _uploadStatusText ?? 'Uploading...',
                      style: TextStyle(color: theme.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _submitPost,
                child: const Text(
                  'Share Post',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
