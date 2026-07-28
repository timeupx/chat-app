import 'package:flutter/material.dart';

import 'live_room_screen.dart';

/// Compatibility wrapper — the viewer experience now lives in [LiveRoomScreen].
@Deprecated('Use LiveRoomScreen(role: LiveRoomRole.viewer) instead')
class ViewerScreen extends StatelessWidget {
  final String roomName;
  final String hostName;

  const ViewerScreen({
    super.key,
    required this.roomName,
    required this.hostName,
  });

  @override
  Widget build(BuildContext context) {
    return LiveRoomScreen(
      roomName: roomName,
      role: LiveRoomRole.viewer,
      hostName: hostName,
    );
  }
}
