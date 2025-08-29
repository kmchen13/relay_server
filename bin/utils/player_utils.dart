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
    if (p.partner.isEmpty && (explicitPair || randomPair)) {
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

void deleteGameId(String gameId) {
  players.removeWhere((p) => p.gameId == gameId);
  savePlayers();
}
