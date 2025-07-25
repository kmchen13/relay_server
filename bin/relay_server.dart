import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'services/utility.dart';

final _debug = true;

class Player {
  final String userName;
  final WebSocket socket;
  final String expectedName;
  final int startTime;

  Player({
    required this.userName,
    required this.socket,
    required this.expectedName,
    required this.startTime,
  });
}

void main() async {
  var players = <Player>[];

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
    '[RELAY] Serveur WebSocket lancé sur ws://${server.address.address}:${server.port}',
  );

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      print('[RELAY] Nouveau client connecté');
      print(
          '[RELAY] Liste des joueurs connectés : Name : expected : startTime');
      for (final p in players) {
        final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
        final hms = '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}:'
            '${dt.second.toString().padLeft(2, '0')}';
        if (_debug)
          print(
            '  - ${p.userName} : ${p.expectedName} : $hms',
          );
      }

      socket.listen(
        (data) {
          _handleMessage(data, socket, players);
        },
        onDone: () {
          print('[RELAY] Déconnexion');
          final removedPlayer = players.firstWhereOrNull(
            (p) => p.socket == socket,
          );

          if (removedPlayer != null) {
            print('[RELAY] Déconnexion de ${removedPlayer.userName}');
            players.remove(removedPlayer);
          } else {
            print('[RELAY] Déconnexion d’un socket inconnu');
          }
        },
      );
    } else {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('WebSocket uniquement')
        ..close();
    }
  }
}

void _handleMessage(
  dynamic data,
  WebSocket senderSocket,
  List<Player> players,
) {
  try {
    final message = jsonDecode(data);

    if (message['type'] == 'connect') {
      final userName = message['userName'];
      final expectedName = message['expectedName'];
      final startTime = message['startTime'];

      final player = Player(
        userName: userName,
        socket: senderSocket,
        expectedName: expectedName,
        startTime: startTime,
      );

      final alreadyExists = players.any((p) => p.userName == userName);
      if (alreadyExists) {
        print('[RELAY] $userName est déjà connecté');
      } else {
        players.add(player);
        print('[RELAY] $userName ajouté à la liste attend $expectedName');
      }

      bool _isMatch(
        String localUser,
        String expectedName,
        String remoteUser,
        String remoteExpected,
      ) {
        return (localUser == remoteExpected && expectedName == remoteUser) ||
            (remoteExpected.isEmpty && expectedName.isEmpty);
      }

      Player? match = players.firstWhereOrNull(
        (p) =>
            _isMatch(userName, expectedName, p.userName, p.expectedName) &&
            p.socket != senderSocket,
      );

      if (match != null) {
        print(
          '[RELAY] Match trouvé entre ${player.userName} et ${match.userName}',
        );

        // Informer chaque joueur que la connexion est établie
        player.socket.add(
          jsonEncode({'type': 'matched', 'partnerName': match.userName}),
        );

        match.socket.add(
          jsonEncode({'type': 'matched', 'partnerName': player.userName}),
        );
      }
    } else if (message['type'] == 'gameState') {
      final gameStateJson = message['data'];

      // Envoyer au partenaire
      Player? sender = players.firstWhereOrNull(
        (p) => p.socket == senderSocket,
      );
      if (sender == null) {
        if (_debug) print('[RELAY] Sender null detected');
        return;
      }

      Player? receiver;
      try {
        receiver = players.firstWhere(
          (p) =>
              p.userName == sender.expectedName &&
              p.expectedName == sender.userName,
        );
      } catch (_) {
        receiver = null;
      }

      if (receiver != null) {
        receiver.socket.add(
          jsonEncode({'type': 'gameState', 'data': gameStateJson}),
        );
      }
    }
  } catch (e) {
    print('[RELAY] Erreur : $e');
  }
}
