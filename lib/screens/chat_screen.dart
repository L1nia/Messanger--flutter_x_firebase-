import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
// ignore: unused_import
import '../widgets/message_status.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthService>().currentUser!;
    _chatService.updateUnreadCount(widget.chatId, currentUser.uid);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
        // Обработка base64 изображения
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
    _chatService.sendMessage(
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
    final currentUser = context.read<AuthService>().currentUser!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF2AABEE),
              backgroundImage: widget.otherUser.avatarUrl != null
                  ? NetworkImage(widget.otherUser.avatarUrl!)
                  : null,
              child: widget.otherUser.avatarUrl == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUser.name,
                    style: TextStyle(
                      color: Theme.of(context).appBarTheme.foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: _chatService.getUserOnlineStatus(widget.otherUser.uid),
                    builder: (context, snapshot) {
                      final isOnline = snapshot.data ?? false;
                      return Text(
                        isOnline ? 'В сети' : 'Не в сети',
                        style: TextStyle(
                          color: Theme.of(context).appBarTheme.foregroundColor?.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Удалить чат',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        // ... код удаления чата
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Ошибка: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                    Icon(
                                      message.readBy.containsKey(widget.otherUser.uid)
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'только что';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} минут назад';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} часов назад';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} дней назад';
    } else if (diff.inDays < 30) {
      return '${diff.inDays ~/ 7} недель назад';
    } else if (diff.inDays < 365) {
      return '${diff.inDays ~/ 30} месяцев назад';
    } else {
      return '${diff.inDays ~/ 365} лет назад';
    }
  }
} 