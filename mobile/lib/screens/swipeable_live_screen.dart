import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/chat_message_model.dart';
import '../models/gift_model.dart';
import '../models/guest_request_status.dart';
import '../models/live_room_model.dart';
import '../services/live_room_service.dart';
import '../services/livekit_service.dart';
import '../services/room_socket_service.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import '../widgets/live_room_chat.dart';
import '../widgets/multi_guest_stage.dart';
import 'live_room_screen.dart';

/// Full-screen vertical swipe feed opened from the Live room list.
///
/// Bigo-style: muted live video preview (no join chrome). Tap to enter
/// (sound + chat), or auto-enter after 10s. Swipe away resets to preview.
class SwipeableLiveScreen extends StatefulWidget {
  final List<LiveRoomModel> rooms;
  final int initialIndex;

  const SwipeableLiveScreen({
    super.key,
    required this.rooms,
    required this.initialIndex,
  });

  @override
  State<SwipeableLiveScreen> createState() => _SwipeableLiveScreenState();
}

class _SwipeableLiveScreenState extends State<SwipeableLiveScreen> {
  final _liveKit = LiveKitService.instance;
  final _roomSocket = RoomSocketService.instance;
  final _liveRoomService = LiveRoomService();

  late final PageController _pageController;
  late int _currentIndex;
  late List<LiveRoomModel> _rooms;
  String? _currentUserId;

  StreamSubscription<RoomEvent>? _eventsSub;
  StreamSubscription<String>? _joinRejectedSub;
  StreamSubscription<String>? _bannedSub;
  StreamSubscription<bool>? _chatMuteSub;
  StreamSubscription<
    ({String userId, String username, String message, bool isSystem})
  >?
  _chatMessageSub;
  StreamSubscription<String>? _chatRejectedSub;
  StreamSubscription<String>? _warningSub;
  StreamSubscription<String>? _guestInvitedSub;
  StreamSubscription<int?>? _guestInviteAcceptedSub;
  StreamSubscription<String>? _guestRequestRejectedSub;

  /// `false` = muted preview (no socket). `true` = fully joined.
  bool _hasEntered = false;
  bool _isConnectingPreview = false;
  bool _isEntering = false;
  String? _previewError;
  bool _isStartingLive = false;

  // Viewer -> co-host flow: request to be promoted to guest, or accept an
  // invite the host sent directly. Mirrors ViewerScreen's implementation.
  bool _isGuest = false;
  bool _isBecomingGuest = false;
  bool _guestMicEnabled = true;
  GuestRequestStatus _guestRequestStatus = GuestRequestStatus.none;
  Timer? _guestRequestResetTimer;

  /// True while the user is dragging/flinging the PageView. During this
  /// window we only show cover images — no LiveKit video — so the swipe
  /// stays smooth.
  bool _isScrolling = false;

  final _chatMessages = <ChatMessageModel>[];
  final _chatScrollController = ScrollController();
  final _chatInputController = TextEditingController();
  bool _isChatMuted = false;
  GiftModel? _flyingGift;
  Timer? _previewDebounce;
  Timer? _autoEnterTimer;
  Timer? _tapArmTimer;

  /// After a swipe/open, taps are ignored briefly so finger-up isn't treated
  /// as "enter". Bigo-style: silent preview, tap when armed, or auto 10s.
  bool _tapArmed = false;
  bool _pendingEnter = false;

  int _sessionGeneration = 0;

  static const _autoEnterDelay = Duration(seconds: 10);
  static const _tapArmDelay = Duration(milliseconds: 450);

  LiveRoomModel get _currentRoom => _rooms[_currentIndex];

  bool _isMine(LiveRoomModel room) =>
      room.hostId != null && room.hostId == _currentUserId;

