import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/banned_user_model.dart';
import '../models/gift_model.dart';
import '../models/guest_request_model.dart';
import '../models/video_filter_settings.dart';
import '../models/viewer_model.dart';
import '../utils/secure_storage_helper.dart';
import 'livekit_service.dart';

/// Thrown when the room socket can't be set up at all (e.g. not logged in).
class RoomSocketException implements Exception {
  final String message;
  RoomSocketException(this.message);

  @override
  String toString() => message;
}

/// Wraps `socket_io_client` for all real-time room-moderation events: ban,
/// chat-mute, warnings, guest invites/requests, and live chat itself.
///
/// This is the ONLY place in the app that talks to Socket.io directly -
/// screens only call its methods and listen to its streams, exactly like
/// [LiveKitService] for video. Every server event maps 1:1 to a broadcast
/// stream here.
class RoomSocketService {
  RoomSocketService._internal();
  static final RoomSocketService instance = RoomSocketService._internal();

  io.Socket? _socket;
  String? _roomName;

  // Broadcast StreamControllers never replay their last value to a new
  // listener - only events emitted *after* `.listen()` is called reach it.
  // The host's viewer-list/guest-request badges subscribe immediately on
  // connect (so they get the first snapshot fine), but ViewerListSheet /
  // GuestRequestsSheet are only opened later via a button tap - by then the
  // snapshot has already been missed and the sheet shows empty until the
  // next unrelated join/leave happens to re-broadcast it. Caching the last
  // value here lets those sheets seed themselves synchronously instead of
  // waiting on the stream.
  List<ViewerModel> _lastViewerList = [];
  List<ViewerModel> _lastOccupiedSlots = [];
  List<GuestRequestModel> _lastGuestRequests = [];
  List<BannedUserModel> _lastBannedUsers = [];
  int _lastSlotCount = 6;

  List<ViewerModel> get currentViewers => _lastViewerList;
  /// Host + guests currently assigned to stage seats (ordered by slot).
  List<ViewerModel> get currentOccupiedSlots => _lastOccupiedSlots;
  int get currentSlotCount => _lastSlotCount;
  List<GuestRequestModel> get currentGuestRequests => _lastGuestRequests;
  List<BannedUserModel> get currentBannedUsers => _lastBannedUsers;

  // Separate, lightweight connection used only by LiveRoomListScreen to
  // hear global `room:statusUpdated` broadcasts - it isn't joined to any
  // particular room, so it's kept independent of the room socket above.
  io.Socket? _lobbySocket;

  bool get isConnected => _socket?.connected ?? false;

  final _joinRejected = StreamController<String>.broadcast();
  final _viewerList = StreamController<List<ViewerModel>>.broadcast();
  final _occupiedSlots = StreamController<List<ViewerModel>>.broadcast();
  final _guestRequests = StreamController<List<GuestRequestModel>>.broadcast();
  final _bannedUsers = StreamController<List<BannedUserModel>>.broadcast();
  final _chatMessage = StreamController<
      ({String userId, String username, String message, bool isSystem})>.broadcast();
  final _chatRejected = StreamController<String>.broadcast();
  final _chatMuteState = StreamController<bool>.broadcast();
  final _warning = StreamController<String>.broadcast();
  final _banned = StreamController<String>.broadcast();
  final _guestInvited = StreamController<String>.broadcast(); // hostName
  final _guestInviteAccepted = StreamController<int?>.broadcast();
  final _guestInviteDeclined = StreamController<String>.broadcast(); // declining viewer's name
  final _guestRequestRejected = StreamController<String>.broadcast();
  final _guestRemovedFromStage = StreamController<String>.broadcast();
  final _videoFilter = StreamController<VideoFilterSettings>.broadcast();
  final _participantFilters =
      StreamController<Map<String, VideoFilterSettings>>.broadcast();
  final _roomStatusUpdates =
      StreamController<({String roomId, bool isLive, bool deleted})>.broadcast();
  final _roomEnded = StreamController<String>.broadcast();
  final _userEntered = StreamController<({String userId, String username})>.broadcast();
  final _giftReceived = StreamController<
      ({String userId, String username, GiftModel gift})>.broadcast();

  VideoFilterSettings? _lastVideoFilter;
  VideoFilterSettings? get currentVideoFilter => _lastVideoFilter;

