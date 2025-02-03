import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
// ignore: unused_import
import 'group_chat_screen.dart';
import 'package:image_picker/image_picker.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _nameController = TextEditingController();
  final _chatService = ChatService();
  final Set<String> _selectedUsers = {};
  File? _selectedImage;
  bool _isLoading = false;
  String _searchQuery = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выбора изображения: $e')),
      );
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название группы')),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите участников группы')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = context.read<AuthService>().currentUser!;
      final participants = {..._selectedUsers, currentUser.uid};
      
      final chatId = await _chatService.createGroupChat(
        _nameController.text.trim(),
        participants.toList(),
        [currentUser.uid],
      );

      if (_selectedImage != null) {
        await _chatService.uploadGroupPhoto(chatId, _selectedImage!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Группа создана')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания группы: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать группу'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Фото группы
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : null,
                        child: _selectedImage == null
                            ? const Icon(
                                Icons.group,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Название группы
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название группы',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск пользователей...',
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
    );
  }
} 