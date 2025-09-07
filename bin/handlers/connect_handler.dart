import 'dart:convert';
import 'dart:io';
import '../player_entry.dart';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleConnect(HttpRequest req) async {
  try {
    final body = await utf8.decoder.bind(req).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final String userName = (data['userName'] ?? '').toString();
    final String expectedName = (data['expectedName'] ?? '').toString();
    final int startTime = (data['startTime'] ?? 0) is int
        ? data['startTime'] as int
        : int.tryParse(data['startTime']?.toString() ?? '0') ?? 0;

    await loadPlayers();

    if (debug) {
      print(
          "[$appName v$version] 🔔 /connect $userName expected=$expectedName start=$startTime");
      showPlayers();
    }
    var me = findOpenEntry(userName, expectedName);
    me ??= PlayerEntry(
        userName: userName, expectedName: expectedName, startTime: startTime);
    if (!players.contains(me)) players.add(me);
    await savePlayers();
    if (debug) showPlayers();

    final match = findMatchingCounterpart(userName, expectedName);
    if (match != null) {
      // 🔑 Réutiliser un gameId existant si déjà assigné
      final gameId = me.gameId.isNotEmpty
          ? me.gameId
          : (match.gameId.isNotEmpty
              ? match.gameId
              : DateTime.now().millisecondsSinceEpoch.toString());

      me.partner = match.userName;
      me.partnerStartTime = match.startTime;
      me.gameId = gameId;

      match.partner = me.userName;
      match.partnerStartTime = me.startTime;
      match.gameId = gameId;

      jsonResponse(req.response, {
        'status': 'matched',
        'gameId': gameId,
        'partner': match.userName,
        'startTime': me.startTime,
        'partnerStartTime': match.startTime,
      });

      queueMessageFor(match.userName, {
        'type': 'matched',
        'gameId': gameId,
        'partner': me.userName,
        'startTime': match.startTime,
        'partnerStartTime': me.startTime,
      });

      print(
          "[$appName v$version] ✅ Match: ${me.userName} ↔ ${match.userName} (gameId=$gameId)");
    } else {
      jsonResponse(req.response, {'status': 'waiting'});
    }
  } catch (e) {
    jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'details': e.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}
