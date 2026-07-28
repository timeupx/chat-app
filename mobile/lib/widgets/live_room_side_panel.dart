import 'package:flutter/material.dart';

import '../models/gift_model.dart';

/// Optional right-side chips next to the live grid (host name / room note).
/// Returns nothing when there is no real data — no fake promo banners.
class LiveRoomSideBanners extends StatelessWidget {
  final String? roomDescription;
  final String? locationLabel;

  const LiveRoomSideBanners({
    super.key,
    this.roomDescription,
    this.locationLabel,
  });

  bool get hasContent {
    final loc = locationLabel?.trim() ?? '';
    final desc = roomDescription?.trim() ?? '';
    return loc.isNotEmpty || desc.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locationLabel != null && locationLabel!.trim().isNotEmpty) ...[
          _InfoChip(
            icon: Icons.person_outline,
            text: locationLabel!.trim(),
          ),
          const SizedBox(height: 8),
        ],
        if (roomDescription != null && roomDescription!.trim().isNotEmpty)
          _InfoChip(
            icon: Icons.info_outline,
            text: roomDescription!.trim(),
            maxLines: 3,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nickname gift banner under the camera grid.
/// Slides in from the right → pauses in the center → exits left.
/// Transparent background with animated rainbow nickname text.
class LiveGiftToast extends StatefulWidget {
  final String username;
  final GiftModel gift;

  const LiveGiftToast({
    super.key,
    required this.username,
    required this.gift,
  });

  @override
  State<LiveGiftToast> createState() => _LiveGiftToastState();
}

class _LiveGiftToastState extends State<LiveGiftToast>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  late final AnimationController _rainbowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  /// Right → center (hold longer) → left.
  late final Animation<double> _slide = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: ConstantTween(0.0),
      weight: 58,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -1.0)
          .chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 24,
    ),
  ]).animate(_slideCtrl);

  static const _rainbow = [
    Color(0xFFFF0040),
    Color(0xFFFF7A00),
    Color(0xFFFFEE00),
    Color(0xFF00E676),
    Color(0xFF00E5FF),
    Color(0xFF2979FF),
    Color(0xFFD500F9),
    Color(0xFFFF0040),
  ];

  @override
  void dispose() {
    _slideCtrl.dispose();
    _rainbowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = constraints.maxWidth;
        return AnimatedBuilder(
          animation: Listenable.merge([_slide, _rainbowCtrl]),
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(_slide.value * travel, 0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    color: Colors.transparent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              final shift = _rainbowCtrl.value;
                              return LinearGradient(
                                colors: _rainbow,
                                begin: Alignment(-1.0 + shift * 2, 0),
                                end: Alignment(1.0 + shift * 2, 0),
                              ).createShader(bounds);
                            },
                            child: Text(
                              widget.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'sent ${widget.gift.emoji} ${widget.gift.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'x1',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
