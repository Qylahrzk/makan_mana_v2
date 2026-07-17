// ============================================================
// FILE: lib/data/services/chat_service.dart
//
// HTTP service for the /chat endpoint on Flask API v4.2
//
// UPDATED FOR v4.2 PRODUCTION STABILITY:
// - Standardized Constructor initialization layout parameters
// - Binds with ChatCubit context aggregation logic natively
// - Preserves all network failure and Render sleep time boundaries
// ============================================================

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../../core/app_constants.dart';

class ChatService {
  // v4.2 PRODUCTION FIX: Support BOTH singleton design profile instances
  // AND standard custom constructor dependency injection trees to match ChatCubit.
  ChatService();

  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  /// POSTs the user's message + conversation history + preference flags to Flask /chat.
  ///
  /// v4.2 PRODUCTION: Carries context-aware string payloads cleanly to prevent data loss.
  ///
  /// Returns the full decoded response map from the backend API:
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
  ///     "language":            String,
  ///   }
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    // Dietary Flags
    bool halal = false,
    bool vegetarian = false,
    bool vegan = false,
    // Facility Flags
    bool parking = false,
    bool wifi = false,
    bool ac = false,
    bool outdoor = false,
    bool accessible = false,
    // Vibe Flags
    bool familyFriendly = false,
    bool groupFriendly = false,
    bool casual = false,
    bool romantic = false,
    bool scenicView = false,
    // Service Quality Flags
    bool worthIt = false,
    bool fastService = false,
  }) async {
    try {
      // Build raw data tracking frame payload dictionary
      final body = <String, dynamic>{'message': message};

      // Extract conversation loops context metrics
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        body['conversation_history'] = conversationHistory;
        log(
          'ChatService → Context active: (${conversationHistory.length} turns in payload history array)',
          name: 'ChatService',
        );
      }

      // Populate valid data states to prevent payload bloat
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
        'ChatService → POST request dispatched to target path: ${ApiConfig.baseUrl}/chat',
        name: 'ChatService',
      );

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      log(
        'ChatService ← Server connection confirmation state returned: ${response.statusCode}',
        name: 'ChatService',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        log(
          'ChatService → Active parsing context language output signature: ${data['language'] ?? 'english'}',
          name: 'ChatService',
        );
        return data;
      } else if (response.statusCode == 503) {
        // Handle Render platform sleep routine wake bounds
        throw 'The server is waking up from sleep. '
            'Please wait 30 seconds and try again.';
      } else {
        throw 'Server error execution warning code: ${response.statusCode}. Please try again.';
      }
    } on http.ClientException {
      throw 'No internet connection detected. Check your network and try again.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Could not process server data connection frames. Please try again.';
    }
  }
}
