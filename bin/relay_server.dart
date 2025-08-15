import 'dart:convert';
import 'dart:io';

final List<Map<String, dynamic>> players = [];

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print("[RELAY] Serveur HTTP polling sur http://${server.address.host}:${server.port}");

  await for (HttpRequest req in server) {
    if (req.method == 'POST' && req.uri.path == '/connect') {
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final userName = jsonData['userName'];
      final expected = jsonData['expectedName'];
      final startTime = jsonData['startTime'];

      players.removeWhere((p) => p['userName'] == userName);
      players.add({
        'userName': userName,
        'expectedName': expected,
        'startTime': startTime,
        'partner': '',
        'gameId': '',
        'message': ''
      });

      // Essayer de matcher
      final match = players.firstWhere(
        (p) =>
            ((p['userName'] == expected && p['expectedName'] == userName) ||
             (p['expectedName'] == '' && expected == '')) &&
            p['userName'] != userName,
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        final gameId = DateTime.now().millisecondsSinceEpoch.toString();
        match['partner'] = userName;
        match['gameId'] = gameId;
        players.firstWhere((p) => p['userName'] == userName)['partner'] = match['userName'];
        players.firstWhere((p) => p['userName'] == userName)['gameId'] = gameId;
        req.response.write(jsonEncode({'status': 'matched', 'gameId': gameId, 'partner': match['userName']}));
      } else {
        req.response.write(jsonEncode({'status': 'waiting'}));
      }
      await req.response.close();

    } else if (req.method == 'POST' && req.uri.path == '/send') {
      final data = await utf8.decoder.bind(req).join();
      final jsonData = jsonDecode(data);
      final from = jsonData['from'];
      final msg = jsonData['message'];

      final sender = players.firstWhere((p) => p['userName'] == from, orElse: () => {});
      if (sender.isNotEmpty) {
        final partnerName = sender['partner'];
        final partner = players.firstWhere((p) => p['userName'] == partnerName, orElse: () => {});
        if (partner.isNotEmpty) {
          partner['message'] = msg;
          req.response.write(jsonEncode({'status': 'sent'}));
        } else {
          req.response.write(jsonEncode({'status': 'partner_not_found'}));
        }
      }
      await req.response.close();

    } else if (req.method == 'GET' && req.uri.path == '/poll') {
      final userName = req.uri.queryParameters['userName'] ?? '';
      final player = players.firstWhere((p) => p['userName'] == userName, orElse: () => {});
      if (player.isNotEmpty) {
        final hasMsg = player['message'] != '';
        req.response.write(jsonEncode({
          'status': hasMsg ? 'message' : 'no_message',
          'message': player['message'],
          'partner': player['partner'],
          'gameId': player['gameId']
        }));
        if (hasMsg) player['message'] = ''; // vider après lecture
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
