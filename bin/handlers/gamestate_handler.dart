import 'dart:convert';
import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../player_entry.dart';
import '../constants.dart';

Future<void> handleGameState(HttpRequest req) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String from = (data['from'] ?? '').toString();
    final String to = (data['to'] ?? '').toString();
    final message = data['message'];

    if (debug)
      print("[$appName v$version] 🎲 /gamestate de $from → $to \n\n$message");

    final target = players.lastWhere(
      (p) =>
          p.userName == to &&
          (p.partner == from ||
              p.expectedName == from ||
              p.expectedName.isEmpty),
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    if (target.userName.isEmpty) {
      jsonResponse(
          req.response,
          {
            'status': 'partner_not_found',
            'message': 'Partenaire non trouvé',
          },
          statusCode: HttpStatus.notFound);
      showPlayers();
      return;
    }

    queueMessageFor(to, from, {
      'type': 'gameState',
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
        statusCode: HttpStatus.badRequest);
  }
}
