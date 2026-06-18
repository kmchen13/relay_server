import 'dart:io';
import '../constants.dart';
import '../services/messages_repository.dart';

Future<void> handleDisconnect(
  HttpRequest req,
  PlayersRepository repo,
) async {
  final user = req.uri.queryParameters['user'];

  if (user == null || user.isEmpty) {
    req.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing user');

    await req.response.close();
    return;
  }

  await repo.deletePendingConnect(user);

  if (debug) {
    print(
      '[$appName v$version] disconnect $user : CONNECT supprimés',
    );
  }

  req.response
    ..statusCode = HttpStatus.ok
    ..write('ok');

  await req.response.close();
}