  @override
  void initState() {
    super.initState();
    _rooms = List<LiveRoomModel>.from(widget.rooms);
    _currentIndex = widget.initialIndex.clamp(0, _rooms.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await SecureStorageHelper.getToken();
    if (token != null) {
      _currentUserId = decodeJwtPayload(token)?['userId'] as String?;
    }
    _armTap();
    if (mounted) await _startPreviewIfNeeded();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _autoEnterTimer?.cancel();
    _tapArmTimer?.cancel();
    _guestRequestResetTimer?.cancel();
    _cancelRoomSubs();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _pageController.dispose();
    // Do not disconnect LiveKit / room socket here. They are singletons and
    // LiveRoomScreen (host) may already own a fresh connection after
    // pushReplacement. Teardown happens in [_leaveCurrent], [_close], and
    // PopScope instead.
    super.dispose();
  }

  void _cancelRoomSubs() {
    _eventsSub?.cancel();
    _joinRejectedSub?.cancel();
    _bannedSub?.cancel();
    _chatMuteSub?.cancel();
    _chatMessageSub?.cancel();
    _chatRejectedSub?.cancel();
    _warningSub?.cancel();
    _guestInvitedSub?.cancel();
    _guestInviteAcceptedSub?.cancel();
    _guestRequestRejectedSub?.cancel();
    _eventsSub = null;
    _joinRejectedSub = null;
    _bannedSub = null;
    _chatMuteSub = null;
    _chatMessageSub = null;
    _chatRejectedSub = null;
    _warningSub = null;
    _guestInvitedSub = null;
    _guestInviteAcceptedSub = null;
    _guestRequestRejectedSub = null;
  }

  void _cancelAutoEnter() {
    _autoEnterTimer?.cancel();
    _autoEnterTimer = null;
  }

  void _disarmTap() {
    _tapArmTimer?.cancel();
    _tapArmTimer = null;
    _tapArmed = false;
    _pendingEnter = false;
  }

  void _armTap() {
    _tapArmTimer?.cancel();
    _tapArmed = false;
    _tapArmTimer = Timer(_tapArmDelay, () {
      if (!mounted || _isScrolling || _hasEntered) return;
      _tapArmed = true;
    });
  }

  void _scheduleAutoEnter() {
    _cancelAutoEnter();
    _autoEnterTimer = Timer(_autoEnterDelay, () {
      if (!mounted || _isScrolling || _hasEntered || _isEntering) return;
      unawaited(_enterRoom());
    });
  }

  void _onPreviewTap() {
    if (!_tapArmed || _isScrolling || _hasEntered || _isEntering) return;
    if (_isConnectingPreview || !_liveKit.isConnected) {
      // Preview still spinning up — enter as soon as it's ready.
      _pendingEnter = true;
      return;
    }
    unawaited(_enterRoom());
  }

  /// Drop the live session immediately (non-blocking) so the next swipe
  /// frame only paints cover images.
  void _dropSessionForSwipe() {
    _previewDebounce?.cancel();
    _cancelAutoEnter();
    _disarmTap();
    _sessionGeneration++;
    _cancelRoomSubs();
    unawaited(_liveKit.disconnect());
    unawaited(_roomSocket.disconnect());

    if (!mounted) return;
    if (_hasEntered ||
        _isConnectingPreview ||
        _isEntering ||
        _previewError != null ||
        _chatMessages.isNotEmpty) {
      setState(() {
        _hasEntered = false;
        _isConnectingPreview = false;
        _isEntering = false;
        _previewError = null;
        _isChatMuted = false;
        _flyingGift = null;
        _chatMessages.clear();
        _isGuest = false;
        _isBecomingGuest = false;
        _guestMicEnabled = true;
        _guestRequestResetTimer?.cancel();
        _guestRequestStatus = GuestRequestStatus.none;
      });
    }
  }

  Future<void> _leaveCurrent() async {
    _previewDebounce?.cancel();
    _cancelAutoEnter();
    _disarmTap();
    _sessionGeneration++;
    _cancelRoomSubs();
    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (!mounted) return;
    setState(() {
      _hasEntered = false;
      _isConnectingPreview = false;
      _isEntering = false;
      _previewError = null;
      _isChatMuted = false;
      _flyingGift = null;
      _chatMessages.clear();
      _isGuest = false;
      _isBecomingGuest = false;
      _guestMicEnabled = true;
      _guestRequestResetTimer?.cancel();
      _guestRequestStatus = GuestRequestStatus.none;
    });
  }

  void _onScrollStart() {
    if (_hasEntered || _isScrolling) return;
    _isScrolling = true;
    // Tear down video/audio right as the finger moves — awaiting disconnect
    // here was what made the PageView feel laggy.
    _dropSessionForSwipe();
  }

  void _onPageChanged(int index) {
    if (_hasEntered || index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  void _onScrollEnd() {
    if (_hasEntered) return;
    _isScrolling = false;
    _armTap();
    _previewDebounce?.cancel();
    // Short delay so a fast multi-swipe doesn't start connecting mid-fling.
    _previewDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || _isScrolling || _hasEntered) return;
      unawaited(_startPreviewIfNeeded());
    });
  }

