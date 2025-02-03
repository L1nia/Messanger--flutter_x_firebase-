class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? avatarUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
} 