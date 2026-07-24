import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/live_room_model.dart';
import '../services/live_room_service.dart';
import '../services/room_socket_service.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import 'create_live_room_screen.dart';
import 'live_room_detail_screen.dart';

enum _ListStatus { loading, ready, error }

/// Bigo Live / TikTok Live style grid of rooms - 2 columns, square cards,
/// room image as background, LIVE + 18+ badges, host name + viewer count
/// overlay. Backed by the real `/api/live-rooms` list - no mock data.
class LiveRoomListScreen extends StatefulWidget {
  const LiveRoomListScreen({super.key});

  @override
  State<LiveRoomListScreen> createState() => _LiveRoomListScreenState();
}

class _LiveRoomListScreenState extends State<LiveRoomListScreen> {
  final _liveRoomService = LiveRoomService();
  final _roomSocket = RoomSocketService.instance;
  StreamSubscription<({String roomId, bool isLive})>? _statusSub;

  _ListStatus _status = _ListStatus.loading;
  List<LiveRoomModel> _rooms = [];
  String? _errorMessage;

  // Needed for the "my own room floats to the top even offline" sort rule
  // below - decoded once from the stored access token, the same way
  // ProfileScreen reads the logged-in user without a dedicated /me call.
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
    _roomSocket.connectLobby();
    _statusSub = _roomSocket.roomStatusUpdates.listen(_handleStatusUpdate);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _roomSocket.disconnectLobby();
    super.dispose();
  }

  Future<void> _init() async {
    final token = await SecureStorageHelper.getToken();
    if (token != null) {
      _currentUserId = decodeJwtPayload(token)?['userId'] as String?;
    }
    await _loadRooms();
  }

  /// Applies a live `room:statusUpdated` push in place - no refetch needed
  /// - then re-sorts so offline rooms immediately drop to the bottom (and
  /// newly-live ones jump to the top) without the user pulling to refresh.
  void _handleStatusUpdate(({String roomId, bool isLive}) event) {
    final index = _rooms.indexWhere((r) => r.id == event.roomId);
    if (index == -1) return;

    setState(() {
      _rooms[index] = _rooms[index].copyWith(isLive: event.isLive);
      _sortRooms();
    });
  }

  /// Custom client-side sort (deliberately NOT done in Prisma/the backend -
  /// prioritizing "your own room" depends on the requesting user's id,
  /// which is a per-viewer concern the room list itself has no notion of):
  ///
  ///   1. Live rooms first.
  ///   2. Your OWN room next, even while offline.
  ///   3. Everything else, by current viewer count.
  void _sortRooms() {
    _rooms.sort((a, b) {
      // 1. Live rooms first.
      if (a.isLive && !b.isLive) return -1;
      if (!a.isLive && b.isLive) return 1;

      // 2. My own room next (whether both are offline or both are live).
      final aIsMine = a.hostId == _currentUserId;
      final bIsMine = b.hostId == _currentUserId;

      if (aIsMine && !bIsMine) return -1;
      if (!aIsMine && bIsMine) return 1;

      // 3. Sort by viewer count.
      return b.viewerCount.compareTo(a.viewerCount);
    });
  }

  Future<void> _loadRooms() async {
    setState(() {
      _status = _ListStatus.loading;
      _errorMessage = null;
    });

    try {
      final rooms = await _liveRoomService.listRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _sortRooms();
        _status = _ListStatus.ready;
      });
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _ListStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _openCreateRoom() async {
    // Refresh the list when coming back, in case a new room was created.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()));
    if (mounted) _loadRooms();
  }

  void _openRoomDetail(LiveRoomModel room) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LiveRoomDetailScreen(roomId: room.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Room',
            onPressed: _openCreateRoom,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _ListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _ListStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'Could not load rooms.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _loadRooms, child: const Text('Retry')),
              ],
            ),
          ),
        );
      case _ListStatus.ready:
        if (_rooms.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('No rooms yet - be the first to create one!'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _openCreateRoom, child: const Text('Create Room')),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadRooms,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _rooms.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final room = _rooms[index];
              return _LiveRoomCard(room: room, onTap: () => _openRoomDetail(room));
            },
          ),
        );
    }
  }
}

class _LiveRoomCard extends StatelessWidget {
  final LiveRoomModel room;
  final VoidCallback onTap;

  const _LiveRoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The room's own image (picked by the host) as background.
                CachedNetworkImage(
                  imageUrl: room.roomImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported, size: 48),
                  ),
                ),

                // Dim overlay when offline so it reads as inactive.
                if (!room.isLive)
                  Container(color: Colors.black.withValues(alpha: 0.45)),

                // LIVE badge, top-left.
                if (room.isLive)
                  const Positioned(top: 8, left: 8, child: _CardBadge(text: '🔴 LIVE')),

                // 18+ badge, top-right.
                if (room.is18Plus)
                  const Positioned(top: 8, right: 8, child: _CardBadge(text: '18+')),

                // Room name + host + viewer count, bottom-left, over a dark
                // gradient for readability.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 28, 10, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room.roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          room.hostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        if (room.isLive) ...[
                          const SizedBox(height: 2),
                          Text(
                            '👁️ ${room.formattedViewerCount}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String text;

  const _CardBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
