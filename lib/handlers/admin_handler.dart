import 'dart:io';
import '../utils/player_utils.dart';
import '../services/player_repository.dart';
import '../constants.dart';
import '../utils/json_utils.dart';
import 'dart:convert';

Future<void> handleAdmin(HttpRequest req, MessageRepository repo) async {
  switch (req.uri.path) {
    case '/admin/clear' when req.method == 'POST':
      // Supprimer tous les joueurs dans la BDD
      await repo.clearAllPlayers();
      break;

    case '/admin/entryDelete' when req.method == 'POST':
      final content = await utf8.decodeStream(req);
      final formData = Uri.splitQueryString(content);

      final String userName = formData['userName'] ?? '';
      final String partner = formData['partner'] ?? '';

      if (userName.isEmpty) {
        jsonResponse(req.response, {'status': 'Invalid_parameters'});
        return;
      }
      if (userName.isEmpty) {
        print(
            "[$appName v$version] 🔔 /admin/entryDelete: missing parameter player='$userName'");
        return jsonResponse(
            req.response,
            {
              'status': 'error: missing_parameters',
            },
            statusCode: HttpStatus.badRequest);
      }
      await repo.deleteMessage(userName, partner);
      print(
          "[$appName v$version] 🔔 /entryDelete: Entry '$userName-$partner' deleted");
  }

  // Page admin par défaut

  req.response.statusCode = HttpStatus.ok;
  req.response.headers.contentType = ContentType.html;
  req.response.write(await showPlayersAsHTML(repo));
  await req.response.close();
}
