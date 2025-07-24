import 'dart:convert';
import 'dart:io';

class Player {
  final String userName;
  final WebSocket socket;
  final String expectedUser;

  Player({
    required this.userName,
    required this.socket,
    required this.expectedUser,
  });
}

void main() async {
  final players = <Player>[];

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
    '[RELAY] Serveur WebSocket lancé sur ws://${server.address.address}:${server.port}',
  );

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      print('[RELAY] Nouveau client connecté');

      socket.listen(
        (data) {
          _handleMessage(data, socket, players);
        },
        onDone: () {
          print('[RELAY] Déconnexion');
          players.removeWhere((p) => p.socket == socket);
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
      final expectedUser = message['expectedUser'];

      final player = Player(
        userName: userName,
        socket: senderSocket,
        expectedUser: expectedUser,
      );

      players.add(player);
      print('[RELAY] $userName attend $expectedUser');

      // Chercher un joueur qui attend cette personne
      Player? match;
      try {
        match = players.firstWhere(
          (p) =>
              p.userName == expectedUser &&
              p.expectedUser == userName &&
              p.socket != senderSocket,
        );
      } catch (_) {
        match = null;
      }

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
      Player? sender = players.firstWhere(
        (p) => p.socket == senderSocket,
        orElse: () => null!,
      );
      if (sender == null) return;

      Player? receiver;
      try {
        receiver = players.firstWhere(
          (p) =>
              p.userName == sender.expectedUser &&
              p.expectedUser == sender.userName,
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