  Map<String, VideoFilterSettings> _lastParticipantFilters = {};
  Map<String, VideoFilterSettings> get currentParticipantFilters =>
      Map.unmodifiable(_lastParticipantFilters);

  /// Emitted with a reason when the server refuses `room:join` (banned).
  Stream<String> get joinRejected => _joinRejected.stream;

  /// Fired for everyone in the room when a viewer fully enters
  /// (after tap-to-enter / socket `room:join` as viewer).
  Stream<({String userId, String username})> get userEntered => _userEntered.stream;

  /// Viewer list + stage occupancy for everyone in the room.
  Stream<List<ViewerModel>> get viewerList => _viewerList.stream;

  /// Occupied stage seats (host + guests), for the multi-slot grid.
  Stream<List<ViewerModel>> get occupiedSlots => _occupiedSlots.stream;

  /// Host-only: pending "request to be guest" list.
  Stream<List<GuestRequestModel>> get guestRequests => _guestRequests.stream;

  /// Host-only: currently banned users, for the Banned Users panel.
  Stream<List<BannedUserModel>> get bannedUsers => _bannedUsers.stream;

  Stream<({String userId, String username, String message, bool isSystem})> get chatMessage =>
      _chatMessage.stream;

  /// Fired at the sender only when their own message was rejected (muted).
  Stream<String> get chatRejected => _chatRejected.stream;

  /// `true` when muted, `false` when unmuted - for the current user only.
  Stream<bool> get chatMuteState => _chatMuteState.stream;

  Stream<String> get warning => _warning.stream;

  /// Fired only on the banned user's own socket, with the ban reason.
  Stream<String> get banned => _banned.stream;

  Stream<String> get guestInvited => _guestInvited.stream;

  /// Fired when this user becomes a guest. Payload is the assigned seat
  /// number when the server sends one, otherwise null.
  Stream<int?> get guestInviteAccepted => _guestInviteAccepted.stream;
  Stream<String> get guestInviteDeclined => _guestInviteDeclined.stream;

  /// Fired when the host declines this viewer's "request to be guest", or
  /// when the guest cap is full - carries a human-readable reason.
  Stream<String> get guestRequestRejected => _guestRequestRejected.stream;

  /// Host kicked this user off the co-host stage (stay in room as viewer).
  Stream<String> get guestRemovedFromStage => _guestRemovedFromStage.stream;

  /// Host beauty filter mirrored to every client for the host video tile.
  Stream<VideoFilterSettings> get videoFilter => _videoFilter.stream;

  /// Per-user beauty filters (host + co-host guests), keyed by userId.
  Stream<Map<String, VideoFilterSettings>> get participantFilters =>
      _participantFilters.stream;

  /// Global (not room-scoped): fired whenever any room's live status
  /// changes, for [connectLobby] listeners like LiveRoomListScreen.
  Stream<({String roomId, bool isLive, bool deleted})> get roomStatusUpdates =>
      _roomStatusUpdates.stream;

  /// Fired when the host intentionally ends/deletes the live room.
  Stream<String> get roomEnded => _roomEnded.stream;

  /// Gift sent by anyone in the room — show the big overlay for everyone.
  Stream<({String userId, String username, GiftModel gift})> get giftReceived =>
      _giftReceived.stream;

  /// Connects the socket (authenticated with the stored access token) and
  /// joins [roomName] as [role] ("host" or "viewer").
  ///
  /// Waits until the server acknowledges `room:joined` so callers (especially
  /// [HostScreen]) don't go "live" with an empty chat because join never ran.
  Future<void> connectAndJoin({
    required String roomName,
    required String role,
  }) async {
    if (_socket != null) await disconnect();

    final token = await SecureStorageHelper.getToken();
    if (token == null) {
      throw RoomSocketException('You must be logged in to join a live room.');
    }

    final baseUrl = kIsWeb
        ? (dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000')
        : (dotenv.env['BASE_URL'] ?? '');

    _roomName = roomName;

    // forceNew: LiveRoomListScreen keeps a lobby socket on the same host.
    // Without this, socket_io_client can hand back a cached/already-connected
    // manager, `onConnect` never fires again, and `room:join` is skipped —
    // which is exactly how a host ends up unable to see chat messages.
    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket = socket;
    _registerListeners(socket);

    final joined = Completer<void>();

    void fail(String reason) {
      if (!joined.isCompleted) {
        joined.completeError(RoomSocketException(reason));
      }
    }

    void succeed() {
      if (!joined.isCompleted) joined.complete();
    }

    socket.once('room:joined', (_) => succeed());
    socket.once('room:joinRejected', (data) {
      final reason = data is Map
          ? (data['reason'] as String? ?? 'Join rejected.')
          : 'Join rejected.';
      fail(reason);
    });
    socket.once('connect_error', (err) {
      fail(err?.toString() ?? 'Failed to connect to room chat.');
    });

    void emitJoin() {
      socket.emit('room:join', {'roomName': roomName, 'role': role});
    }

    // If we somehow got an already-open socket, join immediately — don't
    // wait for a connect event that will never come.
    if (socket.connected) {
      emitJoin();
    } else {
      socket.once('connect', (_) => emitJoin());
      socket.connect();
    }

    try {
      await joined.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw RoomSocketException(
          'Timed out joining the room chat. Please try again.',
        ),
      );
    } catch (e) {
      await disconnect();
      if (e is RoomSocketException) rethrow;
      throw RoomSocketException(e.toString());
    }
  }

