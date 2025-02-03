import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  final _chatService = ChatService();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск пользователей'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск по имени...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _chatService.searchUsers(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Ошибка: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!;
                final filteredUsers = users
                    .where((user) => user.uid != currentUser.uid)
                    .toList();

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.name[0]),
                      ),
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onTap: () async {
                        final chatId = await _chatService.createChat(
                          currentUser.uid,
                          user.uid,
                        );
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                otherUser: user,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 