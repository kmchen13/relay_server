import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';

Future<void> handleDisconnect(HttpRequest req) async {
  final userName = req.uri.queryParameters['userName'] ?? '';

  if (userName == '') {
    req.response.statusCode = HttpStatus.badRequest;
    return jsonResponse(req.response, {
      'error': 'missing_parameters',
      'message': 'userName et expectedName sont requis',
    });
  }
  players.removeWhere((p) => p.userName == userName && p.expectedName == '');
  savePlayers();

  req.response.statusCode = HttpStatus.ok;
  return jsonResponse(req.response, {
    'status': 'disconnected',
    'message': '$userName déconnecté avec succès',
  });
}
