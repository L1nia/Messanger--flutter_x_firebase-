import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
// ignore: unused_import
import '../models/user_model.dart';
import '../providers/theme_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser!;
    _nameController.text = user.name;
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя не может быть пустым')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<AuthService>().updateUserProfile(
            name: _nameController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изменения сохранены')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
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
        _isSaving = true;
      });

      final imageFile = File(pickedFile.path);
      final downloadUrl = await context.read<AuthService>().uploadAvatar(imageFile);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Аватар успешно обновлен')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка при обновлении аватара')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'Профиль',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveChanges,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _nameController.text = user.name;
                });
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Аватар и основная информация
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2AABEE),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      radius: 18,
                      child: IconButton(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.camera_alt, size: 18),
                        onPressed: _isSaving ? null : _pickAndUploadImage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Имя пользователя
          ListTile(
            tileColor: Theme.of(context).cardColor,
            title: _isEditing
                ? TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя',
                      border: const OutlineInputBorder(),
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      filled: true,
                    ),
                  )
                : Text(
                    user.name,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
            subtitle: Text(
              'Имя',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            leading: Icon(
              Icons.person,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).cardColor,
            title: Text(
              user.email,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Text(
              'Email',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            leading: Icon(
              Icons.email,
              color: Theme.of(context).iconTheme.color,
            ),
          ),

          const Divider(height: 32),

          // Настройки
          const Text(
            'Настройки',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Уведомления
          SwitchListTile(
            title: Text(
              'Уведомления',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            subtitle: Text(
              'Включить push-уведомления',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            secondary: Icon(
              Icons.notifications,
              color: Theme.of(context).iconTheme.color,
            ),
            value: true,
            onChanged: (bool value) {
              // TODO: Добавить обработку изменения
            },
          ),

          // Тема
          ListTile(
            title: const Text('Тёмная тема'),
            subtitle: const Text('Включить/выключить тёмную тему'),
            leading: const Icon(Icons.brightness_4),
            trailing: Switch(
              value: context.watch<ThemeProvider>().themeMode == ThemeMode.dark,
              onChanged: (bool value) {
                context.read<ThemeProvider>().setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
              },
            ),
          ),

          const Divider(height: 32),

          // Дополнительные действия
          ListTile(
            title: const Text('Удалить аккаунт'),
            leading: const Icon(Icons.delete_forever),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).dialogBackgroundColor,
                  title: Text(
                    'Удалить аккаунт?',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  content: Text(
                    'Это действие нельзя отменить. Все ваши данные будут удалены.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Отмена',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Добавить функционал удаления аккаунта
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Удалить',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 