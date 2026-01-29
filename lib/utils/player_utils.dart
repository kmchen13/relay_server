import '../player_entry.dart';
import '../constants.dart';
import '../services/player_repository.dart';
import 'dart:convert';

/// Trouver une entrée de joueur ouverte (sans partenaire)
Future<PlayerEntry?> findOpenEntry(PlayerRepository repo, String userName,
    String expectedName, String language) async {
  final results = await repo.connection.query(
    'SELECT * FROM players WHERE userName = @userName AND expectedName = @expectedName AND partner = \'\'',
    substitutionValues: {'userName': userName, 'expectedName': expectedName},
  );

  if (results.isEmpty) return null;
  return PlayerEntry.fromRow(results.first.toColumnMap());
}

/// Trouver un joueur correspondant pour le matching
Future<PlayerEntry?> findMatchingCounterpart(PlayerRepository repo, String me,
    String myExpected, String language) async {
  final results = await repo.connection.query(
    '''
    SELECT * FROM players 
    WHERE partner = '' AND userName != @me 
      AND (expectedName = @me OR expectedName = '') 
      AND (@myExpected = '' OR expectedName = @myExpected)
      AND language = @language
    ''',
    substitutionValues: {
      'me': me,
      'myExpected': myExpected,
      'language': language
    },
  );

  if (results.isEmpty) return null;
  return PlayerEntry.fromRow(results.first.toColumnMap());
}

///Matcher 2 joueurs
/// Assigne mutuellement `partner` et `partnerStartTime`,
/// et sauvegarde les deux entrées en base.
///
/// Appelée quand un match est trouvé.
///
/// PRECONDITIONS:
/// - me.partner == ''
/// - other.partner == ''
/// - me.userName != other.userName
Future<void> matchPlayers(
  PlayerRepository repo,
  PlayerEntry me,
  PlayerEntry match,
) async {
  await repo.connection.query(
    '''
    UPDATE players
    SET partner = @meName,
        partnerStartTime = @meStart
    WHERE userName = @matchName
      AND partner = ''
    ''',
    substitutionValues: {
      'meName': me.userName,
      'meStart': me.startTime,
      'matchName': match.userName,
    },
  );
}

/// Vérifie si deux joueurs sont déjà dans une même partie
Future<PlayerEntry?> findInGame(
  PlayerRepository repo,
  String userName,
  String expectedName,
) async {
  final results = await repo.connection.query(
    'SELECT * FROM players WHERE userName = @userName AND partner = @partner',
    substitutionValues: {'userName': userName, 'partner': expectedName},
  );

  if (results.isEmpty) return null;
  return PlayerEntry.fromRow(results.first.toColumnMap());
}

/// Mettre en file un message pour un joueur spécifique.
/// Si aucune entrée (from → to) n'existe encore, elle est créée.
Future<void> queueMessageFor(
  PlayerRepository repo,
  String targetUser,
  String fromUser,
  Map<String, dynamic> msg,
) async {
  // Copie défensive du message
  final safeMsg = Map<String, dynamic>.from(msg);

  // Tente de récupérer le joueur cible
  var target = await repo.getPlayer(targetUser);

  // Si aucune entrée n'existe encore pour ce joueur, la créer
  if (target == null) {
    if (debug) {
      print(
          "🆕 Création d'une nouvelle PlayerEntry pour $targetUser (from $fromUser)");
    }

    target = PlayerEntry(
      userName: targetUser,
      expectedName: '',
      partner: fromUser,
      language: 'fr', // valeur par défaut
      startTime: DateTime.now().millisecondsSinceEpoch,
      partnerStartTime: 0, //inutilisé
      message: safeMsg,
    );

    await repo.upsertPlayer(target);
  } else {
    // Sinon, mettre à jour le message existant
    target.message = safeMsg;
    await repo.updateMessage(targetUser, fromUser, safeMsg);
    if (debug) {
      print("🆕 Mise à jour de PlayerEntry pour $targetUser (from $fromUser)");
    }
  }

  if (debug) {
    print(
        "💌 Message mis en file pour $targetUser depuis $fromUser: ${jsonEncode(safeMsg)}");
  }
}

class IncomingMessage {
  final String partner;
  final String type;
  final Map<String, dynamic> message;

  IncomingMessage({
    required this.partner,
    required this.type,
    required this.message,
  });
}

