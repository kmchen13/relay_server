import 'dart:io';
import '../constants.dart';
import '../utils/player_utils.dart';
import '../services/player_repository.dart';
import '../utils/json_utils.dart';

Future<void> handlePoll(HttpRequest req, MessageRepository repo) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final language = req.uri.queryParameters['language'] ?? '';

    if (userName.isEmpty) {
      jsonResponse(
        req.response,
        {
          'error': 'missing_userName',
          'message': 'Paramètre userName manquant',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    if (debug) {
      print("[$appName v$version] Poll reçu de '$userName'");
    }

    // Récupérer les joueurs libres
    final freePlayers = await repo.getFreePlayers(language, userName);

    // Cherche un message en attente
    final incomingMessage = await getMessage(repo, userName);

    if (incomingMessage == null) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
        'freePlayers': freePlayers,
      });
      return;
    }

    // Injecter freePlayers dans la réponse
    final response = Map<String, dynamic>.from(incomingMessage.message);
    response['freePlayers'] = freePlayers;

    jsonResponse(req.response, response);

    if (debug) {
      print(
        "[$appName v$version] Poll: ${incomingMessage.type} from '${incomingMessage.partner}'",
      );
    }
  } catch (e) {
    jsonResponse(
      req.response,
      {
        'error': 'invalid_request',
        'details': e.toString(),
      },
      statusCode: HttpStatus.badRequest,
    );
    if (debug)
      print("[$appName v$version] ❌ Exception dans handlePoll: $e.message");
  }
}
