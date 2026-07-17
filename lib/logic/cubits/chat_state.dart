part of 'chat_cubit.dart';

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

  const ChatLoaded({required this.messages, required this.restaurants});

  @override
  List<Object?> get props => [messages, restaurants];
}

class ChatError extends ChatState {
  final List<ChatMessageModel> messages;
  final String errorMessage;

  const ChatError({required this.messages, required this.errorMessage});

  @override
  List<Object?> get props => [messages, errorMessage];
}
