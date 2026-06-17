import 'package:postgres/postgres.dart';
import 'utility.dart';
import '../player_entry.dart';
import '../constants.dart';
import 'dart:convert';

class PlayerRepository {
  PostgreSQLConnection connection;

  PlayerRepository(this.connection);

  Future<void> init() async {
    await connection.query('''
CREATE TABLE IF NOT EXISTS players (
  id SERIAL PRIMARY KEY,
  user TEXT NOT NULL,
  expectedName TEXT NOT NULL DEFAULT '',
  partner TEXT NOT NULL DEFAULT '',
  language TEXT NOT NULL DEFAULT 'fr',
  startTime BIGINT NOT NULL,
  partnerStartTime BIGINT NULL,
  message TEXT,
  UNIQUE (user, partner)
);
    ''');
    await connection.query('DISCARD ALL;');
  }

  /// Insère ou met à jour un joueur
  Future<void> upsertPlayer(PlayerEntry player) async {
    final row = player.asRow();

    // On encode le message si ce n'est pas déjà une String
    if (row['message'] != null && row['message'] is! String) {
      row['message'] = jsonEncode(row['message']);
    }

    await connection.query('''
      INSERT INTO players (user, expectedName, partner, language, startTime, partnerStartTime, message)
      VALUES (@user, @expectedName, @partner, @language, @startTime, @partnerStartTime, @message)
      ON CONFLICT (user, partner) DO UPDATE
      SET expectedName = EXCLUDED.expectedName,
          partner = EXCLUDED.partner,
          language = EXCLUDED.language,
          startTime = EXCLUDED.startTime,
          partnerStartTime = EXCLUDED.partnerStartTime,
          message = EXCLUDED.message
    ''', substitutionValues: row);
  }

  /// Récupérer un joueur
  Future<PlayerEntry?> getPlayer(String user) async {
    final result = await connection.query(
      'SELECT user, expectedName, partner, language, startTime, partnerStartTime, message '
      'FROM players WHERE user = @user',
      substitutionValues: {'user': user},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final messageValue = row[5];

    final message =
        (messageValue is String) ? jsonDecode(messageValue) : messageValue;

    return PlayerEntry(
      user: row[0]?.toString() ?? '',
      expectedName: row[1]?.toString() ?? '',
      partner: row[2]?.toString() ?? '',
      language: row[2]?.toString() ?? 'fr',
      startTime: row[3] is int ? row[3] : int.tryParse(row[3].toString()) ?? 0,
      partnerStartTime: row[4] != null ? int.tryParse(row[4].toString()) : null,
      message: message is Map<String, dynamic> ? message : null,
    );
  }

  /// Récupérer tous les joueurs
  Future<List<PlayerEntry>> getAllPlayers() async {
    final result = await connection.query(
      'SELECT user, expectedName, partner, language, startTime, partnerStartTime, message FROM players',
    );

    return result.map((row) {
      final messageJson = row[5];
      return PlayerEntry(
        user: row[0] ?? '',
        expectedName: row[1] ?? '',
        partner: row[2] ?? '',
        language: row[2] ?? 'fr',
        startTime: row[3] ?? 0,
        partnerStartTime: row[4],
        message: messageJson != null
            ? jsonDecode(messageJson.toString()) as Map<String, dynamic>
            : null,
      );
    }).toList();
  }

  /// Supprime tous les joueurs
  Future<void> clearAllPlayers() async {
    await connection.execute('DELETE FROM players');
  }

  /// Supprimer l'entrée d'une partie d'un joueur
  Future<void> removePlayerEntry(String user, String partner) async {
    try {
      await connection.query(
        'DELETE FROM players WHERE user = @user AND partner = @partner',
        substitutionValues: {'user': user, 'partner': partner},
      );

      if (debug) {
        print("🗑️ Removed player entry: $user ↔ $partner");
      }
    } catch (e) {
      if (debug) {
        if (e is PostgreSQLException) {
          // Message d'erreur PostgreSQL
          print(
              "${logHeader('removePlayerEntry')} ❌ Erreur PostgreSQL: ${e.message}");
          // Code d'erreur PostgreSQL
          print(
              "${logHeader('removePlayerEntry')} 🔢 Code d'erreur: ${e.code}");
          // Sévérité de l'erreur (ex: ERROR, FATAL, etc.)
          print("${logHeader('removePlayerEntry')} ⚠️ Sévérité: ${e.severity}");
        } else {
          // Erreur générique
          print("${logHeader('removePlayerEntry')} ❌ Erreur inattendue: $e");
        }
      }
    }
  }

  /// Mettre à jour le message d'un joueur
  Future<void> updateMessage(
    String user,
    String partner,
    Map<String, dynamic> msg,
  ) async {
    try {
      await connection.query(
        '''
    UPDATE players
    SET message = @message
    WHERE user = @user AND partner = @partner
    ''',
        substitutionValues: {
          'user': user,
          'partner': partner,
          'message': jsonEncode(msg),
        },
      );
    } catch (e) {
      if (debug) {
        print("${logHeader('updateMessage')} Erreur inattendue: $e");
      }
    }
  }

  /// Match deux joueurs :
  /// - me : l'entrée qui vient d'appeler /connect
  /// - match : l'entrée trouvée comme partenaire potentiel
  ///
  /// Règle :
  ///   ✔ On ne modifie le partner du joueur distant que si partner=''
  ///   ✔ On ajoute toujours le message "matched"
  Future<void> matchPlayer(PlayerEntry me, PlayerEntry match) async {
    // 1️⃣ Mise à jour conditionnelle du partner du joueur distant
    try {
      await connection.query(
        '''
        UPDATE players
        SET partner = @meUserName,
            partnerStartTime = @meStartTime
        WHERE user = @theirUserName
          AND partner = ''
        ''',
        substitutionValues: {
          'meUserName': me.user,
          'meStartTime': me.startTime,
          'theirUserName': match.user,
        },
      );
    } catch (e) {
      if (debug) {
        print("${logHeader('matchPlayer')} Erreur UPDATE conditional: $e");
      }
    }

    // 2️⃣ Ajouter le message "matched" dans son entrée user-partner
    //    (ne dépend pas du résultat du UPDATE précédent)
    try {
      await updateMessage(
        match.user,
        me.user,
        {
          'type': 'matched',
          'partner': me.user,
          'startTime': match.startTime,
          'partnerStartTime': me.startTime,
        },
      );
    } catch (e) {
      if (debug) {
        print("${logHeader('matchPlayer')} Erreur updateMessage: $e");
      }
    }
  }
}
