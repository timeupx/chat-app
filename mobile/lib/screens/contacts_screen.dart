import 'package:flutter/material.dart';

/// Mock contact/user model. Will be replaced by API data once the backend
/// exposes a `/api/user` search or listing endpoint.
class _Contact {
  final String id;
  final String name;
  final String username;

  const _Contact({required this.id, required this.name, required this.username});
}

const _mockContacts = [
  _Contact(id: 'u1', name: 'Ayesha Rahman', username: 'ayesha_r'),
  _Contact(id: 'u2', name: 'Tanvir Ahmed', username: 'tanvir.a'),
  _Contact(id: 'u3', name: 'Sadia Islam', username: 'sadia_islam'),
  _Contact(id: 'u4', name: 'Rafi Hasan', username: 'rafi.hasan'),
  _Contact(id: 'u5', name: 'Nusrat Jahan', username: 'nusrat_j'),
  _Contact(id: 'u6', name: 'Imran Khan', username: 'imran.k'),
  _Contact(id: 'u7', name: 'Farhana Akter', username: 'farhana_a'),
  _Contact(id: 'u8', name: 'Shakil Mahmud', username: 'shakil.m'),
];

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';
  final _addedIds = <String>{};

  List<_Contact> get _filteredContacts {
    if (_query.trim().isEmpty) return _mockContacts;
    final lowerQuery = _query.toLowerCase();
    return _mockContacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(lowerQuery) ||
              c.username.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? const Center(child: Text('No contacts found'))
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final isAdded = _addedIds.contains(contact.id);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(contact.name),
                        subtitle: Text('@${contact.username}'),
                        trailing: OutlinedButton(
                          onPressed: isAdded
                              ? null
                              : () {
                                  setState(() => _addedIds.add(contact.id));
                                },
                          child: Text(isAdded ? 'Added' : 'Add Friend'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
