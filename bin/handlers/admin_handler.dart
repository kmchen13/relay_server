import 'dart:io';
import '../utils/player_utils.dart';
import '../services/player_repository.dart';

Future<void> handleAdmin(HttpRequest req, PlayerRepository repo) async {
  if (req.uri.path == '/admin/clear' && req.method == 'POST') {
    // Supprimer tous les joueurs dans la BDD
    await repo.clearAllPlayers();

    // Redirection HTTP vers /admin
    req.response.statusCode = HttpStatus.found; // 302
    req.response.headers.set(HttpHeaders.locationHeader, '/admin');
    await req.response.close();
    return;
  }

  // Page admin par défaut

  req.response.statusCode = HttpStatus.ok;
  req.response.headers.contentType = ContentType.html;
  req.response.write(await showPlayersAsHTML(repo));
  await req.response.close();
}
