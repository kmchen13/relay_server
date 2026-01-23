import 'dart:io';
import '../services/player_repository.dart';

Future<void> handleDisconnect(HttpRequest req, PlayerRepository repo) async {
  final user = req.uri.queryParameters['user'];

  if (user == null || user.isEmpty) {
    req.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing user');
    await req.response.close();
    return;
  }

  repo.removePlayerEntry(user, '');

  req.response
    ..statusCode = HttpStatus.ok
    ..write('ok');

  await req.response.close();
}
