import 'dart:io';
import 'dart:convert';
import '../services/player_repository.dart';

Future<void> handleQuit(HttpRequest req, MessageRepository repo) async {
  final body = await utf8.decoder.bind(req).join();
  final data = jsonDecode(body);

  final user = data['userName'];
  final partner = data['partner'];
  final type = data['type']; // QUITAPP ou TIMEOUT

  repo.deleteMessage(user, '');
  await repo.sendMessage(partner, user, type, '');

  jsonResponse(req.response, {'status': 'ok'});
}
