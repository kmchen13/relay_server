/*
  Handler pour l'endpoint /connect

  Reçoit: { userName, expectedName, startTime }
  Répond: { status: 'waiting' } ou { status: 'matched', gameId, partner, startTime, partnerStartTime }
  
  Un joueur peut avoir plusieurs parties en cours. Les parties sont identifiées par gameId. Chaque partie est représentée par 2 entrées dans players.
  La structure de Players est:
    userName
    expectedName
    partner (vide si pas encore apparié)
    startTime
    partnerStartTime (vide si pas encore apparié)
    gameId (vide si pas encore apparié)
  
  
  Lorsqu'un joueur se connecte, 
    si expectedName != '' 
      on cherche s'il a déjà une partie en cours avec ce partenaire. si oui, s'il a un message en cours on le lui envoie, sinon on répond status: 'waiting'
    sinon on cherche une partie en cours avec un partenaire qui attend (expectedName == '' ou expectedName == userName)
      si oui on complète les 2 entrées (partner, partnerStartTime, gameId) et on répond status: 'matched' avec les infos du partenaire
      sinon on crée une nouvelle entrée avec partner='', gameId='' si elle n'existe pas et on répond status: 'waiting' 
    
   
*/
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

    if (debug)
      print(
          "[$appName v$version] 🔔 /register $userName expected=$expectedName start=$startTime");

    players.removeWhere((p) =>
        p.userName == userName &&
        p.expectedName == expectedName &&
        p.partner.isEmpty);

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
