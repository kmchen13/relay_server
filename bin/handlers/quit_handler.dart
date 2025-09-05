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

    final me = players.firstWhere(
      (p) => p.userName == userName,
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    if (me.userName.isEmpty) {
      jsonResponse(req.response, {'status': 'not_found'});
      return;
    }

    // Prévenir le partenaire s'il existe
    if (me.partner.isNotEmpty) {
      queueMessageFor(me.partner, {
        'type': 'quit',
        'gameId': me.gameId,
        'from': me.userName,
      });

      // Supprimer le partenaire
      players.removeWhere((p) => p.userName == me.partner);
    }

    // Supprimer le joueur
    players.removeWhere((p) => p.userName == me.userName);

    await savePlayers();
    if (debug) showPlayers();

    jsonResponse(req.response, {'status': 'quit_success'});
    print("[$appName v$version] 🛑 ${me.userName} a quitté la partie");
  } catch (e) {
    jsonResponse(
        req.response, {'error': 'invalid_request', 'details': e.toString()},
        statusCode: HttpStatus.badRequest);
  }
}