  Future<void> _startPreviewIfNeeded() async {
    if (_isScrolling) return;
    final room = _currentRoom;
    if (_isMine(room)) return;

    if (!room.isLive) {
      if (_hasEntered ||
          _isConnectingPreview ||
          _isEntering ||
          _previewError != null) {
        setState(() {
          _hasEntered = false;
          _isConnectingPreview = false;
          _isEntering = false;
          _previewError = null;
        });
      }
      return;
    }

    await _startPreview(room);
  }

  /// Muted LiveKit video only — no socket, no chat yet.
  Future<void> _startPreview(LiveRoomModel room) async {
    if (_isScrolling) return;
    final generation = ++_sessionGeneration;
    _cancelAutoEnter();

    setState(() {
      _isConnectingPreview = true;
      _isEntering = false;
      _hasEntered = false;
      _previewError = null;
      _chatMessages.clear();
    });

    try {
      // Backend LiveKit identity == account userId (not the client-supplied
      // `preview_...` / `host_...` string). Pin the host id so
      // remoteHostVideoTrack can find their publisher.
      if (room.hostId != null && room.hostId!.isNotEmpty) {
        _liveKit.knownHostUserId = room.hostId;
      }

      await _liveKit.connect(
        roomName: room.id,
        identity: 'preview_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.viewer,
        displayName: 'Viewer',
      );

      if (!mounted || generation != _sessionGeneration || _isScrolling) {
        await _liveKit.disconnect();
        return;
      }

      await _liveKit.setRemoteAudioMuted(true);

      _eventsSub = _liveKit.events.listen((event) {
        if (!mounted || generation != _sessionGeneration || _isScrolling)
          return;
        if (event is TrackSubscribedEvent) {
          // Keep preview silent even if audio arrives after connect.
          if (!_hasEntered && event.track.kind == TrackType.AUDIO) {
            unawaited(event.track.disable());
          }
          setState(() {});
        } else if (event is ParticipantConnectedEvent ||
            event is ParticipantDisconnectedEvent ||
            event is RoomDisconnectedEvent ||
            event is LocalTrackPublishedEvent ||
            event is TrackUnsubscribedEvent) {
          // Also covers guest tiles appearing/disappearing in the
          // multi-guest grid, both during preview and after entering.
          setState(() {});
        }
      });

      if (!mounted || generation != _sessionGeneration || _isScrolling) {
        await _liveKit.disconnect();
        return;
      }

      setState(() => _isConnectingPreview = false);
      _scheduleAutoEnter();
      _armTap();
      if (_pendingEnter) {
        _pendingEnter = false;
        unawaited(_enterRoom());
      }
    } on LiveKitServiceException catch (e) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _isConnectingPreview = false;
        _previewError = e.message;
      });
    }
  }

  /// Fully enter: unmute audio, join socket, reveal chat.
  /// Triggered by tap (when armed) or the silent 10s auto-enter timer.
  Future<void> _enterRoom() async {
    if (_hasEntered || _isEntering || _isScrolling) return;
    if (_isConnectingPreview || !_liveKit.isConnected) {
      _pendingEnter = true;
      if (!_isConnectingPreview && _previewError == null) {
        unawaited(_startPreviewIfNeeded());
      }
      return;
    }
    _cancelAutoEnter();
    _pendingEnter = false;

    if (_previewError != null) {
      await _startPreviewIfNeeded();
      return;
    }

    final generation = _sessionGeneration;
    final room = _currentRoom;
    if (_isMine(room) || !room.isLive) return;

    setState(() => _isEntering = true);

    try {
      await _liveKit.setRemoteAudioMuted(false);

      await _roomSocket.connectAndJoin(roomName: room.id, role: 'viewer');
      if (!mounted || generation != _sessionGeneration || _isScrolling) {
        await _roomSocket.disconnect();
        return;
      }

      _registerEnteredListeners(generation);

      setState(() {
        _hasEntered = true;
        _isEntering = false;
      });
      unawaited(_loadChatHistory(room.id));
    } on LiveKitServiceException catch (e) {
      await _handleEnterFailure(e.message, generation);
    } on RoomSocketException catch (e) {
      await _handleEnterFailure(e.message, generation);
    }
  }

  Future<void> _handleEnterFailure(String reason, int generation) async {
    await _roomSocket.disconnect();
    if (!mounted || generation != _sessionGeneration) return;

    if (reason.contains('Room is full')) {
      final messenger = ScaffoldMessenger.of(context);
      await _close();
      messenger.showSnackBar(SnackBar(content: Text(reason)));
      return;
    }

    setState(() {
      _isEntering = false;
      _previewError = reason;
    });
  }

  void _registerEnteredListeners(int generation) {
    _joinRejectedSub = _roomSocket.joinRejected.listen((reason) {
      _handleEnterFailure(reason, generation);
    });

    _bannedSub = _roomSocket.banned.listen((reason) async {
      if (!mounted || generation != _sessionGeneration) return;
      await _leaveCurrent();
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
      if (mounted) await _close();
    });

    _chatMuteSub = _roomSocket.chatMuteState.listen((muted) {
      if (mounted && generation == _sessionGeneration) {
        setState(() => _isChatMuted = muted);
      }
    });

    _chatMessageSub = _roomSocket.chatMessage.listen((msg) {
      if (!mounted || generation != _sessionGeneration) return;
      _addChatMessage(
        ChatMessageModel(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          username: msg.username,
          message: msg.message,
          isSystemMessage: msg.isSystem,
        ),
      );
    });

    _chatRejectedSub = _roomSocket.chatRejected.listen((reason) {
      if (!mounted || generation != _sessionGeneration) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
    });

    _warningSub = _roomSocket.warning.listen((reason) {
      if (!mounted || generation != _sessionGeneration) return;
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

    // Host directly invited this viewer to co-host.
    _guestInvitedSub = _roomSocket.guestInvited.listen((hostName) {
      if (!mounted || generation != _sessionGeneration) return;
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
                _roomSocket.acceptGuestInvite();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    });

    // Fires both when the host accepts this viewer's own "request to be
    // guest", and as the ack right after this viewer accepts an invite -
    // either way, enable local publish without dropping host video.
    _guestInviteAcceptedSub = _roomSocket.guestInviteAccepted.listen((_) {
      _guestRequestResetTimer?.cancel();
      if (mounted)
        setState(() => _guestRequestStatus = GuestRequestStatus.none);
      if (generation == _sessionGeneration) unawaited(_becomeGuest(generation));
    });

    // The host declined this viewer's "request to be guest" (or the guest
    // cap is full) - show "Rejected" for a bit, then let them try again.
    _guestRequestRejectedSub = _roomSocket.guestRequestRejected.listen((
      reason,
    ) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() => _guestRequestStatus = GuestRequestStatus.rejected);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      _guestRequestResetTimer?.cancel();
      _guestRequestResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && generation == _sessionGeneration) {
          setState(() => _guestRequestStatus = GuestRequestStatus.none);
        }
      });
    });
  }

  Future<void> _becomeGuest(int generation) async {
    if (!mounted || _isGuest || _isBecomingGuest) return;
    // Guest UI immediately — no full-screen "Joining as guest..." wait.
    setState(() {
      _isBecomingGuest = true;
      _isGuest = true;
    });

    try {
      // Soft promote keeps host remote video; only local cam/mic come up.
      await _liveKit.promoteToGuest(
        roomName: _currentRoom.id,
        identity: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Guest',
      );
      if (!mounted || generation != _sessionGeneration) return;
      setState(() => _isBecomingGuest = false);
    } on LiveKitServiceException catch (e) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _isBecomingGuest = false;
        _isGuest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join as guest: ${e.message}')),
      );
    }
  }

  void _requestToBeGuest() {
    // Guard against the button being spammed - one request is enough; the
    // button itself flips to a disabled "Requested" state so there's no
    // need (or way) to fire another until the host responds.
    if (_guestRequestStatus != GuestRequestStatus.none) return;
    _guestRequestResetTimer?.cancel();
    _roomSocket.requestToBeGuest();
    setState(() => _guestRequestStatus = GuestRequestStatus.pending);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request sent to the host.')));
  }

  Future<void> _toggleGuestMic() async {
    final enabled = await _liveKit.toggleMicrophone();
    if (mounted) setState(() => _guestMicEnabled = enabled);
  }

  Future<void> _loadChatHistory(String roomId) async {
    final generation = _sessionGeneration;
    try {
      final history = await _liveRoomService.getMessages(roomId);
      if (!mounted ||
          history.isEmpty ||
          generation != _sessionGeneration ||
          _isScrolling) {
        return;
      }
      setState(() {
        for (var i = 0; i < history.length; i++) {
          _chatMessages.add(
            ChatMessageModel.fromHistory(
              id: 'hist_${i}_${DateTime.now().microsecondsSinceEpoch}',
              username: history[i].username,
              message: history[i].message,
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
    setState(() => _chatMessages.add(message));
    _scrollChatToBottom();
  }

  /// Jumps the chat list to the newest message - used both for live
  /// messages as they arrive and right after history backfills, so the
  /// feed never gets "stuck" showing old messages above the fold.
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
    if (text.isEmpty || _isChatMuted) return;
    _roomSocket.sendChatMessage(text);
    _chatInputController.clear();
  }

  void _openGiftSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftSheet(
        onGiftSelected: (gift) {
          Navigator.of(context).pop();
          _addChatMessage(
            ChatMessageModel(
              id: 'gift_${DateTime.now().microsecondsSinceEpoch}',
              username: 'You',
              message: 'sent a ${gift.name} ${gift.emoji}',
            ),
          );
          setState(() => _flyingGift = gift);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _flyingGift = null);
          });
        },
      ),
    );
  }

  Future<void> _close() async {
    await _leaveCurrent();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _goLiveAsHost(LiveRoomModel room) async {
    if (_isStartingLive) return;
    setState(() => _isStartingLive = true);
    try {
      final detail = await _liveRoomService.getRoomDetail(room.id);
      if (!mounted) return;
      if (detail.isHost != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only the room host can go live.')),
        );
        return;
      }
      if (!detail.isLive) {
        await _liveRoomService.goLive(room.id);
      }
      if (!mounted) return;
      // Release the viewer socket before LiveRoomScreen (host) connects.
      // dispose() must NOT disconnect again (see dispose) or it will kill
      // the host's chat.
      await _leaveCurrent();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(
            roomName: room.id,
            role: LiveRoomRole.host,
            initialFilterName: detail.filterName,
            initialSlotCount: detail.slotCount,
          ),
        ),
      );
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isStartingLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_leaveCurrent());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // After enter, PageView is locked — ignore swipe teardown.
            if (_hasEntered) return false;
            // Only the PageView itself (not nested chat list, etc.).
            if (notification.depth != 0) return false;
            if (notification is ScrollStartNotification) {
              _onScrollStart();
            } else if (notification is ScrollEndNotification) {
              _onScrollEnd();
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // Bigo-style: browsing is swipeable; once you enter a room,
            // lock to that page until back/close.
            physics: _hasEntered
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(parent: ClampingScrollPhysics()),
            itemCount: _rooms.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final room = _rooms[index];
              final isCurrent = index == _currentIndex;
              // During a swipe, never mount LiveKit video — cover image only.
              // While settled, show muted preview video even before full enter.
              final showVideo =
                  isCurrent &&
                  !_isScrolling &&
                  !_isMine(room) &&
                  room.isLive &&
                  (_isConnectingPreview ||
                      _isEntering ||
                      _hasEntered ||
                      _liveKit.remoteHostVideoTrack != null) &&
                  _previewError == null;

              return RepaintBoundary(
                child: _SwipeRoomPage(
                  room: room,
                  isMine: _isMine(room),
                  isCurrent: isCurrent,
                  hasEntered: isCurrent && !_isScrolling && _hasEntered,
                  isStartingLive: isCurrent && _isStartingLive,
                  previewError: isCurrent && !_isScrolling
                      ? _previewError
                      : null,
                  videoTrack: showVideo ? _liveKit.remoteHostVideoTrack : null,
                  guestVideoTiles: showVideo
                      ? _liveKit.remoteGuestVideoTiles
                      : const [],
                  chatMessages: isCurrent && _hasEntered
                      ? _chatMessages
                      : const [],
                  chatScrollController: _chatScrollController,
                  chatInputController: _chatInputController,
                  isChatMuted: _isChatMuted,
                  flyingGift: isCurrent && _hasEntered ? _flyingGift : null,
                  isGuest: isCurrent && _hasEntered && _isGuest,
                  guestMicEnabled: _guestMicEnabled,
                  guestVideoTrack: isCurrent && _isGuest
                      ? _liveKit.localVideoTrack
                      : null,
                  guestRequestStatus: isCurrent
                      ? _guestRequestStatus
                      : GuestRequestStatus.none,
                  onClose: _close,
                  onTapToEnter: _onPreviewTap,
                  onRetry: () => _startPreviewIfNeeded(),
                  onGoLive: () => _goLiveAsHost(room),
                  onSendMessage: _sendMessage,
                  onOpenGifts: _openGiftSheet,
                  onRequestGuest: _requestToBeGuest,
                  onToggleGuestMic: _toggleGuestMic,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SwipeRoomPage extends StatelessWidget {
  final LiveRoomModel room;
  final bool isMine;
  final bool isCurrent;
  final bool hasEntered;
  final bool isStartingLive;
  final String? previewError;
  final VideoTrack? videoTrack;
  final List<
    ({String identity, String name, RemoteVideoTrack track, bool micEnabled})
  >
  guestVideoTiles;
  final List<ChatMessageModel> chatMessages;
  final ScrollController chatScrollController;
  final TextEditingController chatInputController;
  final bool isChatMuted;
  final GiftModel? flyingGift;
  final bool isGuest;
  final bool guestMicEnabled;
  final VideoTrack? guestVideoTrack;
  final GuestRequestStatus guestRequestStatus;
  final VoidCallback onClose;
  final VoidCallback onTapToEnter;
  final VoidCallback onRetry;
  final VoidCallback onGoLive;
  final VoidCallback onSendMessage;
  final VoidCallback onOpenGifts;
  final VoidCallback onRequestGuest;
  final VoidCallback onToggleGuestMic;

  const _SwipeRoomPage({
    required this.room,
    required this.isMine,
    required this.isCurrent,
    required this.hasEntered,
    required this.isStartingLive,
    required this.previewError,
    required this.videoTrack,
    required this.guestVideoTiles,
    required this.chatMessages,
    required this.chatScrollController,
    required this.chatInputController,
    required this.isChatMuted,
    required this.flyingGift,
    required this.isGuest,
    required this.guestMicEnabled,
    required this.guestVideoTrack,
    required this.guestRequestStatus,
    required this.onClose,
    required this.onTapToEnter,
    required this.onRetry,
    required this.onGoLive,
    required this.onSendMessage,
    required this.onOpenGifts,
    required this.onRequestGuest,
    required this.onToggleGuestMic,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Video / cover image
          Positioned.fill(child: _buildBackground()),

          // 2) Transparent Flutter layer above LiveKit/platform video so
          //    vertical drags reach the parent PageView.
          const Positioned.fill(child: ColoredBox(color: Color(0x01000000))),

          // 3) Bigo-style: tap the preview to enter (armed after swipe settles).
          //    No "Loading preview" / "Enter" chrome — just the live feed.
          if (isCurrent &&
              !isMine &&
              room.isLive &&
              !hasEntered &&
              previewError == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onTapToEnter,
              ),
            ),

          // 4) Chrome
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _TopBar(room: room, onClose: onClose),
          ),
          if (isCurrent && isMine)
            _OwnRoomOverlay(
              room: room,
              isStartingLive: isStartingLive,
              onGoLive: onGoLive,
            )
          else if (isCurrent && !room.isLive)
            const _OfflineOverlay()
          else if (isCurrent && previewError != null)
            _ErrorOverlay(message: previewError!, onRetry: onRetry)
          else if (isCurrent && hasEntered) ...[
            Positioned(
              left: 12,
              right: 96,
              bottom: 16,
              child: LiveRoomChat(
                messages: chatMessages,
                scrollController: chatScrollController,
                inputController: chatInputController,
                isMuted: isChatMuted,
                onSend: onSendMessage,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton.extended(
                heroTag: 'gift_${room.id}',
                onPressed: onOpenGifts,
                backgroundColor: Colors.pinkAccent,
                icon: const Text('🎁', style: TextStyle(fontSize: 18)),
                label: const Text('Gift'),
              ),
            ),
            if (!isGuest)
              Positioned(
                right: 16,
                bottom: 168,
                child: _GuestRequestButton(
                  status: guestRequestStatus,
                  onPressed: onRequestGuest,
                ),
              ),
            // The guest's own video now lives inline in the split-screen
            // grid (see _buildBackground) - this is just the interactive
            // mic toggle, placed above the gesture-passthrough layer so it
            // actually receives taps (a video tile embedded in that layer
            // can't be, on web).
            if (isGuest)
              Positioned(
                top: 64,
                right: 12,
                child: GestureDetector(
                  onTap: onToggleGuestMic,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      guestMicEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ] else if (isCurrent && room.isLive && !isMine)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: IgnorePointer(child: _PreviewInfo(room: room)),
            ),
          if (flyingGift != null) _GiftFlyAnimation(gift: flyingGift!),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (isCurrent && videoTrack != null && room.isLive && !isMine) {
      // Bigo-style multi-guest grid: host's tile stays the biggest one on
      // screen, with any accepted/invited guests - including this
      // viewer's own tile once *they* become a guest - filling in around
      // it. All video textures are IgnorePointer'd so swipes keep
      // reaching the PageView.
      return MultiGuestStage(
        hostTile: IgnorePointer(
          child: VideoTrackRenderer(videoTrack!, fit: VideoViewFit.cover),
        ),
        guestTiles: [
          // No `trailing` control here on purpose: this whole layer sits
          // *below* the transparent gesture-passthrough ColoredBox (see
          // the comment in build()), so anything interactive placed here
          // would silently never receive taps. The mic toggle lives as a
          // separate Positioned button above that layer instead.
          if (isGuest)
            ParticipantVideoTile(
              key: const ValueKey('self_guest_tile'),
              track: guestVideoTrack,
              label: 'You',
            ),
          for (final guest in guestVideoTiles)
            ParticipantVideoTile(
              key: ValueKey(guest.identity),
              track: guest.track,
              label: guest.name.isNotEmpty ? guest.name : 'Guest',
            ),
        ],
      );
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: room.roomImage,
            fit: BoxFit.cover,
            memCacheWidth: 720,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => Container(color: Colors.grey.shade900),
            errorWidget: (_, _, _) => Container(
              color: Colors.grey.shade900,
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.white38,
                size: 48,
              ),
            ),
          ),
          if (!room.isLive)
            Container(color: Colors.black.withValues(alpha: 0.45)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final LiveRoomModel room;
  final VoidCallback onClose;

  const _TopBar({required this.room, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white24,
          backgroundImage: room.hostPhoto != null && room.hostPhoto!.isNotEmpty
              ? CachedNetworkImageProvider(room.hostPhoto!)
              : null,
          child: room.hostPhoto == null || room.hostPhoto!.isEmpty
              ? Text(
                  room.hostName.isNotEmpty
                      ? room.hostName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.hostName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                room.roomName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        if (room.isLive)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _PreviewInfo extends StatelessWidget {
  final LiveRoomModel room;

  const _PreviewInfo({required this.room});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          room.roomName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '@${room.hostName}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
            SizedBox(width: 4),
            Text(
              'Swipe for next room',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Request to be Guest" as a one-shot action: once tapped it flips to a
/// disabled "Requested" state (no more spamming the host), and if the host
/// declines it briefly shows "Rejected" before resetting so they can try
/// again.
class _GuestRequestButton extends StatelessWidget {
  final GuestRequestStatus status;
  final VoidCallback onPressed;

  const _GuestRequestButton({required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, enabled) = switch (status) {
      GuestRequestStatus.none => (
        'Request to be Guest',
        Icons.front_hand,
        Colors.blueAccent,
        true,
      ),
      GuestRequestStatus.pending => (
        'Requested',
        Icons.hourglass_top,
        Colors.grey,
        false,
      ),
      GuestRequestStatus.rejected => (
        'Rejected',
        Icons.block,
        Colors.redAccent,
        false,
      ),
    };

    return Material(
      color: color,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnRoomOverlay extends StatelessWidget {
  final LiveRoomModel room;
  final bool isStartingLive;
  final VoidCallback onGoLive;

  const _OwnRoomOverlay({
    required this.room,
    required this.isStartingLive,
    required this.onGoLive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim is visual-only so vertical swipes still reach PageView.
        IgnorePointer(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
        ),
        // Keep hit targets compact — a full-screen Column steals swipes.
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IgnorePointer(
                  child: Column(
                    children: [
                      Text(
                        room.roomName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.isLive
                            ? 'Your room is live — resume broadcasting'
                            : 'This is your room',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isStartingLive ? null : onGoLive,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.redAccent,
                  ),
                  child: isStartingLive
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(room.isLive ? 'RESUME LIVE' : 'GO LIVE'),
                ),
                const SizedBox(height: 16),
                const IgnorePointer(
                  child: Text(
                    'Swipe up to browse other rooms',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white70, size: 48),
            SizedBox(height: 12),
            Text(
              'Host has not started yet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Swipe for another room',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorOverlay({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IgnorePointer(
              child: Icon(Icons.error_outline, color: Colors.white70, size: 48),
            ),
            const SizedBox(height: 12),
            IgnorePointer(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftSheet extends StatelessWidget {
  final ValueChanged<GiftModel> onGiftSelected;

  const _GiftSheet({required this.onGiftSelected});

  @override
  Widget build(BuildContext context) {
    final gifts = GiftModel.mockGifts;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send a Gift',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: gifts
                .map(
                  (gift) => InkWell(
                    onTap: () => onGiftSelected(gift),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            gift.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gift.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GiftFlyAnimation extends StatelessWidget {
  final GiftModel gift;

  const _GiftFlyAnimation({required this.gift});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Positioned(
          right: 24,
          bottom: 100 + value * 260,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - value).clamp(0.0, 1.0),
              child: Transform.scale(scale: 1 + value * 0.5, child: child),
            ),
          ),
        );
      },
      child: Text(gift.emoji, style: const TextStyle(fontSize: 48)),
    );
  }
}
