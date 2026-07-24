import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/chat_message_model.dart';
import '../models/gift_model.dart';
import '../services/live_room_service.dart';
import '../services/livekit_service.dart';
import '../services/room_socket_service.dart';

enum _ViewerStatus { connecting, watching, error }

/// Full-screen viewer experience: remote host video, live chat overlay
/// (real, backed by [RoomSocketService]), gifts (still mocked - out of
/// scope for the moderation feature), and every moderation event a viewer
/// can be on the receiving end of: ban, chat-mute, warnings, and guest
/// invites/promotion.
class ViewerScreen extends StatefulWidget {
  final String roomName;
  final String hostName;

  const ViewerScreen({
    super.key,
    required this.roomName,
    required this.hostName,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _liveKit = LiveKitService.instance;
  final _roomSocket = RoomSocketService.instance;
  final _liveRoomService = LiveRoomService();

  StreamSubscription<RoomEvent>? _eventsSub;
  StreamSubscription<String>? _joinRejectedSub;
  StreamSubscription<String>? _bannedSub;
  StreamSubscription<bool>? _chatMuteSub;
  StreamSubscription<({String username, String message})>? _chatMessageSub;
  StreamSubscription<String>? _chatRejectedSub;
  StreamSubscription<String>? _warningSub;
  StreamSubscription<String>? _guestInvitedSub;
  StreamSubscription<void>? _guestInviteAcceptedSub;

  // The welcome system message is pre-seeded; the last 50 persisted
  // messages are backfilled by [_loadChatHistory], and every message from
  // then on arrives live over the socket (including the viewer's own,
  // echoed back by the server).
  final _chatMessages = [ChatMessageModel.mockMessages.first];
  final _chatScrollController = ScrollController();
  final _chatInputController = TextEditingController();

  _ViewerStatus _status = _ViewerStatus.connecting;
  String? _errorMessage;
  GiftModel? _flyingGift;

  bool _isChatMuted = false;
  bool _isGuest = false;
  bool _isBecomingGuest = false;
  bool _guestMicEnabled = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _joinRejectedSub?.cancel();
    _bannedSub?.cancel();
    _chatMuteSub?.cancel();
    _chatMessageSub?.cancel();
    _chatRejectedSub?.cancel();
    _warningSub?.cancel();
    _guestInvitedSub?.cancel();
    _guestInviteAcceptedSub?.cancel();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    unawaited(_liveKit.disconnect());
    unawaited(_roomSocket.disconnect());
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _status = _ViewerStatus.connecting;
      _errorMessage = null;
    });

