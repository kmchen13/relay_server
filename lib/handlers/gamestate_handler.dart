import 'dart:convert';
import 'dart:io';
import '../services/player_repository.dart';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleGameState(HttpRequest req, PlayerRepository repo) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String from = (data['from'] ?? '').toString();
    final String to = (data['to'] ?? '').toString();
    var message = data['message'];
    if (message is String) {
      message = jsonDecode(message);
    }

    if (debug) {
      print("[$appName v$version] 🎲 /gamestate de $from → $to");
    }

    // 🔹 Vérifier si le partenaire a un quit en attente
    final partnerEntry = await repo.getPlayer(to);
    final hasQuitPending = partnerEntry?.message != null &&
        partnerEntry!.message!['type'] == 'quit';

    if (hasQuitPending) {
      if (debug) {
        print(
            "⚠️ Quit en attente pour $to → gamestate de $from ignoré pour cette partie");
      }
      jsonResponse(req.response, {'status': 'ignored_quit_pending'});
      return;
    }

    // Sinon, on met le gamestate en file normalement
    await queueMessageFor(repo, to, from, {
      'type': 'gameState',
      'from': from,
      'to': to,
      'message': jsonEncode(message),
    });

    jsonResponse(req.response, {'status': 'sent'});
  } catch (e) {
    if (debug) {
      print("[$appName v$version] ❌ Erreur /gamestate: $e");
    }
    jsonResponse(req.response, {'status': 'Error', 'message': e.toString()},
        statusCode: 500);
  }
}
