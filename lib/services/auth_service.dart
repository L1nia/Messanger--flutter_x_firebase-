import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
// ignore: unused_import
import 'package:image_picker/image_picker.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _user;

  UserModel? get currentUser => _user;

  Future<void> initializeUser() async {
    _user = null;
    
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final userData = await _firestore.collection('users').doc(user.uid).get();
          if (userData.exists) {
            _user = UserModel.fromJson(userData.data()!);
            notifyListeners();
          }
        } catch (e) {
          _user = null;
          await _auth.signOut();
          notifyListeners();
        }
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(user.toJson());

      _user = user;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw 'Слишком простой пароль';
        case 'email-already-in-use':
          throw 'Email уже используется';
        case 'invalid-email':
          throw 'Неверный формат email';
        default:
          throw 'Ошибка регистрации: ${e.message}';
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userData = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userData.exists) {
        _user = UserModel.fromJson(userData.data()!);
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'Пользователь не найден';
        case 'wrong-password':
          throw 'Неверный пароль';
        case 'invalid-email':
          throw 'Неверный формат email';
        case 'user-disabled':
          throw 'Аккаунт отключен';
        default:
          throw 'Ошибка входа: ${e.message}';
      }
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
      
      await _auth.setPersistence(Persistence.NONE);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile({String? name}) async {
    if (currentUser == null) return;

    // Обновляем данные в Firestore
    await _firestore.collection('users').doc(currentUser!.uid).update({
      if (name != null) 'name': name,
    });

    // Обновляем локальную модель пользователя
    _user = UserModel(
      uid: currentUser!.uid,
      email: currentUser!.email,
      name: name ?? currentUser!.name,
    );

    notifyListeners();
  }

  Future<String?> uploadAvatar(File imageFile) async {
    if (currentUser == null) return null;

    try {
      // Создаем ссылку на место хранения в Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_avatars')
          .child('${currentUser!.uid}.jpg');

      // Загружаем файл
      await storageRef.putFile(imageFile);

      // Получаем URL загруженного файла
      final downloadUrl = await storageRef.getDownloadURL();

      // Обновляем информацию о пользователе в Firestore
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'avatarUrl': downloadUrl,
      });

      // Обновляем локальную модель пользователя
      _user = UserModel(
        uid: currentUser!.uid,
        email: currentUser!.email,
        name: currentUser!.name,
        avatarUrl: downloadUrl,
      );

      notifyListeners();
      return downloadUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }
} 