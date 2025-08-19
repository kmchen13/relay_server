import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

final _debug = true;
final List<Map<String, dynamic>> players = [];

void showUsersConnected(List<Map<String, dynamic>> players) {
  print(
      '[RELAY] Liste des joueurs connectés:\n- Name : expectedPartner : startTime');

  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p['startTime']);

    final hms = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    if (_debug) {
      print('  - ${p['userName']} : ${p['expectedPartner']} : $hms');
    }
  }
}

void addPlayer(String userName, String expectedPartner, int startTime) {
  if (isRegistered(userName, expectedPartner)) return;

  players.add({
    'userName': userName,
    'expectedPartner': expectedPartner,
    'partner': '',
    'startTime': startTime,
    'gameId': DateTime.now().millisecondsSinceEpoch.toString(),
    'message': '',
    'type': '' // Pour identifier le type de message
  });
  showUsersConnected(players);
}

isRegistered(String userName, expectedPartner) {
  // Chercher si ce joueur a déjà une partie avec le même expectedPartner
  Map<String, dynamic>? existing = players.firstWhereOrNull(
    (p) =>
        p['userName'] == userName &&
        p['expectedPartner'] == expectedPartner &&
        p['partner'] == '',
  );
  return existing;
}

matchPlayer(String userName, String expectedPartner) {
  // match des joueurs qui n'ont pas encore de partenaire
  Map<String, dynamic>? match = players.firstWhereOrNull(
    (p) =>
        p['userName'] == userName &&
        p['expectedPartner'] == expectedPartner &&
        p['partner'] != '',
  );
  return match;
}

partnerPlayer(String userName, String partnerName) {
  // Chercher si ce joueur a déjà une partie avec le même expectedPartner
  Map<String, dynamic>? partner = players.firstWhereOrNull(
    (p) => p['userName'] == partnerName && p['Partner'] == userName,
  );
  return partner;
}

void addMessageToPlayer(
  String userName,
  String partner,
  String type,
  String message,
) {
  final player = players.firstWhereOrNull((p) => p['userName'] == userName);
  if (player != null) {
    player['message'] = message;
    if (_debug) {
      print("[RELAY] Message ajouté pour $userName: $message");
    }
  } else {
    if (_debug) {
      print("[RELAY] Aucune entrée trouvée pour $userName.");
    }
  }
}

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

  print(
      "[RELAY] Serveur HTTP polling sur http://${server.address.host}:${server.port}");

  await for (HttpRequest req in server) {
    //////// Connect
    if (req.method == 'POST' && req.uri.path == '/register') {
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final userName = jsonData['userName'];
      final expectedPartner = jsonData['expectedPartner'];
      final startTime = jsonData['startTime'];

      if (_debug) {
        print(
            "[RELAY] Demande d'enregistrement' de $userName avec expectedPartner $expectedPartner à $startTime");
      }

      Map<String, dynamic>? match = matchPlayer(userName, expectedPartner);

      if (match != null) {
        if (_debug) {
          print(
              "[RELAY] Match trouvé pour $userName avec ${match['userName']}");
        }
        final gameId = DateTime.now().millisecondsSinceEpoch.toString();

        match['partner'] = userName;
        match['gameId'] = gameId;

        final me = players.firstWhere((p) =>
            p['userName'] == userName &&
            p['expectedPartner'] == expectedPartner &&
            p['partner'] == '');
        me['partner'] = match['userName'];
        me['gameId'] = gameId;
        me['type'] = 'matched';
        me['message'] = jsonEncode({
          'partner': userName,
        });

        // Répondre au joueur qui vient de se connecter
        req.response.write(jsonEncode({
          'status': 'matched',
          'gameId': gameId,
          'partner': match['userName']
        }));
      } else {
        req.response.write(jsonEncode({'status': 'waiting'}));
      }

      await req.response.close();

      //////// Envoit d'un Gamestate: on enregistre en attente du poll du partenaire
    } else if (req.method == 'POST' && req.uri.path == '/gamestate') {
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final from = jsonData['from'];
      final to = jsonData['to'];
      final gamestate = jsonData['data'];

      print("[RELAY] GameState reçu de $from pour $to: \n$gamestate");

      final partner = players
          .firstWhereOrNull((p) => p['userName'] == to && p['partner'] == from);
      if (partner != null) {
        partner['message'] = gamestate;
        partner['type'] = 'gameState';
        print("[RELAY] Gamestate enregistré pour $to");
      } else {
        req.response.write(jsonEncode({'status': 'partner_not_found'}));
      }
      await req.response.close();

      //////// Poll
    } else if (req.method == 'GET' && req.uri.path == '/poll') {
      final userName = req.uri.queryParameters['userName'] ?? '';
      final player = players.firstWhereOrNull(
          (p) => p['userName'] == userName && p['message'] != '');
      if (player != null) {
        req.response.write(jsonEncode({
          'type': player['type'] ?? 'no_message',
          'message': player['message'] ?? '',
        }));
      } else {
        req.response.write(jsonEncode({'type': 'no_message', 'message': ''}));
      }
      await req.response.close();

      //////// Disconnect
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
