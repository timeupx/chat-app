/// A single message in a live room's chat overlay.
class ChatMessageModel {
  final String id;
  final String username;
  final String message;
  final bool isSystemMessage;

  const ChatMessageModel({
    required this.id,
    required this.username,
    required this.message,
    this.isSystemMessage = false,
  });

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
