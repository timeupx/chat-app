import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Bigo-style multi-guest video stage: the host's tile is always bigger
/// than any guest tiles.
///
///  - 0 guests: just the host, full-bleed (unchanged single-broadcaster
///    look - this is the common case).
///  - 1 guest: screen splits host/guest side-by-side.
///  - 2-6 guests: host sits on top (still the biggest tile), guests fill a
///    smaller grid underneath.
///
/// Used by both the host's own screen (their guests) and the viewer/swipe
/// screen (host + every guest), so the exact same layout rules apply
/// everywhere a room is watched from.
class MultiGuestStage extends StatelessWidget {
  final Widget hostTile;
  final List<Widget> guestTiles;

  const MultiGuestStage({super.key, required this.hostTile, required this.guestTiles});

  @override
  Widget build(BuildContext context) {
    if (guestTiles.isEmpty) return hostTile;

    if (guestTiles.length == 1) {
      return Row(
        children: [
          Expanded(flex: 3, child: hostTile),
          const SizedBox(width: 2),
          Expanded(flex: 2, child: guestTiles.first),
        ],
      );
    }

    // 3 columns once there are more than 4 guests (i.e. 5-6), otherwise 2 -
    // keeps tiles from getting too thin as more people join.
    final columns = guestTiles.length <= 4 ? 2 : 3;
    return Column(
      children: [
        Expanded(flex: 3, child: hostTile),
        const SizedBox(height: 2),
        Expanded(
          flex: 2,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.85,
            ),
            itemCount: guestTiles.length,
            itemBuilder: (context, index) => guestTiles[index],
          ),
        ),
      ],
    );
  }
}

/// A single participant's video tile for [MultiGuestStage]: the video (or
/// a spinner while it's still loading) with a small name label pinned to
/// the bottom-left corner.
class ParticipantVideoTile extends StatelessWidget {
  final VideoTrack? track;
  final String label;
  final bool isHost;

  /// Optional small control pinned to the bottom-right corner - e.g. a mic
  /// mute toggle on a guest's own tile in the grid.
  final Widget? trailing;

  const ParticipantVideoTile({
    super.key,
    required this.track,
    required this.label,
    this.isHost = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final track = this.track;
    return ClipRect(
      child: Container(
        color: Colors.grey.shade900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null)
              IgnorePointer(child: VideoTrackRenderer(track, fit: VideoViewFit.cover))
            else
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isHost ? 12 : 10,
                    fontWeight: isHost ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (trailing != null) Positioned(right: 6, bottom: 6, child: trailing!),
          ],
        ),
      ),
    );
  }
}
