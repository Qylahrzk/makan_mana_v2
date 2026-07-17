// ============================================================
// FILE: lib/logic/cubits/chat_cubit_v3.6_backup.dart
//
// BLoC for managing chat state and sending messages.
//
// UPDATED FOR v3.6:
// - Builds conversation history from current messages
// - Passes history to service
// - Maintains conversation context for follow-up questions
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/chat_message_model.dart';
import '../../data/chat_service.dart';

// ─── States ───────────────────────────────────────────────────────────────────

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatSending extends ChatState {
  final List<ChatMessageModel> messages;
  const ChatSending(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatLoaded extends ChatState {
  final List<ChatMessageModel> messages;
  final List<Map<String, dynamic>> restaurants;

  const ChatLoaded({
    required this.messages,
    required this.restaurants,
  });

  @override
  List<Object?> get props => [messages, restaurants];
}

class ChatError extends ChatState {
  final List<ChatMessageModel> messages;
  final String errorMessage;

  const ChatError({
    required this.messages,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [messages, errorMessage];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

class ChatCubit extends Cubit<ChatState> {
  final ChatService _chatService;

  ChatCubit(ChatService chatService)
      : _chatService = chatService,
        super(const ChatInitial());

  /// Sends a message and updates state with response + restaurants
  ///
  /// v3.6 NEW: Builds conversation history from current messages
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

    // Remove typing indicators if any exist before adding user message
    currentMessages.removeWhere((m) => m.isTyping);

    // Add user message to state immediately (optimistic update)
    currentMessages.add(
      ChatMessageModel.user(message),
    );

    // Add typing indicator
    currentMessages.add(ChatMessageModel.typing());

    emit(ChatSending(List.from(currentMessages)));

    try {
      // v3.6 NEW: Build conversation history from current messages
      final conversationHistory = _buildConversationHistory(currentMessages);

      // Call service with conversation history
      final response = await _chatService.sendMessage(
        message: message,
        conversationHistory: conversationHistory,
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

      // Remove typing indicator
      currentMessages.removeWhere((m) => m.isTyping);

      // Parse response
      final reply = (response['reply'] as String?)?.trim() ?? 'No response';
      final modelUsed = response['model_used'] ?? 'Unknown';
      // Note: language parsed but unused in UI
      // final language = response['language'] ?? 'english';
      final isOnTopic = response['is_on_topic'] ?? true;
      final restaurants =
          (response['restaurants'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

      // Explainability fields from response
      final rawRelaxed = response['relaxed_criteria'] as List<dynamic>? ?? [];
      final relaxedCriteria = rawRelaxed.map((e) => e.toString()).toList();
      final hasPartialMatch = response['has_partial_match'] as bool? ?? false;
      final searchUsed = response['search_used'] as bool? ?? false;

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

      // Update state with bot response + restaurants
      emit(
        ChatLoaded(
          messages: List.from(currentMessages),
          restaurants: restaurants,
        ),
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
    }
  }

  /// v3.6 NEW: Build conversation history from messages
  ///
  /// Extracts role and content from chat messages to pass to API
  /// for conversation context in follow-up questions.
  List<Map<String, String>> _buildConversationHistory(
    List<ChatMessageModel> messages,
  ) {
    return messages
        .where((msg) => !msg.isTyping && !msg.isError)
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          },
        )
        .toList();
  }

  /// Clear all chat messages and return to initial state
  void clearChat() {
    emit(const ChatInitial());
  }

  List<ChatMessageModel> get currentMessages {
    final s = state;
    if (s is ChatLoaded) return s.messages;
    if (s is ChatSending) return s.messages;
    if (s is ChatError) return s.messages;
    return [];
  }

  bool get isSending => state is ChatSending;
}
