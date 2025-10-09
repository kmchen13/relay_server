import 'dart:convert';
import 'dart:io';
import '../services/player_repository.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleQuit(HttpRequest req, PlayerRepository repo) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String userName = (data['userName'] ?? '').toString();
    final String partner = (data['partner'] ?? '').toString();

    if (userName.isEmpty || partner.isEmpty) {
      jsonResponse(req.response, {'status': 'Invalid_quit_parameters'});
      if (debug)
        print("[$appName v$version] 🔔 Invalid_quit_parameters '$data'");
      return;
    } else if (debug) {
      print("[$appName v$version] 🔔 /quit $userName - $partner");
    }

    // Chercher le joueur dans la BDD
    final gameInCourse = await repo.getPlayer(userName);

    if (gameInCourse == null || gameInCourse.partner != partner) {
      jsonResponse(req.response, {'status': 'player_not_found'});
      return;
    }

    // Supprimer l’entrée du joueur qui quitte
    await repo.removePlayerGame(userName, partner);

    // Prévenir le partenaire s'il existe
    if (gameInCourse.partner.isNotEmpty) {
      final partnerEntry = await repo.getPlayer(gameInCourse.partner);
      if (partnerEntry != null) {
        partnerEntry.message = {
          'type': 'quit',
          'from': gameInCourse.userName,
          'to': gameInCourse.partner,
        };
        await repo.upsertPlayer(partnerEntry);
      }
    }

    jsonResponse(req.response, {'status': 'quit_success'});
    if (debug) {
      print(
          "[$appName v$version] 🛑 ${gameInCourse.userName} a quitté la partie");
    }
  } catch (e, s) {
    jsonResponse(
      req.response,
      {
        'error': 'invalid_request',
        'details': e.toString(),
        'stack': s.toString()
      },
      statusCode: HttpStatus.badRequest,
    );
  }
}
