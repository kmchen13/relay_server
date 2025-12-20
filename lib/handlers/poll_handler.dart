import 'dart:io';
import '../constants.dart';
import '../utils/player_utils.dart';
import '../services/player_repository.dart';
import '../utils/json_utils.dart';

Future<void> handlePoll(HttpRequest req, PlayerRepository repo) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    if (userName.isEmpty) {
      jsonResponse(
          req.response,
          {
            'error': 'missing_userName',
            'message': 'Paramètre userName manquant',
          },
          statusCode: HttpStatus.badRequest);
      return;
    }
    if (debug) {
      print("[$appName v$version] Poll reçu de '$userName'");
    }
    // Cherche un message en attente pour ce joueur
    final incomingMessage = await getMessage(repo, userName);

    if (incomingMessage == null) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    // Envoie le message. L'entrée sera supprimée lors de l'acknowledgement.
    jsonResponse(req.response, incomingMessage.message);
    if (debug) {
      print(
          "[$appName v$version] Poll: ${incomingMessage.type} from '${incomingMessage.partner}'");
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
