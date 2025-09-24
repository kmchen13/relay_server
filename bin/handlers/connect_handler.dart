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
    if (userName.isEmpty) {
      jsonResponse(req.response, {'status': 'Invalid_connect_parameters'});
      return;
    }
    final String expectedName = (data['expectedName'] ?? '').toString();
    final int startTime = (data['startTime'] ?? 0) is int
        ? data['startTime'] as int
        : int.tryParse(data['startTime']?.toString() ?? '0') ?? 0;

    await loadPlayers();

    if (debug) {
      print(
          "[$appName v$version] 🔔 /connect player=$userName expected=$expectedName start=$startTime");
    }
    var me = findOpenEntry(userName, expectedName);
    me ??= PlayerEntry(
        userName: userName, expectedName: expectedName, startTime: startTime);
    if (!players.contains(me)) players.add(me);

    await savePlayers();

    final match = findMatchingCounterpart(userName, expectedName);
    if (match != null) {
      me.partner = match.userName;
      me.partnerStartTime = match.startTime;

      match.partner = me.userName;
      match.partnerStartTime = me.startTime;

      jsonResponse(req.response, {
        'status': 'matched',
        'partner': match.userName,
        'startTime': me.startTime,
        'partnerStartTime': match.startTime,
      });

      queueMessageFor(match.userName, me.userName, {
        'type': 'matched',
        'partner': me.userName,
        'startTime': match.startTime,
        'partnerStartTime': me.startTime,
      });

      if (debug)
        print(
            "[$appName v$version] ✅ Match: ${me.userName} ↔ ${match.userName} ");
    } else {
      jsonResponse(req.response, {'status': 'waiting'});
      if (debug)
        print(
            "[$appName v$version] ✅ ${userName} Waiting for: '${expectedName}'");
    }
  } catch (e, s) {
    jsonResponse(
        req.response,
        {
          'error': 'invalid_request',
          'exception': e.toString(),
          'stack': s.toString(),
        },
        statusCode: HttpStatus.badRequest);
  }
}
