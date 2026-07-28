/// A single message in a live room's chat overlay.
class ChatMessageModel {
  final String id;
  final String username;
  final String message;
  final bool isSystemMessage;

  /// The sender's user id, so hosts can tap a name in the chat feed and
  /// moderate (ban/mute/warn/invite) without needing to find them in the
  /// separate Viewer List sheet. Empty for messages with no real sender
  /// (mocked gift lines, etc.) - moderation UI should treat that as
  /// "not actionable".
  final String userId;

  /// Matches the server-persisted viewer-join system line ("rana joined").
  static const joinedRoom = 'joined';

  const ChatMessageModel({
    required this.id,
    required this.username,
    required this.message,
    this.isSystemMessage = false,
    this.userId = '',
  });

  factory ChatMessageModel.fromHistory({
    required String id,
    required String username,
    required String message,
    String userId = '',
  }) {
    return ChatMessageModel(
      id: id,
      username: username,
      message: message,
      isSystemMessage: message == joinedRoom || message == 'entered the room',
      userId: userId,
    );
  }

  static const List<ChatMessageModel> mockMessages = [
    ChatMessageModel(
      id: 'm0',
      username: 'System',
      message: 'Welcome to the live room! 🎉',
      isSystemMessage: true,
    ),
    ChatMessageModel(id: 'm1', username: 'ayesha_r', message: 'Hi everyone! 👋'),
    ChatMessageModel(id: 'm2', username: 'tanvir.a', message: 'Great stream today!'),
    ChatMessageModel(
      id: 'm3',
      username: 'sadia_islam',
      message: 'Can you do a shoutout? 😄',
    ),
    ChatMessageModel(id: 'm4', username: 'rafi.hasan', message: 'Sent a Rose 🌹'),
  ];
}
