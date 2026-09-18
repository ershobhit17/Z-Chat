import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/profile/user_profile_screen.dart';

void showProfilePictureViewer(
  BuildContext context, {
  required String? avatarUrl,
  required String displayName,
  String? username,
  UserProfile? user,
}) {
  showDialog(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black.withAlpha(210),
    builder: (ctx) => _ProfilePictureViewerDialog(
      avatarUrl: avatarUrl,
      displayName: displayName,
      username: username,
      user: user,
    ),
  );
}

class _ProfilePictureViewerDialog extends StatefulWidget {
  final String? avatarUrl;
  final String displayName;
  final String? username;
  final UserProfile? user;

  const _ProfilePictureViewerDialog({
    required this.avatarUrl,
    required this.displayName,
    this.username,
    this.user,
  });

  @override
  State<_ProfilePictureViewerDialog> createState() => _ProfilePictureViewerDialogState();
}

class _ProfilePictureViewerDialogState extends State<_ProfilePictureViewerDialog> {
  final TransformationController _transController = TransformationController();

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  String _getInitials() {
    if (widget.displayName.trim().isEmpty) return '?';
    final parts = widget.displayName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.displayName.trim().substring(0, widget.displayName.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (widget.user != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: widget.user!),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 18),
                label: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // User header info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      widget.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.username != null && widget.username!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${widget.username}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Interactive zoomable image
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transController,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: hasImage
                        ? Container(
                            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                widget.avatarUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: 280,
                                    height: 280,
                                    color: Colors.black26,
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => _buildFallbackAvatar(280),
                              ),
                            ),
                          )
                        : _buildFallbackAvatar(240),
                  ),
                ),
              ),

              // Bottom hint
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pinch_rounded, size: 16, color: Colors.white.withAlpha(120)),
                    const SizedBox(width: 6),
                    Text(
                      'Pinch to zoom',
                      style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
