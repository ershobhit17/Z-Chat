import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/moment_service.dart';
import '../../theme/theme_provider.dart';

class CreateMomentModal extends StatefulWidget {
  const CreateMomentModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateMomentModal(),
    );
  }

  @override
  State<CreateMomentModal> createState() => _CreateMomentModalState();
}

class _CreateMomentModalState extends State<CreateMomentModal> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  Uint8List? _mediaBytes;
  String? _fileName;
  String? _mimeType;
  bool _isUploading = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      XFile? file;
      if (isVideo) {
        file = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30),
        );
      } else {
        file = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
      }

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _mediaBytes = bytes;
          _fileName = file!.name;
          _mimeType = isVideo ? 'video/mp4' : 'image/jpeg';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick media: $e')),
        );
      }
    }
  }

  Future<void> _uploadMoment() async {
    if (_mediaBytes == null || _fileName == null || _mimeType == null || _isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo or video first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final momentService = Provider.of<MomentService>(context, listen: false);
      await momentService.createMoment(
        bytes: _mediaBytes!,
        fileName: _fileName!,
        mimeType: _mimeType!,
        caption: _captionController.text.trim(),
        visibility: _visibility,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moment shared successfully! (Expires in 24h)')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add to Moments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                TextButton(
                  onPressed: _isUploading ? null : _uploadMoment,
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Share',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preview Box
                  if (_mediaBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 320,
                            width: double.infinity,
                            color: Colors.black,
                            child: _mimeType?.startsWith('video') == true
                                ? const Center(
                                    child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70),
                                  )
                                : Image.memory(
                                    _mediaBytes!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              onPressed: () {
                                setState(() {
                                  _mediaBytes = null;
                                  _fileName = null;
                                  _mimeType = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withAlpha(50), style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPickerButton(
                            icon: Icons.photo_library_rounded,
                            label: 'Photo',
                            onTap: () => _pickMedia(ImageSource.gallery, isVideo: false),
                            theme: theme,
                          ),
                          _buildPickerButton(
                            icon: Icons.video_library_rounded,
                            label: 'Video',
                            onTap: () => _pickMedia(ImageSource.gallery, isVideo: true),
                            theme: theme,
                          ),
                          _buildPickerButton(
                            icon: Icons.camera_alt_rounded,
                            label: 'Camera',
                            onTap: () => _pickMedia(ImageSource.camera, isVideo: false),
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Caption
                  TextField(
                    controller: _captionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a moment caption... (optional)',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.withAlpha(60)),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(4),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visibility dropdown
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Audience: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _visibility,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'public', child: Text('Public')),
                          DropdownMenuItem(value: 'followers', child: Text('Followers Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _visibility = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Moments automatically disappear after 24 hours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.primaryColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.primaryColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
