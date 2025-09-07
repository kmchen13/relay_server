import 'dart:developer';
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

    print(
        "[$appName v$version] 📡 /poll $userName (message? ${withMsg.message != null})");

    if (withMsg.userName.isEmpty) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    final msg = withMsg.message!;
    withMsg.message = null;
    await savePlayers();

    switch (msg['type']) {
      case 'matched':
      case 'quit':
        jsonResponse(req.response, msg);
        break;

      case 'gameState':
        jsonResponse(req.response, {
          'type': 'gameState',
          'message': msg['message'],
          'from': msg['from'],
          'gameId': msg['gameId'],
        });
        break;

      case 'gameOver':
        final gameId = msg['gameId'] ?? '';
        jsonResponse(req.response, msg);
        if (gameId.isNotEmpty) {
          deleteGameId(gameId);
        }
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
