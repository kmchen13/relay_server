import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

final _debug = true;
final List<Map<String, dynamic>> players = [];

void showUsersConnected(List<Map<String, dynamic>> players) {
  print('[RELAY] Liste des joueurs connectés:\n- Name : expected : startTime');

  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p['startTime']);

    final hms = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    if (_debug) {
      print('  - ${p['userName']} : ${p['expectedName']} : $hms');
    }
  }
}

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

      if (_debug) {
        print(
            "[RELAY] Demande de Connexion de $userName avec expected $expected à $startTime");
      }

      // Chercher si ce joueur a déjà une partie avec le même expected
      Map<String, dynamic>? existing = players.firstWhereOrNull(
        (p) =>
            p['userName'] == userName &&
            p['expectedName'] == expected &&
            p['partner'] == '',
      );

      if (existing != null) {
        // S'il a un message en attente, l'envoyer (TODO)
      } else {
        players.add({
          'userName': userName,
          'expectedName': expected,
          'startTime': startTime,
          'partner': '',
          'gameId': '',
          'message': '',
          'type': '' // gameState ou message
        });
        showUsersConnected(players);
      }

      // Matchmaking uniquement avec joueurs sans partenaire
      final match = players.firstWhereOrNull((p) =>
          p['partner'] == '' &&
          p['userName'] != userName &&
          ((p['userName'] == expected && expected != '') ||
              (expected == '' && p['expectedName'] == '')));

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

        // Préparer le message "matched" pour l’autre joueur
        final starterEntry =
            players.firstWhere((p) => p['userName'] == match['userName']);
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
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final from = jsonData['from'];
      final msg = jsonData['message'];

      print("[RELAY] Message reçu de $from: $msg");

      final sender = players.firstWhereOrNull((p) => p['userName'] == from);
      if (sender != null) {
        final partnerName = sender['partner'];
        final partner =
            players.firstWhereOrNull((p) => p['userName'] == partnerName);
        if (partner != null) {
          partner['message'] = msg;
          req.response.write(jsonEncode({'status': 'sent'}));
          print("[RELAY] Message de $from envoyé à $partnerName");
        } else {
          req.response.write(jsonEncode({'status': 'partner_not_found'}));
        }
      }
      await req.response.close();
    } else if (req.method == 'GET' && req.uri.path == '/poll') {
      final userName = req.uri.queryParameters['userName'] ?? '';
      final player = players.firstWhereOrNull((p) => p['userName'] == userName);

      if (player != null) {
        final hasMsg = player['message'] != '';
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
        req.response.write(jsonEncode({'status': 'unknown_user $userName'}));
        if (_debug) {
          print("[RELAY] Poll pour $userName, aucun joueur trouvé.");
        }
        showUsersConnected(players);
      }
      await req.response.close();
    } else if (req.method == 'GET' && req.uri.path == '/disconnect') {
      if (_debug) {
        print("[RELAY] Déconnexion demandée pour ${req.uri.queryParameters}");
      }
      final userName = req.uri.queryParameters['leftName'] ?? '';
      final partner = req.uri.queryParameters['rightName'] ?? '';
      players.removeWhere(
          (p) => p['userName'] == userName || p['partner'] == partner);
      showUsersConnected(players);
      await req.response.close();
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  }
}
