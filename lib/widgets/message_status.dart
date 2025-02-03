import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageStatus extends StatelessWidget {
  final MessageModel message;
  final int participantsCount;
  final bool isGroupChat;

  const MessageStatus({
    super.key,
    required this.message,
    required this.participantsCount,
    required this.isGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    final readCount = message.readCount();
    
    // Общий стиль для иконок
    const double iconSize = 16.0;
    
    // Если сообщение прочитано хотя бы одним получателем
    if (readCount > 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: iconSize,
            color: Colors.green,
          ),
          if (isGroupChat) ...[
            const SizedBox(width: 2),
            Text(
              '$readCount/$participantsCount',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.green,
              ),
            ),
          ],
        ],
      );
    }
    
    // Если сообщение доставлено (есть в базе данных)
    if (message.id.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: iconSize,
            color: Colors.grey,
          ),
          if (isGroupChat) ...[
            const SizedBox(width: 2),
            Text(
              '$readCount/$participantsCount',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      );
    }
    
    // Если сообщение только отправлено
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.done,
          size: iconSize,
          color: Colors.grey,
        ),
        if (isGroupChat) ...[
          const SizedBox(width: 2),
          Text(
            '$readCount/$participantsCount',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
} 