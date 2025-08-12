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
  WebSocket? partnerSocket; // 🆕

  Player({
    required this.userName,
    required this.socket,
    required this.expectedName,
    required this.startTime,
    this.partnerSocket,
  });
}

void showUsersConnected(players) {
  print('[RELAY] Liste des joueurs connectés:\n- Name : expected : startTime');
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

      socket.listen(
        (data) {
          _handleMessage(data, socket, players);
        },
        onDone: () {
          final removedPlayer = players.firstWhereOrNull(
            (p) => p.socket == socket,
          );

          if (removedPlayer != null) {
            print('[RELAY] Déconnexion de ${removedPlayer.userName}');
            players.remove(removedPlayer);
            showUsersConnected(players);
          } else {
            print(
                '[RELAY] Déconnexion d’un socket non retrouvé dans la liste des joueurs:');
            showUsersConnected(players);
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

// Avant d’ajouter le nouveau joueur, supprimer l’ancien s’il existe
      players.removeWhere((p) {
        final shouldRemove = p.userName ==
            userName; //et toutes les occurences de ce joueurs laissées par erreur
        if (shouldRemove) {
          try {
            p.socket.close(); // fermeture explicite
            if (_debug)
              print(
                  '[RELAY] fermeture socket de ${p.userName} : ${p.startTime}');
          } catch (_) {}
        }
        return shouldRemove;
      });

// Ajouter le nouveau joueur avec le socket actuel
      players.add(player);
      if (_debug)
        print('[RELAY] Ajout de ${player.userName} : ${player.startTime}');
      showUsersConnected(players);

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

      if (match != null &&
          match.partnerSocket == null &&
          player.partnerSocket == null) {
        print(
          '[RELAY] Match trouvé entre ${player.userName} et ${match.userName}',
        );

        //Mémorisation des sockets pour les échanges futurs
        player.partnerSocket = match.socket;
        match.partnerSocket = player.socket;

        final matchedMsg = jsonEncode({
          'type': 'matched',
          'leftName': player.userName,
          'leftStartTime': player.startTime,
          'leftIP': '',
          'leftPort': 0,
          'rightName': match.userName,
          'rightStartTime': match.startTime,
          'rightIP': '',
          'rightPort': 0,
        });

        // Informer chaque joueur que la connexion est établie
        player.socket.add(matchedMsg);
        match.socket.add(matchedMsg);
      }
    } else if (message['type'] == 'gameState') {
      final gameStateJson = message['data'];

      // Envoyer au partenaire
      Player? sender = players.firstWhereOrNull(
        (p) => p.socket == senderSocket,
      );
      sender = players.firstWhere((p) => p.socket == senderSocket);
      final receiverSocket = sender.partnerSocket;

      if (receiverSocket != null) {
        receiverSocket.add(
          jsonEncode({
            'type': 'gameState',
            'data': jsonDecode(gameStateJson), // <- CORRECTION ICI
          }),
        );
        print(
            '[RELAY] GameState envoyé de ${sender.userName} à son partenaire');
      } else {
        print('[RELAY] Partenaire introuvable pour ${sender.userName}');
      }
    } else if (message['type'] == 'ping' || message['type'] == 'keepalive') {
      senderSocket.add(jsonEncode({'type': 'pong'}));
      return;
    }
  } catch (e) {
    print('[RELAY] Erreur : $e');
  }
}
