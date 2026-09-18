import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ZVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl; // Poster frame shown before video initialises
  final bool autoPlay;
  final bool looping;
  final bool isMuted;
  final bool showControls;
  final BoxFit fit;
  final VoidCallback? onTap;
  final Function(Duration current, Duration total)? onProgress;

  const ZVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.looping = false,
    this.isMuted = false,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.onTap,
    this.onProgress,
  });

  @override
  State<ZVideoPlayerWidget> createState() => _ZVideoPlayerWidgetState();
}

class _ZVideoPlayerWidgetState extends State<ZVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isMutedState = false;
  bool _showOverlayControls = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isMutedState = widget.isMuted;
    _initializePlayer();
  }

  @override
  void didUpdateWidget(ZVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      try {
        _controller?.pause();
        _controller?.dispose();
      } catch (_) {}
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initializePlayer();
    } else {
      if (oldWidget.isMuted != widget.isMuted) {
        _isMutedState = widget.isMuted;
        _controller?.setVolume(_isMutedState ? 0.0 : 1.0);
      }
      if (oldWidget.autoPlay != widget.autoPlay) {
        if (widget.autoPlay) {
          _controller?.play();
        } else {
          _controller?.pause();
        }
      }
    }
  }

  Future<void> _initializePlayer() async {
    if (widget.videoUrl.trim().isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize();
      if (!mounted || _isDisposed) {
        try {
          controller.dispose();
        } catch (_) {}
        return;
      }

      controller.setLooping(widget.looping);
      controller.setVolume(_isMutedState ? 0.0 : 1.0);

      controller.addListener(() {
        if (!mounted || _isDisposed) return;
        final playing = controller.value.isPlaying;
        if (playing != _isPlaying) {
          setState(() => _isPlaying = playing);
        }
        if (widget.onProgress != null && controller.value.isInitialized) {
          widget.onProgress!(controller.value.position, controller.value.duration);
        }
      });

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.autoPlay) {
          controller.play();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted && !_isDisposed) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _controller?.pause();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _showOverlayControls = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showOverlayControls = false);
    });
  }

  void _toggleMute() {
    setState(() {
      _isMutedState = !_isMutedState;
    });
    _controller?.setVolume(_isMutedState ? 0.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (!_isInitialized || _controller == null) {
      return _buildLoadingState();
    }

    final videoSize = _controller!.value.size;

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          _togglePlayPause();
        }
      },
      child: ClipRect(
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              // Video Surface
              SizedBox.expand(
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: videoSize.width > 0 ? videoSize.width : 300,
                    height: videoSize.height > 0 ? videoSize.height : 300,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

              // Play/Pause Floating Overlay
              if (widget.showControls && (!_isPlaying || _showOverlayControls))
                AnimatedOpacity(
                  opacity: (!_isPlaying || _showOverlayControls) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),

              // Mute / Unmute Button
              if (widget.showControls)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMutedState ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

              // Subtle Progress Bar
              if (widget.showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.transparent,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading state — shows thumbnail poster if available, otherwise a spinner.
  Widget _buildLoadingState() {
    final hasThumbnail = widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (hasThumbnail)
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Container(
            color: Colors.black.withAlpha(hasThumbnail ? 60 : 255),
          ),
          const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
        ],
      ),
    );
  }

  /// Error state — shows thumbnail (if available) with a retry button.
  Widget _buildErrorState() {
    final hasThumbnail = widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    return Container(
      color: Colors.black87,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (hasThumbnail)
            Opacity(
              opacity: 0.4,
              child: Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white54),
              const SizedBox(height: 8),
              const Text(
                'Unable to play video',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
