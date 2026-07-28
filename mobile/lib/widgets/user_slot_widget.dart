import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/video_filter_settings.dart';

/// A single seat in the Bigo-style multi-guest grid ([LiveRoomGrid]):
/// either a live video feed (host/guest) with a slot number, username,
/// mic-status icon and gift counter, or an empty seat with a "Join"
/// button a viewer can tap to request to co-host.
///
/// Level/VIP/SVIP badges and gift counts are part of the API so this
/// widget's layout matches Bigo's, but nothing in this app tracks
/// per-user levels, VIP tiers, or a persistent gift ledger yet - callers
/// simply don't pass [level]/[isVip]/[isSvip] (or leave [giftCount] at 0)
/// until that data exists for real; the badges just don't render rather
/// than showing made-up numbers.
class UserSlotWidget extends StatelessWidget {
  final int slotNumber;
  final bool isHost;
  final String? name;
  final String? avatarUrl;
  final VideoTrack? videoTrack;
  final bool isMicMuted;
  final bool isEmpty;
  final int giftCount;
  final int? level;
  final bool isVip;
  final bool isSvip;

  /// Tap on an occupied seat - e.g. open a profile/moderation sheet.
  final VoidCallback? onTap;

  /// Tap on an empty seat's "Join" button.
  final VoidCallback? onJoin;

  /// Optional beauty/color grading applied on top of [videoTrack]
  /// (host local preview and remote host tile for viewers).
  final VideoFilterSettings? videoFilters;

  /// When false, only color grading is applied (no blur) — used for remote
  /// tiles so viewers don't pay the blur GPU cost.
  final bool enableFilterBlur;

  /// Optional small control pinned to the bottom-right corner, e.g. this
  /// user's own mic mute toggle on their own seat.
  final Widget? trailing;

  const UserSlotWidget({
    super.key,
    required this.slotNumber,
    this.isHost = false,
    this.name,
    this.avatarUrl,
    this.videoTrack,
    this.isMicMuted = false,
    this.isEmpty = false,
    this.giftCount = 0,
    this.level,
    this.isVip = false,
    this.isSvip = false,
    this.onTap,
    this.onJoin,
    this.videoFilters,
    this.enableFilterBlur = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEmpty ? onJoin : onTap,
      child: Container(
        decoration: BoxDecoration(
          // Square tiles flush against each other (no radius gaps).
          borderRadius: BorderRadius.zero,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isEmpty
                ? const [Color(0xFF2E2348), Color(0xFF1A122C)]
                : const [Color(0xFF3A2C5C), Color(0xFF221636)],
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(),
            // Soft bottom fade so name/badge text stays readable over video.
            if (!isEmpty)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
              ),
            if (isEmpty)
              _buildJoinOverlay()
            else ...[
              Positioned(top: 5, left: 5, right: 5, child: _buildTopRow()),
              Positioned(
                bottom: 5,
                left: 5,
                right: 5,
                child: _buildBottomRow(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (videoTrack != null) {
      Widget video = IgnorePointer(
        child: VideoTrackRenderer(videoTrack!, fit: VideoViewFit.cover),
      );
      final filters = videoFilters;
      if (filters != null && (filters.beautyModeEnabled || filters.isActive)) {
        video = FilteredVideoPreview(
          settings: filters,
          enableBlur: enableFilterBlur,
          child: video,
        );
      }
      return video;
    }
    // No live video (host offline / not publishing) → show profile pic.
    if (!isEmpty && avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _initialAvatar(),
      );
    }
    if (!isEmpty) return _initialAvatar();
    return const SizedBox.shrink();
  }

  Widget _initialAvatar() {
    final initial = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : '?';
    return Container(
      color: const Color(0xFF3A2C5C),
      child: Center(
        child: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white12,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinOverlay() {
    // FittedBox so the icon + "Join" label never overflow tiny seats
    // after the grid scales down to fit short screens.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: onJoin != null
                    ? const Color(0xFF00D4C8)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onJoin,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'Join',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        _pill(child: Text('$slotNumber', style: _pillTextStyle)),
        const SizedBox(width: 3),
        _pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                color: Colors.amberAccent,
                size: 9,
              ),
              const SizedBox(width: 2),
              Text('$giftCount', style: _pillTextStyle),
            ],
          ),
        ),
        const Spacer(),
        if (level != null) ...[_levelBadge(), const SizedBox(width: 3)],
        // Skip top mic when a bottom trailing mic control is already shown
        // (own guest seat) so the tile doesn't show two mic icons.
        if (trailing == null)
          Icon(
            isMicMuted ? Icons.mic_off : Icons.mic,
            size: 12,
            color: isMicMuted ? Colors.redAccent : Colors.white70,
          ),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        if (isHost)
          _tagChip('Host', const Color(0xFF00E5A8))
        else if (isSvip)
          _tagChip('SVIP', Colors.deepPurpleAccent)
        else if (isVip)
          _tagChip('VIP', Colors.amber),
        Expanded(
          child: Text(
            isHost
                ? (name?.isNotEmpty == true ? name! : 'Host')
                : (name?.isNotEmpty == true ? name! : 'Guest'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 2), trailing!],
      ],
    );
  }

  static const _pillTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 9,
    fontWeight: FontWeight.bold,
  );

  Widget _pill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  Widget _levelBadge() {
    // Color scales roughly with level so LV1 and LV20 don't look identical.
    final Color a;
    final Color b;
    final lv = level ?? 1;
    if (lv >= 20) {
      a = const Color(0xFFFF6B6B);
      b = const Color(0xFFFFD93D);
    } else if (lv >= 10) {
      a = const Color(0xFF7C4DFF);
      b = const Color(0xFFE040FB);
    } else if (lv >= 5) {
      a = const Color(0xFFFF8A00);
      b = const Color(0xFFFFD54F);
    } else {
      a = const Color(0xFF26A69A);
      b = const Color(0xFF80CBC4);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a, b]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'LV$level',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _tagChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'Host' ? Colors.black : Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
