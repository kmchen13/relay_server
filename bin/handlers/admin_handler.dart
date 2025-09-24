import 'dart:io';
import '../utils/player_utils.dart';

Future<void> handleAdmin(HttpRequest req) async {
  if (req.uri.path == '/admin/clear' && req.method == 'POST') {
    players.clear();
    await savePlayers();

    // Redirection HTTP vers /admin
    req.response.statusCode = HttpStatus.found; // 302
    req.response.headers.set(HttpHeaders.locationHeader, '/admin');
    await req.response.close();
    return;
  }

  // page admin par défaut
  req.response.statusCode = HttpStatus.ok;
  req.response.headers.contentType = ContentType.html;
  req.response.write(showPlayersAsHTML());
  await req.response.close();
}
