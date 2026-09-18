import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/moment_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/video_player_widget.dart';

class MomentViewerScreen extends StatefulWidget {
  final List<Moment> moments;
  final int initialIndex;

  const MomentViewerScreen({
    super.key,
    required this.moments,
    this.initialIndex = 0,
  });

  @override
  State<MomentViewerScreen> createState() => _MomentViewerScreenState();
}

class _MomentViewerScreenState extends State<MomentViewerScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.moments.length - 1);
    _animController = AnimationController(vsync: this);
    _loadCurrentMoment();
  }

  void _loadCurrentMoment() {
    _animController.stop();
    _animController.reset();

    final moment = widget.moments[_currentIndex];
    final momentService = Provider.of<MomentService>(context, listen: false);
    momentService.markMomentViewed(moment.id);

    // Auto advance after 5 seconds
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextMoment();
      }
    });
  }

  void _nextMoment() {
    if (_currentIndex < widget.moments.length - 1) {
      setState(() => _currentIndex++);
      _loadCurrentMoment();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevMoment() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadCurrentMoment();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _showViewersSheet(Moment moment) async {
    _animController.stop();
    final momentService = Provider.of<MomentService>(context, listen: false);
    final viewers = await momentService.getMomentViewers(moment.id);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFF1E2026),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, size: 20, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'Viewers (${viewers.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
            Expanded(
              child: viewers.isEmpty
                  ? const Center(
                      child: Text('No views yet', style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (_, i) {
                        final v = viewers[i];
                        final u = v.viewerProfile;
                        return ListTile(
                          leading: AvatarWidget(
                            displayName: u?.displayName ?? 'User',
                            avatarUrl: u?.avatarUrl,
                            size: 40,
                          ),
                          title: Text(u?.displayName ?? 'User', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('@${u?.username ?? 'user'}', style: const TextStyle(color: Colors.white54)),
                          trailing: Text(
                            DateFormat.jm().format(v.viewedAt.toLocal()),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    if (mounted) {
      _animController.forward();
    }
  }

  void _deleteCurrentMoment(Moment moment) async {
    _animController.stop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Moment?'),
        content: const Text('This moment will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final momentService = Provider.of<MomentService>(context, listen: false);
      await momentService.deleteMoment(moment.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moments.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final moment = widget.moments[_currentIndex];
    final author = moment.userProfile;
    final myUid = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final isOwner = moment.userId == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevMoment();
          } else {
            _nextMoment();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Background
            Center(
              child: moment.isVideo
                  ? ZVideoPlayerWidget(
                      videoUrl: moment.mediaUrl,
                      autoPlay: true,
                      looping: false,
                      showControls: false,
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      moment.mediaUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                      ),
                    ),
            ),

            // Top Gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Top Header: Segmented Progress Bar & Author Info
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  // Progress Bars Row
                  Row(
                    children: List.generate(widget.moments.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, _) {
                              double val = 0.0;
                              if (index < _currentIndex) {
                                val = 1.0;
                              } else if (index == _currentIndex) {
                                val = _animController.value;
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: val,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 2.5,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Author Info & Close Button
                  Row(
                    children: [
                      AvatarWidget(
                        displayName: author?.displayName ?? 'User',
                        avatarUrl: author?.avatarUrl,
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author?.displayName ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat.jm().format(moment.createdAt.toLocal()),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          onPressed: () => _deleteCurrentMoment(moment),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Caption & Viewers Bar
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (moment.caption != null && moment.caption!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        moment.caption!,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isOwner)
                    GestureDetector(
                      onTap: () => _showViewersSheet(moment),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Views', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
