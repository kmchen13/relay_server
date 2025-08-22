import 'dart:convert';
import 'dart:io';

const bool _debug = true;

/// Représente une “ligne” dans la table players (une partie potentielle ou en cours)
class PlayerEntry {
  String userName; // le joueur local
  String expectedName; // partenaire attendu ("" = aléatoire)
  String partner; // rempli après match
  int startTime; // startTime local (ms epoch)
  int? partnerStartTime; // startTime du partenaire après match
  String gameId; // rempli au match
  Map<String, dynamic>? message; // message en attente

  PlayerEntry({
    required this.userName,
    required this.expectedName,
    required this.startTime,
    this.partner = '',
    this.partnerStartTime,
    this.gameId = '',
    this.message,
  });

  Map<String, dynamic> asRow() => {
        'userName': userName,
        'expectedName': expectedName,
        'partner': partner,
        'startTime': startTime,
        'partnerStartTime': partnerStartTime,
        'gameId': gameId,
        'message': message,
      };
}

final List<PlayerEntry> players = [];

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
      "[RELAY] Serveur HTTP polling sur http://${server.address.address}:${server.port}");

  await for (final req in server) {
    try {
      if (req.method == 'POST' && req.uri.path == '/register') {
        await _handleRegister(req);
      } else if (req.method == 'POST' && req.uri.path == '/gamestate') {
        await _handleGameState(req);
      } else if (req.method == 'GET' && req.uri.path == '/poll') {
        await _handlePoll(req);
      } else if (req.method == 'GET' && req.uri.path == '/disconnect') {
        await _handleDisconnect(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        _jsonResponse(req.response, {
          'error': 'not_found',
          'message': 'Endpoint non trouvé',
        });
      }
    } catch (e, st) {
      if (_debug) {
        print("[RELAY] ❌ Exception: $e");
        print(st);
      }
      _jsonResponse(
          req.response,
          {
            'error': 'server_error',
            'details': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    } finally {
      await req.response.close();
    }
  }
}

/// ---------- Helpers

void _jsonResponse(HttpResponse res, Map<String, dynamic> json,
    {int statusCode = HttpStatus.ok}) {
  res.statusCode = statusCode;
  res.headers.contentType = ContentType.json;
  res.write(jsonEncode(json));
}

void _showUsers() {
  if (!_debug) return;
  print(
      '[RELAY] Joueurs enregistrés (user : expected -> partner | gameId | message?):');
  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    print(
        '  - ${p.userName} : ${p.expectedName} ($hms) -> ${p.partner.isEmpty ? '—' : p.partner}'
        ' | ${p.gameId.isEmpty ? '—' : p.gameId}'
        ' | ${p.message == null ? 'no' : p.message!['type']}');
  }
}

PlayerEntry? _findOpenEntry(String userName, String expectedName) {
  return players
      .where((p) =>
          p.userName == userName &&
          p.expectedName == expectedName &&
          p.partner.isEmpty)
      .lastOrNull;
}

PlayerEntry? _findMatchingCounterpart(String me, String myExpected) {
  for (final p in players) {
    final explicitPair = (p.userName == myExpected && p.expectedName == me);
    final randomPair =
        (myExpected.isEmpty && p.expectedName.isEmpty && p.userName != me);
    if (p.partner.isEmpty && (explicitPair || randomPair)) {
      return p;
    }
  }
  return null;
}

void _queueMessageFor(String userName, Map<String, dynamic> message) {
  final target = players.lastWhere(
    (p) => p.userName == userName,
    orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
  );
  if (target.userName.isEmpty) {
    if (_debug)
      print(
          "[RELAY] ⚠️ Impossible de placer le message: joueur $userName introuvable");
    return;
  }
  target.message = message;
  if (_debug)
    print("[RELAY] 📩 Message en file pour $userName: ${message['type']}");
}

/// ---------- Handlers

Future<void> _handleRegister(HttpRequest req) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String userName = (data['userName'] ?? '').toString();
    final String expectedName = (data['expectedName'] ?? '').toString();
    final int startTime = (data['startTime'] ?? 0) is int
        ? data['startTime'] as int
        : int.tryParse(data['startTime']?.toString() ?? '0') ?? 0;

    if (_debug) {
      print(
          "[RELAY] 🔔 /register $userName expected=$expectedName start=$startTime");
    }

    players.removeWhere((p) =>
        p.userName == userName &&
        p.expectedName == expectedName &&
        p.partner.isEmpty);

    var me = _findOpenEntry(userName, expectedName);
    me ??= PlayerEntry(
        userName: userName, expectedName: expectedName, startTime: startTime);
    if (!players.contains(me)) players.add(me);

    final match = _findMatchingCounterpart(userName, expectedName);
    if (match != null) {
      final gameId = DateTime.now().millisecondsSinceEpoch.toString();
      me.partner = match.userName;
      me.partnerStartTime = match.startTime;
      me.gameId = gameId;
      match.partner = me.userName;
      match.partnerStartTime = me.startTime;
      match.gameId = gameId;

      _jsonResponse(req.response, {
        'status': 'matched',
        'gameId': gameId,
        'partner': match.userName,
        'startTime': me.startTime,
        'partnerStartTime': match.startTime,
      });

      _queueMessageFor(match.userName, {
        'type': 'matched',
        'gameId': gameId,
        'partner': me.userName,
        'startTime': match.startTime,
        'partnerStartTime': me.startTime,
      });

      if (_debug) {
        print(
            "[RELAY] ✅ Match: ${me.userName} ↔ ${match.userName} (gameId=$gameId)");
        _showUsers();
      }
    } else {
      _jsonResponse(req.response, {'status': 'waiting'});
      if (_debug) _showUsers();
    }
  } catch (e) {
    _jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'details': e.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}

