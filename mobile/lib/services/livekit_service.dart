import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

import '../utils/secure_storage_helper.dart';
import '../models/video_filter_settings.dart';

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
  Timer? _speakerWatchdog;

  /// LiveKit participant identity of the room's host (= their account
  /// [userId], because the backend mints tokens with `identity: userId`
  /// and ignores the client-supplied `host_...` string). Set by screens
  /// after they learn the host id from room detail / socket so
  /// [remoteHostVideoTrack] can find the right publisher among guests.
  String? knownHostUserId;

  /// Host-local beauty / color grading. Applied to the local camera
  /// preview via [FilteredVideoPreview]; HD capture still ships to viewers.
  VideoFilterSettings videoFilters = const VideoFilterSettings();

  /// Default live capture — snappy like Bigo (720p @ 30fps).
  static final CameraCaptureOptions _hdCameraOptions = CameraCaptureOptions(
    cameraPosition: CameraPosition.front,
    maxFrameRate: 30,
    params: VideoParametersPresets.h720_169,
  );

  /// While native lipstick/blush runs: still smooth, but lighter so MediaPipe
  /// can lock lips every frame without starving the capturer.
  static final CameraCaptureOptions _makeupCameraOptions = CameraCaptureOptions(
    cameraPosition: CameraPosition.front,
    maxFrameRate: 24,
    params: VideoParametersPresets.h540_169,
  );

  static final VideoPublishOptions _hdPublishOptions = VideoPublishOptions(
    simulcast: true,
    videoEncoding: const VideoEncoding(
      maxBitrate: 1700 * 1000,
      maxFramerate: 30,
    ),
    videoSimulcastLayers: [
      VideoParametersPresets.h360_169,
      VideoParametersPresets.h180_169,
    ],
    degradationPreference: DegradationPreference.balanced,
  );

  bool _makeupCapture = false;

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

  /// The host's video track, as seen by a viewer/guest.
  ///
  /// Resolution order:
  ///  1. [knownHostUserId] (backend tokens use `identity = userId`)
  ///  2. Legacy/dev `host_...` identity prefix (local token fallback)
  ///  3. First remote participant that is actually publishing video
  ///
  /// Previously this only looked for `host_...`, which silently returned
  /// null against the real backend - viewers saw an empty host seat with
  /// no live video.
  RemoteVideoTrack? get remoteHostVideoTrack {
    final host = _findHostParticipant();
    if (host == null) return null;
    return _firstVideoTrack(host);
  }

  /// Whether the host currently has their mic enabled, as seen by a
  /// viewer/guest - real LiveKit publish state (not guessed), for the mic
  /// icon on the host's grid seat. Defaults to "on" if the host hasn't
  /// been seen yet, so the icon doesn't flash muted before they connect.
  bool get remoteHostMicEnabled {
    final host = _findHostParticipant();
    if (host == null) return true;
    return host.isMicrophoneEnabled();
  }

  /// Every co-hosting guest's video track (remote publishers that aren't
  /// the host) - used to build the Bigo-style multi-guest grid.
  List<
    ({String identity, String name, RemoteVideoTrack track, bool micEnabled})
  >
  get remoteGuestVideoTiles {
    final room = _room;
    if (room == null) return [];

    // Prefer the known account id — do NOT call [_findHostParticipant] here.
    // On the host's own screen, the host is the *local* participant, so the
    // old "first remote with video" fallback wrongly treated the first guest
    // as the host and hid their camera from the grid.
    final hostId = knownHostUserId;
    final localId = room.localParticipant?.identity;

    final tiles =
        <
          ({
            String identity,
            String name,
            RemoteVideoTrack track,
            bool micEnabled,
          })
        >[];
    for (final entry in room.remoteParticipants.entries) {
      if (hostId != null &&
          hostId.isNotEmpty &&
          entry.key == hostId) {
        continue;
      }
      if (localId != null && entry.key == localId) continue;
      if (entry.key.startsWith('host_')) continue;
      final track = _firstVideoTrack(entry.value);
      if (track == null) continue;
      tiles.add((
        identity: entry.key,
        name: entry.value.name,
        track: track,
        micEnabled: entry.value.isMicrophoneEnabled(),
      ));
    }
    return tiles;
  }

  RemoteParticipant? _findHostParticipant() {
    final room = _room;
    if (room == null) return null;

    final knownId = knownHostUserId;
    final localId = room.localParticipant?.identity;

    if (knownId != null && knownId.isNotEmpty) {
      final byId = room.remoteParticipants[knownId];
      if (byId != null) return byId;
      // We ourselves are the host — there is no remote host participant.
      if (localId == knownId) return null;
    }

    for (final entry in room.remoteParticipants.entries) {
      if (entry.key.startsWith('host_')) return entry.value;
    }

    // Single-broadcaster fallback ONLY when we don't know who the host is.
    // Otherwise a host watching guests would mis-label the first guest.
    if (knownId == null || knownId.isEmpty) {
      for (final participant in room.remoteParticipants.values) {
        if (_firstVideoTrack(participant) != null) return participant;
      }
    }
    return null;
  }

  RemoteVideoTrack? _firstVideoTrack(RemoteParticipant participant) {
    for (final pub in participant.videoTrackPublications) {
      final track = pub.track;
      if (track != null) return track;
    }
    return null;
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
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: _hdCameraOptions,
        defaultVideoPublishOptions: _hdPublishOptions,
        // Live rooms should play on the loudspeaker, not the earpiece.
        defaultAudioOutputOptions: const AudioOutputOptions(speakerOn: true),
      ),
    );
    _room = room;
    _listener = room.createListener();
    _listener!.listen((event) {
      _eventsController.add(event);
      // Local mic (re)start or a new remote audio track (e.g. host's voice
      // arriving on a guest's phone) can reset Android to the earpiece —
      // the underlying AudioSwitch device manager re-activates and can
      // silently re-pick a different output any time a track is
      // (un)published or a participant (re)connects.
      if (event is LocalTrackPublishedEvent ||
          event is TrackSubscribedEvent ||
          event is TrackPublishedEvent ||
          event is TrackUnsubscribedEvent ||
          event is ParticipantConnectedEvent ||
          event is RoomReconnectedEvent) {
        _kickSpeakerWatchdog(room);
      }
    });

    try {
      await room.connect(url, token);
    } catch (e) {
      await _teardownRoom();
      throw LiveKitServiceException('Could not connect to the live room: $e');
    }

    _kickSpeakerWatchdog(room);

    // Guests publish camera/mic just like the host - the only difference is
    // how they got here (invited/promoted vs. starting the stream).
    if (role == LiveKitRole.host || role == LiveKitRole.guest) {
      await _enableLocalMedia();
      _kickSpeakerWatchdog(room);
    }
  }

  /// (Re)starts a watchdog that keeps forcing loudspeaker output for as
  /// long as this room stays connected.
  ///
  /// On some Android devices (seen on this project's Motorola test phone),
  /// the loudspeaker isn't in `AudioSwitch`'s enumerated device list yet at
  /// the exact moment we call `setSpeakerphoneOn` right after connect/mic
  /// start — so that single call silently no-ops (there's no "speakerphone
  /// device available" event surfaced to Dart to react to). Polling for the
  /// whole call, not just a short burst, guarantees we eventually catch the
  /// moment the device becomes selectable, and re-corrects if anything
  /// (headset plug/unplug, a call interruption, etc.) flips it back later.
  void _kickSpeakerWatchdog(Room room) {
    if (kIsWeb) return;
    _speakerWatchdog?.cancel();
    _speakerWatchdog = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) {
      if (_room != room) {
        timer.cancel();
        return;
      }
      unawaited(_routeAudioToSpeaker(room));
    });
    // Fire immediately too, don't wait for the first tick.
    unawaited(_routeAudioToSpeaker(room));
  }

  /// Force loudspeaker output on phones (not the top earpiece).
  ///
  /// Live rooms are "media playback", Bigo-style: everyone's voice comes out
  /// of the loudspeaker on the media volume slider, never the earpiece.
  ///
  /// Android specifics: we keep media mode (`bypassVoiceProcessing: true` in
  /// main.dart) so the "… is using the bluetooth microphone" banner stays
  /// away — but in media mode the plugin's AudioSwitch manager refuses to do
  /// any routing at all unless `forceHandleAudioRouting` is set, which is
  /// why plain `setSpeakerphoneOn(true)` silently did nothing. Set that flag
  /// first, then pick the speaker.
  Future<void> _routeAudioToSpeaker(Room room) async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await webrtc.Helper.setAndroidAudioConfiguration(
          webrtc.AndroidAudioConfiguration(
            manageAudioFocus: true,
            androidAudioMode: webrtc.AndroidAudioMode.normal,
            androidAudioFocusMode: webrtc.AndroidAudioFocusMode.gain,
            androidAudioStreamType: webrtc.AndroidAudioStreamType.music,
            androidAudioAttributesUsageType:
                webrtc.AndroidAudioAttributesUsageType.media,
            androidAudioAttributesContentType:
                webrtc.AndroidAudioAttributesContentType.speech,
            forceHandleAudioRouting: true,
          ),
        );
        await webrtc.Helper.setSpeakerphoneOn(true);
      }
      await room.setSpeakerOn(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Hardware.instance.setSpeakerphoneOn(
          true,
          forceSpeakerOutput: true,
        );
      }
    } catch (e) {
      debugPrint('setSpeakerOn failed: $e');
    }
  }

  /// Promote an already-connected viewer to guest publisher without leaving
  /// the LiveKit room. Keeps the host remote track subscribed so host video
  /// does not reload. Falls back to a full guest [connect] if publishing
  /// cannot be enabled (e.g. server permission grant missed).
  Future<void> promoteToGuest({
    required String roomName,
    required String identity,
    String? displayName,
  }) async {
    if (isConnected) {
      try {
        await _enableLocalMedia();
        final room = _room;
        if (room != null) _kickSpeakerWatchdog(room);
        return;
      } on LiveKitServiceException {
        // Fall through to reconnect with a guest token.
      }
    }

    await connect(
      roomName: roomName,
      identity: identity,
      role: LiveKitRole.guest,
      displayName: displayName,
    );
  }

  /// Stop publishing local camera/mic while staying in the room as a viewer.
  /// Prefer this over reconnecting so remote host video is not torn down.
  Future<void> demoteToViewer({
    required String roomName,
    required String identity,
    String? displayName,
  }) async {
    if (isConnected) {
      try {
        await _disableLocalMedia();
        return;
      } catch (_) {
        // Fall through to a clean viewer reconnect.
      }
    }

    await connect(
      roomName: roomName,
      identity: identity,
      role: LiveKitRole.viewer,
      displayName: displayName,
    );
  }

  Future<void> _enableLocalMedia() async {
    final participant = localParticipant;
    if (participant == null) {
      throw LiveKitServiceException('Not connected to LiveKit');
    }

    Object? lastError;
    // Server grant may land a beat after guest:inviteAccepted — retry briefly.
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        await participant.setCameraEnabled(
          true,
          cameraCaptureOptions: _hdCameraOptions,
        );
        await participant.setMicrophoneEnabled(true);
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }

    throw LiveKitServiceException(
      'Could not access camera/microphone. Check app permissions: $lastError',
    );
  }

  Future<void> _disableLocalMedia() async {
    final participant = localParticipant;
    if (participant == null) return;

    try {
      await participant.setCameraEnabled(false);
    } catch (_) {}
    try {
      await participant.setMicrophoneEnabled(false);
    } catch (_) {}
  }

  void updateVideoFilters(VideoFilterSettings settings) {
    videoFilters = settings;
  }

  /// Drop to 540p@24 while AR makeup is on (lip lock needs every-frame
  /// MediaPipe); restore 720p@30 when makeup is off.
  Future<void> setMakeupCapture(bool active) async {
    if (_makeupCapture == active) return;
    final track = localVideoTrack;
    if (track == null) {
      _makeupCapture = active;
      return;
    }

    final current = track.currentOptions;
    final facing = current is CameraCaptureOptions
        ? current.cameraPosition
        : CameraPosition.front;
    final base = active ? _makeupCameraOptions : _hdCameraOptions;

    try {
      await track.restartTrack(
        CameraCaptureOptions(
          cameraPosition: facing,
          maxFrameRate: base.maxFrameRate,
          params: base.params,
        ),
      );
      _makeupCapture = active;
    } catch (e) {
      debugPrint('setMakeupCapture($active) failed: $e');
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

  /// Mutes or unmutes all remote audio tracks (viewer preview mode).
  /// Uses [Track.disable]/[Track.enable] so preview stays silent without
  /// leaving the LiveKit room. Does not affect local mic publishing.
  Future<void> setRemoteAudioMuted(bool muted) async {
    final room = _room;
    if (room == null) return;

    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.audioTrackPublications) {
        final track = pub.track;
        if (track == null) continue;
        if (muted) {
          await track.disable();
        } else {
          await track.enable();
        }
      }
    }
  }

  /// Leaves the room and releases camera/mic/network resources. Safe to
  /// call even if not currently connected.
  Future<void> disconnect() async {
    await _teardownRoom();
  }

  Future<void> _teardownRoom() async {
    _speakerWatchdog?.cancel();
    _speakerWatchdog = null;
    await _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _makeupCapture = false;
    // Keep [knownHostUserId] across reconnects (e.g. viewer → guest) so the
    // host track is never mis-classified as a guest tile.
    videoFilters = const VideoFilterSettings();
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
    } on LiveKitServiceException {
      // The backend WAS reached and explicitly refused to mint a token -
      // banned from the room, room full, etc. This is a real moderation
      // decision, not "the backend is unreachable", so it must never fall
      // through to the dev fallback below (which has no ban/capacity check
      // at all and would silently let a banned user preview/join anyway).
      rethrow;
    } catch (backendError) {
      // ---------------------------------------------------------------
      // DEV-ONLY FALLBACK - remove before shipping.
      // Only reached for actual connectivity failures (backend not
      // running, DNS/timeout, etc.) - never for an explicit rejection.
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
      if (apiKey == null ||
          apiKey.isEmpty ||
          apiSecret == null ||
          apiSecret.isEmpty) {
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
      final token =
          (body['data'] as Map<String, dynamic>?)?['token'] as String?;
      if (token != null) return token;
    }

    throw LiveKitServiceException(
      body['message'] as String? ??
          'Token endpoint returned ${response.statusCode}',
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
    final encodedSignature = base64Url
        .encode(signature.bytes)
        .replaceAll('=', '');

    return '$signingInput.$encodedSignature';
  }
}
