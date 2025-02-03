import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'add_participants_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/message_status.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class GroupChatScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final Map<String, UserModel> _usersCache = {};
  bool _isScreenFocused = true;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final currentUser = context.read<AuthService>().currentUser!;
    _chatService.updateGroupUnreadCount(widget.chatId, currentUser.uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isScreenFocused = state == AppLifecycleState.resumed;
    });

    if (_isScreenFocused) {
      final currentUser = context.read<AuthService>().currentUser!;
      _chatService.updateGroupUnreadCount(widget.chatId, currentUser.uid);
    }
  }

  void _updateReadStatus() {
    if (_isScreenFocused) {
      final currentUser = context.read<AuthService>().currentUser!;
      _chatService.updateGroupUnreadCount(widget.chatId, currentUser.uid);
    }
  }

  Future<UserModel?> _getUser(String userId) async {
    if (_usersCache.containsKey(userId)) {
      return _usersCache[userId];
    }
    final user = await _chatService.getUser(userId);
    if (user != null) {
      _usersCache[userId] = user;
    }
    return user;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        _sendMessage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выбора изображения: $e')),
      );
    }
  }

  Future<void> _handlePaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text?.startsWith('data:image') == true) {
        final base64Image = clipboardData!.text!.split(',')[1];
        final bytes = base64Decode(base64Image);
        
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/pasted_image.jpg');
        await file.writeAsBytes(bytes);
        
        setState(() {
          _selectedImage = file;
        });
        _sendMessage();
      }
    } catch (e) {
      print('Error handling paste: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось вставить изображение. Попробуйте использовать кнопку прикрепления файла.'),
        ),
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;

    final currentUser = context.read<AuthService>().currentUser!;
    _chatService.sendGroupMessage(
      widget.chatId,
      currentUser.uid,
      _messageController.text.trim(),
      imageFile: _selectedImage,
    );
    
    _messageController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Row(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _chatService.getGroupChatStream(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final photoUrl = data['photoUrl'] as String?;

                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          widget.groupName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              widget.groupName,
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
        actions: [
          FutureBuilder<bool>(
            future: _chatService.isGroupAdmin(widget.chatId, context.read<AuthService>().currentUser!.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Добавить участников'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddParticipantsScreen(
                              chatId: widget.chatId,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Text(
                        'Удалить группу',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить группу'),
                            content: const Text(
                              'Вы уверены, что хотите удалить эту группу? '
                              'Это действие нельзя отменить.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await _chatService.deleteGroupChat(widget.chatId);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Группа удалена')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).pop();
          },
        },
        child: Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _updateReadStatus();
            }
          },
          child: Column(
            children: [
              Container(
                height: 1,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _chatService.getGroupMessages(
                    widget.chatId,
                    context.read<AuthService>().currentUser!.uid,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Ошибка: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;
                    final currentUser = context.read<AuthService>().currentUser!;

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser.uid;
                        final showAvatar = index == messages.length - 1 || 
                            messages[index + 1].senderId != message.senderId;

                        return StreamBuilder<DocumentSnapshot>(
                          stream: _chatService.getGroupChatStream(widget.chatId),
                          builder: (context, chatSnapshot) {
                            if (!chatSnapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                            final participants = List<String>.from(chatData['participants'] as List);

                            return FutureBuilder<UserModel?>(
                              future: _getUser(message.senderId),
                              builder: (context, userSnapshot) {
                                final sender = userSnapshot.data;
                                final userName = sender?.name ?? 'Пользователь';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe && showAvatar) ...[
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(0xFF2AABEE),
                                          backgroundImage: sender?.avatarUrl != null
                                              ? NetworkImage(sender!.avatarUrl!)
                                              : null,
                                          child: sender?.avatarUrl == null
                                              ? Text(
                                                  userName[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (!isMe && !showAvatar)
                                        const SizedBox(width: 40),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isMe 
                                                ? Theme.of(context).primaryColor
                                                : Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 16),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (!isMe)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    userName,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              if (message.imageUrl != null)
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => Scaffold(
                                                          backgroundColor: Colors.black,
                                                          body: Center(
                                                            child: InteractiveViewer(
                                                              child: Image.network(message.imageUrl!),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      message.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      width: 200,
                                                      height: 200,
                                                    ),
                                                  ),
                                                ),
                                              if (message.text.isNotEmpty) ...[
                                                if (message.imageUrl != null)
                                                  const SizedBox(height: 8),
                                                Text(
                                                  message.text,
                                                  style: TextStyle(
                                                    color: isMe 
                                                        ? Colors.white 
                                                        : Theme.of(context).textTheme.bodyLarge?.color,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTime(message.timestamp),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isMe 
                                                          ? Colors.white70 
                                                          : Theme.of(context).textTheme.bodySmall?.color,
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    MessageStatus(
                                                      message: message,
                                                      participantsCount: participants.length,
                                                      isGroupChat: true,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isMe && showAvatar) ...[
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(0xFF2AABEE),
                                          backgroundImage: currentUser.avatarUrl != null
                                              ? NetworkImage(currentUser.avatarUrl!)
                                              : null,
                                          child: currentUser.avatarUrl == null
                                              ? Text(
                                                  currentUser.name[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                      if (isMe && !showAvatar)
                                        const SizedBox(width: 40),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _pickImage,
                      color: Theme.of(context).primaryColor,
                    ),
                    Expanded(
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
                            _handlePaste();
                          }
                        },
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Введите сообщение...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            fillColor: Theme.of(context).scaffoldBackgroundColor,
                            filled: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
} 