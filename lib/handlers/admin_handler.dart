import 'dart:io';
import 'dart:convert';

import '../services/messages_repository.dart';
import '../constants.dart';
import '../utils/json_utils.dart';
import '../utils/player_utils.dart';

Future<void> handleAdmin(
  HttpRequest req,
  PlayersRepository repo,
) async {
  bool refresh = false;

  switch (req.uri.path) {
    case '/admin/clear' when req.method == 'POST':
      await repo.clear();

      if (debug) {
        print(
          "[$appName v$version] 🧹 messages table cleared",
        );
      }

      refresh = true;
      break;

    case '/admin/entryDelete' when req.method == 'POST':
      final content = await utf8.decodeStream(req);
      final formData = Uri.splitQueryString(content);

      final user = formData['user'] ?? '';
      final partner = formData['partner'] ?? '';
      final dateStr = formData['date'] ?? '';

      final date = int.tryParse(dateStr);

      if (user.isEmpty || date == null) {
        jsonResponse(
          req.response,
          {
            'status': 'error',
            'message': 'missing parameters',
          },
          statusCode: HttpStatus.badRequest,
        );
        return;
      }

      await repo.deleteMessage(
        user,
        partner.isEmpty ? null : partner,
        date,
      );

      if (debug) {
        print(
          "[$appName v$version] 🗑 message supprimé "
          "$user/$partner/$date",
        );
      }

      refresh = true;
      break;
  }

  // traitement commun des POST admin
  if (refresh) {
    req.response.statusCode = HttpStatus.seeOther;

    req.response.headers.set(
      HttpHeaders.locationHeader,
      '/admin/players',
    );

    await req.response.close();
    return;
  }

  // affichage normal GET /admin/players

  req.response.statusCode = HttpStatus.ok;

  req.response.headers.contentType = ContentType.html;

  req.response.write(
    await showMessagesAsHTML(repo),
  );

  await req.response.close();
}
