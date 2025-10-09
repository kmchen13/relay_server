import 'dart:convert';
import 'dart:io';
import '../services/player_repository.dart';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleGameState(HttpRequest req, PlayerRepository repo) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String from = (data['from'] ?? '').toString();
    final String to = (data['to'] ?? '').toString();
    var message = data['message'];
    if (message is String) {
      message = jsonDecode(message);
    }
    if (debug) {
      print("[$appName v$version] 🎲 /gamestate de $from → $to \n\n $message");
    }

    await queueMessageFor(repo, to, from, {
      'type': 'gameState',
      'from': from,
      'to': to,
      'message': jsonEncode(message), // ✅ re-stringification ici
    });
    jsonResponse(req.response, {'status': 'sent'});
  } catch (e) {
    if (debug) {
      print("[$appName v$version] ❌ Erreur /gamestate: $e");
    }
    jsonResponse(req.response, {'status': 'Error', 'message': e.toString()},
        statusCode: 500);
  }
}
