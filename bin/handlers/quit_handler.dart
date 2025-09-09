import 'dart:convert';
import 'dart:io';
import '../player_entry.dart';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleQuit(HttpRequest req) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String userName = (data['userName'] ?? '').toString();
    final String partner = (data['partner'] ?? '').toString();

    if (userName.isEmpty || partner.isEmpty) {
      jsonResponse(req.response, {'status': 'Invalid_quit_parameters'});
      print("[$appName v$version] 🔔 Invalid_quit_parameters '$data'");
      return;
    } else if (debug) {
      print("[$appName v$version] 🔔 /quit $userName - $partner");
    }
    final gameInCourse = findInGame(userName, partner);

    if (gameInCourse == null) {
      jsonResponse(req.response, {'status': 'player_not_found'});
      return;
    }
    removePlayerGame(gameInCourse, partner);

    // Prévenir le partenaire s'il existe
    if (gameInCourse.partner.isNotEmpty) {
      queueMessageFor(gameInCourse.partner, {
        'type': 'quit',
        'gameId': gameInCourse.gameId,
        'from': gameInCourse.userName,
      });
    }
    jsonResponse(req.response, {'status': 'quit_success'});
    if (debug)
      print(
          "[$appName v$version] 🛑 ${gameInCourse.userName} a quitté la partie");
  } catch (e) {
    jsonResponse(
        req.response, {'error': 'invalid_request', 'details': e.toString()},
        statusCode: HttpStatus.badRequest);
  }
}