Future<void> _handleGameState(HttpRequest req) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String from = (data['from'] ?? '').toString();
    final String to = (data['to'] ?? '').toString();
    final payload = data['message'];

    if (_debug) {
      print("[RELAY] 🎲 /gamestate de $from → $to");
    }

    final target = players.lastWhere(
      (p) =>
          p.userName == to &&
          (p.partner == from ||
              p.expectedName == from ||
              p.expectedName.isEmpty),
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    if (target.userName.isEmpty) {
      _jsonResponse(
          req.response,
          {
            'status': 'partner_not_found',
            'message': 'Partenaire non trouvé',
          },
          statusCode: HttpStatus.notFound);
      return;
    }

    _queueMessageFor(to, {
      'type': 'gameState',
      'from': from,
      'to': to,
      'gameId': target.gameId,
      'payload': payload,
    });

    _jsonResponse(req.response, {'status': 'sent'});
  } catch (e) {
    _jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'details': e.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}

Future<void> _handlePoll(HttpRequest req) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final withMsg = players.firstWhere(
      (p) => p.userName == userName && p.message != null,
      orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
    );

    if (withMsg.userName.isEmpty) {
      _jsonResponse(req.response, {
        'type': 'no_message',
        'message': '',
      });
      return;
    }

    final msg = withMsg.message!;
    withMsg.message = null;

    if (msg['type'] == 'matched') {
      _jsonResponse(req.response, msg);
    } else if (msg['type'] == 'gameState') {
      _jsonResponse(req.response, {
        'type': 'gameState',
        'message': msg['payload'],
        'from': msg['from'],
        'gameId': msg['gameId'],
      });
    } else {
      _jsonResponse(req.response, {
        'type': 'message',
        'message': msg,
      });
    }
  } catch (e) {
    _jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'details': e.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}

Future<void> _handleDisconnect(HttpRequest req) async {
  try {
    final userName = req.uri.queryParameters['userName'] ?? '';
    final gameId = req.uri.queryParameters['gameId'];

    if (gameId != null && gameId.isNotEmpty) {
      players.removeWhere((p) => p.userName == userName && p.gameId == gameId);
    } else {
      players.removeWhere((p) => p.userName == userName);
    }

    _jsonResponse(req.response, {'status': 'disconnected'});
  } catch (e) {
    _jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'details': e.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}
