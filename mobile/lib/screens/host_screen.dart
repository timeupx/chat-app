import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/chat_message_model.dart';
import '../models/guest_request_model.dart';
import '../services/live_room_service.dart';
import '../services/livekit_service.dart';
import '../services/room_socket_service.dart';
import '../widgets/guest_requests_sheet.dart';
import '../widgets/room_entry_toast.dart';
import '../widgets/viewer_list_sheet.dart';

enum _HostStatus {
  requestingPermissions,
  connecting,
  live,
  permissionDenied,
  error,
}

/// Full-screen host broadcast view: local camera preview + flip camera /
/// mute / end-live controls. Publishing is handled entirely by
/// [LiveKitService] - this screen only reacts to its state.
class HostScreen extends StatefulWidget {
  final String roomName;

  const HostScreen({super.key, required this.roomName});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _liveKit = LiveKitService.instance;
  final _roomSocket = RoomSocketService.instance;
  final _liveRoomService = LiveRoomService();
  StreamSubscription<RoomEvent>? _eventsSub;
  StreamSubscription<List<GuestRequestModel>>? _guestRequestsSub;
  StreamSubscription<({String username, String message})>? _chatMessageSub;
  StreamSubscription<({String userId, String username})>? _userEnteredSub;

  _HostStatus _status = _HostStatus.requestingPermissions;
  String? _errorMessage;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  int _pendingGuestRequestCount = 0;
  String? _entryToastUsername;
  Timer? _entryToastTimer;

