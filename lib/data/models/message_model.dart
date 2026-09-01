class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String? mediaUrl; // For images/voice notes
  final DateTime timestamp;
  final bool isRead;      // For Read Receipts
  final String type;      // 'text', 'image', or 'voice'

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.mediaUrl,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
  });

  // This converts Firebase data into a Flutter object
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      senderId: map['senderId'],
      text: map['text'],
      mediaUrl: map['mediaUrl'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'text',
    );
  }
}
