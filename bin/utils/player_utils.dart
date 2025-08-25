import '../player_entry.dart';
import '../constants.dart';

final List<PlayerEntry> players = [];

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
}
