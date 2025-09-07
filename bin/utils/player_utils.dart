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

    // ✅ Si déjà matché (gameId non vide), ignorer
    if (p.gameId.isNotEmpty) continue;

    if (p.partner.isEmpty && (explicitPair || randomPair)) {
      return p;
    }
  }
  return null;
}

/// Vérifie si deux joueurs sont déjà dans une même partie.
/// Retourne leur gameId si trouvé, sinon `null`.
String? findInGame(String userName, String expectedName) {
  for (final p in players) {
    if (p.userName == userName &&
        p.partner == expectedName &&
        p.gameId.isNotEmpty) {
      return p.gameId;
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
  print(
      '+----------------+----------------+-----------+-----------+-------------+---------------+');
  print(
      '| User            | Expected       | Time      | Partner   | Game ID     | Message       |');
  print(
      '+----------------+----------------+-----------+-----------+-------------+---------------+');

  // Parcourir et afficher chaque joueur sous forme de tableau
  for (final p in players) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    // Formater chaque ligne de joueur pour une longueur fixe
    final userName = p.userName.padRight(14).substring(0, 14);
    final expectedName = p.expectedName.padRight(14).substring(0, 14);
    final time = hms.padRight(9).substring(0, 9);
    final partner =
        p.partner.isEmpty ? '—' : p.partner.padRight(10).substring(0, 10);
    final gameId =
        p.gameId.isEmpty ? '—' : p.gameId.padRight(11).substring(0, 11);
    final message = p.message == null
        ? 'no'
        : p.message!['type'].toString().padRight(12).substring(0, 12);

    // Imprimer la ligne du tableau
    print(
        '| $userName | $expectedName | $time | $partner | $gameId | $message |');
  }

  // Imprimer la fin du tableau
  print(
      '+----------------+----------------+-----------+-----------+-------------+---------------+');
}

void deleteGameId(String gameId) {
  players.removeWhere((p) => p.gameId == gameId);
  savePlayers();
}
