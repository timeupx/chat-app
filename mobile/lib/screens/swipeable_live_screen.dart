import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/chat_message_model.dart';
import '../models/gift_model.dart';
import '../models/live_room_model.dart';
import '../services/live_room_service.dart';
import '../services/livekit_service.dart';
import '../services/room_socket_service.dart';
import '../widgets/room_entry_toast.dart';

/// Bigo-style vertical swipe feed of live rooms.
///
/// **Preview:** muted LiveKit video only — no socket join, no chat/buttons.
/// **Entered:** tap the preview to unmute, join the room socket, and reveal
/// the full interactive UI. Swiping away tears everything down and starts
/// a fresh muted preview for the next room.
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

  /// `false` = muted preview (no socket). `true` = fully joined.
  bool _hasEntered = false;
  bool _isConnectingPreview = false;
  bool _isEntering = false;
  String? _previewError;

  StreamSubscription<RoomEvent>? _eventsSub;
  StreamSubscription<String>? _joinRejectedSub;
  StreamSubscription<String>? _bannedSub;
  StreamSubscription<bool>? _chatMuteSub;
  StreamSubscription<({String username, String message})>? _chatMessageSub;
  StreamSubscription<String>? _chatRejectedSub;
  StreamSubscription<String>? _warningSub;
  StreamSubscription<({String userId, String username})>? _userEnteredSub;

  final _chatMessages = <ChatMessageModel>[];
  final _chatScrollController = ScrollController();
  final _chatInputController = TextEditingController();

  bool _isChatMuted = false;
  GiftModel? _flyingGift;
  String? _entryToastUsername;
  Timer? _entryToastTimer;

  /// Generation counter so stale async preview/enter work is ignored after
  /// a swipe or dispose.
  int _sessionGeneration = 0;

  LiveRoomModel get _currentRoom => widget.rooms[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.rooms.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _startPreview();
  }

  @override
  void dispose() {
    _entryToastTimer?.cancel();
    _cancelSubs();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _pageController.dispose();
    unawaited(_liveKit.disconnect());
    unawaited(_roomSocket.disconnect());
    super.dispose();
  }

  void _cancelSubs() {
    _eventsSub?.cancel();
    _joinRejectedSub?.cancel();
    _bannedSub?.cancel();
    _chatMuteSub?.cancel();
    _chatMessageSub?.cancel();
    _chatRejectedSub?.cancel();
    _warningSub?.cancel();
    _userEnteredSub?.cancel();
    _eventsSub = null;
    _joinRejectedSub = null;
    _bannedSub = null;
    _chatMuteSub = null;
    _chatMessageSub = null;
    _chatRejectedSub = null;
    _warningSub = null;
    _userEnteredSub = null;
  }

  Future<void> _leaveCurrent() async {
    _sessionGeneration++;
    _cancelSubs();
    _entryToastTimer?.cancel();
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
      _entryToastUsername = null;
      _chatMessages.clear();
    });
  }

  Future<void> _onPageChanged(int index) async {
    if (index == _currentIndex) return;
    await _leaveCurrent();
    if (!mounted) return;
    setState(() => _currentIndex = index);
    await _startPreview();
  }

  /// Connect LiveKit as a muted viewer only — no socket join yet.
  Future<void> _startPreview() async {
    final generation = ++_sessionGeneration;
    final room = _currentRoom;

    setState(() {
      _isConnectingPreview = true;
      _previewError = null;
      _hasEntered = false;
    });

    try {
      await _liveKit.connect(
        roomName: room.id,
        identity: 'preview_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.viewer,
        displayName: 'Viewer',
      );

      if (!mounted || generation != _sessionGeneration) return;

      await _liveKit.setRemoteAudioMuted(true);

      _eventsSub = _liveKit.events.listen((event) {
        if (!mounted || generation != _sessionGeneration) return;
        if (event is TrackSubscribedEvent) {
          // Keep preview silent even if audio arrives after connect.
          if (!_hasEntered && event.track.kind == TrackType.AUDIO) {
            unawaited(event.track.disable());
          }
          setState(() {});
        } else if (event is ParticipantConnectedEvent ||
            event is RoomDisconnectedEvent) {
          setState(() {});
        }
      });

      if (!mounted || generation != _sessionGeneration) return;
      setState(() => _isConnectingPreview = false);
    } on LiveKitServiceException catch (e) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _isConnectingPreview = false;
        _previewError = e.message;
      });
    }
  }

  /// Fully enter: unmute audio, join socket, reveal chat/buttons.
  Future<void> _enterRoom() async {
    if (_hasEntered || _isEntering || _isConnectingPreview) return;
    if (_previewError != null) {
      await _startPreview();
      return;
    }
    if (!_liveKit.isConnected) {
      await _startPreview();
      if (!_liveKit.isConnected) return;
    }

    final generation = _sessionGeneration;
    final room = _currentRoom;

    setState(() => _isEntering = true);

    try {
      await _liveKit.setRemoteAudioMuted(false);
      await _roomSocket.connectAndJoin(roomName: room.id, role: 'viewer');

      if (!mounted || generation != _sessionGeneration) return;

      _registerEnteredListeners(generation);
      await _loadChatHistory(room.id);

      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _hasEntered = true;
        _isEntering = false;
      });
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
      Navigator.of(context).pop();
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
        ),
      );
    });

    _chatRejectedSub = _roomSocket.chatRejected.listen((reason) {
      if (!mounted || generation != _sessionGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
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

    _userEnteredSub = _roomSocket.userEntered.listen((event) {
      if (!mounted || generation != _sessionGeneration) return;
      _showEntryToast(event.username);
    });
  }

  void _showEntryToast(String username) {
    _entryToastTimer?.cancel();
    setState(() => _entryToastUsername = username);
    _entryToastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _entryToastUsername = null);
    });
  }

  Future<void> _loadChatHistory(String roomId) async {
    try {
      final history = await _liveRoomService.getMessages(roomId);
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
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: widget.rooms.length,
          onPageChanged: (index) => unawaited(_onPageChanged(index)),
          itemBuilder: (context, index) {
            final room = widget.rooms[index];
            final isCurrent = index == _currentIndex;
            return _SwipeRoomPage(
              room: room,
              isCurrent: isCurrent,
              hasEntered: isCurrent && _hasEntered,
              isConnectingPreview: isCurrent && _isConnectingPreview,
              isEntering: isCurrent && _isEntering,
              previewError: isCurrent ? _previewError : null,
              videoTrack: isCurrent ? _liveKit.remoteHostVideoTrack : null,
              chatMessages: isCurrent ? _chatMessages : const [],
              chatScrollController: _chatScrollController,
              chatInputController: _chatInputController,
              isChatMuted: _isChatMuted,
              flyingGift: isCurrent ? _flyingGift : null,
              entryToastUsername: isCurrent ? _entryToastUsername : null,
              onTapToEnter: _enterRoom,
              onClose: _close,
              onSendMessage: _sendMessage,
              onOpenGifts: _openGiftSheet,
            );
          },
        ),
      ),
    );
  }
}

