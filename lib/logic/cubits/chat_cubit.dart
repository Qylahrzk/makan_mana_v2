// ============================================================
// FILE: lib/logic/cubits/chat_cubit.dart
//
// BLoC for managing chat state and sending messages.
//
// UPDATED FOR v4.1:
// - Preserve preferences for follow-up questions
// - Detect follow-up queries ("more suggestions", "lagi", etc.)
// - Builds conversation history from current messages
// - Passes history to service
// - Maintains conversation context for follow-up questions
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/chat_message_model.dart';
import '../../data/chat_service.dart';
import 'dart:developer';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatService _chatService;

  // ── v4.1 NEW: Context preservation for follow-ups ──────────────────
  /// Stores the last user preferences extracted from the previous query.
  /// Used to preserve filters when user asks "more suggestions"
  Map<String, dynamic> _lastPreferences = {};

  /// Tracks if current message is a follow-up to enable context preservation
  bool _isFollowUpQuestion = false;

  /// Stores cuisine/vibe from last query for consistency checking
  String _lastCuisineType = '';
  String _lastVibe = '';

  ChatCubit(ChatService chatService)
    : _chatService = chatService,
      super(const ChatInitial());

  // ── v4.1 NEW: Follow-up Question Detection ────────────────────────

  /// Detects if a message is asking for "more suggestions" or similar follow-ups.
  ///
  /// Returns: true if message contains follow-up keywords
  bool _isFollowUpQuery(String message) {
    final followUpKeywords = [
      // English
      'more', 'other', 'another', 'different', 'else', 'instead',
      'alternatives', 'options', 'different option', 'what else',
      'any other', 'suggest again', 'try another', 'how about',
      'what about', 'more suggestions', 'more options',
      // Malay
      'lagi', 'lain', 'yang lain', 'beza', 'berbeza', 'lain pula',
      'ganti', 'alternatif', 'pilihan lain', 'saya nak lagi',
      'apa tentang', 'macam mana pula', 'ada lagi', 'ada lagi ke',
      'yang lain pula', 'lagi apa', 'apa lg', 'ada lain',
    ];

    final msgLower = message.toLowerCase();

    // For very short messages (1-3 words), use keyword matching
    final wordCount = message.split(RegExp(r'\s+')).length;
    if (wordCount <= 3) {
      return followUpKeywords.any((kw) => msgLower.contains(kw));
    }

    // For longer messages, require at least one follow-up keyword
    return followUpKeywords.any((kw) => msgLower.contains(kw));
  }

  // ── v4.1 NEW: Preference Preservation ──────────────────────────────

  /// Preserves the current user preferences to use in follow-up questions.
  void _savePreferencesForFollowUp({
    required bool halal,
    required bool vegetarian,
    required bool vegan,
    required bool parking,
    required bool wifi,
    required bool ac,
    required bool outdoor,
    required bool accessible,
    required bool familyFriendly,
    required bool groupFriendly,
    required bool casual,
    required bool romantic,
    required bool scenicView,
    required bool worthIt,
    required bool fastService,
  }) {
    _lastPreferences = {
      'halal': halal,
      'vegetarian': vegetarian,
      'vegan': vegan,
      'parking': parking,
      'wifi': wifi,
      'ac': ac,
      'outdoor': outdoor,
      'accessible': accessible,
      'familyFriendly': familyFriendly,
      'groupFriendly': groupFriendly,
      'casual': casual,
      'romantic': romantic,
      'scenicView': scenicView,
      'worthIt': worthIt,
      'fastService': fastService,
    };

    log(
      '[v4.1] Preferences saved for follow-up: halal=$halal, casual=$casual, romantic=$romantic',
      name: 'ChatCubit',
    );
  }

  /// Applies saved preferences to follow-up questions UNLESS explicitly overridden.
  Map<String, bool> _applySavedPreferencesIfFollowUp({
    required bool isFollowUp,
    required bool halal,
    required bool vegetarian,
    required bool vegan,
    required bool parking,
    required bool wifi,
    required bool ac,
    required bool outdoor,
    required bool accessible,
    required bool familyFriendly,
    required bool groupFriendly,
    required bool casual,
    required bool romantic,
    required bool scenicView,
    required bool worthIt,
    required bool fastService,
  }) {
    if (!isFollowUp || _lastPreferences.isEmpty) {
      // Not a follow-up or no saved preferences
      return {
        'halal': halal,
        'vegetarian': vegetarian,
        'vegan': vegan,
        'parking': parking,
        'wifi': wifi,
        'ac': ac,
        'outdoor': outdoor,
        'accessible': accessible,
        'familyFriendly': familyFriendly,
        'groupFriendly': groupFriendly,
        'casual': casual,
        'romantic': romantic,
        'scenicView': scenicView,
        'worthIt': worthIt,
        'fastService': fastService,
      };
    }

    // Apply saved preferences for follow-up questions
    return {
      'halal': halal || (_lastPreferences['halal'] as bool? ?? false),
      'vegetarian':
          vegetarian || (_lastPreferences['vegetarian'] as bool? ?? false),
      'vegan': vegan || (_lastPreferences['vegan'] as bool? ?? false),
      'parking': parking || (_lastPreferences['parking'] as bool? ?? false),
      'wifi': wifi || (_lastPreferences['wifi'] as bool? ?? false),
      'ac': ac || (_lastPreferences['ac'] as bool? ?? false),
      'outdoor': outdoor || (_lastPreferences['outdoor'] as bool? ?? false),
      'accessible':
          accessible || (_lastPreferences['accessible'] as bool? ?? false),
      'familyFriendly':
          familyFriendly ||
          (_lastPreferences['familyFriendly'] as bool? ?? false),
      'groupFriendly':
          groupFriendly ||
          (_lastPreferences['groupFriendly'] as bool? ?? false),
      'casual': casual || (_lastPreferences['casual'] as bool? ?? false),
      'romantic': romantic || (_lastPreferences['romantic'] as bool? ?? false),
      'scenicView':
          scenicView || (_lastPreferences['scenicView'] as bool? ?? false),
      'worthIt': worthIt || (_lastPreferences['worthIt'] as bool? ?? false),
      'fastService':
          fastService || (_lastPreferences['fastService'] as bool? ?? false),
    };
  }

  // ── v4.1 UPDATED: sendMessage with Follow-up Support ────────────────

  /// Sends a message with v4.1 follow-up question support.
  Future<void> sendMessage(
    String message, {
    bool halal = false,
    bool vegetarian = false,
    bool vegan = false,
    bool parking = false,
    bool wifi = false,
    bool ac = false,
    bool outdoor = false,
    bool accessible = false,
    bool familyFriendly = false,
    bool groupFriendly = false,
    bool casual = false,
    bool romantic = false,
    bool scenicView = false,
    bool worthIt = false,
    bool fastService = false,
  }) async {
    if (message.isEmpty) return;

    // Get current messages
    final currentMessages = (state is ChatLoaded)
        ? List<ChatMessageModel>.from((state as ChatLoaded).messages)
        : (state is ChatSending)
        ? List<ChatMessageModel>.from((state as ChatSending).messages)
        : (state is ChatError)
        ? List<ChatMessageModel>.from((state as ChatError).messages)
        : <ChatMessageModel>[];

    // Remove typing indicators
    currentMessages.removeWhere((m) => m.isTyping);

    // Add user message (optimistic update)
    currentMessages.add(ChatMessageModel.user(message));

    // Add typing indicator
    currentMessages.add(ChatMessageModel.typing());

    emit(ChatSending(List.from(currentMessages)));

    try {
      // ── v4.1: DETECT FOLLOW-UP ────────────────────────────────────
      _isFollowUpQuestion = _isFollowUpQuery(message);

      if (_isFollowUpQuestion) {
        log(
          '[v4.1] Follow-up question detected: "$message"',
          name: 'ChatCubit',
        );
      }

      // ── v4.1: PRESERVE PREFERENCES FOR FOLLOW-UPS ─────────────────
      final finalPreferences = _applySavedPreferencesIfFollowUp(
        isFollowUp: _isFollowUpQuestion,
        halal: halal,
        vegetarian: vegetarian,
        vegan: vegan,
        parking: parking,
        wifi: wifi,
        ac: ac,
        outdoor: outdoor,
        accessible: accessible,
        familyFriendly: familyFriendly,
        groupFriendly: groupFriendly,
        casual: casual,
        romantic: romantic,
        scenicView: scenicView,
        worthIt: worthIt,
        fastService: fastService,
      );

      if (_isFollowUpQuestion) {
        log(
          '[v4.1] Applied saved preferences: '
          'halal=${finalPreferences['halal']}, '
          'romantic=${finalPreferences['romantic']}, '
          'casual=${finalPreferences['casual']}',
          name: 'ChatCubit',
        );
      }

      // ── v4.1: BUILD CONVERSATION HISTORY ──────────────────────────
      final conversationHistory = _buildConversationHistory(currentMessages);

      if (conversationHistory.isNotEmpty) {
        log(
          '[v4.1] Sending conversation history: ${conversationHistory.length} messages',
          name: 'ChatCubit',
        );
      }

      // ── CALL SERVICE WITH UPDATED PREFERENCES ─────────────────────
      final response = await _chatService.sendMessage(
        message: message,
        conversationHistory: conversationHistory,
        halal: finalPreferences['halal'] ?? false,
        vegetarian: finalPreferences['vegetarian'] ?? false,
        vegan: finalPreferences['vegan'] ?? false,
        parking: finalPreferences['parking'] ?? false,
        wifi: finalPreferences['wifi'] ?? false,
        ac: finalPreferences['ac'] ?? false,
        outdoor: finalPreferences['outdoor'] ?? false,
        accessible: finalPreferences['accessible'] ?? false,
        familyFriendly: finalPreferences['familyFriendly'] ?? false,
        groupFriendly: finalPreferences['groupFriendly'] ?? false,
        casual: finalPreferences['casual'] ?? false,
        romantic: finalPreferences['romantic'] ?? false,
        scenicView: finalPreferences['scenicView'] ?? false,
        worthIt: finalPreferences['worthIt'] ?? false,
        fastService: finalPreferences['fastService'] ?? false,
      );

      // Remove typing indicator
      currentMessages.removeWhere((m) => m.isTyping);

      // Parse response
      final reply = (response['reply'] as String?)?.trim() ?? 'No response';
      final modelUsed = response['model_used'] ?? 'Unknown';
      final isOnTopic = response['is_on_topic'] ?? true;
      final restaurants =
          (response['restaurants'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

      final rawRelaxed = response['relaxed_criteria'] as List<dynamic>? ?? [];
      final relaxedCriteria = rawRelaxed.map((e) => e.toString()).toList();
      final hasPartialMatch = response['has_partial_match'] as bool? ?? false;
      final searchUsed = response['search_used'] as bool? ?? false;

      // ── v4.1: SAVE PREFERENCES FOR NEXT FOLLOW-UP ─────────────────
      _savePreferencesForFollowUp(
        halal: finalPreferences['halal'] ?? false,
        vegetarian: finalPreferences['vegetarian'] ?? false,
        vegan: finalPreferences['vegan'] ?? false,
        parking: finalPreferences['parking'] ?? false,
        wifi: finalPreferences['wifi'] ?? false,
        ac: finalPreferences['ac'] ?? false,
        outdoor: finalPreferences['outdoor'] ?? false,
        accessible: finalPreferences['accessible'] ?? false,
        familyFriendly: finalPreferences['familyFriendly'] ?? false,
        groupFriendly: finalPreferences['groupFriendly'] ?? false,
        casual: finalPreferences['casual'] ?? false,
        romantic: finalPreferences['romantic'] ?? false,
        scenicView: finalPreferences['scenicView'] ?? false,
        worthIt: finalPreferences['worthIt'] ?? false,
        fastService: finalPreferences['fastService'] ?? false,
      );

      // Add bot message
      currentMessages.add(
        ChatMessageModel.ai(
          reply,
          restaurants: restaurants,
          relaxedCriteria: relaxedCriteria,
          hasPartialMatch: hasPartialMatch,
          modelUsed: modelUsed,
          searchUsed: searchUsed,
          isOnTopic: isOnTopic,
        ),
      );

      // Update state
      emit(
        ChatLoaded(
          messages: List.from(currentMessages),
          restaurants: restaurants,
        ),
      );

      log(
        '[v4.1] Message processed successfully. '
        'Follow-up=$_isFollowUpQuestion, Restaurants=${restaurants.length}',
        name: 'ChatCubit',
      );
    } catch (e) {
      currentMessages.removeWhere((m) => m.isTyping);
      currentMessages.add(ChatMessageModel.error(e.toString()));
      emit(
        ChatError(
          messages: List.from(currentMessages),
          errorMessage: e.toString(),
        ),
      );

      log('[v4.1] Error: ${e.toString()}', name: 'ChatCubit');
    }
  }

  /// Builds conversation history from chat messages.
  /// Filters out typing indicators and error messages.
  List<Map<String, String>> _buildConversationHistory(
    List<ChatMessageModel> messages,
  ) {
    return messages
        .where((msg) => !msg.isTyping && !msg.isError && msg.text.isNotEmpty)
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          },
        )
        .toList();
  }

  /// Clears all chat messages and resets follow-up context.
  void clearChat() {
    _lastPreferences.clear();
    _isFollowUpQuestion = false;
    _lastCuisineType = '';
    _lastVibe = '';
    emit(const ChatInitial());

    log('[v4.1] Chat cleared. Follow-up context reset.', name: 'ChatCubit');
  }

  /// Returns current messages from state.
  List<ChatMessageModel> get currentMessages {
    final s = state;
    if (s is ChatLoaded) return s.messages;
    if (s is ChatSending) return s.messages;
    if (s is ChatError) return s.messages;
    return [];
  }

  /// Returns true if currently sending a message.
  bool get isSending => state is ChatSending;

  // ── v4.1: DEBUGGING HELPERS ──────────────────────────────────────

  /// Returns debug info about current follow-up state.
  /// Useful for testing conversation continuity.
  String get debugFollowUpInfo {
    return '''
[v4.1 Debug Info]
IsFollowUp: $_isFollowUpQuestion
SavedPreferences: ${_lastPreferences.entries.where((e) => e.value == true).map((e) => e.key).toList()}
LastCuisine: $_lastCuisineType
LastVibe: $_lastVibe
MessageCount: ${currentMessages.length}
''';
  }
}
