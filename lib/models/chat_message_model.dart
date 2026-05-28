// ============================================================
// FILE: lib/models/chat_message_model.dart
//
// v4.0 ENHANCED - Full compatibility with Flask v4.0 API
//   - Added isOnTopic, scopeConfidence, detectedKeywords
//   - Added validation (hallucination detection)
//   - Fully compatible with all API response fields
// ============================================================

import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String text;
  final bool isUser;
  final bool isTyping;
  final bool isError;
  final DateTime timestamp;

  /// Restaurant preview cards shown below a bot message.
  /// Each map contains: name, rating, municipality, matched_filters, etc.
  final List<Map<String, dynamic>> restaurants;

  // ── v3.1 explainability fields ────────────────────────────────────────────
  /// Criteria that were relaxed to produce results, e.g. ['scenic_view']
  final List<String> relaxedCriteria;

  /// True when at least one criterion was relaxed (partial match)
  final bool hasPartialMatch;

  /// Which LLM answered this message, e.g. 'Groq Llama-3.3'
  final String modelUsed;

  /// Whether a web search was performed for this reply
  final bool searchUsed;

  // ── v4.0 NEW: Scope & Intent fields ───────────────────────────────────────
  /// Whether the query was detected as on-topic (restaurant-related)
  final bool isOnTopic;

  /// Confidence score for on-topic detection (0.0-1.0)
  final double scopeConfidence;

  /// Keywords detected in the user's message for transparency
  final List<String> detectedKeywords;

  // ── v4.0 NEW: Validation fields ───────────────────────────────────────────
  /// Whether hallucinations were attempted/detected in LLM response
  final bool hadHallucinations;

  /// Rate of hallucination attempts (0.0-1.0)
  final double halluccinationRate;

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
    required this.isOnTopic,
    required this.scopeConfidence,
    required this.detectedKeywords,
    required this.hadHallucinations,
    required this.halluccinationRate,
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
    isOnTopic: true,
    scopeConfidence: 1.0,
    detectedKeywords: const [],
    hadHallucinations: false,
    halluccinationRate: 0.0,
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
    isOnTopic: true,
    scopeConfidence: 1.0,
    detectedKeywords: const [],
    hadHallucinations: false,
    halluccinationRate: 0.0,
  );

  factory ChatMessageModel.ai(
    String text, {
    List<Map<String, dynamic>> restaurants = const [],
    List<String> relaxedCriteria = const [],
    bool hasPartialMatch = false,
    String modelUsed = '',
    bool searchUsed = false,
    bool isOnTopic = true,
    double scopeConfidence = 1.0,
    List<String> detectedKeywords = const [],
    bool hadHallucinations = false,
    double halluccinationRate = 0.0,
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
    isOnTopic: isOnTopic,
    scopeConfidence: scopeConfidence,
    detectedKeywords: detectedKeywords,
    hadHallucinations: hadHallucinations,
    halluccinationRate: halluccinationRate,
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
    isOnTopic: false,
    scopeConfidence: 0.0,
    detectedKeywords: const [],
    hadHallucinations: false,
    halluccinationRate: 0.0,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Returns a confidence percentage string, e.g. "95%"
  String get confidencePercentage =>
      '${(scopeConfidence * 100).toStringAsFixed(0)}%';

  /// Returns true if the LLM attempted hallucinations (security flag)
  bool get hasSecurityConcern => hadHallucinations || halluccinationRate > 0.0;

  /// Returns a security message if hallucinations were detected
  String? get securityMessage {
    if (!hasSecurityConcern) return null;
    if (halluccinationRate > 0.1) {
      return 'Hallucination risk detected ($halluccinationRate)';
    }
    return 'Minor hallucination attempt detected';
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
    isOnTopic,
    scopeConfidence,
    detectedKeywords,
    hadHallucinations,
    halluccinationRate,
  ];
}
