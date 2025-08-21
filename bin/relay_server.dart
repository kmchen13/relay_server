import 'dart:convert';
import 'dart:io';

/// Petit serveur relais WebSocket/HTTP pour Scrabble
/// Permet de gérer le matching et le polling de messages entre joueurs.

class RelayServer {
  final String host;
  final int port;
  HttpServer? _server;

  /// File d’attente des messages en attente pour chaque joueur
  final Map<String, List<String>> _messageQueues = {};

  RelayServer({this.host = '0.0.0.0', this.port = 8080});

  Future<void> start() async {
    _server = await HttpServer.bind(host, port);
    print("✅ RelayServer démarré sur http://$host:$port");

    await for (HttpRequest req in _server!) {
      _handleRequest(req);
    }
  }

  void _handleRequest(HttpRequest req) async {
    final path = req.uri.path;
    if (path == '/send' && req.method == 'POST') {
      await _handleSend(req);
    } else if (path == '/poll' && req.method == 'GET') {
      await _handlePoll(req);
    } else {
      _sendJson(req.response, {'error': 'Route inconnue'});
    }
  }

  Future<void> _handleSend(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      final data = jsonDecode(body);

      final to = data['to'] as String?;
      final message = data['message'] as String?;

      if (to == null || message == null) {
        _sendJson(req.response,
            {'status': 'error', 'reason': 'Paramètres manquants'});
        return;
      }

      _messageQueues.putIfAbsent(to, () => []);
      _messageQueues[to]!.add(message);

      print("📨 Message stocké pour $to : $message");

      _sendJson(req.response, {'status': 'ok'});
    } catch (e) {
      _sendJson(req.response, {'status': 'error', 'reason': e.toString()});
    }
  }

  Future<void> _handlePoll(HttpRequest req) async {
    try {
      final userName = req.uri.queryParameters['userName'];
      if (userName == null) {
        _sendJson(
            req.response, {'status': 'error', 'reason': 'userName manquant'});
        return;
      }

      final queue = _messageQueues[userName];
      if (queue != null && queue.isNotEmpty) {
        final message = queue.removeAt(0);
        print("📤 Message délivré à $userName : $message");
        _sendJson(req.response, {'status': 'gameState', 'message': message});
      } else {
        _sendJson(req.response, {'status': 'empty'});
      }
    } catch (e) {
      _sendJson(req.response, {'status': 'error', 'reason': e.toString()});
    }
  }

  void _sendJson(HttpResponse res, Map<String, dynamic> data) {
    try {
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(data));
    } catch (e) {
      print("Erreur en envoyant la réponse : $e");
    } finally {
      res.close();
    }
  }
}

Future<void> main() async {
  final server = RelayServer(port: 8080);
  await server.start();
}
