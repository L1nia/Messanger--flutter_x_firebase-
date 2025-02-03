import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // Получить список всех пользователей для поиска
  Stream<List<UserModel>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + 'z')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    });
  }

  // Создать или получить существующий чат
  Future<String> createChat(String currentUserId, String otherUserId) async {
    // Проверяем, существует ли уже чат между пользователями
    final chatQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContainsAny: [currentUserId, otherUserId])
        .get();

    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(currentUserId) &&
          participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Создаем новый чат
    final chatId = _uuid.v4();
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },
    });

    return chatId;
  }

  // Отправить сообщение
  Future<void> sendMessage(String chatId, String senderId, String text, {File? imageFile}) async {
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadMessageImage(chatId, imageFile, false);
    }

    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      readBy: {senderId: true},
      imageUrl: imageUrl,
    );

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    
    // Увеличиваем счетчик непрочитанных сообщений для получателя
    Map<String, dynamic> unreadCount = chatDoc.data()?['unreadCount'] ?? {};
    for (var participantId in participants) {
      if (participantId != senderId) {
        unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
      }
    }

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': message.timestamp.toIso8601String(),
      'unreadCount': unreadCount,
    });
  }

  // Получить сообщения чата
  Stream<List<MessageModel>> getMessages(String chatId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final message = MessageModel.fromJson(doc.data());
        // Отмечаем сообщение как прочитанное
        if (!message.isReadBy(currentUserId)) {
          markMessageAsRead(chatId, message.id, currentUserId, false);
        }
        return message;
      }).toList();
      return messages;
    });
  }

  // Получить список чатов пользователя
  Stream<List<DocumentSnapshot>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Обновить счетчик непрочитанных сообщений
  Future<void> updateUnreadCount(String chatId, String userId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) return;

    Map<String, dynamic> unreadCount = chatDoc.data()?['unreadCount'] ?? {};
    if (unreadCount[userId] != null) {
      unreadCount[userId] = 0;
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount': unreadCount,
      });
    }
  }

  // Создать групповой чат
  Future<String> createGroupChat(
    String name,
    List<String> participants,
    List<String> admins,
  ) async {
    final chatId = _uuid.v4();
    final unreadCount = {for (var id in participants) id: 0};

    await _firestore.collection('group_chats').doc(chatId).set({
      'id': chatId,
      'name': name,
      'participants': participants,
      'admins': admins,
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadCount': unreadCount,
    });

    return chatId;
  }

  // Добавить участников в групповой чат
  Future<void> addParticipantsToGroup(String chatId, List<String> newParticipants) async {
    final chatDoc = await _firestore.collection('group_chats').doc(chatId).get();
    if (!chatDoc.exists) return;

    final currentParticipants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    final unreadCount = Map<String, int>.from(chatDoc.data()?['unreadCount'] ?? {});

    // Добавляем новых участников
    for (var participantId in newParticipants) {
      if (!currentParticipants.contains(participantId)) {
        currentParticipants.add(participantId);
        unreadCount[participantId] = 0;
      }
    }

    await _firestore.collection('group_chats').doc(chatId).update({
      'participants': currentParticipants,
      'unreadCount': unreadCount,
    });
  }

  // Получить групповые чаты пользователя
  Stream<List<DocumentSnapshot>> getUserGroupChats(String userId) {
    return _firestore
        .collection('group_chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Отправить сообщение в групповой чат
  Future<void> sendGroupMessage(String chatId, String senderId, String text, {File? imageFile}) async {
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadMessageImage(chatId, imageFile, true);
    }

    final message = MessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      readBy: {senderId: true},
      imageUrl: imageUrl,
    );

    final chatDoc = await _firestore.collection('group_chats').doc(chatId).get();
    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    
    Map<String, dynamic> unreadCount = chatDoc.data()?['unreadCount'] ?? {};
    for (var participantId in participants) {
      if (participantId != senderId) {
        unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
      }
    }

    await _firestore
        .collection('group_chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());

    await _firestore.collection('group_chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': message.timestamp.toIso8601String(),
      'unreadCount': unreadCount,
    });
  }

  // Удалить групповой чат
  Future<void> deleteGroupChat(String chatId) async {
    // Удаляем все сообщения в чате
    final messages = await _firestore
        .collection('group_chats')
        .doc(chatId)
        .collection('messages')
        .get();
    
    for (var message in messages.docs) {
      await message.reference.delete();
    }

    // Удаляем сам чат
    await _firestore.collection('group_chats').doc(chatId).delete();
  }

  // Проверить, является ли пользователь администратором
  Future<bool> isGroupAdmin(String chatId, String userId) async {
    final chatDoc = await _firestore.collection('group_chats').doc(chatId).get();
    if (!chatDoc.exists) return false;

    final admins = List<String>.from(chatDoc.data()?['admins'] ?? []);
    return admins.contains(userId);
  }

  // Получить сообщения группового чата
  Stream<List<MessageModel>> getGroupMessages(String chatId, String currentUserId) {
    // Сначала обновляем счетчик непрочитанных сообщений
    updateGroupUnreadCount(chatId, currentUserId);

    // Затем возвращаем поток сообщений
    return _firestore
        .collection('group_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final message = MessageModel.fromJson(doc.data());
        // Отмечаем сообщение как прочитанное
        if (!message.isReadBy(currentUserId)) {
          markMessageAsRead(chatId, message.id, currentUserId, true);
        }
        return message;
      }).toList();
      return messages;
    });
  }

  // Получить информацию о пользователе
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!);
  }

  // Обновить счетчик непрочитанных сообщений в групповом чате
  Future<void> updateGroupUnreadCount(String chatId, String userId) async {
    final chatDoc = await _firestore.collection('group_chats').doc(chatId).get();
    
    if (!chatDoc.exists) return;

    Map<String, dynamic> unreadCount = Map<String, dynamic>.from(chatDoc.data()?['unreadCount'] ?? {});
    if (unreadCount.containsKey(userId)) {
      unreadCount[userId] = 0;
      await _firestore.collection('group_chats').doc(chatId).update({
        'unreadCount': unreadCount,
      });
    }
  }

  // Добавим метод для отметки сообщения как прочитанного
  Future<void> markMessageAsRead(String chatId, String messageId, String userId, bool isGroupChat) async {
    final collectionPath = isGroupChat ? 'group_chats' : 'chats';
    final messageRef = _firestore
        .collection(collectionPath)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await messageRef.update({
      'readBy.$userId': true,
    });
  }

  Stream<DocumentSnapshot> getGroupChatStream(String chatId) {
    return _firestore.collection('group_chats').doc(chatId).snapshots();
  }

  Future<String?> uploadGroupPhoto(String chatId, File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_photos')
          .child('$chatId.jpg');

      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection('group_chats').doc(chatId).update({
        'photoUrl': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading group photo: $e');
      return null;
    }
  }

  Future<void> deleteGroupPhoto(String chatId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_photos')
          .child('$chatId.jpg');

      await storageRef.delete();
      await _firestore.collection('group_chats').doc(chatId).update({
        'photoUrl': FieldValue.delete(),
      });
    } catch (e) {
      print('Error deleting group photo: $e');
    }
  }

  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['isOnline'] ?? false);
  }

  Future<String?> uploadMessageImage(String chatId, File imageFile, bool isGroupChat) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final folderName = isGroupChat ? 'group_messages' : 'messages';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(folderName)
          .child(chatId)
          .child(fileName);

      await storageRef.putFile(imageFile);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading message image: $e');
      return null;
    }
  }
} 