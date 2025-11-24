import 'dart:io';
import '../utils/json_utils.dart';
import '../services/player_repository.dart';

Future<void> handleAck(HttpRequest req, PlayerRepository repo) async {
  final userName = req.uri.queryParameters['userName'] ?? '';
  final partner = req.uri.queryParameters['partner'] ?? '';
  if (userName.isEmpty || partner.isEmpty) {
    return jsonResponse(
        req.response,
        {
          'error': 'missing_parameters',
        },
        statusCode: HttpStatus.badRequest);
  }
  repo.removePlayerGame(userName, partner);
  jsonResponse(req.response, {'status': 'ok'});
}
