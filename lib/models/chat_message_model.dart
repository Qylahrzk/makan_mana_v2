// ============================================================
// FILE: lib/models/chat_message_model.dart
//
// Updated: restaurants field added so the chat screen can render
// tappable restaurant mini-cards below each AI reply bubble.
// ============================================================

class ChatMessageModel {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isTyping;
  final DateTime timestamp;
  // Restaurants returned by /chat API for this AI message.
  // Only populated on AI reply messages.
  final List<Map<String, dynamic>> restaurants;

  const ChatMessageModel({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isTyping = false,
    required this.timestamp,
    this.restaurants = const [],
  });

  factory ChatMessageModel.user(String text) =>
      ChatMessageModel(text: text, isUser: true, timestamp: DateTime.now());

  factory ChatMessageModel.ai(
    String text, {
    List<Map<String, dynamic>> restaurants = const [],
  }) => ChatMessageModel(
    text: text,
    isUser: false,
    timestamp: DateTime.now(),
    restaurants: restaurants,
  );

  factory ChatMessageModel.typing() => ChatMessageModel(
    text: '',
    isUser: false,
    isTyping: true,
    timestamp: DateTime.now(),
  );

  factory ChatMessageModel.error(String message) => ChatMessageModel(
    text: message,
    isUser: false,
    isError: true,
    timestamp: DateTime.now(),
  );

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
