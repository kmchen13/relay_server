import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleDisconnect(HttpRequest req) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final gameId = req.uri.queryParameters['gameId'];

    if (gameId != null && gameId.isNotEmpty) {
      players.removeWhere((p) => p.userName == userName && p.gameId == gameId);
    } else {
      players.removeWhere((p) => p.userName == userName);
    }

    jsonResponse(req.response, {'status': 'disconnected'});
    await req.response.close();

    if (debug) {
      print("[$appName v$version] ❌ /disconnect $userName (gameId=$gameId)");
      showPlayers();
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
