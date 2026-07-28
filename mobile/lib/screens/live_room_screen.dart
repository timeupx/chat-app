import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_message_model.dart';
import '../models/gift_model.dart';
import '../models/guest_request_status.dart';
import '../models/live_room_model.dart';
import '../models/video_filter_settings.dart';
import '../models/viewer_model.dart';
import '../services/gift_sound.dart';
import '../services/live_room_service.dart';
import '../services/livekit_service.dart';
import '../services/makeup_service.dart';
import '../services/room_socket_service.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import '../widgets/banned_users_sheet.dart';
import '../widgets/live_room_chat.dart';
import '../widgets/live_room_grid.dart';
import '../widgets/live_room_side_panel.dart';
import '../widgets/live_room_theme.dart';
import '../widgets/live_room_top_bar.dart';
import '../widgets/gpu_image_filter.dart';
import '../widgets/video_filter_controls.dart';
import '../widgets/viewer_list_sheet.dart';
import '../widgets/viewer_moderation_sheet.dart';

/// Whether this client entered the room as the broadcaster or as an audience
/// member. Guests are still [LiveRoomRole.viewer] at entry — they promote via
/// invite/request after joining.
enum LiveRoomRole { host, viewer }

enum _RoomStatus {
  requestingPermissions,
  connecting,
  live,
  permissionDenied,
  error,
}

/// Unified Bigo-style multi-slot live room used by host, viewer, and guest.
///
/// Layout is shared; role only changes connection path, bottom controls, and
/// which moderation / guest-request affordances appear.
class LiveRoomScreen extends StatefulWidget {
  final String roomName;
  final LiveRoomRole role;

  /// Display name of the host — used by viewers when room detail hasn't
  /// loaded yet.
  final String? hostName;

  /// Beauty filter preset name from create-room (e.g. "Cool"), applied by
  /// the host after connect when room detail isn't available yet.
  final String? initialFilterName;

  /// Seat count hint (3 / 6 / 9) before room detail arrives.
  final int? initialSlotCount;

