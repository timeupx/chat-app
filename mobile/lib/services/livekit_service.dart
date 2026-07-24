import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

import '../utils/secure_storage_helper.dart';

enum LiveKitRole { host, viewer, guest }

/// Thrown for any failure connecting to, or interacting with, a LiveKit room.
class LiveKitServiceException implements Exception {
  final String message;
  LiveKitServiceException(this.message);

  @override
  String toString() => message;
}

/// Wraps the `livekit_client` SDK behind a small, UI-agnostic API.
///
/// Nothing here is aware of "LiveKit Cloud" vs. a self-hosted server - the
/// server URL and credentials come entirely from `.env`
/// (LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET). Pointing this app
/// at a different LiveKit deployment later is a one-line `.env` change, not
/// a code change - `Room.connect` treats a livekit.cloud URL and a
/// self-hosted URL identically.
///
/// Screens never touch the `livekit_client` types directly for connection
/// management - they call [connect], [disconnect], [toggleMicrophone], etc.,
/// and listen to [events] for room/participant updates.
class LiveKitService {
  LiveKitService._internal();
  static final LiveKitService instance = LiveKitService._internal();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final _eventsController = StreamController<RoomEvent>.broadcast();

  /// Every room event (participant joined/left, track subscribed, muted,
  /// disconnected, ...) so screens can react without depending on the
  /// `livekit_client` connection internals.
  Stream<RoomEvent> get events => _eventsController.stream;

  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  LocalParticipant? get localParticipant => _room?.localParticipant;

  /// The local camera preview track, once published (host only).
  LocalVideoTrack? get localVideoTrack {
    final pubs = localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return null;
    return pubs.first.track;
  }

  /// The first remote participant's video track (viewer's view of the host).
  RemoteVideoTrack? get remoteHostVideoTrack {
    final room = _room;
    if (room == null || room.remoteParticipants.isEmpty) return null;
    final host = room.remoteParticipants.values.first;
    if (host.videoTrackPublications.isEmpty) return null;
    return host.videoTrackPublications.first.track;
  }

  /// Connects to [roomName] as either a HOST (publishes camera + mic) or a
  /// VIEWER (subscribe-only, no local tracks are published).
  Future<void> connect({
    required String roomName,
    required String identity,
    required LiveKitRole role,
    String? displayName,
  }) async {
    if (isConnected) {
      await disconnect();
    }

    final url = dotenv.env['LIVEKIT_URL'];
    if (url == null || url.isEmpty) {
      throw LiveKitServiceException('LIVEKIT_URL is not set in .env');
    }

    final token = await _fetchToken(
      roomName: roomName,
      identity: identity,
      role: role,
      displayName: displayName,
    );

    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listener = room.createListener();
    _listener!.listen(_eventsController.add);

    try {
      await room.connect(url, token);
    } catch (e) {
      await _teardownRoom();
      throw LiveKitServiceException('Could not connect to the live room: $e');
    }

    // Guests publish camera/mic just like the host - the only difference is
    // how they got here (invited/promoted vs. starting the stream).
    if (role == LiveKitRole.host || role == LiveKitRole.guest) {
      try {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
      } catch (e) {
        throw LiveKitServiceException(
          'Could not access camera/microphone. Check app permissions: $e',
        );
      }
    }
  }

  /// Flips the local camera between front and back. No-op for viewers or if
  /// the camera isn't published yet.
  Future<void> flipCamera() async {
    final track = localVideoTrack;
    if (track == null) return;

    final current = track.currentOptions;
    final isFront =
        current is CameraCaptureOptions &&
        current.cameraPosition == CameraPosition.front;

    await track.setCameraPosition(
      isFront ? CameraPosition.back : CameraPosition.front,
    );
  }

  /// Enables/disables the local camera. Returns the resulting enabled state.
  Future<bool> toggleCamera() async {
    final participant = localParticipant;
    if (participant == null) return false;

    final newEnabled = !participant.isCameraEnabled();
    await participant.setCameraEnabled(newEnabled);
    return newEnabled;
  }

  /// Mutes/unmutes the local microphone. Returns the resulting enabled state
  /// (`true` = mic on / unmuted).
  Future<bool> toggleMicrophone() async {
    final participant = localParticipant;
    if (participant == null) return false;

    final newEnabled = !participant.isMicrophoneEnabled();
    await participant.setMicrophoneEnabled(newEnabled);
    return newEnabled;
  }

