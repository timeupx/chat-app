import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/live_room_model.dart';
import '../services/live_room_service.dart';
import '../services/room_socket_service.dart';
import '../theme/bigo_theme.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import 'create_live_room_screen.dart';
import 'live_room_screen.dart';

enum _ListStatus { loading, ready, error }

/// Neon Night Live feed — atmospheric header, clean category rail,
/// full-bleed room covers that feel like stages, not cards.
class LiveRoomListScreen extends StatefulWidget {
  const LiveRoomListScreen({super.key});

  @override
  State<LiveRoomListScreen> createState() => _LiveRoomListScreenState();
}

class _LiveRoomListScreenState extends State<LiveRoomListScreen> {
  final _liveRoomService = LiveRoomService();
  final _roomSocket = RoomSocketService.instance;
  StreamSubscription<({String roomId, bool isLive, bool deleted})>? _statusSub;

  _ListStatus _status = _ListStatus.loading;
  List<LiveRoomModel> _rooms = [];
  String? _errorMessage;
  String? _currentUserId;

  static const _categories = ['Popular', 'Nearby', 'New', 'Party'];
  int _selectedCategory = 0;

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

  void _handleStatusUpdate(({String roomId, bool isLive, bool deleted}) event) {
    if (event.deleted) {
      setState(() {
        _rooms.removeWhere((r) => r.id == event.roomId);
      });
      return;
    }

    final index = _rooms.indexWhere((r) => r.id == event.roomId);
    if (index == -1) return;

    setState(() {
      _rooms[index] = _rooms[index].copyWith(isLive: event.isLive);
      _sortRooms();
    });
  }

  void _sortRooms() {
    _rooms.sort((a, b) {
      if (a.isLive && !b.isLive) return -1;
      if (!a.isLive && b.isLive) return 1;

      final aIsMine = a.hostId == _currentUserId;
      final bIsMine = b.hostId == _currentUserId;
      if (aIsMine && !bIsMine) return -1;
      if (!aIsMine && bIsMine) return 1;

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
    if (_currentUserId != null) {
      for (final room in _rooms) {
        if (room.hostId == _currentUserId) {
          await _openOwnRoomAsHost(room);
          return;
        }
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()),
    );
    if (mounted) _loadRooms();
  }

  Future<void> _openRoom(LiveRoomModel room) async {
    if (room.hostId != null && room.hostId == _currentUserId) {
      await _openOwnRoomAsHost(room);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(
          roomName: room.id,
          role: LiveRoomRole.viewer,
          hostName: room.hostName,
          initialFilterName: room.filterName,
          initialSlotCount: room.slotCount,
        ),
      ),
    );
    if (mounted) _loadRooms();
  }

  Future<void> _openOwnRoomAsHost(LiveRoomModel room) async {
    try {
      final detail = await _liveRoomService.getRoomDetail(room.id);
      if (!mounted) return;

      if (detail.isHost != true) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(
              roomName: room.id,
              role: LiveRoomRole.viewer,
              hostName: room.hostName,
              initialFilterName: room.filterName,
              initialSlotCount: room.slotCount,
            ),
          ),
        );
        if (mounted) _loadRooms();
        return;
      }

      if (!detail.isLive) {
        await _liveRoomService.goLive(room.id);
      }
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(
            roomName: room.id,
            role: LiveRoomRole.host,
            initialFilterName: room.filterName,
            initialSlotCount: room.slotCount,
          ),
        ),
      );
      if (mounted) _loadRooms();
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  int get _liveCount => _rooms.where((r) => r.isLive).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigoColors.bg,
      body: Stack(
        children: [
          const _AtmosphereBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildCategoryRail(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STAGE',
                  style: GoogleFonts.spaceGrotesk(
                    color: BigoColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live now',
                  style: GoogleFonts.spaceGrotesk(
                    color: BigoColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          if (_liveCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 4, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BigoColors.hot.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: BigoColors.hot.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '$_liveCount ON AIR',
                style: GoogleFonts.dmSans(
                  color: BigoColors.hot,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
            icon: const Icon(Icons.search_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRail() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? BigoColors.primary.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: selected
                      ? BigoColors.primary.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                _categories[index],
                style: GoogleFonts.dmSans(
                  color: selected ? BigoColors.primary : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
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
                const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Could not load rooms.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white70),
                ),
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
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BigoColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: BigoColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.sensors,
                      size: 32,
                      color: BigoColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'The stage is empty',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go live and own the first seat of the night.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _openCreateRoom,
                    icon: const Icon(Icons.sensors),
                    label: const Text('Go Live'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: BigoColors.primary,
          backgroundColor: BigoColors.bgElevated,
          onRefresh: _loadRooms,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 108),
            itemCount: _rooms.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, index) {
              final room = _rooms[index];
              return _NeonLiveTile(
                room: room,
                onTap: () => _openRoom(room),
              );
            },
          ),
        );
    }
  }
}

class _AtmosphereBackdrop extends StatelessWidget {
  const _AtmosphereBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: BigoColors.bg),
        // Soft cyan wash top-left.
        Positioned(
          top: -80,
          left: -60,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BigoColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Soft coral wash top-right.
        Positioned(
          top: 40,
          right: -70,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BigoColors.hot.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Subtle noise-like vertical fade.
        const DecoratedBox(
          decoration: BoxDecoration(gradient: BigoColors.appGradient),
        ),
      ],
    );
  }
}

class _NeonLiveTile extends StatelessWidget {
  final LiveRoomModel room;
  final VoidCallback onTap;

  const _NeonLiveTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: room.isLive
                  ? BigoColors.primary.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: room.roomImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: BigoColors.surface,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: BigoColors.surface,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
                if (!room.isLive)
                  Container(color: Colors.black.withValues(alpha: 0.45)),
                // Bottom readable grade — no floating badge clutter on the media.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 110,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                if (room.isLive)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: _LiveBadge(),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              room.formattedViewerCount,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.roomName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: BigoColors.surface,
                            backgroundImage:
                                (room.hostPhoto != null &&
                                    room.hostPhoto!.isNotEmpty)
                                ? CachedNetworkImageProvider(room.hostPhoto!)
                                : null,
                            child:
                                (room.hostPhoto == null ||
                                    room.hostPhoto!.isEmpty)
                                ? Text(
                                    room.hostName.isNotEmpty
                                        ? room.hostName[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              room.hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (room.slotCount > 0)
                            Text(
                              '${room.slotCount}s',
                              style: GoogleFonts.dmSans(
                                color: BigoColors.primary.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
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
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final glow = 0.25 + (t * 0.55);
        final scale = 1.0 + (t * 0.06);
        final textOpacity = 0.55 + (t * 0.45);
        final dotScale = 0.75 + (t * 0.55);

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: BigoColors.liveGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: BigoColors.hot.withValues(alpha: glow),
                  blurRadius: 12 + (t * 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: dotScale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Opacity(
                  opacity: textOpacity,
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
