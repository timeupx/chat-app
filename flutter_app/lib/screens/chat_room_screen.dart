import 'package:flutter/material.dart';

/// Mock group-chat model. Will be replaced by API data once the backend
/// exposes a `/api/chat/rooms` (or similar) endpoint.
class _GroupChat {
  final String id;
  final String name;
  final String lastMessage;
  final String time;

  const _GroupChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
  });
}

const _mockGroups = [
  _GroupChat(
    id: 'g1',
    name: 'Flutter Devs BD',
    lastMessage: 'Rafi: Anyone tried the new Riverpod 3 codegen?',
    time: '09:41 AM',
  ),
  _GroupChat(
    id: 'g2',
    name: 'Family',
    lastMessage: 'Mom: Dinner at 8, don\'t be late!',
    time: 'Yesterday',
  ),
  _GroupChat(
    id: 'g3',
    name: 'Project Chat App',
    lastMessage: 'Sadia: Pushed the login screen, please review',
    time: 'Yesterday',
  ),
  _GroupChat(
    id: 'g4',
    name: 'Weekend Trip 🏖️',
    lastMessage: 'Tanvir: Booked the resort, sending link',
    time: 'Monday',
  ),
];

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Rooms')),
      body: ListView.separated(
        itemCount: _mockGroups.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final group = _mockGroups[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 24,
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              group.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              group.time,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupChatScreen(groupName: group.name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Placeholder screen for an individual group's chat thread.
class GroupChatScreen extends StatelessWidget {
  final String groupName;

  const GroupChatScreen({super.key, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: Center(child: Text('Group Chat: $groupName')),
    );
  }
}
