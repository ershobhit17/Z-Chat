import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/media_storage_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _statusController;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthService>().currentProfile;
    _displayNameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _statusController = TextEditingController(text: profile?.status ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final auth = context.read<AuthService>();
    final storage = context.read<MediaStorageService>();
    final uid = auth.currentUser?.id;
    if (uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';

      final oldAvatarKey = auth.currentProfile?.avatarObjectKey;

      final uploadResult = await storage.uploadBytes(
        bytes: bytes,
        fileExtension: ext,
        mimeType: 'image/$ext',
        category: MediaCategory.avatar,
      );

      await auth.updateProfile(
        avatarUrl: uploadResult.publicUrl,
        avatarObjectKey: uploadResult.objectKey,
      );

      // Clean up old avatar from R2 / storage if present
      if (oldAvatarKey != null && oldAvatarKey.isNotEmpty && oldAvatarKey != uploadResult.objectKey) {
        try {
          await storage.delete(oldAvatarKey);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthService>();
      await auth.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        status: _statusController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    final profile = context.watch<AuthService>().currentProfile;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: theme.getTextStyle(
            baseSize: 17.0,
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Avatar with edit button
          Center(
            child: Stack(
              children: [
                AvatarWidget(
                  displayName: profile?.displayName ?? 'User',
                  avatarUrl: profile?.avatarUrl,
                  size: 88,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.surface, width: 2),
                      ),
                      child: _isUploadingAvatar
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '@${profile?.username ?? 'username'}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primary),
            ),
          ),
          const SizedBox(height: 28),

          // Display Name
          Text('DISPLAY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _displayNameController,
            style: TextStyle(color: theme.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
            ),
          ),
          const SizedBox(height: 18),

          // Bio
          Text('BIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _bioController,
            maxLines: 3,
            style: TextStyle(color: theme.text),
            decoration: InputDecoration(
              hintText: 'Tell the world about yourself...',
              hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6)),
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
            ),
          ),
          const SizedBox(height: 18),

          // Status message
          Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: theme.mutedText)),
          const SizedBox(height: 6),
          TextField(
            controller: _statusController,
            style: TextStyle(color: theme.text),
            decoration: InputDecoration(
              hintText: 'e.g. Building AI things 🚀',
              hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6)),
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
            ),
          ),
        ],
      ),
    );
  }
}
