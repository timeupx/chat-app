import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_model.dart';

/// Renders a single full-screen video page inside the TikTok-style feed,
/// including playback, the like/comment/share rail, captions, and the
/// scrubber. Playback is driven entirely by [isActive] - the parent
/// (`VideosScreen`) decides which page should currently be playing.
class VideoPlayerItem extends StatefulWidget {
  final VideoModel video;
  final bool isActive;

  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _loadFailed = false;

  late bool _isLiked;
  late int _likeCount;
  bool _showHeartBurst = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLiked;
    _likeCount = widget.video.likes;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
    } catch (e, st) {
      // Unsupported codecs on Flutter web used to throw an uncaught
      // PlatformException and leave the whole app on a white screen.
      debugPrint('Video init failed for ${widget.video.videoUrl}: $e\n$st');
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _loadFailed = true;
        _initialized = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _initialized = true);

    if (widget.isActive) {
      controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (!_initialized || _controller == null) return;

    if (widget.isActive) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  void _setLiked(bool liked) {
    if (liked == _isLiked) return;
    setState(() {
      _isLiked = liked;
      _likeCount += liked ? 1 : -1;
    });
  }

  void _handleDoubleTap() {
    _setLiked(true);
    setState(() => _showHeartBurst = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon')));
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video surface (tap to pause/play, double-tap to like).
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          child: Container(
            color: Colors.black,
            child: _loadFailed
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Video unavailable',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : _initialized && controller != null
                    ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                    : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
          ),
        ),

        // Paused indicator.
        if (_initialized &&
            controller != null &&
            !controller.value.isPlaying &&
            !_showHeartBurst)
          const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 88,
              color: Colors.white70,
            ),
          ),

        // Heart burst animation on double-tap.
        IgnorePointer(
          child: Center(
            child: AnimatedScale(
              scale: _showHeartBurst ? 1.1 : 0.4,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _showHeartBurst ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.redAccent,
                  size: 120,
                ),
              ),
            ),
          ),
        ),

        // Right-side action rail: like, comment, share.
        Positioned(
          right: 8,
          bottom: 96,
          child: Column(
            children: [
              _RailAction(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: _isLiked ? Colors.red : Colors.white,
                label: _formatCount(_likeCount),
                onTap: () => _setLiked(!_isLiked),
              ),
              const SizedBox(height: 20),
              _RailAction(
                icon: Icons.comment,
                iconColor: Colors.white,
                label: _formatCount(widget.video.comments),
                onTap: () => _showComingSoon('Comments'),
              ),
              const SizedBox(height: 20),
              _RailAction(
                icon: Icons.share,
                iconColor: Colors.white,
                label: 'Share',
                onTap: () => _showComingSoon('Share'),
              ),
            ],
          ),
        ),

        // Bottom caption / song overlay.
        Positioned(
          left: 12,
          right: 80,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.video.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.video.caption,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MarqueeText(
                      text: widget.video.songName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrub bar.
        if (_initialized && controller != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _RailAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Continuously scrolls [text] horizontally when it doesn't fit in the
/// available width - used for the "now playing" song name.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = painter.width;
        final boxWidth = constraints.maxWidth;

        if (textWidth <= boxWidth || boxWidth <= 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return ClipRect(
          child: SizedBox(
            height: painter.height,
            width: boxWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final dx = boxWidth - (boxWidth + textWidth) * _controller.value;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: dx,
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
