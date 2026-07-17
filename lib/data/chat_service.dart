// ============================================================
// FILE: lib/data/services/chat_service.dart
//
// HTTP service for the /chat endpoint on Flask API v3.6
//
// UPDATED FOR v3.6:
// - Added conversation_history parameter
// - Sends full conversation context with each message
// - Maintains all existing error handling
// ============================================================

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../../core/app_constants.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  /// POSTs the user's message + conversation history + preference flags to Flask /chat.
  ///
  /// v3.6 NEW: Supports conversation_history for follow-up questions
  ///
  /// Returns the full decoded response map from v3.6 API:
  ///   {
  ///     "reply":               String,
  ///     "restaurants":         List<Map>,
  ///     "model_used":          String,
  ///     "search_used":         bool,
  ///     "search_query":        String,
  ///     "intent":              String,
  ///     "relaxed_criteria":    List<String>,
  ///     "has_partial_match":   bool,
  ///     "is_on_topic":         bool,
  ///     "language":            String,              ← v3.6 NEW
  ///   }
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    // v3.6 NEW: Conversation history for follow-ups
    List<Map<String, String>>? conversationHistory,
    // Dietary
    bool halal = false,
    bool vegetarian = false,
    bool vegan = false,
    // Facilities
    bool parking = false,
    bool wifi = false,
    bool ac = false,
    bool outdoor = false,
    bool accessible = false,
    // Vibes
    bool familyFriendly = false,
    bool groupFriendly = false,
    bool casual = false,
    bool romantic = false,
    bool scenicView = false,
    // Service
    bool worthIt = false,
    bool fastService = false,
  }) async {
    try {
      // Build request body with message + preferences
      final body = <String, dynamic>{'message': message};

      // v3.6: Add conversation history if provided
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        body['conversation_history'] = conversationHistory;
        log(
          'ChatService → Including conversation history (${conversationHistory.length} messages)',
          name: 'ChatService',
        );
      }

      // Add only true preference values to keep payload clean
      if (halal) body['halal'] = true;
      if (vegetarian) body['vegetarian'] = true;
      if (vegan) body['vegan'] = true;
      if (parking) body['parking'] = true;
      if (wifi) body['wifi'] = true;
      if (ac) body['ac'] = true;
      if (outdoor) body['outdoor'] = true;
      if (accessible) body['accessible'] = true;
      if (familyFriendly) body['family_friendly'] = true;
      if (groupFriendly) body['group_friendly'] = true;
      if (casual) body['casual'] = true;
      if (romantic) body['romantic'] = true;
      if (scenicView) body['scenic_view'] = true;
      if (worthIt) body['worth_it'] = true;
      if (fastService) body['fast_service'] = true;

      log(
        'ChatService → POST ${ApiConfig.baseUrl}/chat message_length=${message.length}',
        name: 'ChatService',
      );

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      log('ChatService ← ${response.statusCode}', name: 'ChatService');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        log(
          'ChatService → Language: ${data['language'] ?? 'english'}',
          name: 'ChatService',
        );
        return data;
      } else if (response.statusCode == 503) {
        throw 'The server is waking up from sleep. '
            'Please wait 30 seconds and try again.';
      } else {
        throw 'Server error ${response.statusCode}. Please try again.';
      }
    } on http.ClientException {
      throw 'No internet connection. Check your network and try again.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Could not reach the server. Please try again.';
    }
  }
}