  // Chat was previously missing entirely from this screen - the host had
  // no way to see messages viewers were sending, even though the backend
  // was already broadcasting them to everyone in the room (host included).
  final _chatMessages = <ChatMessageModel>[];
  final _chatScrollController = ScrollController();
  final _chatInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _entryToastTimer?.cancel();
    _eventsSub?.cancel();
    _guestRequestsSub?.cancel();
    _chatMessageSub?.cancel();
    _userEnteredSub?.cancel();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    // Ensure camera/mic/socket are released even if the user backs out
    // without tapping "End Live".
    unawaited(_liveKit.disconnect());
    unawaited(_roomSocket.disconnect());
    super.dispose();
  }

  void _showEntryToast(String username) {
    _entryToastTimer?.cancel();
    setState(() => _entryToastUsername = username);
    _entryToastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _entryToastUsername = null);
    });
  }

  Future<void> _start() async {
    setState(() {
      _status = _HostStatus.requestingPermissions;
      _errorMessage = null;
    });

    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      if (!mounted) return;
      setState(() => _status = _HostStatus.permissionDenied);
      return;
    }

    if (!mounted) return;
    setState(() => _status = _HostStatus.connecting);

    try {
      await _liveKit.connect(
        roomName: widget.roomName,
        identity: 'host_${DateTime.now().millisecondsSinceEpoch}',
        role: LiveKitRole.host,
        displayName: 'Host',
      );

      _eventsSub = _liveKit.events.listen((event) {
        if (!mounted) return;
        // Rebuild once the camera track actually publishes, and if the
        // connection drops unexpectedly.
        if (event is LocalTrackPublishedEvent ||
            event is RoomDisconnectedEvent) {
          setState(() {});
        }
      });

      // Moderation (ban/mute/warn/invite/guest-requests) rides on a
      // separate Socket.io connection - independent from the LiveKit media
      // connection above.
      await _roomSocket.connectAndJoin(roomName: widget.roomName, role: 'host');
      _guestRequestsSub = _roomSocket.guestRequests.listen((requests) {
        if (mounted) {
          setState(() => _pendingGuestRequestCount = requests.length);
        }
      });

      // The fix for "host can't see viewer messages": the backend was
      // already broadcasting `chat:message` to everyone in the room
      // (including the host's own socket) - this screen just never
      // listened for it or rendered anything.
      _chatMessageSub = _roomSocket.chatMessage.listen((msg) {
        _addChatMessage(
          ChatMessageModel(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            username: msg.username,
            message: msg.message,
          ),
        );
      });
      _userEnteredSub = _roomSocket.userEntered.listen((event) {
        if (mounted) _showEntryToast(event.username);
      });
      await _loadChatHistory();

      if (!mounted) return;
      setState(() => _status = _HostStatus.live);
    } on LiveKitServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _HostStatus.error;
        _errorMessage = e.message;
      });
    } on RoomSocketException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _HostStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _endLive() async {
    await _endLiveOnBackend();
    await _liveKit.disconnect();
    await _roomSocket.disconnect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Flips the room's `isLive` flag back to false. Best-effort: a failure
  /// here shouldn't block the host from actually leaving the stream.
  Future<void> _endLiveOnBackend() async {
    try {
      await _liveRoomService.endLive(widget.roomName);
    } on LiveRoomException catch (e) {
      debugPrint('Failed to mark room offline: ${e.message}');
    }
  }

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

  /// Backfills the last 50 persisted messages so the host sees prior chat
  /// history immediately, same as viewers do. Non-fatal if it fails.
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

  void _addChatMessage(ChatMessageModel message) {
    if (!mounted) return;
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
    if (text.isEmpty) return;
    _roomSocket.sendChatMessage(text);
    _chatInputController.clear();
  }

  void _openViewerList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ViewerListSheet(),
    );
  }

  void _openGuestRequests() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const GuestRequestsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_endLiveOnBackend());
          unawaited(_liveKit.disconnect());
          unawaited(_roomSocket.disconnect());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildBody()),
              if (_status == _HostStatus.live)
                const Positioned(top: 12, left: 12, child: _LiveIndicator()),
              if (_status == _HostStatus.live)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildModerationButtons(),
                ),
              if (_status == _HostStatus.live)
                Positioned(
                  left: 12,
                  bottom: 100,
                  width: MediaQuery.of(context).size.width * 0.65,
                  height: 200,
                  child: _buildChatOverlay(),
                ),
              if (_status == _HostStatus.live)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: _buildControls(),
                ),
              if (_entryToastUsername != null)
                RoomEntryToast(username: _entryToastUsername!),
            ],
          ),
        ),
      ),
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
            child: _chatMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
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
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationButtons() {
    return Row(
      children: [
        _TopBarIconButton(
          icon: Icons.groups,
          tooltip: 'Viewers',
          onTap: _openViewerList,
        ),
        const SizedBox(width: 8),
        _TopBarIconButton(
          icon: Icons.front_hand,
          tooltip: 'Guest Requests',
          badgeCount: _pendingGuestRequestCount,
          onTap: _openGuestRequests,
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _HostStatus.requestingPermissions:
        return const _StatusMessage(
          icon: CircularProgressIndicator(color: Colors.white),
          message: 'Requesting camera & microphone access...',
        );
      case _HostStatus.connecting:
        return const _StatusMessage(
          icon: CircularProgressIndicator(color: Colors.white),
          message: 'Starting your live stream...',
        );
      case _HostStatus.permissionDenied:
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
          onAction: _start,
        );
      case _HostStatus.error:
        return _StatusMessage(
          icon: const Icon(
            Icons.error_outline,
            color: Colors.white70,
            size: 56,
          ),
          message: _errorMessage ?? 'Something went wrong.',
          actionLabel: 'Retry',
          onAction: _start,
        );
      case _HostStatus.live:
        final track = _liveKit.localVideoTrack;
        if (track == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
  }

  Widget _buildControls() {
    // Horizontally scrollable so 4 controls + the "End Live" button never
    // overflow on narrower phones; Center keeps them centered on wider ones.
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: Icons.flip_camera_ios,
              label: 'Flip',
              onTap: _flipCamera,
            ),
            const SizedBox(width: 20),
            _ControlButton(
              icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: _cameraEnabled ? 'Camera Off' : 'Camera On',
              onTap: _toggleCamera,
            ),
            const SizedBox(width: 20),
            _ControlButton(
              icon: _micEnabled ? Icons.mic : Icons.mic_off,
              label: _micEnabled ? 'Mute' : 'Unmute',
              onTap: _toggleMic,
            ),
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: _endLive,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.call_end),
              label: const Text(
                'End Live',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '🔴 LIVE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white24,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.black45,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            tooltip: tooltip,
            onPressed: onTap,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