  /// Leaves the room and releases camera/mic/network resources. Safe to
  /// call even if not currently connected.
  Future<void> disconnect() async {
    await _teardownRoom();
  }

  Future<void> _teardownRoom() async {
    await _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }

  /// Call once when the app shuts down / the service is no longer needed.
  void dispose() {
    unawaited(_teardownRoom());
    _eventsController.close();
  }

  // ---------------------------------------------------------------------
  // Token acquisition
  // ---------------------------------------------------------------------

  Future<String> _fetchToken({
    required String roomName,
    required String identity,
    required LiveKitRole role,
    String? displayName,
  }) async {
    // PRODUCTION PATH: the Express.js backend holds the LiveKit API secret
    // and mints a signed token per-request (see
    // backend/src/modules/livekit for the corresponding route). This is the
    // only path that should exist in a shipped app.
    try {
      return await _fetchTokenFromBackend(
        roomName: roomName,
        identity: identity,
        role: role,
        displayName: displayName,
      );
    } catch (backendError) {
      // ---------------------------------------------------------------
      // DEV-ONLY FALLBACK - remove before shipping.
      //
      // Signs a LiveKit access token locally using LIVEKIT_API_KEY /
      // LIVEKIT_API_SECRET from .env. This embeds your API secret in the
      // client bundle, which is fine for local testing but NEVER safe for
      // production (anyone could extract the secret and mint their own
      // tokens). It only exists so host/viewer flows can be tested before
      // the backend /api/livekit/token route is wired up.
      // ---------------------------------------------------------------
      final apiKey = dotenv.env['LIVEKIT_API_KEY'];
      final apiSecret = dotenv.env['LIVEKIT_API_SECRET'];
      if (apiKey == null || apiKey.isEmpty || apiSecret == null || apiSecret.isEmpty) {
        throw LiveKitServiceException(
          'Could not reach the token backend ($backendError), and no local '
          'LIVEKIT_API_KEY/LIVEKIT_API_SECRET is set in .env for the dev '
          'fallback.',
        );
      }
      return _generateLocalDevToken(
        apiKey: apiKey,
        apiSecret: apiSecret,
        roomName: roomName,
        identity: identity,
        role: role,
        displayName: displayName,
      );
    }
  }

  Future<String> _fetchTokenFromBackend({
    required String roomName,
    required String identity,
    required LiveKitRole role,
    String? displayName,
  }) async {
    final baseUrl = kIsWeb
        ? (dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000')
        : (dotenv.env['BASE_URL'] ?? '');

    final uri = Uri.parse('$baseUrl/api/livekit/token');
    final accessToken = await SecureStorageHelper.getToken();

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            // Note: this backend's `auth` middleware reads the raw JWT
            // straight off the Authorization header (no "Bearer " prefix).
            'Authorization': ?accessToken,
          },
          body: jsonEncode({
            'roomName': roomName,
            'identity': identity,
            'role': role.name,
            'displayName': ?displayName,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final token = (body['data'] as Map<String, dynamic>?)?['token'] as String?;
      if (token != null) return token;
    }

    throw LiveKitServiceException(
      body['message'] as String? ?? 'Token endpoint returned ${response.statusCode}',
    );
  }

  /// Builds a LiveKit access token (JWT) by hand: base64url(header).base64url
  /// (payload).base64url(HMAC-SHA256 signature). Matches the token format
  /// LiveKit's server SDKs generate - see
  /// https://docs.livekit.io/home/get-started/authentication/.
  String _generateLocalDevToken({
    required String apiKey,
    required String apiSecret,
    required String roomName,
    required String identity,
    required LiveKitRole role,
    String? displayName,
  }) {
    String encodeSegment(Object segment) {
      final jsonBytes = utf8.encode(jsonEncode(segment));
      return base64Url.encode(jsonBytes).replaceAll('=', '');
    }

    final now = DateTime.now().toUtc();
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'iss': apiKey,
      'sub': identity,
      'name': displayName ?? identity,
      'nbf': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': role == LiveKitRole.host || role == LiveKitRole.guest,
        'canSubscribe': true,
        'canPublishData': true,
      },
    };

    final signingInput = '${encodeSegment(header)}.${encodeSegment(payload)}';
    final signature = Hmac(
      sha256,
      utf8.encode(apiSecret),
    ).convert(utf8.encode(signingInput));
    final encodedSignature = base64Url.encode(signature.bytes).replaceAll('=', '');

    return '$signingInput.$encodedSignature';
  }
}
