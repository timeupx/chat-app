import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Live room top bar: host avatar + names, eye/count, optional ban + filter
/// (host), then fullscreen / close.
class LiveRoomTopBar extends StatelessWidget {
  final String roomName;
  final String hostName;
  final String? hostAvatarUrl;
  final int viewerCount;
  final VoidCallback onClose;
  final VoidCallback onFullscreen;
  final bool isFullscreen;

  /// Tap the eye / count pill to open the online viewer list.
  final VoidCallback? onTapViewerCount;

  /// Host-only: open banned users list.
  final VoidCallback? onBannedUsers;

  /// Host-only: open beauty filters.
  final VoidCallback? onFilters;

  /// Host-only: delete this room (after confirmation in the parent).
  final VoidCallback? onDeleteRoom;

  const LiveRoomTopBar({
    super.key,
    required this.roomName,
    required this.hostName,
    this.hostAvatarUrl,
    required this.viewerCount,
    required this.onClose,
    required this.onFullscreen,
    this.isFullscreen = false,
    this.onTapViewerCount,
    this.onBannedUsers,
    this.onFilters,
    this.onDeleteRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _hostPill(),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                roomName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                hostName.isNotEmpty ? hostName : 'Host',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
        _viewerCountPill(),
        if (onFilters != null) ...[
          const SizedBox(width: 4),
          _circleButton(
            icon: Icons.face_retouching_natural,
            onTap: onFilters!,
          ),
        ],
        const SizedBox(width: 4),
        _circleButton(
          icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          onTap: onFullscreen,
        ),
        // Host-only banned list — sits beside the close (exit) button.
        if (onBannedUsers != null) ...[
          const SizedBox(width: 4),
          _circleButton(icon: Icons.list_alt, onTap: onBannedUsers!),
        ],
        if (onDeleteRoom != null) ...[
          const SizedBox(width: 4),
          _circleButton(
            icon: Icons.delete_outline,
            onTap: onDeleteRoom!,
            iconColor: const Color(0xFFFF6B6B),
          ),
        ],
        const SizedBox(width: 4),
        _circleButton(icon: Icons.close, onTap: onClose),
      ],
    );
  }

  Widget _hostPill() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
        color: Colors.black26,
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white24,
        backgroundImage: (hostAvatarUrl != null && hostAvatarUrl!.isNotEmpty)
            ? CachedNetworkImageProvider(hostAvatarUrl!)
            : null,
        child: (hostAvatarUrl == null || hostAvatarUrl!.isEmpty)
            ? Text(
                hostName.isNotEmpty
                    ? hostName[0].toUpperCase()
                    : (roomName.isNotEmpty ? roomName[0].toUpperCase() : '?'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.black38,
    Color iconColor = Colors.white,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: iconColor, size: 15),
        ),
      ),
    );
  }

  Widget _viewerCountPill() {
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTapViewerCount,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_red_eye, color: Colors.white70, size: 12),
              const SizedBox(width: 3),
              Text(
                _formatCount(viewerCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
