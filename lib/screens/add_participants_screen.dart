import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

class AddParticipantsScreen extends StatefulWidget {
  final String chatId;

  const AddParticipantsScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends State<AddParticipantsScreen> {
  final _chatService = ChatService();
  final Set<String> _selectedUsers = {};
  String _searchQuery = '';

  Future<void> _addParticipants() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите участников для добавления')),
      );
      return;
    }

    try {
      await _chatService.addParticipantsToGroup(
        widget.chatId,
        _selectedUsers.toList(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участники успешно добавлены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить участников'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск пользователей',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _chatService.searchUsers(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!
                    .where((user) => user.uid != currentUser.uid)
                    .toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUsers.contains(user.uid);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUsers.add(user.uid);
                          } else {
                            _selectedUsers.remove(user.uid);
                          }
                        });
                      },
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      secondary: CircleAvatar(
                        child: Text(user.name[0]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addParticipants,
        label: const Text('Добавить'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
} 