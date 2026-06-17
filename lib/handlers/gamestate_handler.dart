import 'dart:convert';
import 'dart:io';

import '../services/messages_repository.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleGameState(
  HttpRequest req,
  PlayersRepository repo,
) async {
  try {
    final body = await utf8.decoder.bind(req).join();

    final data = jsonDecode(body) as Map<String, dynamic>;

    final user = data['user']?.toString() ?? '';
    final partner = data['partner']?.toString() ?? '';

    var message = data['message'];

    if (message is String) {
      message = jsonDecode(message);
    }

    if (user.isEmpty || partner.isEmpty) {
      jsonResponse(
        req.response,
        {'status': 'ERROR', 'message': 'missing user or partner'},
        statusCode: 400,
      );
      return;
    }

    if (debug) {
      print("[$appName v$version] 🎲 /gamestate $user → $partner");
    }

    await repo.insertMessage(
      user: partner,
      partner: user,
      type: 'GAMESTATE',
      message: jsonEncode(message),
    );

    jsonResponse(
      req.response,
      {'status': 'SENT'},
    );
  } catch (e, st) {
    if (debug) {
      print("[$appName v$version] ❌ /gamestate $e");
      print(st);
    }

    jsonResponse(
      req.response,
      {'status': 'ERROR', 'message': e.toString()},
      statusCode: 500,
    );
  }
}
