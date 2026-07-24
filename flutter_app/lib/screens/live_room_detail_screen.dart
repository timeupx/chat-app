import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/live_room_model.dart';
import '../services/live_room_service.dart';
import '../services/room_socket_service.dart';
import 'host_screen.dart';
import 'viewer_screen.dart';

enum _DetailStatus { loading, ready, error }

/// Room landing page shown before actually joining the live session.
/// Displays name/image/rules/18+ badge, and renders the "GO LIVE" button
/// ONLY when the backend's `isHost` flag says so - never a client-side
/// `currentUserId == hostId` comparison.
class LiveRoomDetailScreen extends StatefulWidget {
  final String roomId;

  const LiveRoomDetailScreen({super.key, required this.roomId});

  @override
  State<LiveRoomDetailScreen> createState() => _LiveRoomDetailScreenState();
}

class _LiveRoomDetailScreenState extends State<LiveRoomDetailScreen> {
  final _liveRoomService = LiveRoomService();
  final _roomSocket = RoomSocketService.instance;
  StreamSubscription<({String roomId, bool isLive})>? _statusSub;

  _DetailStatus _status = _DetailStatus.loading;
  LiveRoomModel? _room;
  String? _errorMessage;
  bool _isStartingLive = false;

  @override
  void initState() {
    super.initState();
    _load();

    // Fixes the "Host has not started streaming yet" placeholder never
    // going away: this screen used to fetch the room's isLive status ONCE
    // and never again, so a viewer who opened it before the host went live
    // was stuck on the stale offline state forever. Now it reacts to the
    // same global broadcast LiveRoomListScreen uses.
    _roomSocket.connectLobby();
    _statusSub = _roomSocket.roomStatusUpdates.listen((event) {
      if (event.roomId == widget.roomId) _silentRefresh();
    });
  }

  /// Like [_load], but doesn't flash the whole screen back to a loading
  /// spinner - just quietly swaps in the fresh room data once it arrives.
  Future<void> _silentRefresh() async {
    try {
      final room = await _liveRoomService.getRoomDetail(widget.roomId);
      if (!mounted) return;
      setState(() => _room = room);
    } on LiveRoomException {
      // Keep showing whatever we already have; the user can still pull
      // this screen's Retry button if something is properly broken.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _roomSocket.disconnectLobby();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = _DetailStatus.loading;
      _errorMessage = null;
    });

    try {
      final room = await _liveRoomService.getRoomDetail(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _status = _DetailStatus.ready;
      });
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _DetailStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _handleGoLive() async {
    final room = _room;
    if (room == null) return;

    setState(() => _isStartingLive = true);
    try {
      // Only flips the DB flag if not already live - the host may be
      // re-opening this screen after navigating away mid-stream.
      if (!room.isLive) {
        await _liveRoomService.goLive(room.id);
      }
      if (!mounted) return;

      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => HostScreen(roomName: room.id)));

      // Refresh isLive/viewerCount once the host comes back from streaming.
      if (mounted) _load();
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isStartingLive = false);
    }
  }

  void _handleWatchLive() {
    final room = _room;
    if (room == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(roomName: room.id, hostName: room.hostName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _DetailStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case _DetailStatus.error:
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Could not load this room.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        );

      case _DetailStatus.ready:
        return _buildReady(context, _room!);
    }
  }

  Widget _buildReady(BuildContext context, LiveRoomModel room) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(room.roomName)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: room.roomImage,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 220,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  height: 220,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              ),
              if (room.is18Plus)
                Positioned(top: 12, left: 12, child: _Badge(text: '18+', color: Colors.red)),
              if (room.isLive)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Badge(text: '🔴 LIVE', color: Colors.red),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.roomName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: room.hostPhoto != null
                          ? CachedNetworkImageProvider(room.hostPhoto!)
                          : null,
                      child: room.hostPhoto == null
                          ? Text(room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : '?')
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Hosted by ${room.hostName}', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Icon(Icons.visibility, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(room.formattedViewerCount, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Room Rules',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  (room.roomRules?.isNotEmpty ?? false)
                      ? room.roomRules!
                      : 'No specific rules set for this room.',
                ),
                const SizedBox(height: 32),
                _buildActionArea(room),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(LiveRoomModel room) {
    // CRITICAL: this is the only place the "GO LIVE" button can appear, and
    // it is strictly gated by the server-computed `isHost` flag from the
    // room-detail response - never a client-side ID comparison.
    if (room.isHost == true) {
      return _buildGoLiveButton(room);
    }

    if (room.isLive) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _handleWatchLive,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Watch Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: Text('Host has not started streaming yet')),
    );
  }

  /// A prominent, gradient-filled CTA - the same visual language as
  /// CreateLiveRoomScreen's "Create Room" button - with a loading state
  /// while the go-live REST call is in flight.
  Widget _buildGoLiveButton(LiveRoomModel room) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _isStartingLive ? null : _handleGoLive,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isStartingLive
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          room.isLive ? 'RESUME LIVE' : 'GO LIVE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
