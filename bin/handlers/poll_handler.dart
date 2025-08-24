import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../player_entry.dart';

Future<void> handlePoll(HttpRequest req) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final withMsg = players.firstWhere(
      (p) => p.userName == userName && p.message != null,
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    // print("[$appName v$version] 📡 /poll $userName (message? ${withMsg.message != null})");

    if (withMsg.userName.isEmpty) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    final msg = withMsg.message!;
    withMsg.message = null;

    if (msg['type'] == 'matched') {
      jsonResponse(req.response, msg);
    } else if (msg['type'] == 'gameState') {
      jsonResponse(req.response, {
        'type': 'gameState',
        'message': msg['payload'],
        'from': msg['from'],
        'gameId': msg['gameId'],
      });
    } else {
      jsonResponse(req.response, {
        'type': 'message',
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