class _SwipeRoomPage extends StatelessWidget {
  final LiveRoomModel room;
  final bool isCurrent;
  final bool hasEntered;
  final bool isConnectingPreview;
  final bool isEntering;
  final String? previewError;
  final VideoTrack? videoTrack;
  final List<ChatMessageModel> chatMessages;
  final ScrollController chatScrollController;
  final TextEditingController chatInputController;
  final bool isChatMuted;
  final GiftModel? flyingGift;
  final String? entryToastUsername;
  final VoidCallback onTapToEnter;
  final VoidCallback onClose;
  final VoidCallback onSendMessage;
  final VoidCallback onOpenGifts;

  const _SwipeRoomPage({
    required this.room,
    required this.isCurrent,
    required this.hasEntered,
    required this.isConnectingPreview,
    required this.isEntering,
    required this.previewError,
    required this.videoTrack,
    required this.chatMessages,
    required this.chatScrollController,
    required this.chatInputController,
    required this.isChatMuted,
    required this.flyingGift,
    required this.entryToastUsername,
    required this.onTapToEnter,
    required this.onClose,
    required this.onSendMessage,
    required this.onOpenGifts,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildVideoLayer()),
          // Preview: tap anywhere (except close) to fully enter.
          if (isCurrent && !hasEntered)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapToEnter,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _buildTopBar(),
          ),
          if (isCurrent && !hasEntered && previewError == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      room.roomName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isEntering
                            ? 'Entering...'
                            : isConnectingPreview
                                ? 'Loading preview...'
                                : 'Tap to enter',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasEntered) ...[
            Positioned(
              left: 12,
              right: 96,
              bottom: 16,
              height: 220,
              child: _buildChatOverlay(),
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
          ],
          if (flyingGift != null) _GiftFlyAnimation(gift: flyingGift!),
          if (entryToastUsername != null) RoomEntryToast(username: entryToastUsername!),
          if (isEntering)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (!isCurrent) {
      return CachedNetworkImage(
        imageUrl: room.roomImage,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(color: Colors.black),
      );
    }

    if (previewError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                previewError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onTapToEnter,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (videoTrack != null) {
      return VideoTrackRenderer(videoTrack!, fit: VideoViewFit.cover);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: room.roomImage,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(color: Colors.black),
        ),
        Container(color: Colors.black45),
        if (isConnectingPreview)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _buildTopBar() {
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
                  room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                room.roomName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        if (!hasEntered)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _PreviewBadge(),
          ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: onClose,
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
              controller: chatScrollController,
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      children: [
                        TextSpan(
                          text: '${message.username}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                        TextSpan(text: message.message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          if (isChatMuted)
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
                    controller: chatInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onSubmitted: (_) => onSendMessage(),
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
                  onPressed: onSendMessage,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PREVIEW',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                          Text(gift.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(
                            gift.name,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
    return Center(
      child: Text(gift.emoji, style: const TextStyle(fontSize: 72)),
    );
  }
}
