import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
// ignore: unused_import
import '../models/group_chat_model.dart';
import 'login_screen.dart';
import 'search_users_screen.dart';
import 'chat_screen.dart';
import 'create_group_chat_screen.dart';
import 'group_chat_screen.dart';
import 'profile_screen.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final chatService = ChatService();

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user.name),
                accountEmail: Text(user.email),
                currentAccountPicture: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Закрываем drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF2AABEE),
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Создать группу'),
                onTap: () {
                  Navigator.pop(context); // Закрываем drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupChatScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Поиск пользователей'),
                onTap: () {
                  Navigator.pop(context); // Закрываем drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchUsersScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Профиль'),
                onTap: () {
                  Navigator.pop(context); // Закрываем drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  context.watch<ThemeProvider>().themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                title: Text(
                  context.watch<ThemeProvider>().themeMode == ThemeMode.dark
                      ? 'Тёмная тема'
                      : 'Светлая тема',
                ),
                trailing: IconButton(
                  icon: Icon(
                    context.watch<ThemeProvider>().themeMode == ThemeMode.dark
                        ? Icons.wb_sunny
                        : Icons.nightlight_round,
                  ),
                  onPressed: () {
                    final currentMode = context.read<ThemeProvider>().themeMode;
                    context.read<ThemeProvider>().setThemeMode(
                          currentMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                        );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Выйти',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  await context.read<AuthService>().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Чаты'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Личные'),
              Tab(text: 'Группы'),
            ],
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Личные чаты
            StreamBuilder<List<DocumentSnapshot>>(
              stream: chatService.getUserChats(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data!;

                if (chats.isEmpty) {
                  return const Center(
                    child: Text('У вас пока нет личных чатов'),
                  );
                }

                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final participants = List<String>.from(chat['participants']);
                    final otherUserId = participants.firstWhere((id) => id != user.uid);

                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(
                            title: Text('Загрузка...'),
                          );
                        }

                        final otherUser = userSnapshot.data!;
                        final unreadCount = (chat.data() as Map<String, dynamic>)['unreadCount'] as Map<String, dynamic>?;
                        final hasUnreadMessages = unreadCount != null && 
                            unreadCount[user.uid] != null && 
                            unreadCount[user.uid] > 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border(
                              left: BorderSide(
                                color: hasUnreadMessages 
                                    ? Theme.of(context).primaryColor 
                                    : Colors.transparent,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2AABEE),
                              child: Text(
                                otherUser['name'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              otherUser['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: chat['lastMessage'] != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      chat['lastMessage'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : null,
                            trailing: hasUnreadMessages
                                ? Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount[user.uid].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : chat['lastMessageTime'] != null
                                    ? Text(
                                        _formatTime(DateTime.parse(chat['lastMessageTime'])),
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chat.id,
                                    otherUser: UserModel.fromJson(otherUser.data()!),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            // Групповые чаты
            StreamBuilder<List<DocumentSnapshot>>(
              stream: chatService.getUserGroupChats(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groupChats = snapshot.data!;

                if (groupChats.isEmpty) {
                  return const Center(
                    child: Text('У вас пока нет групповых чатов'),
                  );
                }

                return ListView.separated(
                  itemCount: groupChats.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chat = groupChats[index].data() as Map<String, dynamic>;
                    final unreadCount = chat['unreadCount'] as Map<String, dynamic>?;
                    final hasUnreadMessages = unreadCount != null && 
                        unreadCount[user.uid] != null && 
                        unreadCount[user.uid] > 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(
                          left: BorderSide(
                            color: hasUnreadMessages 
                                ? Theme.of(context).primaryColor 
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2AABEE),
                          child: Text(
                            chat['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (chat['admins']?.contains(user.uid) == true)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                          ],
                        ),
                        subtitle: chat['lastMessage'] != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  chat['lastMessage'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        trailing: hasUnreadMessages
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount[user.uid].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : chat['lastMessageTime'] != null
                                ? Text(
                                    _formatTime(DateTime.parse(chat['lastMessageTime'])),
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(
                                chatId: chat['id'],
                                groupName: chat['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} д.';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч.';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин.';
    } else {
      return 'сейчас';
    }
  }
} 