import 'dart:io';
import '../constants.dart';
import '../utils/json_utils.dart';
import '../services/player_repository.dart';

Future<void> handleAck(HttpRequest req, PlayerRepository repo) async {
  final userName = req.uri.queryParameters['userName'] ?? '';
  final partner = req.uri.queryParameters['partner'] ?? '';
  final type = req.uri.queryParameters['type'] ?? '';
  if (userName.isEmpty) {
    print(
        "[$appName v$version] 🔔 /ack error: missing parameter player='$userName'");
    return jsonResponse(
        req.response,
        {
          'status': 'error: missing_parameters',
        },
        statusCode: HttpStatus.badRequest);
  }
  repo.removePlayerEntry(userName, partner);
  if (type == 'quit') {
    // Si c'est un quit, on supprime aussi l'entrée du partenaire
    repo.removePlayerEntry(partner, userName);
  }
  jsonResponse(req.response, {'status': 'ok'});
  if (debug) {
    print("[$appName v$version] 🔔 /ack player=$userName partner=$partner");
  }
}
