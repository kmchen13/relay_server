import 'dart:convert';
import 'dart:io';
import 'package:relay_server/services/utility.dart';
import 'package:relay_server/player_entry.dart';

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

    //supprimer l'entrée si elle existe'
    repo.removePlayerEntry(
      userName,
      partner,
    );

    //créer une entrée avec le message de quit pour le partenaire
    final message = {
      'type': 'quit',
      'from': userName,
      'to': partner,
    };

    final partnerEntry = PlayerEntry(
      userName: partner,
      expectedName: '',
      language: 'fr',
      startTime: DateTime.now().millisecondsSinceEpoch,
      partner: userName,
      partnerStartTime: 0,
      message: message,
    );

    await repo.upsertPlayer(partnerEntry);

    jsonResponse(req.response, {'status': 'quit_success'});
    if (debug) {
      print("[$appName v$version] 🛑 $userName a quitté la partie");
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
