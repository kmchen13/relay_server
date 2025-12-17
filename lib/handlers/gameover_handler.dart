import 'dart:convert';
import 'dart:io';
import '../constants.dart';
import '../services/player_repository.dart';
import '../utils/json_utils.dart';
import '../utils/player_utils.dart';

Future<void> handleGameOver(HttpRequest req, PlayerRepository repo) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String from = (data['from'] ?? '').toString();
    final String to = (data['to'] ?? '').toString();
    final message = data['message'];

    if (debug) print("[$appName v$version] 🏁 /gameover de $from → $to");

    // Mettre en file le message gameOver
    await queueMessageFor(repo, to, from, {
      'type': 'gameOver',
      'from': from,
      'to': to,
      'message': message,
    });

    jsonResponse(req.response, {'status': 'sent'});
  } catch (e) {
    jsonResponse(
      req.response,
      {
        'error': 'invalid_request',
        'details': e.toString(),
      },
      statusCode: HttpStatus.badRequest,
    );
  }
}
