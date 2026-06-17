import 'dart:convert';
import 'dart:io';

import '../services/messages_repository.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleQuit(
  HttpRequest req,
  PlayersRepository repo,
) async {
  try {
    final body = await utf8.decoder.bind(req).join();

    final data = jsonDecode(body) as Map<String, dynamic>;

    final String user = (data['user'] ?? '').toString();
    final String partner = (data['partner'] ?? '').toString();

    if (user.isEmpty || partner.isEmpty) {
      jsonResponse(
        req.response,
        {'status': 'ERROR', 'message': 'Invalid_quit_parameters'},
      );

      if (debug) {
        print(
          "[$appName v$version] 🔔 Invalid_quit_parameters $data",
        );
      }

      return;
    }

    if (debug) {
      print(
        "[$appName v$version] 🔔 /quit $user → $partner",
      );
    }

    // Nettoyage éventuel des messages de partie
    await repo.deleteGameMessages(
      user,
      partner,
    );

    // Message envoyé au partenaire
    await repo.insertMessage(
      user: partner,
      partner: user,
      type: 'GAMEQUIT',
      message: jsonEncode({
        'from': user,
        'to': partner,
      }),
    );

    jsonResponse(
      req.response,
      {
        'status': 'QUIT_SUCCESS',
      },
    );

    if (debug) {
      print(
        "[$appName v$version] 🛑 $user a quitté la partie",
      );
    }
  } catch (e, s) {
    jsonResponse(
      req.response,
      {
        'error': 'invalid_request',
        'details': e.toString(),
        'stack': s.toString(),
      },
      statusCode: HttpStatus.badRequest,
    );
  }
}
