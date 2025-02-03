class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final Map<String, bool> readBy;
  final String? imageUrl;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.readBy,
    this.imageUrl,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      readBy: Map<String, bool>.from(json['readBy'] as Map),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'readBy': readBy,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  bool isReadBy(String userId) => readBy[userId] == true;
  int readCount() => readBy.values.where((v) => v).length;
} 