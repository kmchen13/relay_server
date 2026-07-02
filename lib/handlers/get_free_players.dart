import 'dart:io';
import 'dart:convert';

import '../services/messages_repository.dart';
import '../constants.dart';
import '../utils/json_utils.dart';
import '../utils/player_utils.dart';

Future<void> getFreePlayersList(HttpRequest req, PlayersRepository repo) async {
  try {
    final freePlayers = await repo.getFreePlayers();

    jsonResponse(
      req.response,
      {
        'status': 'success',
        'players': freePlayers,
      },
      statusCode: HttpStatus.ok,
    );
  } catch (e, st) {
    if (debug) {
      print("[$appName v$version] ❌ Erreur getFreePlayersList: $e");
      print(st);
    }
    jsonResponse(
      req.response,
      {
        'error': 'server_error',
        'details': e.toString(),
      },
      statusCode: HttpStatus.internalServerError,
    );
  }
}