  void _registerListeners(io.Socket socket) {
    /// Normalizes socket.io payloads across mobile + Flutter web (JS objects
    /// often fail a plain `is Map` check until JSON-round-tripped).
    Map<String, dynamic> asMap(dynamic data) {
      dynamic raw = data;
      if (raw is List && raw.isNotEmpty) raw = raw.first;
      if (raw == null) return <String, dynamic>{};
      if (raw is Map) {
        try {
          return Map<String, dynamic>.from(raw);
        } catch (_) {/* fall through */}
      }
      try {
        final decoded = jsonDecode(jsonEncode(raw));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
      return <String, dynamic>{};
    }

    GiftModel? parseGift(Map<String, dynamic> map) {
      Map<String, dynamic>? giftMap;
      final giftRaw = map['gift'];
      if (giftRaw != null) {
        final coerced = asMap(giftRaw);
        if (coerced.isNotEmpty) giftMap = coerced;
      }
      final id = (giftMap?['id'] ?? map['giftId'] ?? map['id'])?.toString() ?? '';
      final name =
          (giftMap?['name'] ?? map['giftName'] ?? 'Gift')?.toString() ?? 'Gift';
      final emoji =
          (giftMap?['emoji'] ?? map['giftEmoji'] ?? '🎁')?.toString() ?? '🎁';
      final coinRaw = giftMap?['coinCost'] ?? map['coinCost'];
      final coinCost = coinRaw is num
          ? coinRaw.toInt()
          : int.tryParse('$coinRaw') ?? 0;
      if (id.isEmpty && emoji.isEmpty) return null;
      return GiftModel(id: id, name: name, emoji: emoji, coinCost: coinCost);
    }

    // The one-time snapshot sent right after a successful join. This was
    // previously never listened for, which meant a host who joined AFTER
    // viewers were already in the room (or reconnected mid-stream) saw an
    // empty viewer list / guest-request list until the next unrelated
    // broadcast happened to fire.
    socket.on('room:joined', (data) {
      final map = asMap(data);

      // Backend LiveKit identity == account userId. Stash the host's id so
      // [LiveKitService.remoteHostVideoTrack] can find their publisher
      // among guests (the client-supplied `host_...` identity is ignored
      // by the token endpoint).
      final hostUserId = map['hostUserId'] as String?;
      if (hostUserId != null && hostUserId.isNotEmpty) {
        LiveKitService.instance.knownHostUserId = hostUserId;
      }

      final filterRaw = map['videoFilter'];
      if (filterRaw is Map) {
        _setVideoFilter(
          VideoFilterSettings.fromJson(Map<String, dynamic>.from(filterRaw)),
        );
      }

      final participantFiltersRaw = map['participantFilters'] as List?;
      if (participantFiltersRaw != null) {
        final next = <String, VideoFilterSettings>{};
        for (final entry in participantFiltersRaw) {
          if (entry is! Map) continue;
          final entryMap = Map<String, dynamic>.from(entry);
          final userId = entryMap['userId'] as String?;
          final filterMap = entryMap['filter'];
          if (userId == null || userId.isEmpty || filterMap is! Map) continue;
          next[userId] = VideoFilterSettings.fromJson(
            Map<String, dynamic>.from(filterMap),
          );
        }
        _setParticipantFilters(next);
      }

      final joinedSlotCount = map['slotCount'];
      if (joinedSlotCount is int) {
        _lastSlotCount = joinedSlotCount;
      }

      final slotsRaw = map['slots'] as List?;
      if (slotsRaw != null) {
        _setOccupiedSlots(
          slotsRaw
              .map((e) => ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      }

      final viewersRaw = map['viewers'] as List?;
      if (viewersRaw != null) {
        _setViewerList(
          viewersRaw
              .map((e) => ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      }

      if (map['isHost'] == true) {
        final requestsRaw = map['guestRequests'] as List?;
        if (requestsRaw != null) {
          _setGuestRequests(
            requestsRaw
                .map((e) => GuestRequestModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
        }
        final bannedRaw = map['bannedUsers'] as List?;
        if (bannedRaw != null) {
          _setBannedUsers(
            bannedRaw
                .map((e) => BannedUserModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
        }
      }

      if (map['isMuted'] == true) _chatMuteState.add(true);
    });

    socket.on('room:joinRejected', (data) {
      _joinRejected.add(asMap(data)['reason'] as String? ?? 'Join rejected.');
    });

    socket.on('room:ended', (data) {
      final reason = asMap(data)['reason'] as String? ?? 'Host ended the live.';
      _roomEnded.add(reason);
    });

    socket.on('room:userEntered', (data) {
      final map = asMap(data);
      _userEntered.add((
        userId: map['userId'] as String? ?? '',
        username: map['username'] as String? ?? 'Someone',
      ));
    });

    socket.on('room:viewerListUpdated', (data) {
      final map = asMap(data);
      final viewersRaw = map['viewers'] as List? ?? const [];
      final viewers = viewersRaw
          .map((e) => ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _setViewerList(viewers);

      final slotsRaw = map['slots'] as List?;
      if (slotsRaw != null) {
        _setOccupiedSlots(
          slotsRaw
              .map((e) => ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      }

      final slotCount = map['slotCount'];
      if (slotCount is int) {
        _lastSlotCount = slotCount;
      }
    });

    socket.on('guest:requestListUpdated', (data) {
      final requests = (asMap(data)['requests'] as List)
          .map((e) => GuestRequestModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _setGuestRequests(requests);
    });

    socket.on('room:bannedListUpdated', (data) {
      final banned = (asMap(data)['banned'] as List)
          .map((e) => BannedUserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _setBannedUsers(banned);
    });

    socket.on('chat:message', (data) {
      final map = asMap(data);
      final message = map['message'] as String? ?? '';
      _chatMessage.add((
        userId: map['userId'] as String? ?? '',
        username: map['name'] as String? ?? 'Unknown',
        message: message,
        isSystem: map['isSystem'] == true ||
            message == 'joined' ||
            message == 'entered the room',
      ));
    });

    socket.on('gift:received', (data) {
      final map = asMap(data);
      if (map.isEmpty) return;
      final gift = parseGift(map);
      if (gift == null) return;
      final username = map['username'] as String? ??
          map['name'] as String? ??
          'Someone';
      _giftReceived.add((
        userId: map['userId'] as String? ?? '',
        username: username,
        gift: gift,
      ));
    });

    socket.on('chat:rejected', (data) {
      _chatRejected.add(asMap(data)['reason'] as String? ?? 'Message rejected.');
    });

    socket.on('chat:muted', (_) => _chatMuteState.add(true));
    socket.on('chat:unmuted', (_) => _chatMuteState.add(false));

    socket.on('warning:received', (data) {
      _warning.add(asMap(data)['reason'] as String? ?? 'No reason given.');
    });

    socket.on('room:banned', (data) {
      _banned.add(asMap(data)['reason'] as String? ?? 'You have been banned.');
    });

    socket.on('guest:invited', (data) {
      _guestInvited.add(asMap(data)['hostName'] as String? ?? 'The host');
    });

    socket.on('guest:inviteAccepted', (data) {
      int? slotNumber;
      if (data is Map) {
        final raw = Map<String, dynamic>.from(data)['slotNumber'];
        if (raw is int) {
          slotNumber = raw;
        } else {
          slotNumber = int.tryParse('$raw');
        }
      }
      _guestInviteAccepted.add(slotNumber);
    });

    socket.on('guest:inviteDeclined', (data) {
      _guestInviteDeclined.add(asMap(data)['name'] as String? ?? 'A viewer');
    });

    socket.on('guest:requestRejected', (data) {
      final reason = data is Map
          ? (Map<String, dynamic>.from(data)['reason'] as String? ?? 'Your request was declined.')
          : 'Your request was declined.';
      _guestRequestRejected.add(reason);
    });

    socket.on('guest:removedFromStage', (data) {
      final reason = data is Map
          ? (Map<String, dynamic>.from(data)['reason'] as String? ??
              'Removed from the live stage.')
          : 'Removed from the live stage.';
      _guestRemovedFromStage.add(reason);
    });

    socket.on('room:filterUpdated', (data) {
      final filterRaw = asMap(data)['filter'];
      if (filterRaw is Map) {
        _setVideoFilter(
          VideoFilterSettings.fromJson(Map<String, dynamic>.from(filterRaw)),
        );
      }
    });

    socket.on('room:participantFilterUpdated', (data) {
      final map = asMap(data);
      final userId = map['userId'] as String?;
      if (userId == null || userId.isEmpty) return;
      final filterRaw = map['filter'];
      final next = Map<String, VideoFilterSettings>.from(_lastParticipantFilters);
      if (filterRaw is Map) {
        next[userId] = VideoFilterSettings.fromJson(
          Map<String, dynamic>.from(filterRaw),
        );
      } else {
        next.remove(userId);
      }
      _setParticipantFilters(next);
    });
  }

  void _setViewerList(List<ViewerModel> viewers) {
    _lastViewerList = viewers;
    _viewerList.add(viewers);
  }

  void _setOccupiedSlots(List<ViewerModel> slots) {
    _lastOccupiedSlots = slots;
    _occupiedSlots.add(slots);
  }

  void _setVideoFilter(VideoFilterSettings filter) {
    _lastVideoFilter = filter;
    _videoFilter.add(filter);
  }

  void _setParticipantFilters(Map<String, VideoFilterSettings> filters) {
    _lastParticipantFilters = filters;
    _participantFilters.add(Map.unmodifiable(filters));
  }

  void _setGuestRequests(List<GuestRequestModel> requests) {
    _lastGuestRequests = requests;
    _guestRequests.add(requests);
  }

  void _setBannedUsers(List<BannedUserModel> banned) {
    _lastBannedUsers = banned;
    _bannedUsers.add(banned);
  }

  void _emit(String event, [Map<String, dynamic> data = const {}]) {
    final socket = _socket;
    final roomName = _roomName;
    if (socket == null || roomName == null) return;
    socket.emit(event, {'roomName': roomName, ...data});
  }

  // ---- Chat ----

  void sendChatMessage(String message) => _emit('chat:send', {'message': message});

  /// Broadcast a gift overlay to everyone currently in the room.
  void sendGift(GiftModel gift) {
    final socket = _socket;
    final roomName = _roomName;
    if (socket == null || roomName == null) return;
    // Emit a plain map (not a nested custom object) so every socket.io
    // transport serializes gift fields reliably for other clients.
    socket.emit('gift:send', {
      'roomName': roomName,
      'gift': {
        'id': gift.id,
        'name': gift.name,
        'emoji': gift.emoji,
        'coinCost': gift.coinCost,
      },
    });
  }

  // ---- Host moderation actions ----

  void banUser(String targetUserId, {String? reason}) =>
      _emit('host:ban', {'targetUserId': targetUserId, 'reason': ?reason});

  void unbanUser(String targetUserId) => _emit('host:unban', {'targetUserId': targetUserId});

  /// Asks the server for a fresh banned-users snapshot - used as a
  /// belt-and-suspenders refresh whenever the Banned Users sheet opens, on
  /// top of the cache seeded from [currentBannedUsers].
  void refreshBannedUsers() => _emit('host:listBans');

  void chatMuteUser(String targetUserId) => _emit('host:chatMute', {'targetUserId': targetUserId});

  void chatUnmuteUser(String targetUserId) => _emit('host:chatUnmute', {'targetUserId': targetUserId});

  void warnUser(String targetUserId, String reason) =>
      _emit('host:warn', {'targetUserId': targetUserId, 'reason': reason});

  void inviteGuest(String targetUserId) => _emit('host:inviteGuest', {'targetUserId': targetUserId});

  void acceptGuestRequest(String targetUserId) =>
      _emit('host:acceptGuestRequest', {'targetUserId': targetUserId});

  void rejectGuestRequest(String targetUserId) =>
      _emit('host:rejectGuestRequest', {'targetUserId': targetUserId});

  // ---- Viewer-initiated guest flows ----

  void requestToBeGuest() => _emit('viewer:requestGuest');

  /// Join co-host stage immediately (no host approval). Optional seat preference.
  void joinGuestStage({int? slotNumber}) => _emit(
        'viewer:joinGuest',
        {if (slotNumber != null) 'slotNumber': slotNumber},
      );

  void acceptGuestInvite() => _emit('guest:acceptInvite');

  /// Host-only: broadcast beauty filter so viewers mirror it on the host tile.
  void setVideoFilter(VideoFilterSettings settings) {
    _setVideoFilter(settings);
    _emit('host:setFilter', {'filter': settings.toJson()});
  }

  /// Host or on-stage guest: broadcast this user's beauty look for their tile.
  void setParticipantFilter(VideoFilterSettings settings) {
    _emit('participant:setFilter', {'filter': settings.toJson()});
  }

  void declineGuestInvite() => _emit('guest:declineInvite');

  /// Leave the co-host seat but stay in the room as a viewer.
  void leaveGuestStage() => _emit('guest:leaveStage');

  /// Host-only: kick a co-host off stage (they remain a viewer).
  void removeGuest(String targetUserId) =>
      _emit('host:removeGuest', {'targetUserId': targetUserId});

  // ---- Lobby (LiveRoomListScreen + LiveRoomDetailScreen) ----

  // Reference-counted because both LiveRoomListScreen AND
  // LiveRoomDetailScreen use the lobby socket simultaneously (the list
  // screen stays mounted underneath the detail screen in the Navigator
  // stack) - without this, whichever screen's `dispose()` ran first would
  // rip the connection out from under the other one.
  int _lobbyRefCount = 0;

  /// Connects a lightweight second socket, joined to no particular room,
  /// purely to receive global `room:statusUpdated` broadcasts so the room
  /// list (and any open room-detail screen) can react instantly to any
  /// room going live/offline. Safe to call from multiple screens at once -
  /// pair every call with [disconnectLobby].
  Future<void> connectLobby() async {
    _lobbyRefCount++;
    if (_lobbySocket != null) return;

    final token = await SecureStorageHelper.getToken();
    if (token == null) return;

    final baseUrl = kIsWeb
        ? (dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000')
        : (dotenv.env['BASE_URL'] ?? '');

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _lobbySocket = socket;

    socket.on('room:statusUpdated', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _roomStatusUpdates.add((
        roomId: map['roomId'] as String,
        isLive: map['isLive'] as bool? ?? false,
        deleted: map['deleted'] == true,
      ));
    });

    socket.connect();
  }

  /// Must be paired 1:1 with [connectLobby]. Only actually tears down the
  /// connection once every caller has released it.
  void disconnectLobby() {
    if (_lobbyRefCount > 0) _lobbyRefCount--;
    if (_lobbyRefCount > 0) return;

    _lobbySocket?.dispose();
    _lobbySocket = null;
  }

  // ---- Lifecycle ----

  Future<void> disconnect() async {
    if (_roomName != null) _emit('room:leave');
    _socket?.dispose();
    _socket = null;
    _roomName = null;
    // Don't leak this room's moderation snapshot into whatever room is
    // joined next.
    _lastViewerList = [];
    _lastOccupiedSlots = [];
    _lastGuestRequests = [];
    _lastBannedUsers = [];
    _lastSlotCount = 6;
    _lastVideoFilter = null;
    _lastParticipantFilters = {};
  }

  void dispose() {
    unawaited(disconnect());
    disconnectLobby();
    _joinRejected.close();
    _viewerList.close();
    _occupiedSlots.close();
    _guestRequests.close();
    _bannedUsers.close();
    _chatMessage.close();
    _chatRejected.close();
    _chatMuteState.close();
    _warning.close();
    _banned.close();
    _guestInvited.close();
    _guestInviteAccepted.close();
    _guestInviteDeclined.close();
    _guestRequestRejected.close();
    _guestRemovedFromStage.close();
    _videoFilter.close();
    _participantFilters.close();
    _roomStatusUpdates.close();
    _roomEnded.close();
    _userEntered.close();
    _giftReceived.close();
  }
}
