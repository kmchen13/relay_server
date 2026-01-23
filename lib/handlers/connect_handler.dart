import 'dart:convert';
import 'dart:io';
import '../player_entry.dart';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';
import '../services/player_repository.dart';

Future<void> handleConnect(HttpRequest req, PlayerRepository repo) async {
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

    if (debug) {
      print(
          "[$appName v$version] 🔔 /connect player=$userName expected=$expectedName start=$startTime");
    }
    final String language = (data['language'] ?? 'fr').toString().toLowerCase();
    if (!['fr', 'en', 'es'].contains(language)) {
      jsonResponse(req.response, {'status': 'invalid_language'});
      return;
    }
    // Cherche une entrée ouverte en base
    var me = await findOpenEntry(repo, userName, expectedName, language);
    me ??= PlayerEntry(
        userName: userName,
        expectedName: expectedName,
        language: language,
        startTime: startTime);

    await repo.upsertPlayer(me);

    // Chercher un partenaire correspondant
    final match =
        await findMatchingCounterpart(repo, userName, expectedName, language);

    if (match != null) {
      //supprimer l'entrée userName ouverte
      repo.removePlayerEntry(userName, '');

      jsonResponse(req.response, {
        'status': 'matched',
        'partner': match.userName,
        'startTime': me.startTime,
        'partnerStartTime': match.startTime,
      });
      //mettre un message matched en attente pour match et mettre à jour son entrée partner
      repo.matchPlayer(me, match);

      if (debug)
        print(
            "[$appName v$version] ✅ Match: ${me.userName} ↔ ${match.userName}");
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
    if (debug) {
      print("Error in /connect: $e");
      print(s);
    }
  }
}