  const LiveRoomScreen({
    super.key,
    required this.roomName,
    required this.role,
    this.hostName,
    this.initialFilterName,
    this.initialSlotCount,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _liveKit = LiveKitService.instance;
  final _roomSocket = RoomSocketService.instance;
  final _liveRoomService = LiveRoomService();

  StreamSubscription<RoomEvent>? _eventsSub;
  StreamSubscription<List<ViewerModel>>? _viewerListSub;
  StreamSubscription<List<ViewerModel>>? _occupiedSlotsSub;
  StreamSubscription<VideoFilterSettings>? _videoFilterSub;
  StreamSubscription<Map<String, VideoFilterSettings>>? _participantFiltersSub;
  StreamSubscription<
    ({String userId, String username, String message, bool isSystem})
  >?
  _chatMessageSub;
  StreamSubscription<String>? _joinRejectedSub;
  StreamSubscription<String>? _bannedSub;
  StreamSubscription<bool>? _chatMuteSub;
  StreamSubscription<String>? _chatRejectedSub;
  StreamSubscription<String>? _warningSub;
  StreamSubscription<String>? _guestInvitedSub;
  StreamSubscription<int?>? _guestInviteAcceptedSub;
  StreamSubscription<String>? _guestRequestRejectedSub;
  StreamSubscription<String>? _guestRemovedFromStageSub;
  StreamSubscription<String>? _roomEndedSub;
  StreamSubscription<({String userId, String username, GiftModel gift})>?
      _giftReceivedSub;

  _RoomStatus _status = _RoomStatus.connecting;
  String? _errorMessage;

  /// True after host intentionally taps Exit (or system back). Prevents
  /// dispose / double-pop from treating app-kill as a room delete.
  bool _hostEndedIntentionally = false;

  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _isFullscreen = false;

  bool _isChatMuted = false;
  bool _isGuest = false;
  bool _isBecomingGuest = false;
  GuestRequestStatus _guestRequestStatus = GuestRequestStatus.none;
  Timer? _guestRequestResetTimer;

  GiftModel? _flyingGift;
  String _flyingGiftUsername = '';
  Timer? _giftClearTimer;
  final GlobalKey _hostSlotKey = GlobalKey(debugLabel: 'hostSlot');
  final LayerLink _giftToastLink = LayerLink();

  String? _currentUserId;
  String _currentUsername = 'You';

  LiveRoomModel? _roomDetail;

  /// Host beauty look mirrored on every client (local for host, remote tile
  /// for viewers). Seeded from room `filterName`, updated live over socket.
  VideoFilterSettings _hostFilters = const VideoFilterSettings();

  /// This client's own beauty look when joining / sitting as a co-host guest.
  VideoFilterSettings _guestFilters = const VideoFilterSettings();

  /// Per-user filters for remote guest tiles (and host via socket snapshot).
  Map<String, VideoFilterSettings> _participantFilters = {};

  /// Native AR lipstick shade, or null when it is off.
  Color? _lipColor;

  /// Native AR cheek blush shade, or null when it is off.
  Color? _blushColor;

  /// Native under-eye brightening, or null when it is off.
  Color? _underEyeColor;

  final _chatMessages = <ChatMessageModel>[];
  final _chatScrollController = ScrollController();
  final _chatInputController = TextEditingController();

  bool get _isHost => widget.role == LiveRoomRole.host;

  String get _hostDisplayName =>
      _roomDetail?.hostName ?? widget.hostName ?? 'Host';

  int get _effectiveSlotCount {
    final fromDetail = _roomDetail?.slotCount;
    final fromInitial = widget.initialSlotCount;
    final fromSocket = _roomSocket.currentSlotCount;
    final raw = fromDetail ?? fromInitial ?? fromSocket;
    return [3, 6, 9].contains(raw) ? raw : 6;
  }

  @override
  void initState() {
    super.initState();
    // Seed from create-room choice immediately so the first frame is filtered.
    final initial = widget.initialFilterName;
    if (initial != null && initial.trim().isNotEmpty) {
      _hostFilters = VideoFilterSettings.fromFilterName(initial);
      _liveKit.updateVideoFilters(_hostFilters);
    }
    MakeupService.instance.onLowLight = _onMakeupLowLight;
    MakeupService.instance.onLightRestored = _onMakeupLightRestored;
    if (_isHost) {
      _status = _RoomStatus.requestingPermissions;
      _startAsHost();
    } else {
      _startAsViewer();
    }
  }

  @override
  void dispose() {
    if (MakeupService.instance.onLowLight == _onMakeupLowLight) {
      MakeupService.instance.onLowLight = null;
    }
    if (MakeupService.instance.onLightRestored == _onMakeupLightRestored) {
      MakeupService.instance.onLightRestored = null;
    }
    _cancelSubscriptions();
    _guestRequestResetTimer?.cancel();
    _giftClearTimer?.cancel();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    // App close / offline: tear down media only — do NOT delete the room.
    unawaited(MakeupService.instance.detach());
    unawaited(_liveKit.setMakeupCapture(false));
    unawaited(_liveKit.disconnect());
    unawaited(_roomSocket.disconnect());
    super.dispose();
  }

  void _cancelSubscriptions() {
    _eventsSub?.cancel();
    _viewerListSub?.cancel();
    _occupiedSlotsSub?.cancel();
    _videoFilterSub?.cancel();
    _participantFiltersSub?.cancel();
    _chatMessageSub?.cancel();
    _joinRejectedSub?.cancel();
    _bannedSub?.cancel();
    _chatMuteSub?.cancel();
    _chatRejectedSub?.cancel();
    _warningSub?.cancel();
    _guestInvitedSub?.cancel();
    _guestInviteAcceptedSub?.cancel();
    _guestRequestRejectedSub?.cancel();
    _guestRemovedFromStageSub?.cancel();
    _roomEndedSub?.cancel();
    _giftReceivedSub?.cancel();
  }

  Future<void> _loadIdentity() async {
    final token = await SecureStorageHelper.getToken();
    if (token == null) return;
    final claims = decodeJwtPayload(token);
    _currentUserId = claims?['userId'] as String?;
    final name = claims?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      _currentUsername = name.trim();
    }
  }

  // ── Host path ──────────────────────────────────────────────────────────

  Future<void> _startAsHost() async {
    setState(() => _errorMessage = null);

    await _loadIdentity();
    // So guest tiles aren't mis-classified as "host" before room detail loads.
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _liveKit.knownHostUserId = _currentUserId;
    }

    // Create-room already asked for camera — skip the wait screen when granted.
    var cameraStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      if (!mounted) return;
      setState(() => _status = _RoomStatus.requestingPermissions);
      cameraStatus = await Permission.camera.request();
      micStatus = await Permission.microphone.request();
      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (!mounted) return;
        setState(() => _status = _RoomStatus.permissionDenied);
        return;
      }
    }

    // Enter the room UI immediately; media/socket connect in the background.
    if (!mounted) return;
    setState(() => _status = _RoomStatus.live);
    unawaited(_loadRoomDetail(applyHostFilters: true));
    unawaited(_connectHostSession());
  }

  Future<void> _connectHostSession() async {
    try {
      await _liveKit.connect(
        roomName: widget.roomName,
        identity: 'host_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.host,
        displayName: _currentUsername,
      );

      _eventsSub?.cancel();
      _eventsSub = _liveKit.events.listen(_onLiveKitEvent);

      await _roomSocket.connectAndJoin(roomName: widget.roomName, role: 'host');
      _registerSharedSocketListeners();
      // Publish current filter so late-joining viewers match create-room look.
      _roomSocket.setVideoFilter(_hostFilters);
      await _loadChatHistory();
      if (mounted) setState(() {});
    } on LiveKitServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _RoomStatus.error;
        _errorMessage = e.message;
      });
    } on RoomSocketException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _RoomStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  /// Leave the live UI only — does NOT delete the room (close / back /
  /// app kill all keep the room so the host can resume later).
  Future<void> _leaveRoom() async {
    if (_hostEndedIntentionally) return;
    _hostEndedIntentionally = true;
    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Host-only: confirm, then permanently delete room + chat.
  Future<void> _confirmDeleteRoom() async {
    if (!_isHost || _hostEndedIntentionally) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete this room?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete the room and all chat messages. '
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _hostEndedIntentionally = true;
    try {
      await _liveRoomService.endLive(widget.roomName);
    } on LiveRoomException catch (e) {
      _hostEndedIntentionally = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ── Viewer path ────────────────────────────────────────────────────────

  Future<void> _startAsViewer() async {
    setState(() => _errorMessage = null);

    await _loadIdentity();
    // Show room chrome immediately; connect media/socket in background.
    if (!mounted) return;
    setState(() => _status = _RoomStatus.live);
    unawaited(_loadRoomDetail());
    unawaited(_connectViewerSession());
  }

  Future<void> _connectViewerSession() async {
    try {
      await _liveKit.connect(
        roomName: widget.roomName,
        identity: 'viewer_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.viewer,
        displayName: _currentUsername,
      );

      _eventsSub?.cancel();
      _eventsSub = _liveKit.events.listen(_onLiveKitEvent);

      await _roomSocket.connectAndJoin(
        roomName: widget.roomName,
        role: 'viewer',
      );
      _registerSharedSocketListeners();
      _registerViewerSocketListeners();
      await _loadChatHistory();
      if (mounted) setState(() {});
    } on LiveKitServiceException catch (e) {
      await _handleUnrecoverableJoinFailure(e.message);
    } on RoomSocketException catch (e) {
      await _handleUnrecoverableJoinFailure(e.message);
    }
  }

  void _registerViewerSocketListeners() {
    _joinRejectedSub = _roomSocket.joinRejected.listen((reason) {
      _handleUnrecoverableJoinFailure(reason);
    });

    _bannedSub = _roomSocket.banned.listen((reason) async {
      if (!mounted) return;
      await _liveKit.disconnect();
      await _roomSocket.disconnect();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Removed from room'),
          content: Text(reason),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    });

    _chatMuteSub = _roomSocket.chatMuteState.listen((muted) {
      if (mounted) setState(() => _isChatMuted = muted);
    });

    _chatRejectedSub = _roomSocket.chatRejected.listen((reason) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
    });

    _warningSub = _roomSocket.warning.listen((reason) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('⚠️ Warning from Host'),
          content: Text(reason),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
    });

    _guestInvitedSub = _roomSocket.guestInvited.listen((hostName) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Co-Host Invitation'),
          content: Text('$hostName invited you to co-host. Accept?'),
          actions: [
            TextButton(
              onPressed: () {
                _roomSocket.declineGuestInvite();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Pick beauty look before going on camera, then accept.
                unawaited(_acceptInviteWithFilter());
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    });

    _guestInviteAcceptedSub = _roomSocket.guestInviteAccepted.listen((_) {
      _guestRequestResetTimer?.cancel();
      if (mounted) {
        setState(() => _guestRequestStatus = GuestRequestStatus.none);
      }
      unawaited(_becomeGuest());
    });

    _guestRequestRejectedSub = _roomSocket.guestRequestRejected.listen((
      reason,
    ) {
      if (!mounted) return;
      setState(() => _guestRequestStatus = GuestRequestStatus.rejected);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      _guestRequestResetTimer?.cancel();
      _guestRequestResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _guestRequestStatus = GuestRequestStatus.none);
        }
      });
    });

    _guestRemovedFromStageSub = _roomSocket.guestRemovedFromStage.listen((
      reason,
    ) {
      if (!mounted || !_isGuest) return;
      unawaited(_demoteToViewer(notifyServer: false, message: reason));
    });
  }

  Future<void> _handleUnrecoverableJoinFailure(String reason) async {
    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (!mounted) return;

    if (reason.contains('Room is full')) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(reason)));
      return;
    }

    setState(() {
      _status = _RoomStatus.error;
      _errorMessage = reason;
    });
  }

  Future<void> _becomeGuest() async {
    if (!mounted || _isGuest || _isBecomingGuest) return;
    // Flip to guest UI immediately — no full-screen "Joining as guest..." wait.
    setState(() {
      _isBecomingGuest = true;
      _isGuest = true;
      _micEnabled = true;
      _cameraEnabled = true;
      _guestRequestStatus = GuestRequestStatus.none;
    });

    try {
      // Identity must be the real account id so host/viewers can map this
      // publisher onto the single socket-assigned seat (not every empty seat).
      final identity = (_currentUserId != null && _currentUserId!.isNotEmpty)
          ? _currentUserId!
          : 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final hostId = _roomDetail?.hostId ?? _liveKit.knownHostUserId;
      // Soft promote: enable cam/mic in-place so host video stays subscribed.
      await _liveKit.promoteToGuest(
        roomName: widget.roomName,
        identity: identity,
        displayName: _currentUsername,
      );
      if (hostId != null && hostId.isNotEmpty) {
        _liveKit.knownHostUserId = hostId;
      }
      // Everyone else mirrors this guest tile with the same beauty look.
      _roomSocket.setParticipantFilter(_guestFilters);
      if (!mounted) return;
      setState(() => _isBecomingGuest = false);
    } on LiveKitServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBecomingGuest = false;
        _isGuest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join as guest: ${e.message}')),
      );
    }
  }

  VideoFilterSettings _settingsFromGpuBeauty(BeautyGpuSettings gpu) {
    if (!gpu.enabled) return VideoFilterSettings.identity;
    final intensity = gpu.intensity.clamp(0.0, 1.0);
    final preset = intensity < 0.25
        ? VideoFilterPreset.natural
        : intensity < 0.55
            ? VideoFilterPreset.smooth
            : VideoFilterPreset.bright;
    return VideoFilterSettings(
      beauty: intensity,
      brightness: intensity * 0.08,
      contrast: -0.03,
      saturation: 0.05,
      beautyModeEnabled: true,
      preset: preset,
    );
  }

  /// Beauty picker before going on stage. Returns false if cancelled.
  Future<bool> _pickGuestFilterBeforeJoin() async {
    final gpu = await showGpuBeautyControls(
      context: context,
      enabled: _guestFilters.beautyModeEnabled,
      intensity: _guestFilters.beautyModeEnabled
          ? _guestFilters.beauty.clamp(0.0, 1.0)
          : 0.55,
    );
    if (gpu == null || !mounted) return false;
    setState(() => _guestFilters = _settingsFromGpuBeauty(gpu));
    return true;
  }

  Future<void> _acceptInviteWithFilter() async {
    if (_isHost || _isGuest || _isBecomingGuest) return;
    final ok = await _pickGuestFilterBeforeJoin();
    if (!ok || !mounted) return;
    _roomSocket.acceptGuestInvite();
  }

  /// Join co-host stage without host approval (empty seat tap).
  Future<void> _joinGuestLive({int? slotNumber}) async {
    if (_isHost || _isGuest || _isBecomingGuest) return;
    if (_guestRequestStatus == GuestRequestStatus.pending) return;
    final ok = await _pickGuestFilterBeforeJoin();
    if (!ok || !mounted) return;
    _guestRequestResetTimer?.cancel();
    setState(() => _guestRequestStatus = GuestRequestStatus.pending);
    _roomSocket.joinGuestStage(slotNumber: slotNumber);
  }

  Future<void> _closeAsViewer() async {
    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Shared ─────────────────────────────────────────────────────────────

  void _onLiveKitEvent(RoomEvent event) {
    if (!mounted) return;
    if (event is LocalTrackPublishedEvent ||
        event is RoomDisconnectedEvent ||
        event is ParticipantConnectedEvent ||
        event is ParticipantDisconnectedEvent ||
        event is TrackSubscribedEvent ||
        event is TrackUnsubscribedEvent) {
      setState(() {});
    }
  }

  void _registerSharedSocketListeners() {
    _viewerListSub = _roomSocket.viewerList.listen((_) {
      if (mounted) setState(() {});
    });
    _occupiedSlotsSub = _roomSocket.occupiedSlots.listen((_) {
      if (mounted) setState(() {});
    });
    _videoFilterSub = _roomSocket.videoFilter.listen((settings) {
      _applyHostFilters(settings, broadcast: false);
    });
    _participantFiltersSub = _roomSocket.participantFilters.listen((filters) {
      if (!mounted) return;
      setState(() => _participantFilters = filters);
    });
    // Snapshot from room:joined if the host already set a live filter.
    final joinedFilter = _roomSocket.currentVideoFilter;
    if (joinedFilter != null) {
      _applyHostFilters(joinedFilter, broadcast: false);
    }
    if (_roomSocket.currentParticipantFilters.isNotEmpty) {
      _participantFilters = Map<String, VideoFilterSettings>.from(
        _roomSocket.currentParticipantFilters,
      );
    }

    _chatMessageSub = _roomSocket.chatMessage.listen((msg) {
      // Everyone inserts own chat optimistically — skip the socket echo.
      if (_currentUserId != null &&
          msg.userId == _currentUserId &&
          !msg.isSystem) {
        return;
      }
      _addChatMessage(
        ChatMessageModel(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          username: msg.username,
          message: msg.message,
          isSystemMessage: msg.isSystem,
          userId: msg.userId,
        ),
      );
    });

    _giftReceivedSub?.cancel();
    _giftReceivedSub = _roomSocket.giftReceived.listen((event) {
      if (!mounted) return;
      // Sender already showed the overlay optimistically — only skip that.
      // Chat is fed by the matching chat:message broadcast for everyone.
      final isSelf =
          _currentUserId != null && event.userId == _currentUserId;
      if (isSelf) return;
      _showGiftEffect(
        gift: event.gift,
        username: event.username,
        userId: event.userId,
        addChat: false,
      );
    });

    _roomEndedSub = _roomSocket.roomEnded.listen((_) async {
      if (!mounted || _hostEndedIntentionally) return;
      _hostEndedIntentionally = true;
      await _liveKit.disconnect();
      await _roomSocket.disconnect();
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  Future<void> _loadRoomDetail({bool applyHostFilters = false}) async {
    try {
      final detail = await _liveRoomService.getRoomDetail(widget.roomName);
      if (!mounted) return;

      if (detail.hostId != null && detail.hostId!.isNotEmpty) {
        _liveKit.knownHostUserId = detail.hostId;
      }

      // Prefer a live socket filter if the host already pushed one; otherwise
      // fall back to the room's stored filterName so viewers match create-room.
      final liveFilter = _roomSocket.currentVideoFilter;
      if (liveFilter != null) {
        _applyHostFilters(liveFilter, broadcast: false);
      } else if (applyHostFilters || detail.filterName.isNotEmpty) {
        final filterName = detail.filterName.isNotEmpty
            ? detail.filterName
            : widget.initialFilterName;
        _applyHostFilters(
          VideoFilterSettings.fromFilterName(filterName),
          broadcast: _isHost,
        );
      }

      setState(() => _roomDetail = detail);
    } on LiveRoomException catch (e) {
      debugPrint('Failed to load room detail: ${e.message}');
      if (widget.initialFilterName != null) {
        _applyHostFilters(
          VideoFilterSettings.fromFilterName(widget.initialFilterName),
          broadcast: _isHost,
        );
      }
    }
  }

  void _applyHostFilters(
    VideoFilterSettings settings, {
    required bool broadcast,
  }) {
    _hostFilters = settings;
    _liveKit.updateVideoFilters(settings);
    if (broadcast && _isHost) {
      _roomSocket.setVideoFilter(settings);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await _liveRoomService.getMessages(widget.roomName);
      if (!mounted || history.isEmpty) return;

      setState(() {
        for (var i = 0; i < history.length; i++) {
          _chatMessages.add(
            ChatMessageModel.fromHistory(
              id: 'hist_${i}_${DateTime.now().microsecondsSinceEpoch}',
              username: history[i].username,
              message: history[i].message,
              userId: history[i].userId,
            ),
          );
        }
      });
      _scrollChatToBottom();
    } on LiveRoomException catch (e) {
      debugPrint('Failed to load chat history: ${e.message}');
    }
  }

  void _addChatMessage(ChatMessageModel message) {
    if (!mounted) return;
    setState(() => _chatMessages.add(message));
    _scrollChatToBottom();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      // reverse:true list — newest sits at offset 0.
      _chatScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    if (!_isHost && _isChatMuted) return;
    _chatInputController.clear();

    // Same optimistic insert for host, viewer, and guest.
    _addChatMessage(
      ChatMessageModel(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        username: _currentUsername,
        message: text,
        userId: _currentUserId ?? '',
      ),
    );
    _roomSocket.sendChatMessage(text);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
  }

  void _openBeautyFilters() {
    final makeup = MakeupService.instance.isSupported;
    showVideoFilterControls(
      context: context,
      initial: _hostFilters,
      onChanged: (settings) {
        // Push to viewers so they see the same look on the host tile.
        _applyHostFilters(settings, broadcast: true);
      },
      initialLipColor: _lipColor,
      onLipColorChanged: makeup ? _applyLipstick : null,
      initialBlushColor: _blushColor,
      onBlushColorChanged: makeup ? _applyBlush : null,
      initialUnderEyeColor: _underEyeColor,
      onUnderEyeColorChanged: makeup ? _applyUnderEye : null,
    );
  }

  /// Native makeup is baked into published frames — no socket broadcast.
  Future<void> _ensureMakeupAttached() async {
    // Lighter capture first so lip detect can run every frame, then attach
    // to the (possibly restarted) track id.
    await _liveKit.setMakeupCapture(true);
    await MakeupService.instance.attach(
      _liveKit.localVideoTrack?.mediaStreamTrack.id,
    );
  }

  Future<void> _detachMakeupIfIdle() async {
    if (!_nativeMakeupOn) {
      await MakeupService.instance.detach();
      await _liveKit.setMakeupCapture(false);
    }
  }

  Future<void> _applyLipstick(Color? color) async {
    setState(() => _lipColor = color);
    if (color != null) await _ensureMakeupAttached();
    await MakeupService.instance.setLipstick(color);
    await _detachMakeupIfIdle();
  }

  Future<void> _applyBlush(Color? color) async {
    setState(() => _blushColor = color);
    if (color != null) await _ensureMakeupAttached();
    await MakeupService.instance.setBlush(color);
    await _detachMakeupIfIdle();
  }

  Future<void> _applyUnderEye(Color? color) async {
    setState(() => _underEyeColor = color);
    if (color != null) await _ensureMakeupAttached();
    await MakeupService.instance.setUnderEye(color);
    await _detachMakeupIfIdle();
  }

  /// Native paused drawing for darkness — keep selections; auto-resume later.
  void _onMakeupLowLight() {
    if (!mounted) return;
    if (!_nativeMakeupOn) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not enough light — makeup paused'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Light is back — native already resumed drawing with the same shades.
  void _onMakeupLightRestored() {
    if (!mounted) return;
    if (!_nativeMakeupOn) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Light OK — makeup restored'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool get _nativeMakeupOn =>
      _lipColor != null || _blushColor != null || _underEyeColor != null;

  Future<void> _flipCamera() => _liveKit.flipCamera();

  Future<void> _toggleMic() async {
    final enabled = await _liveKit.toggleMicrophone();
    if (!mounted) return;
    setState(() => _micEnabled = enabled);
  }

  Future<void> _toggleCamera() async {
    final enabled = await _liveKit.toggleCamera();
    if (!mounted) return;
    setState(() => _cameraEnabled = enabled);
  }

  void _openViewerList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ViewerListSheet(isHost: _isHost),
    );
  }

  void _openBannedUsers() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BannedUsersSheet(),
    );
  }

  void _openModerationMenu(ChatMessageModel message) {
    if (!_isHost) return;
    final viewer = _roomSocket.currentViewers.firstWhere(
      (v) => v.userId == message.userId,
      orElse: () => ViewerModel(
        userId: message.userId,
        name: message.username,
        isMuted: false,
        isGuest: false,
      ),
    );
    showViewerModerationSheet(
      context,
      roomSocket: _roomSocket,
      userId: viewer.userId,
      name: viewer.name,
      isMuted: viewer.isMuted,
      isGuest: viewer.isGuest,
    );
  }

  void _openGiftSheet() {
    // Chrome blocks audio until a gesture — unlock here so send + receive play.
    unawaited(GiftSound.instance.unlock());
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftSheet(onGiftSelected: _sendGift),
    );
  }

  void _sendGift(GiftModel gift) {
    if (_isHost) return;
    Navigator.of(context).pop();
    // Sender: optimistic overlay + chat. Everyone else gets overlay via
    // gift:received and the chat line via chat:message.
    _showGiftEffect(
      gift: gift,
      username: _currentUsername,
      userId: _currentUserId ?? '',
      addChat: true,
    );
    _roomSocket.sendGift(gift);
  }

  void _showGiftEffect({
    required GiftModel gift,
    required String username,
    String userId = '',
    bool addChat = true,
  }) {
    if (addChat) {
      _addChatMessage(
        ChatMessageModel(
          id: 'gift_${DateTime.now().microsecondsSinceEpoch}',
          username: username,
          message: 'sent a ${gift.name} ${gift.emoji}',
          userId: userId,
        ),
      );
    }

    unawaited(GiftSound.instance.play());

    _giftClearTimer?.cancel();
    setState(() {
      _flyingGift = gift;
      _flyingGiftUsername = username;
    });
    _giftClearTimer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) {
        setState(() {
          _flyingGift = null;
          _flyingGiftUsername = '';
        });
      }
    });
  }

  String _resolveUserIdForName(String name) {
    for (final viewer in _roomSocket.currentViewers) {
      if (viewer.name == name) return viewer.userId;
    }
    return '';
  }

  // ── Slot building ──────────────────────────────────────────────────────

  /// Host not publishing video — show profile pic instead of a spinner.
  Widget _hostAbsentPlaceholder() {
    final photo = _roomDetail?.hostPhoto;
    final name = _isHost ? _currentUsername : _hostDisplayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ColoredBox(
      color: const Color(0xFF3A2C5C),
      child: Center(
        child: photo != null && photo.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photo,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _hostInitialAvatar(initial),
                ),
              )
            : _hostInitialAvatar(initial),
      ),
    );
  }

  Widget _hostInitialAvatar(String initial) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white12,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  LiveGridSlotData _buildHostSlot() {
    if (_isHost) {
      return LiveGridSlotData(
        userId: _currentUserId ?? '',
        name: _currentUsername,
        avatarUrl: _roomDetail?.hostPhoto,
        videoTrack: _liveKit.localVideoTrack,
        isMicMuted: !_micEnabled,
        videoFilters: _hostFilters,
        enableFilterBlur: !_nativeMakeupOn,
      );
    }
    return LiveGridSlotData(
      userId: _roomDetail?.hostId ?? '',
      name: _hostDisplayName,
      avatarUrl: _roomDetail?.hostPhoto,
      videoTrack: _liveKit.remoteHostVideoTrack,
      isMicMuted: !_liveKit.remoteHostMicEnabled,
      // Viewers apply the same color grade (no blur — keeps FPS up).
      videoFilters: _hostFilters,
      enableFilterBlur: false,
    );
  }

  List<LiveGridSlotData?> _buildSlots() {
    final slotCount = _effectiveSlotCount;

    // Socket is the source of truth: one userId → one seat. Never spray a
    // remote track across empty Join seats.
    final occupiedBySlot = <int, ViewerModel>{};
    final seatedUserIds = <String>{};
    for (final v in _roomSocket.currentOccupiedSlots) {
      final seat = v.slotNumber;
      if (seat == null || seat < 1 || seat > slotCount) continue;
      if (seat == 1) continue; // host rendered separately
      if (seatedUserIds.contains(v.userId)) continue;
      seatedUserIds.add(v.userId);
      occupiedBySlot.putIfAbsent(seat, () => v);
    }

    final tracksByUserId = <String,
        ({
          String identity,
          String name,
          RemoteVideoTrack track,
          bool micEnabled,
        })>{};
    for (final g in _liveKit.remoteGuestVideoTiles) {
      tracksByUserId.putIfAbsent(g.identity, () => g);
    }

    return List<LiveGridSlotData?>.generate(slotCount, (i) {
      final seat = i + 1;
      if (seat == 1) return _buildHostSlot();

      final occupant = occupiedBySlot[seat];
      if (occupant == null) return null;

      // This client's own guest seat — local camera + mic toggle.
      if (_isGuest &&
          _currentUserId != null &&
          occupant.userId == _currentUserId) {
        return LiveGridSlotData(
          userId: _currentUserId!,
          name: _currentUsername,
          videoTrack: _liveKit.localVideoTrack,
          isMicMuted: !_micEnabled,
          videoFilters: _guestFilters,
          enableFilterBlur: !_nativeMakeupOn,
          trailing: GestureDetector(
            onTap: _toggleMic,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Icon(
                _micEnabled ? Icons.mic : Icons.mic_off,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        );
      }

      final remote = tracksByUserId[occupant.userId];
      final guestFilters = _participantFilters[occupant.userId];
      return LiveGridSlotData(
        userId: occupant.userId,
        name: occupant.name.isNotEmpty
            ? occupant.name
            : (remote != null && remote.name.isNotEmpty
                  ? remote.name
                  : 'Guest'),
        videoTrack: remote?.track,
        isMicMuted: remote != null ? !remote.micEnabled : false,
        videoFilters: guestFilters,
        enableFilterBlur: false,
      );
    });
  }

  Widget _wrapLocalVideo(Widget child) {
    // Native lipstick already blits every frame on the capture thread —
    // stacking GpuImageFilter snapshots on top doubles the lag.
    return FilteredVideoPreview(
      settings: _hostFilters,
      enableBlur: !_nativeMakeupOn,
      child: child,
    );
  }

  void _onTapGridSlot(LiveGridSlotData slot) {
    if (!_isHost) return;
    if (slot.userId.isEmpty || slot.userId == _currentUserId) return;
    final viewer = _roomSocket.currentViewers.firstWhere(
      (v) => v.userId == slot.userId,
      orElse: () => ViewerModel(
        userId: slot.userId.isNotEmpty
            ? slot.userId
            : _resolveUserIdForName(slot.name),
        name: slot.name,
        isMuted: false,
        isGuest: true,
      ),
    );
    if (viewer.userId.isEmpty) return;
    showViewerModerationSheet(
      context,
      roomSocket: _roomSocket,
      userId: viewer.userId,
      name: viewer.name,
      isMuted: viewer.isMuted,
      isGuest: viewer.isGuest,
    );
  }

  void _onTapEmptySlot(int slotNumber) {
    if (_isHost) return;
    if (!_isGuest) unawaited(_joinGuestLive(slotNumber: slotNumber));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Back / close: leave media only — never delete the room.
        _hostEndedIntentionally = true;
        unawaited(_liveKit.disconnect());
        unawaited(_roomSocket.disconnect());
      },
      child: Scaffold(
        // Keep the stage fixed; only the chat strip lifts with the keyboard.
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF0F0A20),
        body: Listener(
          // Chrome autoplay: any tap unlocks gift audio for later receive events.
          onPointerDown: (_) => unawaited(GiftSound.instance.unlock()),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: liveRoomBackgroundGradient),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _status == _RoomStatus.live
                        ? _buildLiveLayout()
                        : _buildStatusBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveLayout() {
    final hostTrack = _isHost
        ? _liveKit.localVideoTrack
        : _liveKit.remoteHostVideoTrack;
    final slotCount = _effectiveSlotCount;
    final slots = _buildSlots();

    // Stage stays fixed under the keyboard; only the bottom chat strip lifts.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: LiveRoomTopBar(
                roomName: _roomDetail?.roomName ?? widget.roomName,
                hostName: _isHost ? _currentUsername : _hostDisplayName,
                hostAvatarUrl: _roomDetail?.hostPhoto,
                viewerCount: _roomSocket.currentViewers.isNotEmpty
                    ? _roomSocket.currentViewers.length
                    : (_roomDetail?.viewerCount ?? 0),
                onClose: _isHost ? _leaveRoom : _closeAsViewer,
                onFullscreen: _toggleFullscreen,
                isFullscreen: _isFullscreen,
                onTapViewerCount: _openViewerList,
                onBannedUsers: _isHost ? _openBannedUsers : null,
                onFilters: _isHost ? _openBeautyFilters : null,
                onDeleteRoom: _isHost ? _confirmDeleteRoom : null,
              ),
            ),
            Expanded(
              child: Padding(
                // Keep stage clear of the overlaid chat strip when keyboard is closed.
                // Keep grid parked at the top; chat overlays upward over it.
                padding: EdgeInsets.only(bottom: _isFullscreen ? 0 : 52),
                child: _isFullscreen
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: KeyedSubtree(
                          key: _hostSlotKey,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: hostTrack == null
                                ? _hostAbsentPlaceholder()
                                : (_isHost
                                      ? _wrapLocalVideo(
                                          VideoTrackRenderer(
                                            hostTrack,
                                            fit: VideoViewFit.cover,
                                          ),
                                        )
                                      : FilteredVideoPreview(
                                          settings: _hostFilters,
                                          enableBlur: false,
                                          child: VideoTrackRenderer(
                                            hostTrack,
                                            fit: VideoViewFit.cover,
                                          ),
                                        )),
                          ),
                        ),
                      )
                    : Padding(
                        // Full-bleed grid — no side gutters between seats/edges.
                        padding: EdgeInsets.zero,
                        child: Builder(
                          builder: (context) {
                            final side = LiveRoomSideBanners(
                              roomDescription: _roomDetail?.roomRules,
                            );
                            final stage = LiveRoomGrid(
                              slotCount: slotCount,
                              slots: slots,
                              hostSlotKey: _hostSlotKey,
                              onTapSlot: _isHost ? _onTapGridSlot : null,
                              onTapEmptySlot: _onTapEmptySlot,
                              // Invisible anchor — real toast follows this above chat.
                              footer: _flyingGift == null
                                  ? null
                                  : CompositedTransformTarget(
                                      link: _giftToastLink,
                                      child: const SizedBox(
                                        height: 52,
                                        width: double.infinity,
                                      ),
                                    ),
                            );
                            if (side.hasContent) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: stage),
                                  const SizedBox(width: 8),
                                  side,
                                ],
                              );
                            }
                            return stage;
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (!_isFullscreen)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: LiveRoomChat(
                      messages: _chatMessages,
                      scrollController: _chatScrollController,
                      inputController: _chatInputController,
                      isMuted: !_isHost && _isChatMuted,
                      onSend: _sendMessage,
                      onGift: _isHost ? null : _openGiftSheet,
                      onTapUsername: _isHost ? _openModerationMenu : null,
                      currentUserId: _currentUserId,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 192),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: _isHost
                          ? _buildHostControls()
                          : _isGuest
                              ? _buildGuestControls()
                              : _buildViewerControls(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_flyingGift != null) ...[
          // Follows the cam-grid footer anchor so it stays flush under the
          // seats, while painting above the chat strip.
          CompositedTransformFollower(
            link: _giftToastLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.topLeft,
            child: SizedBox(
              // Match cam-grid stage width (capped like LiveRoomGrid).
              width: MediaQuery.sizeOf(context).width.clamp(0, 420),
              height: 52,
              child: IgnorePointer(
                child: LiveGiftToast(
                  key: ValueKey(
                    'gift_${_flyingGiftUsername}_${_flyingGift!.id}_'
                    '${_flyingGift.hashCode}',
                  ),
                  username: _flyingGiftUsername,
                  gift: _flyingGift!,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _GiftFlyToHost(
                gift: _flyingGift!,
                hostSlotKey: _hostSlotKey,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Step off the co-host seat and keep watching as a normal viewer.
  Future<void> _leaveGuestLive() => _demoteToViewer(notifyServer: true);

  Future<void> _demoteToViewer({
    required bool notifyServer,
    String? message,
  }) async {
    if (!_isGuest || !mounted) return;
    final hostId = _roomDetail?.hostId ?? _liveKit.knownHostUserId;
    if (notifyServer) {
      _roomSocket.leaveGuestStage();
    }

    try {
      final identity = (_currentUserId != null && _currentUserId!.isNotEmpty)
          ? _currentUserId!
          : 'viewer_${DateTime.now().millisecondsSinceEpoch}';
      // Soft demote: stop publishing without reconnecting (host video stays).
      await _liveKit.demoteToViewer(
        roomName: widget.roomName,
        identity: identity,
        displayName: _currentUsername,
      );
      if (hostId != null && hostId.isNotEmpty) {
        _liveKit.knownHostUserId = hostId;
      }
      if (!mounted) return;
      setState(() {
        _isGuest = false;
        _micEnabled = true;
        _cameraEnabled = true;
        _guestRequestStatus = GuestRequestStatus.none;
        _guestFilters = const VideoFilterSettings();
      });
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on LiveKitServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not leave live: ${e.message}')),
      );
    }
  }

  Widget _buildHostControls() {
    // Room end is the top-bar close (X) — no separate End button here.
    return _VerticalControls(
      children: [
        _ControlButton(
          icon: Icons.flip_camera_ios,
          label: 'Flip',
          onTap: _flipCamera,
        ),
        _ControlButton(
          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: 'Cam',
          onTap: _toggleCamera,
        ),
        _ControlButton(
          icon: _micEnabled ? Icons.mic : Icons.mic_off,
          label: 'Mic',
          onTap: _toggleMic,
        ),
      ],
    );
  }

  Widget _buildGuestControls() {
    return _VerticalControls(
      children: [
        _ControlButton(
          icon: Icons.flip_camera_ios,
          label: 'Flip',
          onTap: _flipCamera,
        ),
        _ControlButton(
          icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
          label: 'Cam',
          onTap: _toggleCamera,
        ),
        _ControlButton(
          icon: _micEnabled ? Icons.mic : Icons.mic_off,
          label: 'Mic',
          onTap: _toggleMic,
        ),
        _ControlButton(
          icon: Icons.logout_rounded,
          label: 'Leave',
          color: const Color(0xFFFF8A00),
          onTap: _leaveGuestLive,
        ),
      ],
    );
  }

  // Viewers have no side controls: chat + gifts live in the bottom strip.
  Widget _buildViewerControls() => const SizedBox.shrink();

  Widget _buildStatusBody() {
    switch (_status) {
      case _RoomStatus.requestingPermissions:
        return const _StatusMessage(
          icon: CircularProgressIndicator(color: Colors.white),
          message: 'Requesting camera & microphone access...',
        );
      case _RoomStatus.connecting:
        return _StatusMessage(
          icon: const CircularProgressIndicator(color: Colors.white),
          message: _isHost
              ? 'Starting your live stream...'
              : 'Joining live stream...',
        );
      case _RoomStatus.permissionDenied:
        return _StatusMessage(
          icon: const Icon(
            Icons.no_photography,
            color: Colors.white70,
            size: 56,
          ),
          message:
              'Camera and microphone access are required to go live.\n'
              'Please enable them in your device settings.',
          actionLabel: 'Try Again',
          onAction: _startAsHost,
        );
      case _RoomStatus.error:
        return _StatusMessage(
          icon: const Icon(
            Icons.error_outline,
            color: Colors.white70,
            size: 56,
          ),
          message: _errorMessage ??
              (_isHost
                  ? 'Something went wrong.'
                  : 'Could not join the stream.'),
          actionLabel: 'Retry',
          onAction: _isHost ? _startAsHost : _startAsViewer,
        );
      case _RoomStatus.live:
        return const SizedBox.shrink();
    }
  }
}

// ── Private helpers (parity with host_screen / viewer_screen) ────────────

class _StatusMessage extends StatelessWidget {
  final Widget icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerticalControls extends StatelessWidget {
  final List<Widget> children;

  const _VerticalControls({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white24,
  });

  static const double _size = 30;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Icon(icon, color: Colors.white, size: 15),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _GiftSheet extends StatelessWidget {
  final ValueChanged<GiftModel> onGiftSelected;

  const _GiftSheet({required this.onGiftSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send a Gift',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: GiftModel.mockGifts.map((gift) {
                return GestureDetector(
                  onTap: () => onGiftSelected(gift),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white10,
                          child: Text(
                            gift.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gift.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${gift.coinCost} 🪙',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gift emoji only — pops in the middle, then flies into the host seat.
class _GiftFlyToHost extends StatefulWidget {
  final GiftModel gift;
  final GlobalKey hostSlotKey;

  const _GiftFlyToHost({
    required this.gift,
    required this.hostSlotKey,
  });

  @override
  State<_GiftFlyToHost> createState() => _GiftFlyToHostState();
}

class _GiftFlyToHostState extends State<_GiftFlyToHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final Animation<double> _pop = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fly = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.38, 1.0, curve: Curves.easeInOutCubic),
  );

  Offset? _hostCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveHostCenter());
  }

  void _resolveHostCenter() {
    if (_hostCenter != null || !mounted) return;
    final box =
        widget.hostSlotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        if (mounted) _resolveHostCenter();
      });
      return;
    }
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) return;
    final global = box.localToGlobal(box.size.center(Offset.zero));
    setState(() {
      _hostCenter = overlayBox.globalToLocal(global);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final start = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight * 0.40,
        );
        final end = _hostCenter ??
            Offset(constraints.maxWidth * 0.28, constraints.maxHeight * 0.22);

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _fly.value.clamp(0.0, 1.0);
            final arc = Offset(0, -48 * (4 * t * (1 - t)));
            final pos = Offset.lerp(start, end, t)! + arc;
            final popScale = 0.7 + (_pop.value.clamp(0.0, 1.0) * 0.35);
            final flyScale = 1.0 - (t * 0.45);
            final emojiOpacity = t < 0.88 ? 1.0 : (1.0 - (t - 0.88) / 0.12);
            const emojiSize = 64.0;
            const half = emojiSize / 2;

            return Stack(
              children: [
                Positioned(
                  left: pos.dx - half,
                  top: pos.dy - half,
                  child: Opacity(
                    opacity: emojiOpacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: popScale * flyScale,
                      child: Text(
                        widget.gift.emoji,
                        style: const TextStyle(fontSize: emojiSize, height: 1),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

