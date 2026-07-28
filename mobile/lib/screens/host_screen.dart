import 'package:flutter/material.dart';

import 'live_room_screen.dart';

/// Compatibility wrapper — the host experience now lives in [LiveRoomScreen].
///
/// GPU beauty (skin smooth + whitening) is applied on the host camera tile
/// via [FilteredVideoPreview] / [GpuImageFilter] inside [LiveRoomScreen].
/// Open the Beauty control on the top bar to toggle / set intensity.
@Deprecated('Use LiveRoomScreen(role: LiveRoomRole.host) instead')
class HostScreen extends StatelessWidget {
  final String roomName;

  /// Optional beauty preset name (e.g. Natural, Smooth) seeded into the room.
  final String? initialFilterName;

  const HostScreen({
    super.key,
    required this.roomName,
    this.initialFilterName,
  });

  @override
  Widget build(BuildContext context) {
    return LiveRoomScreen(
      roomName: roomName,
      role: LiveRoomRole.host,
      initialFilterName: initialFilterName,
    );
  }
}
