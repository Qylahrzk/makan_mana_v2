// ============================================================
// FILE: lib/logic/cubits/chat_cubit.dart
//
// BLoC for managing chat state and sending messages.
//
// UPDATED FOR v4.2:
// - Preserve preferences for follow-up questions
// - Translate checkbox filters to hidden tokens for API matching
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

  // ── v4.2 STABILIZED PARAMETERS ─────────────────────────────────────
  /// Stores the last user preferences extracted from the previous query.
  Map<String, dynamic> _lastPreferences = {};

  /// Tracks if current message is a follow-up to enable context preservation
  bool _isFollowUpQuestion = false;

  /// Stores cuisine/vibe from last query for consistency checking
  String _lastCuisineType = '';
  String _lastVibe = '';

  ChatCubit(ChatService chatService)
    : _chatService = chatService,
      super(const ChatInitial());

  // ── FOLLOW-UP DETECTION LOGIC ──────────────────────────────────────
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

    final msgLower = message.toLowerCase().trim();
    return followUpKeywords.any((kw) => msgLower.contains(kw));
  }

  // ── PREFERENCE UTILITY STATE ROUTINES ──────────────────────────────
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
      '[v4.2] Ground State Preferences Saved: halal=$halal, romantic=$romantic, scenicView=$scenicView',
      name: 'ChatCubit',
    );
  }

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

  /// v4.2 FIX: Translates active UI checkbox filters into explicit string
  /// tokens so your Python API keywords extraction engine matches correctly.
  String _buildHiddenPayloadTokens(Map<String, bool> prefs) {
    final List<String> tokens = [];
    if (prefs['halal'] == true) tokens.add('halal');
    if (prefs['vegetarian'] == true) tokens.add('vegetarian');
    if (prefs['vegan'] == true) tokens.add('vegan');
    if (prefs['parking'] == true) tokens.add('parking');
    if (prefs['wifi'] == true) tokens.add('wifi');
    if (prefs['ac'] == true) tokens.add('air-cond');
    if (prefs['outdoor'] == true) tokens.add('outdoor open air luar');
    if (prefs['accessible'] == true) tokens.add('accessible');
    if (prefs['familyFriendly'] == true)
      tokens.add('family friendly keluarga anak');
    if (prefs['groupFriendly'] == true) tokens.add('group friendly ramai');
    if (prefs['casual'] == true) tokens.add('casual santai');
    if (prefs['romantic'] == true) tokens.add('romantic date pasangan');
    if (prefs['scenicView'] == true)
      tokens.add('scenic view pantai pata pemandangan laut');
    if (prefs['worthIt'] == true) tokens.add('worth it');
    if (prefs['fastService'] == true) tokens.add('fast service');

    if (tokens.isEmpty) return '';
    return '[Context Flags: ${tokens.join(" ")}]';
  }

  // ── INTERACTIVE CORE TRANSACTION VALUE METHOD ──────────────────────
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

    final currentMessages = (state is ChatLoaded)
        ? List<ChatMessageModel>.from((state as ChatLoaded).messages)
        : (state is ChatSending)
        ? List<ChatMessageModel>.from((state as ChatSending).messages)
        : (state is ChatError)
        ? List<ChatMessageModel>.from((state as ChatError).messages)
        : <ChatMessageModel>[];

    currentMessages.removeWhere((m) => m.isTyping);
    currentMessages.add(ChatMessageModel.user(message));
    currentMessages.add(ChatMessageModel.typing());
    emit(ChatSending(List.from(currentMessages)));

    try {
      _isFollowUpQuestion = _isFollowUpQuery(message);

      if (_isFollowUpQuestion) {
        log(
          '[v4.2] Follow-up query state triggered: "$message"',
          name: 'ChatCubit',
        );
      }

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
          '[v4.2] Applied state variables: halal=${finalPreferences['halal']}, romantic=${finalPreferences['romantic']}',
          name: 'ChatCubit',
        );
      }

      // Format payload string footprints
      final hiddenTokens = _buildHiddenPayloadTokens(finalPreferences);

      // Build context history array (passing tokens safely inside user turns)
      final List<Map<String, String>> conversationHistory = [];
      for (var idx = 0; idx < currentMessages.length; idx++) {
        final msg = currentMessages[idx];
        if (msg.isTyping || msg.isError || msg.text.isEmpty) continue;

        if (msg.isUser) {
          // If this is the active message turn, append the active hidden token footprint
          if (idx == currentMessages.length - 2 && hiddenTokens.isNotEmpty) {
            conversationHistory.add({
              'role': 'user',
              'content': '${msg.text} $hiddenTokens'.trim(),
            });
          } else {
            conversationHistory.add({'role': 'user', 'content': msg.text});
          }
        } else {
          conversationHistory.add({'role': 'assistant', 'content': msg.text});
        }
      }

      // Strip trailing elements to balance the processing footprint
      if (conversationHistory.isNotEmpty) conversationHistory.removeLast();

      if (conversationHistory.isNotEmpty) {
        log(
          '[v4.2] Dispatching history footprint: ${conversationHistory.length} turns',
          name: 'ChatCubit',
        );
      }

      // Call ChatService carrying payload dependencies
      final response = await _chatService.sendMessage(
        message: hiddenTokens.isNotEmpty && !_isFollowUpQuestion
            ? '$message $hiddenTokens'.trim()
            : message,
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

      currentMessages.removeWhere((m) => m.isTyping);

      final reply = (response['reply'] as String?)?.trim() ?? 'No response';
      final modelUsed = response['model_used'] ?? 'Unknown';
      final isOnTopic = response['is_on_topic'] ?? true;
      final restaurants =
          (response['restaurants'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

      final rawRelaxed = response['relaxed_criteria'] as List? ?? [];
      final relaxedCriteria = rawRelaxed.map((e) => e.toString()).toList();
      final hasPartialMatch = response['has_partial_match'] as bool? ?? false;
      final searchUsed = response['search_used'] as bool? ?? false;

      // Sync state preferences for follow-up reference limits
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

      // Append verified response item model to list
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

      emit(
        ChatLoaded(
          messages: List.from(currentMessages),
          restaurants: restaurants,
        ),
      );

      log(
        '[v4.2] Dynamic processing complete. Found locations: ${restaurants.length}',
        name: 'ChatCubit',
      );
      for (var i = 0; i < restaurants.length; i++) {
        final r = restaurants[i];
        log(
          '  📍 Restaurant [#${i + 1}]: ${r['name']} | Rating: ${r['rating']} | Location: ${r['municipality']} | Filters: ${r['matched_filters']}',
          name: 'ChatCubit',
        );
      }
    } catch (e) {
      currentMessages.removeWhere((m) => m.isTyping);
      currentMessages.add(ChatMessageModel.error(e.toString()));
      emit(
        ChatError(
          messages: List.from(currentMessages),
          errorMessage: e.toString(),
        ),
      );
      log('[v4.2 Exception Block Triggered]: $e', name: 'ChatCubit');
    }
  }

  void clearChat() {
    _lastPreferences.clear();
    _isFollowUpQuestion = false;
    _lastCuisineType = '';
    _lastVibe = '';
    emit(const ChatInitial());
    log('[v4.2] Chat state trace completely cleared.', name: 'ChatCubit');
  }

  List<ChatMessageModel> get currentMessages {
    final s = state;
    if (s is ChatLoaded) return s.messages;
    if (s is ChatSending) return s.messages;
    if (s is ChatError) return s.messages;
    return [];
  }

  bool get isSending => state is ChatSending;

  // ── DEBUGGING LOG ARCHITECTURE UTILITIES ───────────────────────────
  String get debugFollowUpInfo {
    return '''
[v4.2 System Monitor Debug Payload Logs]
IsFollowUpActive: $_isFollowUpQuestion
SavedToggles: ${_lastPreferences.entries.where((e) => e.value == true).map((e) => e.key).toList()}
LastCuisineTracked: $_lastCuisineType
LastVibeTracked: $_lastVibe
MessageMemoryArrayDepth: ${currentMessages.length}
''';
  }
}
