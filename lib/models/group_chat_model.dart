class GroupChatModel {
  final String id;
  final String name;
  final String creatorId;
  final List<String> participants;
  final List<String> admins;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;

  GroupChatModel({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.participants,
    required this.admins,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
  });

  factory GroupChatModel.fromJson(Map<String, dynamic> json) {
    return GroupChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      creatorId: json['creatorId'] as String,
      participants: List<String>.from(json['participants'] as List),
      admins: List<String>.from(json['admins'] as List),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
      unreadCount: Map<String, int>.from(json['unreadCount'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'participants': participants,
      'admins': admins,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  bool isAdmin(String userId) => admins.contains(userId);
} 