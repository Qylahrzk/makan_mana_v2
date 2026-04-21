// ============================================================
// FILE: lib/logic/cubits/chat_cubit.dart
//
// Updated: ChatMessageModel.ai() now receives restaurants list
// from the API response so they render as cards in chat_screen.
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
  const ChatLoaded(this.messages);
  @override
  List<Object?> get props => [messages];
}

class ChatError extends ChatState {
  final List<ChatMessageModel> messages;
  const ChatError(this.messages);
  @override
  List<Object?> get props => [messages];
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

class ChatCubit extends Cubit<ChatState> {
  final ChatService _service;
  final List<ChatMessageModel> _messages = [];

  ChatCubit(this._service) : super(const ChatInitial());

  Future<void> sendMessage(
    String text, {
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
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(ChatMessageModel.user(trimmed));
    _messages.add(ChatMessageModel.typing());
    emit(ChatSending(List.from(_messages)));

    try {
      final response = await _service.sendMessage(
        message: trimmed,
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

      _messages.removeWhere((m) => m.isTyping);

      final reply =
          (response['reply'] as String?)?.trim() ??
          'Sorry, I could not understand that. Please try again.';

      // Extract restaurant list from the API response for mini-cards
      final rawList = response['restaurants'] as List<dynamic>? ?? [];
      final restaurants = rawList.whereType<Map<String, dynamic>>().toList();

      _messages.add(ChatMessageModel.ai(reply, restaurants: restaurants));
      emit(ChatLoaded(List.from(_messages)));
    } catch (e) {
      _messages.removeWhere((m) => m.isTyping);
      _messages.add(ChatMessageModel.error(e.toString()));
      emit(ChatError(List.from(_messages)));
    }
  }

  void clearChat() {
    _messages.clear();
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
