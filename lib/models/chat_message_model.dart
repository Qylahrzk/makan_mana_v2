// ============================================================
// FILE: lib/models/chat_message_model.dart
//
// v3.1 CHANGES:
//   - Added relaxedCriteria, hasPartialMatch, modelUsed, searchUsed
//     so ChatScreen can render:
//       • 'Partial match — scenic view relaxed' banner
//       • 'Answered by Groq · Searched online' badge
//       • Per-restaurant 'Matched: Halal + LDA: Romantic Vibe' chips
// ============================================================

import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String text;
  final bool isUser;
  final bool isTyping;
  final bool isError;
  final DateTime timestamp;

  /// Restaurant preview cards shown below a bot message.
  /// Each map may contain a 'matched_filters' key (List<String>).
  final List<Map<String, dynamic>> restaurants;

  // ── NEW explainability fields (v3.1) ──────────────────────────────────────
  /// Criteria that were relaxed to produce these results, e.g. ['scenic_view']
  final List<String> relaxedCriteria;

  /// True when at least one criterion was relaxed (partial match)
  final bool hasPartialMatch;

  /// Which LLM answered this message, e.g. 'Groq Llama-3.3'
  final String modelUsed;

  /// Whether a web search was performed for this reply
  final bool searchUsed;

  const ChatMessageModel._({
    required this.text,
    required this.isUser,
    required this.isTyping,
    required this.isError,
    required this.timestamp,
    required this.restaurants,
    required this.relaxedCriteria,
    required this.hasPartialMatch,
    required this.modelUsed,
    required this.searchUsed,
  });

  // ── Factories ──────────────────────────────────────────────────────────────

  factory ChatMessageModel.user(String text) => ChatMessageModel._(
    text: text,
    isUser: true,
    isTyping: false,
    isError: false,
    timestamp: DateTime.now(),
    restaurants: const [],
    relaxedCriteria: const [],
    hasPartialMatch: false,
    modelUsed: '',
    searchUsed: false,
  );

  factory ChatMessageModel.typing() => ChatMessageModel._(
    text: '',
    isUser: false,
    isTyping: true,
    isError: false,
    timestamp: DateTime.now(),
    restaurants: const [],
    relaxedCriteria: const [],
    hasPartialMatch: false,
    modelUsed: '',
    searchUsed: false,
  );

  factory ChatMessageModel.ai(
    String text, {
    List<Map<String, dynamic>> restaurants = const [],
    List<String> relaxedCriteria = const [],
    bool hasPartialMatch = false,
    String modelUsed = '',
    bool searchUsed = false,
  }) => ChatMessageModel._(
    text: text,
    isUser: false,
    isTyping: false,
    isError: false,
    timestamp: DateTime.now(),
    restaurants: restaurants,
    relaxedCriteria: relaxedCriteria,
    hasPartialMatch: hasPartialMatch,
    modelUsed: modelUsed,
    searchUsed: searchUsed,
  );

  factory ChatMessageModel.error(String message) => ChatMessageModel._(
    text: message,
    isUser: false,
    isTyping: false,
    isError: true,
    timestamp: DateTime.now(),
    restaurants: const [],
    relaxedCriteria: const [],
    hasPartialMatch: false,
    modelUsed: '',
    searchUsed: false,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  List<Object?> get props => [
    text,
    isUser,
    isTyping,
    isError,
    timestamp,
    restaurants,
    relaxedCriteria,
    hasPartialMatch,
    modelUsed,
    searchUsed,
  ];
}
