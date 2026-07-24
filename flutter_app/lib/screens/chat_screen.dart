import 'package:flutter/material.dart';

/// Mock 1-to-1 conversation model. Will be replaced by API data once the
/// backend exposes a conversations endpoint.
class _Conversation {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;

  const _Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });
}

const _mockConversations = [
  _Conversation(
    id: 'c1',
    name: 'Ayesha Rahman',
    lastMessage: 'See you at 6pm then!',
    time: '10:24 AM',
    unreadCount: 3,
  ),
  _Conversation(
    id: 'c2',
    name: 'Tanvir Ahmed',
    lastMessage: 'Sent the invoice, check your email',
    time: '09:02 AM',
  ),
  _Conversation(
    id: 'c3',
    name: 'Sadia Islam',
    lastMessage: 'Haha that\'s hilarious 😂',
    time: 'Yesterday',
    unreadCount: 1,
  ),
  _Conversation(
    id: 'c4',
    name: 'Rafi Hasan',
    lastMessage: 'You: Sounds good, talk soon',
    time: 'Yesterday',
  ),
  _Conversation(
    id: 'c5',
    name: 'Nusrat Jahan',
    lastMessage: 'Can you review my PR?',
    time: 'Monday',
    unreadCount: 12,
  ),
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ChatSearchDelegate(_mockConversations),
              );
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _mockConversations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return _ConversationTile(conversation: _mockConversations[index]);
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final _Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        child: Text(
          conversation.name.isNotEmpty
              ? conversation.name[0].toUpperCase()
              : '?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        conversation.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          color: hasUnread ? null : Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(conversation.time, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(userName: conversation.name),
          ),
        );
      },
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<void> {
  final List<_Conversation> conversations;

  _ChatSearchDelegate(this.conversations);

  List<_Conversation> _filter() {
    if (query.trim().isEmpty) return conversations;
    return conversations
        .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = _filter();
    if (results.isEmpty) {
      return const Center(child: Text('No conversations found'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => _ConversationTile(
        conversation: results[index],
      ),
    );
  }
}

/// Placeholder screen for an individual 1-to-1 chat thread.
class IndividualChatScreen extends StatelessWidget {
  final String userName;

  const IndividualChatScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(userName)),
      body: Center(child: Text('Chat with: $userName')),
    );
  }
}
