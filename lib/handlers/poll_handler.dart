import 'dart:io';
import '../constants.dart';
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

    // Cherche un message en attente pour ce joueur
    final target = await repo.getPlayer(userName);

    if (target == null || target.message == null) {
      jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    // Envoie le message. L'entrée sera supprimée lors de l'acknowledgement.
    final msg = target.message!;
    jsonResponse(req.response, msg);
    if (debug) {
      print(
          "[$appName v$version] Poll: ${msg['type']} sent to ${target.userName} from '${target.partner}'");
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
