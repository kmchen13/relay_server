import 'dart:convert';
import 'dart:io';

import '../constants.dart';
import '../services/messages_repository.dart';
import '../utils/json_utils.dart';

Future<void> handleGameOver(
  HttpRequest req,
  PlayersRepository repo,
) async {
  try {
    final body = await utf8.decoder.bind(req).join();

    final data = jsonDecode(body) as Map<String, dynamic>;

    final String user = (data['user'] ?? data['from'] ?? '').toString();

    final String partner = (data['partner'] ?? data['to'] ?? '').toString();

    var message = data['message'];

    if (message is String) {
      message = jsonDecode(message);
    }

    if (user.isEmpty || partner.isEmpty) {
      jsonResponse(
        req.response,
        {
          'status': 'ERROR',
          'message': 'missing user or partner',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    if (debug) {
      print(
        "[$appName v$version] 🏁 /gameover $user → $partner",
      );
    }

    await repo.insertMessage(
      user: partner,
      partner: user,
      type: 'GAMEOVER',
      message: jsonEncode(message),
    );

    jsonResponse(
      req.response,
      {'status': 'SENT'},
    );
  } catch (e, st) {
    if (debug) {
      print(
        "[$appName v$version] ❌ /gameover $e",
      );
      print(st);
    }

    jsonResponse(
      req.response,
      {
        'status': 'ERROR',
        'message': e.toString(),
      },
      statusCode: HttpStatus.internalServerError,
    );
  }
}
