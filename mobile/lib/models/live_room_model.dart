/// A persistent live-streaming room/channel, as returned by the backend's
/// `/api/live-rooms` endpoints. Replaces the earlier mock-only model - every
/// field here comes straight from the `LiveRoom` Prisma model.
class LiveRoomModel {
  final String id;

  /// Only present on the list response historically; detail now also
  /// returns it so viewers can resolve the host's LiveKit identity
  /// (`identity == userId`) for the video grid.
  final String? hostId;

  final String roomName;
  final String roomImage;
  final bool is18Plus;
  final bool isLive;
  final String hostName;
  final String? hostPhoto;
  final int viewerCount;

  /// Beauty filter preset chosen at room creation (e.g. Natural, Smooth).
  final String filterName;

  /// Bigo-style seat count: 3, 6, or 9. Host always occupies seat 1.
  final int slotCount;

  /// Only present on the single-room detail response, not the list.
  final String? roomRules;

  /// Server-computed: `true` only for the request-maker if they are this
  /// room's host. This - not a client-side ID comparison - is what decides
  /// whether the "GO LIVE" button renders.
  final bool? isHost;

  const LiveRoomModel({
    required this.id,
    this.hostId,
    required this.roomName,
    required this.roomImage,
    required this.is18Plus,
    required this.isLive,
    required this.hostName,
    this.hostPhoto,
    required this.viewerCount,
    this.filterName = 'Natural',
    this.slotCount = 6,
    this.roomRules,
    this.isHost,
  });

  factory LiveRoomModel.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slotCount'];
    final slotCount = rawSlots is int
        ? rawSlots
        : int.tryParse('$rawSlots') ?? 6;

    return LiveRoomModel(
      id: json['id'] as String,
      hostId: json['hostId'] as String?,
      roomName: json['roomName'] as String,
      roomImage: json['roomImage'] as String,
      is18Plus: json['is18Plus'] as bool? ?? false,
      isLive: json['isLive'] as bool? ?? false,
      hostName: json['hostName'] as String? ?? 'Unknown',
      hostPhoto: json['hostPhoto'] as String?,
      viewerCount: json['viewerCount'] as int? ?? 0,
      filterName: json['filterName'] as String? ?? 'Natural',
      slotCount: [3, 6, 9].contains(slotCount) ? slotCount : 6,
      roomRules: json['roomRules'] as String?,
      isHost: json['isHost'] as bool?,
    );
  }

  /// Used by LiveRoomListScreen to apply a live `room:statusUpdated` event
  /// without refetching the whole list from the backend.
  LiveRoomModel copyWith({bool? isLive}) {
    return LiveRoomModel(
      id: id,
      hostId: hostId,
      roomName: roomName,
      roomImage: roomImage,
      is18Plus: is18Plus,
      isLive: isLive ?? this.isLive,
      hostName: hostName,
      hostPhoto: hostPhoto,
      viewerCount: viewerCount,
      filterName: filterName,
      slotCount: slotCount,
      roomRules: roomRules,
      isHost: isHost,
    );
  }

  /// Compact viewer count, e.g. 1234 -> "1.2K".
  String get formattedViewerCount {
    if (viewerCount >= 1000000) {
      return '${(viewerCount / 1000000).toStringAsFixed(1)}M';
    }
    if (viewerCount >= 1000) {
      return '${(viewerCount / 1000).toStringAsFixed(1)}K';
    }
    return '$viewerCount';
  }
}