    try {
      // Ban enforcement point #1: the backend rejects the LiveKit token
      // request outright if this user is banned from the room.
      await _liveKit.connect(
        roomName: widget.roomName,
        identity: 'viewer_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.viewer,
        displayName: 'Viewer',
      );

      _eventsSub = _liveKit.events.listen((event) {
        if (!mounted) return;
        // Rebuild when the host's video track arrives, when this viewer's
        // own guest camera publishes, or on disconnect.
        if (event is TrackSubscribedEvent ||
            event is ParticipantConnectedEvent ||
            event is LocalTrackPublishedEvent ||
            event is RoomDisconnectedEvent) {
          setState(() {});
        }
      });

      // Ban enforcement point #2: rejected here too if banned after the
      // LiveKit token was minted (e.g. banned while already connected,
      // trying to rejoin). Also the channel for chat/mute/warn/invite.
      await _roomSocket.connectAndJoin(roomName: widget.roomName, role: 'viewer');
      _registerRoomSocketListeners();
      await _loadChatHistory();

      if (!mounted) return;
      setState(() => _status = _ViewerStatus.watching);
    } on LiveKitServiceException catch (e) {
      await _handleUnrecoverableJoinFailure(e.message);
    } on RoomSocketException catch (e) {
      await _handleUnrecoverableJoinFailure(e.message);
    }
  }

  /// A join attempt can fail for two very different reasons, which need
  /// very different UX:
  ///  - "Room is full (50/50)" -> bounce back to the room list with a
  ///    SnackBar (per the capacity-check requirement), not a retry screen.
  ///  - Anything else (banned, network error, ...) -> show the normal
  ///    error state with a Retry button.
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
      _status = _ViewerStatus.error;
      _errorMessage = reason;
    });
  }

  /// Backfills the last 50 persisted messages (see `LiveMessage` on the
  /// backend) so a newly-joined viewer isn't staring at a blank chat feed.
  /// Non-fatal if it fails - live chat still works either way.
  Future<void> _loadChatHistory() async {
    try {
      final history = await _liveRoomService.getMessages(widget.roomName);
      if (!mounted || history.isEmpty) return;

      setState(() {
        for (var i = 0; i < history.length; i++) {
          _chatMessages.add(
            ChatMessageModel(
              id: 'hist_${i}_${DateTime.now().microsecondsSinceEpoch}',
              username: history[i].username,
              message: history[i].message,
            ),
          );
        }
      });
    } on LiveRoomException catch (e) {
      debugPrint('Failed to load chat history: ${e.message}');
    }
  }

  void _registerRoomSocketListeners() {
    _joinRejectedSub = _roomSocket.joinRejected.listen((reason) {
      _handleUnrecoverableJoinFailure(reason);
    });

    // Kicked out mid-stream by the host. Re-entry is blocked server-side
    // (the ban is persisted), so this dialog + pop is the end of the line.
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

    _chatMessageSub = _roomSocket.chatMessage.listen((msg) {
      _addChatMessage(
        ChatMessageModel(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          username: msg.username,
          message: msg.message,
        ),
      );
    });

    _chatRejectedSub = _roomSocket.chatRejected.listen((reason) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
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
    // either way, the next step is the same: reconnect as a publisher.
    _guestInviteAcceptedSub = _roomSocket.guestInviteAccepted.listen((_) {
      _becomeGuest();
    });
  }

  Future<void> _becomeGuest() async {
    if (!mounted || _isGuest) return;
    setState(() => _isBecomingGuest = true);

    try {
      await _liveKit.connect(
        roomName: widget.roomName,
        identity: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.guest,
        displayName: 'Guest',
      );
      if (!mounted) return;
      setState(() {
        _isGuest = true;
        _isBecomingGuest = false;
      });
    } on LiveKitServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isBecomingGuest = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join as guest: ${e.message}')));
    }
  }

  Future<void> _toggleGuestMic() async {
    final enabled = await _liveKit.toggleMicrophone();
    if (mounted) setState(() => _guestMicEnabled = enabled);
  }

  void _requestToBeGuest() {
    _roomSocket.requestToBeGuest();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request sent to the host.')));
  }

  void _addChatMessage(ChatMessageModel message) {
    setState(() => _chatMessages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
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
      builder: (_) => _GiftSheet(onGiftSelected: _sendGift),
    );
  }

  void _sendGift(GiftModel gift) {
    Navigator.of(context).pop(); // close the bottom sheet
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
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_liveKit.disconnect());
          unawaited(_roomSocket.disconnect());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildVideo()),
              Positioned(top: 8, left: 8, right: 8, child: _buildHostBar()),
              if (_isGuest) Positioned(top: 64, right: 12, child: _buildGuestSelfView()),
              Positioned(
                left: 12,
                right: 96,
                bottom: 16,
                height: 220,
                child: _buildChatOverlay(),
              ),
              Positioned(right: 16, bottom: 100, child: _buildGiftButton()),
              if (!_isGuest)
                Positioned(right: 16, bottom: 168, child: _buildRequestGuestButton()),
              if (_flyingGift != null) _GiftFlyAnimation(gift: _flyingGift!),
              if (_isBecomingGuest) const _BecomingGuestOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    switch (_status) {
      case _ViewerStatus.connecting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Joining live stream...', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      case _ViewerStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 56),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Could not join the stream.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _connect,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case _ViewerStatus.watching:
        final track = _liveKit.remoteHostVideoTrack;
        if (track == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Waiting for host video...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }
        return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
  }

  Widget _buildGuestSelfView() {
    final track = _liveKit.localVideoTrack;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 136,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (track != null)
                VideoTrackRenderer(track, fit: VideoViewFit.cover)
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _toggleGuestMic,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      _guestMicEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostBar() {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white24,
          child: Text(
            widget.hostName.isNotEmpty ? widget.hostName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.hostName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            await _liveKit.disconnect();
            await _roomSocket.disconnect();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildChatOverlay() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) => _ChatBubble(message: _chatMessages[index]),
            ),
          ),
          const SizedBox(height: 6),
          if (_isChatMuted)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'You are muted by the host',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white24,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGiftButton() {
    return FloatingActionButton.extended(
      heroTag: 'gift',
      onPressed: _openGiftSheet,
      backgroundColor: Colors.pinkAccent,
      icon: const Text('🎁', style: TextStyle(fontSize: 18)),
      label: const Text('Gift'),
    );
  }

  Widget _buildRequestGuestButton() {
    // Small icon-only FAB with a tooltip, not the full-width extended
    // button - this is a secondary action and shouldn't compete visually
    // with the primary Gift button right above it.
    return Tooltip(
      message: 'Request to be Guest',
      child: FloatingActionButton(
        heroTag: 'requestGuest',
        mini: true,
        onPressed: _requestToBeGuest,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.front_hand, size: 18),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.white),
          children: [
            if (!message.isSystemMessage)
              TextSpan(
                text: '${message.username}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
              ),
            TextSpan(
              text: message.message,
              style: TextStyle(
                color: message.isSystemMessage ? Colors.white70 : Colors.white,
                fontStyle: message.isSystemMessage ? FontStyle.italic : FontStyle.normal,
              ),
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: GiftModel.mockGifts.map((gift) {
                return GestureDetector(
                  onTap: () => onGiftSelected(gift),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white10,
                        child: Text(gift.emoji, style: const TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(height: 6),
                      Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${gift.coinCost} 🪙',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                      ),
                    ],
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

/// Big emoji that floats up and fades out - a lightweight stand-in for a
/// full gift animation, purely for UI testing.
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

class _BecomingGuestOverlay extends StatelessWidget {
  const _BecomingGuestOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Joining as guest...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
