import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

final List<Map<String, dynamic>> players = [];

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

  print(
      "[RELAY] Serveur HTTP polling sur http://${server.address.host}:${server.port}");

  await for (HttpRequest req in server) {
    if (req.method == 'POST' && req.uri.path == '/connect') {
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final userName = jsonData['userName'];
      final expected = jsonData['expectedName'];
      final startTime = jsonData['startTime'];

      // Chercher si ce joueur a déjà une partie avec le même expected
      Map<String, dynamic>? existing = players.firstWhereOrNull(
        (p) =>
            p['userName'] == userName &&
            p['expectedName'] == expected &&
            p['partner'] == '',
      );

      if (existing != null) {
        // S'il aun message en attente, l'envoyer
      } else {
        // Créer une nouvelle entrée pour cette partie
        players.add({
          'userName': userName,
          'expectedName': expected,
          'startTime': startTime,
          'partner': '',
          'gameId': '',
          'message': '',
        });
      }

      // Matchmaking uniquement avec joueurs sans partenaire
      final match = players.firstWhereOrNull((p) =>
              p['partner'] == '' &&
              p['userName'] != userName &&
              ((p['userName'] == expected && expected != '') ||
                  (expected == '' &&
                      p['expectedName'] == '')) // match aléatoire
          );

      if (match != null) {
        final gameId = DateTime.now().millisecondsSinceEpoch.toString();

        // Mettre à jour les deux entrées
        match['partner'] = userName;
        match['gameId'] = gameId;

        final me = players.firstWhere((p) =>
            p['userName'] == userName &&
            p['expectedName'] == expected &&
            p['partner'] == '');
        me['partner'] = match['userName'];
        me['gameId'] = gameId;

        // Répondre au joueur qui vient de se connecter
        req.response.write(jsonEncode({
          'status': 'matched',
          'gameId': gameId,
          'partner': match['userName']
        }));

        // Préparer le message "matched" uniquement pour le starter
        final starterEntry =
            players.firstWhere((p) => p['userName'] == match['username']);
        starterEntry['message'] = jsonEncode({
          'status': 'matched',
          'partner': userName,
          'gameId': gameId,
        });

        print(
            "[RELAY] Match trouvé entre $userName et ${match['userName']} (Game ID: $gameId)");
      } else {
        req.response.write(jsonEncode({'status': 'waiting'}));
      }

      await req.response.close();
    } else if (req.method == 'POST' && req.uri.path == '/send') {
      print("[RELAY] Message reçu de ${req.uri.queryParameters['from']}");
      print("[Message: ${req.uri.queryParameters['message']}");
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final from = jsonData['from'];
      final msg = jsonData['message'];

      final sender =
          players.firstWhere((p) => p['userName'] == from, orElse: () => {});
      if (sender.isNotEmpty) {
        final partnerName = sender['partner'];
        final partner = players.firstWhere((p) => p['userName'] == partnerName,
            orElse: () => {});
        if (partner.isNotEmpty) {
          partner['message'] = msg;
          req.response.write(jsonEncode({'status': 'sent'}));
          print("[RELAY] Message de $from envoyé à $partnerName");
        } else {
          req.response.write(jsonEncode({'status': 'partner_not_found'}));
        }
      }
      await req.response.close();
    } else if (req.method == 'GET' && req.uri.path == '/poll') {
      // Traitement polling
      final userName = req.uri.queryParameters['userName'] ?? '';
      final player = players.firstWhere((p) => p['userName'] == userName,
          orElse: () => {});
      if (player.isNotEmpty) {
        final hasMsg = player['message'] != '';
        // @todo implémenter la possibilité d'envoyer des messages; switch (player['message'])
        req.response.write(jsonEncode({
          'status': hasMsg ? 'gameState' : 'no_message',
          'message': player['message'],
          'partner': player['partner'],
          'gameId': player['gameId']
        }));
        if (hasMsg) {
          print("[RELAY] Poll pour $userName, message: ${player['message']}");
          player['message'] = '';
        }
      } else {
        req.response.write(jsonEncode({'status': 'unknown_user'}));
      }
      await req.response.close();
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  }
}
