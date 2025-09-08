import '../player_entry.dart';
import '../constants.dart';
import 'dart:convert';
import 'dart:io';

List<PlayerEntry> players = [];

/// Sauvegarder la liste des players dans un fichier JSON
Future<void> savePlayers() async {
  final file = File('players.json');
  final jsonList = players.map((p) => p.asRow()).toList();
  await file.writeAsString(jsonEncode(jsonList));
  if (debug) showPlayers();
}

/// Charger la liste des players depuis un fichier JSON
Future<void> loadPlayers() async {
  final file = File('players.json');
  if (!await file.exists()) {
    players = [];
    return;
  }
  final contents = await file.readAsString();
  final List<dynamic> jsonList = jsonDecode(contents);
  players = jsonList.map((row) => PlayerEntry.fromRow(row)).toList();
}

Future<void> removePlayerGame(player, partner) async {
  players.removeWhere((p) => p.userName == player && p.partner == partner);
  savePlayers();
}

PlayerEntry? findOpenEntry(String userName, String expectedName) {
  return players
      .where((p) =>
          p.userName == userName &&
          p.expectedName == expectedName &&
          p.partner.isEmpty)
      .lastOrNull;
}

PlayerEntry? findMatchingCounterpart(String me, String myExpected) {
  for (final p in players) {
    final explicitPair = (p.userName == myExpected && p.expectedName == me);
    final randomPair =
        (myExpected.isEmpty && p.expectedName.isEmpty && p.userName != me);

    if (findInGame(me, p.userName) != null) continue;

    if (p.partner.isEmpty && (explicitPair || randomPair)) {
      return p;
    }
  }
  return null;
}

/// Vérifie si deux joueurs sont déjà dans une même partie.
/// Retourne leur gameId si trouvé, sinon `null`.
PlayerEntry? findInGame(String userName, String expectedName) {
  for (final p in players) {
    if (p.userName == userName &&
        p.partner == expectedName &&
        p.gameId.isNotEmpty) {
      return p;
    }
  }
  return null;
}

void queueMessageFor(String userName, Map<String, dynamic> message) {
  final target = players.lastWhere(
    (p) => p.userName == userName,
    orElse: () => PlayerEntry(userName: '', expectedName: '', startTime: 0),
  );
  if (target.userName.isEmpty) {
    print(
        "[$appName v$version] ⚠️ Impossible de placer le message: joueur $userName introuvable");
    return;
  }
  target.message = message;
  print(
      "[$appName v$version] 📩 Message en file pour $userName: ${message['type']}");
  savePlayers();
}

void showPlayers() {
  print(
      '[$appName v$version] Joueurs enregistrés (user : expected -> partner | gameId | message?):');

  // Imprimer l'en-tête du tableau
  print('| Usr |Expct|  Time    |Prtnr| GID |Message|');
  print('+-----+-----+----------+-----+-----+-------');

  // Parcourir et afficher chaque joueur sous forme de tableau
  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    // Formater chaque ligne de joueur pour une longueur fixe
    final userName = p.userName.substring(0, 3);
    final expectedName =
        p.expectedName.isEmpty ? ' - ' : p.expectedName.substring(0, 3);
    final time = hms.padRight(9);
    final partner = p.partner.isEmpty ? ' — ' : p.partner.substring(0, 3);
    final gameId = p.gameId.isEmpty ? ' — ' : p.gameId.substring(5);
    final message = p.message == null
        ? 'no'
        : p.message!['type'].toString().padRight(9).substring(0, 7);

    // Imprimer la ligne du tableau
    print(
        '| $userName | $expectedName | $time | $partner | $gameId | $message |');
  }
}

showPlayersAsHTML() {
  final buffer = StringBuffer();
  buffer.writeln('<h1>$appName v$version</h1>');
  buffer.writeln('<table border="1" cellpadding="5" cellspacing="0">');
  buffer.writeln(
      '<tr><th>User</th><th>Expected</th><th>Time</th><th>Partner</th><th>Game ID</th><th>Message</th></tr>');

  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final userName = p.userName;
    final expectedName = p.expectedName;
    final time = hms;
    final partner = p.partner.isEmpty ? '—' : p.partner;
    final gameId = p.gameId.isEmpty ? '—' : p.gameId;
    final message = p.message == null ? 'no' : p.message!['type'].toString();

    buffer.writeln(
        '<tr><td>$userName</td><td>$expectedName</td><td>$time</td><td>$partner</td><td>$gameId</td><td>$message</td></tr>');
  }

  buffer.writeln('</table>');
  return buffer.toString();
}

void deleteGameId(String gameId) {
  players.removeWhere((p) => p.gameId == gameId);
  savePlayers();
}
