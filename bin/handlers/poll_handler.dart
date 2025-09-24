import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../player_entry.dart';
import '../constants.dart';

Future<void> handlePoll(HttpRequest req) async {
  await loadPlayers();
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final withMsg = players.firstWhere(
      (p) => p.userName == userName && p.message != null,
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    // print(
    //     "[$appName v$version] 📡 /poll $userName (message? ${withMsg.message != null})");

    if (withMsg.userName.isEmpty) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    final msg = withMsg.message!;
    withMsg.message = null;
    savePlayers();

    switch (msg['type']) {
      case 'matched':
      case 'quit':
        if (debug)
          print(
              "Message ${msg['type']} sent to $userName from '${msg['partner']}'");
        jsonResponse(req.response, msg);
        break;

      case 'gameState':
        jsonResponse(req.response, {
          'type': 'gameState',
          'message': msg['message'],
          'from': msg['from'],
        });
        if (debug)
          print(
              "Message ${msg['type']} sent to $userName from '${msg['partner']}'");
        break;

      case 'gameOver':
        jsonResponse(req.response, msg);
        final from = msg['from'];
        final to = msg['to'];
        removePlayerGame(from, to);
        break;

      case 'message':
        jsonResponse(req.response, {
          'type': 'message',
          'message': msg,
        });
        break;

      default:
        jsonResponse(req.response, {
          'type': 'type_inconnu',
          'message': msg,
        });
    }
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
