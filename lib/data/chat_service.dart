// ============================================================
// FILE: lib/data/chat_service.dart
//
// HTTP service for the /chat endpoint on your Flask API.
//
// v3.1 CHANGES:
//   - Returns full response map including relaxed_criteria,
//     has_partial_match, and matched_filters per restaurant
//     so ChatCubit + ChatScreen can render explainability chips.
// ============================================================

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../core/app_constants.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  /// POSTs the user's message + all preference flags to Flask /chat.
  ///
  /// Returns the full decoded response map:
  ///   {
  ///     "reply":             String,
  ///     "restaurants":       List<Map>,   ← now includes matched_filters
  ///     "model_used":        String,
  ///     "search_used":       bool,
  ///     "search_query":      String,
  ///     "intent":            String,
  ///     "relaxed_criteria":  List<String>,
  ///     "has_partial_match": bool,
  ///   }
  Future<Map<String, dynamic>> sendMessage({
    required String message,
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
      // Only send true values to keep the payload clean
      final body = <String, dynamic>{'message': message};
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
        'ChatService → POST ${ApiConfig.baseUrl}/chat  body=$body',
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
        return jsonDecode(response.body) as Map<String, dynamic>;
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
