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

    final msg = target.message!;
    target.message = null;
    await repo.upsertPlayer(target); // sauvegarder la suppression du message

    switch (msg['type']) {
      case 'matched':
      case 'quit':
        if (debug) {
          print(
              "Message ${msg['type']} sent to $userName from '${msg['partner']}'");
        }
        jsonResponse(req.response, msg);
        break;

      case 'gameState':
        jsonResponse(req.response, {
          'type': 'gameState',
          'message': msg['message'],
          'from': msg['from'],
        });
        if (debug) {
          print(
              "Message ${msg['type']} sent to $userName from '${msg['partner']}'");
        }
        break;

      case 'gameOver':
        jsonResponse(req.response, msg);
        final from = msg['from'];
        final to = msg['to'];
        await repo.removePlayerGame(from, to);
        break;

      case 'message':
        jsonResponse(req.response, {
          'type': 'message',
          'message': msg,
        });
        break;

      default:
        jsonResponse(req.response, {
          'type': 'type_inconnu',
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
      statusCode: HttpStatus.badRequest,
    );
  }
}
