import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/guest_request_model.dart';
import '../models/viewer_model.dart';
import '../utils/secure_storage_helper.dart';

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

  // Separate, lightweight connection used only by LiveRoomListScreen to
  // hear global `room:statusUpdated` broadcasts - it isn't joined to any
  // particular room, so it's kept independent of the room socket above.
  io.Socket? _lobbySocket;

  bool get isConnected => _socket?.connected ?? false;

  final _joinRejected = StreamController<String>.broadcast();
  final _viewerList = StreamController<List<ViewerModel>>.broadcast();
  final _guestRequests = StreamController<List<GuestRequestModel>>.broadcast();
  final _chatMessage =
      StreamController<({String username, String message})>.broadcast();
  final _chatRejected = StreamController<String>.broadcast();
  final _chatMuteState = StreamController<bool>.broadcast();
  final _warning = StreamController<String>.broadcast();
  final _banned = StreamController<String>.broadcast();
  final _guestInvited = StreamController<String>.broadcast(); // hostName
  final _guestInviteAccepted = StreamController<void>.broadcast();
  final _guestInviteDeclined =
      StreamController<String>.broadcast(); // declining viewer's name
  final _guestRequestRejected = StreamController<void>.broadcast();
  final _roomStatusUpdates =
      StreamController<({String roomId, bool isLive})>.broadcast();

  List<ViewerModel> _currentViewers = [];
  List<ViewerModel> get currentViewers => _currentViewers;

  List<GuestRequestModel> _currentGuestRequests = [];
  List<GuestRequestModel> get currentGuestRequests => _currentGuestRequests;

  /// Emitted with a reason when the server refuses `room:join` (banned).
  Stream<String> get joinRejected => _joinRejected.stream;

  /// Host-only: the current viewer list for the moderation panel.
  Stream<List<ViewerModel>> get viewerList => _viewerList.stream;

  /// Host-only: pending "request to be guest" list.
  Stream<List<GuestRequestModel>> get guestRequests => _guestRequests.stream;

  Stream<({String username, String message})> get chatMessage =>
      _chatMessage.stream;

  /// Fired at the sender only when their own message was rejected (muted).
  Stream<String> get chatRejected => _chatRejected.stream;

  /// `true` when muted, `false` when unmuted - for the current user only.
  Stream<bool> get chatMuteState => _chatMuteState.stream;

  Stream<String> get warning => _warning.stream;

  /// Fired only on the banned user's own socket, with the ban reason.
  Stream<String> get banned => _banned.stream;

  Stream<String> get guestInvited => _guestInvited.stream;
  Stream<void> get guestInviteAccepted => _guestInviteAccepted.stream;
  Stream<String> get guestInviteDeclined => _guestInviteDeclined.stream;
  Stream<void> get guestRequestRejected => _guestRequestRejected.stream;

  /// Global (not room-scoped): fired whenever any room's live status
  /// changes, for [connectLobby] listeners like LiveRoomListScreen.
  Stream<({String roomId, bool isLive})> get roomStatusUpdates =>
      _roomStatusUpdates.stream;

  /// Connects the socket (authenticated with the stored access token) and
  /// joins [roomName] as [role] ("host" or "viewer").
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

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    _registerListeners(socket);

    socket.onConnect((_) {
      socket.emit('room:join', {'roomName': roomName, 'role': role});
    });
    socket.connect();
  }

  void _registerListeners(io.Socket socket) {
    Map<String, dynamic> asMap(dynamic data) =>
        Map<String, dynamic>.from(data as Map);

    // The one-time snapshot sent right after a successful join. This was
    // previously never listened for, which meant a host who joined AFTER
    // viewers were already in the room (or reconnected mid-stream) saw an
    // empty viewer list / guest-request list until the next unrelated
    // broadcast happened to fire.
    socket.on('room:joined', (data) {
      final map = asMap(data);

      if (map['isHost'] == true) {
        final viewersRaw = map['viewers'] as List?;
        if (viewersRaw != null) {
          _currentViewers = viewersRaw
              .map(
                (e) =>
                    ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
          _viewerList.add(_currentViewers);
        }
        final requestsRaw = map['guestRequests'] as List?;
        if (requestsRaw != null) {
          _currentGuestRequests = requestsRaw
              .map(
                (e) => GuestRequestModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          _guestRequests.add(_currentGuestRequests);
        }
      }

      if (map['isMuted'] == true) _chatMuteState.add(true);
    });

    socket.on('room:joinRejected', (data) {
      _joinRejected.add(asMap(data)['reason'] as String? ?? 'Join rejected.');
    });

    socket.on('room:viewerListUpdated', (data) {
      _currentViewers = (asMap(data)['viewers'] as List)
          .map((e) => ViewerModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _viewerList.add(_currentViewers);
    });

    socket.on('guest:requestListUpdated', (data) {
      _currentGuestRequests = (asMap(data)['requests'] as List)
          .map(
            (e) =>
                GuestRequestModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      _guestRequests.add(_currentGuestRequests);
    });

    socket.on('chat:message', (data) {
      final map = asMap(data);
      _chatMessage.add((
        username: map['name'] as String? ?? 'Unknown',
        message: map['message'] as String? ?? '',
      ));
    });

    socket.on('chat:rejected', (data) {
      _chatRejected.add(
        asMap(data)['reason'] as String? ?? 'Message rejected.',
      );
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

    socket.on('guest:inviteAccepted', (_) => _guestInviteAccepted.add(null));

    socket.on('guest:inviteDeclined', (data) {
      _guestInviteDeclined.add(asMap(data)['name'] as String? ?? 'A viewer');
    });

    socket.on('guest:requestRejected', (_) => _guestRequestRejected.add(null));
  }

  void _emit(String event, [Map<String, dynamic> data = const {}]) {
    final socket = _socket;
    final roomName = _roomName;
    if (socket == null || roomName == null) return;
    socket.emit(event, {'roomName': roomName, ...data});
  }

  // ---- Chat ----

  void sendChatMessage(String message) =>
      _emit('chat:send', {'message': message});

  // ---- Host moderation actions ----

  void banUser(String targetUserId, {String? reason}) =>
      _emit('host:ban', {'targetUserId': targetUserId, 'reason': ?reason});

  void unbanUser(String targetUserId) =>
      _emit('host:unban', {'targetUserId': targetUserId});

  void chatMuteUser(String targetUserId) =>
      _emit('host:chatMute', {'targetUserId': targetUserId});

  void chatUnmuteUser(String targetUserId) =>
      _emit('host:chatUnmute', {'targetUserId': targetUserId});

  void warnUser(String targetUserId, String reason) =>
      _emit('host:warn', {'targetUserId': targetUserId, 'reason': reason});

  void inviteGuest(String targetUserId) =>
      _emit('host:inviteGuest', {'targetUserId': targetUserId});

  void acceptGuestRequest(String targetUserId) =>
      _emit('host:acceptGuestRequest', {'targetUserId': targetUserId});

  void rejectGuestRequest(String targetUserId) =>
      _emit('host:rejectGuestRequest', {'targetUserId': targetUserId});

  // ---- Viewer-initiated guest flows ----

  void requestToBeGuest() => _emit('viewer:requestGuest');

  void acceptGuestInvite() => _emit('guest:acceptInvite');

  void declineGuestInvite() => _emit('guest:declineInvite');

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
          .build(),
    );
    _lobbySocket = socket;

    socket.on('room:statusUpdated', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _roomStatusUpdates.add((
        roomId: map['roomId'] as String,
        isLive: map['isLive'] as bool,
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
  }

  void dispose() {
    unawaited(disconnect());
    disconnectLobby();
    _joinRejected.close();
    _viewerList.close();
    _guestRequests.close();
    _chatMessage.close();
    _chatRejected.close();
    _chatMuteState.close();
    _warning.close();
    _banned.close();
    _guestInvited.close();
    _guestInviteAccepted.close();
    _guestInviteDeclined.close();
    _guestRequestRejected.close();
    _roomStatusUpdates.close();
  }
}
