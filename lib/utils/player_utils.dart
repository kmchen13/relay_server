import '../player_entry.dart';
import '../constants.dart';
import '../services/messages_repository.dart';
import '../models/message.dart';
import 'dart:convert';

/// Trouver une entrée de joueur ouverte (sans partenaire)
Future<PlayerEntry?> findOpenEntry(PlayersRepository repo, String user,
    String expectedName, String language) async {
  final results = await repo.connection.query(
    'SELECT * FROM players WHERE user = @user AND expectedName = @expectedName AND partner = \'\'',
    substitutionValues: {'user': user, 'expectedName': expectedName},
  );

  if (results.isEmpty) return null;
  return PlayerEntry.fromRow(results.first.toColumnMap());
}

/// Trouver un joueur correspondant pour le matching
Future<PlayerEntry?> findMatchingCounterpart(PlayersRepository repo, String me,
    String myExpected, String language) async {
  final results = await repo.connection.query(
    '''
    SELECT * FROM players 
    WHERE partner = '' AND user != @me 
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
/// - me.user != other.user
Future<void> matchPlayers(
  PlayersRepository repo,
  PlayerEntry me,
  PlayerEntry match,
) async {
  await repo.connection.query(
    '''
    UPDATE players
    SET partner = @meName,
        partnerStartTime = @meStart
    WHERE user = @matchName
      AND partner = ''
    ''',
    substitutionValues: {
      'meName': me.user,
      'meStart': me.startTime,
      'matchName': match.user,
    },
  );
}

/// Vérifie si deux joueurs sont déjà dans une même partie
Future<PlayerEntry?> findInGame(
  PlayersRepository repo,
  String user,
  String expectedName,
) async {
  final results = await repo.connection.query(
    'SELECT * FROM players WHERE user = @user AND partner = @partner',
    substitutionValues: {'user': user, 'partner': expectedName},
  );

  if (results.isEmpty) return null;
  return PlayerEntry.fromRow(results.first.toColumnMap());
}

/// Mettre en file un message pour un joueur spécifique.
/// Si aucune entrée (from → to) n'existe encore, elle est créée.
Future<void> queueMessageFor(
  PlayersRepository repo,
  String targetUser,
  String fromUser,
  Map<String, dynamic> msg,
) async {}

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
Future<IncomingMessage?> getMessage(PlayersRepository repo, String user) async {
  final result = await repo.connection.query(
    'SELECT partner, message '
    'FROM players '
    'WHERE user = @user AND message IS NOT NULL '
    'LIMIT 1',
    substitutionValues: {'user': user},
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
Future<void> showPlayers(PlayersRepository repo) async {
  final results = await repo.connection.query(
      'SELECT user, expectedName, partner, startTime, partnerStartTime, message FROM players');
  if (!debug) return;

  print('[$appName v$version] Joueurs enregistrés:');
  print('| Usr |  Time    |Prtnr|Message|');
  print('+-----+----------+-----+-------');

  for (final row in results) {
    final p = PlayerEntry.fromRow(row.toColumnMap());
    final dt = DateTime.fromMillisecondsSinceEpoch(p.startTime);
    final hms =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final user = p.user.length > 3 ? p.user.substring(0, 3) : p.user;
    final partner = p.partner.isEmpty
        ? ' — '
        : p.partner.length > 3
            ? p.partner.substring(0, 3)
            : p.partner;
    final message = p.message == null
        ? 'no'
        : p.message!['type'].toString().padRight(9).substring(0, 7);

    print('| $user | $hms | $partner | $message |');
  }
}

Future<String> showMessagesAsHTML(
  PlayersRepository repo,
) async {
  final results = await repo.connection.query('''
    SELECT
      user_name,
      partner_name,
      date,
      type,
      message
    FROM messages
    ORDER BY date ASC
    ''');

  final buffer = StringBuffer();

  buffer.writeln('''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">

<title>$appName v$version</title>

<style>
body {
 background:#000;
 color:#fff;
 font-family:Arial;
 padding:10px;
}

table {
 border-collapse:collapse;
 width:100%;
}

th,td {
 border:1px solid #555;
 padding:6px;
}

th {
 background:#222;
}

button {
 padding:8px 12px;
 font-size:16px;
 border-radius:6px;
 cursor:pointer;
}

.delete-button {
 background:#f44;
 color:white;
 border:none;
}

.delete-button:hover {
 background:#f66;
}

.refresh-button {
 background:#444;
 color:white;
 border:none;
}

</style>

<script>
function confirmDelete(x){
 return confirm("Supprimer "+x+" ?");
}
</script>

</head>

<body>
''');

  buffer.writeln('<h1>$appName v$version</h1>');

  buffer.writeln('''
<table>

<tr>
<th>User</th>
<th>Partner</th>
<th>Date</th>
<th>Type</th>
<th>Action</th>
</tr>
''');

  for (final row in results) {
    final msg = MessageEntry.fromRow(row);

    final dt = DateTime.fromMillisecondsSinceEpoch(msg.date);

    final hms = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    buffer.writeln('''
<tr>

<td>${msg.user}</td>

<td>${msg.partner ?? ''}</td>

<td>
${dt.toIso8601String()}<br>
$hms
</td>

<td>
${msg.type}
</td>

<td>

<form method="POST"
 action="/admin/entryDelete"
 onsubmit="return confirmDelete('${msg.user}-${msg.partner ?? ''}')">


<input type="hidden"
 name="user"
 value="${msg.user}">


<input type="hidden"
 name="partner"
 value="${msg.partner ?? ''}">


<input type="hidden"
 name="date"
 value="${msg.date}">


<button 
 type="submit"
 class="delete-button">
</button>


</form>

</td>

</tr>
''');
  }

  buffer.writeln('''
</table>

<br>

<div style="display:flex; gap:10px;">

<form method="GET" action="/admin/players">
<button class="refresh-button" type="submit">
Rafraîchir
</button>
</form>


<form method="POST" action="/admin/clear">

<button class="delete-button" type="submit">
Clear messages
</button>

</form>

</div>


</body>
</html>
''');

  return buffer.toString();
}