/// Récupérer un message en attente pour un joueur spécifique.
Future<IncomingMessage?> getMessage(
    PlayerRepository repo, String userName) async {
  final result = await repo.connection.query(
    'SELECT partner, message '
    'FROM players '
    'WHERE userName = @userName AND message IS NOT NULL '
    'LIMIT 1',
    substitutionValues: {'userName': userName},
  );

  if (result.isEmpty) return null;

  final row = result.first;
  final partner = row[0]?.toString() ?? '';
  final rawMessage = row[1];

  if (partner.isEmpty || rawMessage == null) return null;

  final Map<String, dynamic> decoded = rawMessage is String
      ? jsonDecode(rawMessage)
      : rawMessage as Map<String, dynamic>;

  final String type = decoded['type'] ?? 'unknown';

  // Convention : le vrai contenu est dans 'message'
  final Map<String, dynamic> message =
      decoded['message'] is Map<String, dynamic> ? decoded['message'] : decoded;

  return IncomingMessage(
    partner: partner,
    type: type,
    message: message,
  );
}

/// Afficher la liste des joueurs dans la console pour le débogage
Future<void> showPlayers(PlayerRepository repo) async {
  final results = await repo.connection.query(
      'SELECT userName, expectedName, partner, startTime, partnerStartTime, message FROM players');
  if (!debug) return;

  print('[$appName v$version] Joueurs enregistrés:');
  print('| Usr |  Time    |Prtnr|Message|');
  print('+-----+----------+-----+-------');

  for (final row in results) {
    final p = PlayerEntry.fromRow(row.toColumnMap());
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final userName =
        p.userName.length > 3 ? p.userName.substring(0, 3) : p.userName;
    final partner = p.partner.isEmpty
        ? ' — '
        : p.partner.length > 3
            ? p.partner.substring(0, 3)
            : p.partner;
    final message = p.message == null
        ? 'no'
        : p.message!['type'].toString().padRight(9).substring(0, 7);

    print('| $userName | $hms | $partner | $message |');
  }
}

Future<String> showPlayersAsHTML(PlayerRepository repo) async {
  final results = await repo.connection.query('SELECT * FROM players');
  final buffer = StringBuffer();

  buffer.writeln('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$appName v$version</title>
  <style>
    body {
      background-color: #000;
      color: #fff;
      font-family: Arial, sans-serif;
      font-size: clamp(12px, 1.8vw, 22px);
      padding: 10px;
    }

    h1 {
      font-size: clamp(20px, 3vw, 40px);
    }

    table {
      border-collapse: collapse;
      width: 100%;
      margin-top: 20px;
      font-size: inherit;
    }

    th, td {
      border: 1px solid #555;
      padding: 6px 10px;
      text-align: left;
      word-break: break-word;
    }

    th {
      background-color: #222;
    }

    tr:nth-child(even) {
      background-color: #111;
    }

    button {
      margin-top: 20px;
      padding: 8px 12px;
      font-size: clamp(12px, 1.5vw, 18px);
      border-radius: 6px;
      border: none;
      background: #444;
      color: white;
      cursor: pointer;
    }

    button:hover {
      background: #666;
    }

    .delete-button {
      background: #ff4444;
    }

    .delete-button:hover {
      background: #ff6666;
    }
  </style>
  <script>
    function confirmDelete(userName) {
      return confirm('Voulez-vous vraiment supprimer l\\'entrée pour ' + userName + ' ?');
    }
  </script>
</head>
<body>
''');

  buffer.writeln('<h1>$appName v$version</h1>');
  buffer.writeln('<table>');
  buffer.writeln(
      '<tr><th width="60pt">User</th><th width="60pt">Prtnr</th><th>Message</th><th width="30pt">Actions</th></tr>');

  for (final row in results) {
    final p = PlayerEntry.fromPgRow(row);
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final userName = p.userName;
    final partner =
        p.partner; // Conservez la valeur originale pour le formulaire
    final displayPartner = p.partner.isEmpty
        ? '—'
        : p.partner; // Utilisez cette valeur pour l'affichage
    final message = p.message == null ? 'no' : p.message!['type'].toString();

    buffer.writeln('''
    <tr>
      <td><center>$userName</center></td>
      <td><center>$displayPartner</center></td> <!-- Affiche le tiret si vide -->
      <td>$message</td>
      <td>
        <form method="POST" action="/admin/entryDelete" onsubmit="return confirmDelete('$userName-$partner')">
          <input type="hidden" name="userName" value="$userName">
          <input type="hidden" name="partner" value="$partner"> <!-- Utilisez la valeur originale -->
          <button type="submit" class="delete-button">x</button>
        </form>
      </td>
    </tr>
  ''');
  }

  buffer.writeln('</table>');

  // Bloc boutons
  buffer.writeln('''
    <div style="display:flex; gap:10px; margin-top:10px;">
      <form method="GET" action="/admin/players">
        <button type="submit">Rafraîchir</button>
      </form>
      <form method="POST" action="/admin/clear">
        <button type="submit">Clear Players</button>
      </form>
    </div>
  ''');

  buffer.writeln('</body></html>');

  return buffer.toString();
}
