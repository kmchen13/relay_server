import 'package:postgres/postgres.dart';
import '../player_entry.dart';
import '../constants.dart';
import 'dart:convert';

class PlayerRepository {
  PostgreSQLConnection connection;

  PlayerRepository(this.connection);

  Future<void> init() async {
    // await connection.open();
    await connection.query('''
      CREATE TABLE IF NOT EXISTS players (
        userName TEXT PRIMARY KEY NOT NULL,
        expectedName TEXT NOT NULL DEFAULT '',
        partner TEXT NOT NULL DEFAULT '',
        startTime BIGINT NOT NULL,
        partnerStartTime BIGINT NULL,
        message JSONB
      )
    ''');
  }

  /// Insère ou met à jour un joueur
  Future<void> upsertPlayer(PlayerEntry player) async {
    final row = player.asRow();
    if (row['message'] != null && row['message'] is! String) {
      row['message'] = jsonEncode(row['message']);
    }
    await connection.query('''
      INSERT INTO players (userName, expectedName, partner, startTime, partnerStartTime, message)
      VALUES (@userName, @expectedName, @partner, @startTime, @partnerStartTime, @message::jsonb)
      ON CONFLICT (userName) DO UPDATE
      SET expectedName = EXCLUDED.expectedName,
          partner = EXCLUDED.partner,
          startTime = EXCLUDED.startTime,
          partnerStartTime = EXCLUDED.partnerStartTime,
          message = EXCLUDED.message
    ''', substitutionValues: row);
  }

  /// Récupérer un joueur
  Future<PlayerEntry?> getPlayer(String userName) async {
    final result = await connection.query(
      'SELECT userName, expectedName, partner, startTime, partnerStartTime, message '
      'FROM players WHERE userName = @userName',
      substitutionValues: {'userName': userName},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final messageValue = row[5];

    // 🔧 ici : messageValue peut être déjà Map<String, dynamic> ou une String JSON
    final message =
        (messageValue is String) ? jsonDecode(messageValue) : messageValue;

    return PlayerEntry(
      userName: row[0]?.toString() ?? '',
      expectedName: row[1]?.toString() ?? '',
      partner: row[2]?.toString() ?? '',
      startTime: row[3] is int ? row[3] : int.tryParse(row[3].toString()) ?? 0,
      partnerStartTime: row[4] != null ? int.tryParse(row[4].toString()) : null,
      message: message is Map<String, dynamic> ? message : null,
    );
  }

  /// Récupérer tous les joueurs
  Future<List<PlayerEntry>> getAllPlayers() async {
    final result = await connection.query(
      'SELECT userName, expectedName, partner, startTime, partnerStartTime, message FROM players',
    );

    return result.map((row) {
      final messageJson = row[5];
      return PlayerEntry(
        userName: row[0] ?? '',
        expectedName: row[1] ?? '',
        partner: row[2] ?? '',
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
  Future<void> removePlayerGame(String userName, String partner) async {
    await connection.query(
      'DELETE FROM players WHERE userName = @userName AND partner = @partner',
      substitutionValues: {'userName': userName, 'partner': partner},
    );

    if (debug) {
      print("🗑️ Removed game entry: $userName ↔ $partner");
    }
  }

  /// Mettre à jour le message d'un joueur
  Future<void> updateMessage(
    String userName,
    String partner,
    Map<String, dynamic> msg,
  ) async {
    await connection.query(
      '''
    UPDATE players
    SET message = @message::jsonb
    WHERE userName = @userName AND partner = @partner
    ''',
      substitutionValues: {
        'userName': userName,
        'partner': partner,
        'message': jsonEncode(msg),
      },
    );
  }
}
