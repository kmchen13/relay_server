import 'package:postgres/postgres.dart';
import '../constants.dart';

class MessageRepository {
  final PostgreSQLConnection connection;

  MessageRepository(this.connection);

  Future<void> init() async {
    await connection.query('''
CREATE TABLE messages (
    language TEXT,
    userName TEXT,
    expectedName TEXT,
    partner TEXT,
    date BIGINT,
    type TEXT,
    message TEXT,
    PRIMARY KEY (userName, partner),
    INDEX idx_messages_date ON messages(date)
);
    ''');
    await connection.query('DISCARD ALL;');
  }

  Future<void> insertOrReplaceMessage({
    required String language,
    required String userName,
    required String expectedName,
    required String partner,
    required String type,
    required String message,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await connection.query('''
      INSERT INTO messages(language, userName, expectedName, partner, date, type, message)
      VALUES (@language, @userName, @expectedName, @partner, @date, @type, @message)
      ON CONFLICT (userName, partner)
      DO UPDATE SET
        date = @date,
        type = @type,
        message = @message
    ''', substitutionValues: {
      'language': language,
      'userName': userName,
      'expectedName': expectedName,
      'partner': partner,
      'date': now,
      'type': type,
      'message': message,
    });
  }

  Future<Map<String, dynamic>?> getMessage(String userName) async {
    final result = await connection.query('''
      SELECT language, userName, expectedName, partner, date, type, message
      FROM messages
      WHERE userName = @userName
      LIMIT 1
    ''', substitutionValues: {'userName': userName});

    if (result.isEmpty) return null;

    final row = result.first;
    return {
      'language': row[0],
      'userName': row[1],
      'expectedName': row[2],
      'partner': row[3],
      'date': row[4],
      'type': row[5],
      'message': row[6],
    };
  }

  Future<void> deleteMessage(String userName, String partner) async {
    await connection.query('''
      DELETE FROM messages
      WHERE userName = @userName AND partner = @partner
    ''', substitutionValues: {
      'userName': userName,
      'partner': partner,
    });
  }

  Future<List<String>> getFreePlayers(String language) async {
    final result = await connection.query('''
      SELECT userName
      FROM messages
      WHERE type = 'HELLO'
      AND language = @language
    ''', substitutionValues: {'language': language});

    return result.map((r) => r[0] as String).toList();
  }

  Future<void> deleteOldMessages() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final warningLimit = now - messageLifetimeMs;
    final deleteLimit = now - messageLifetimeMs - warningDeltaMs;

    // WARNING
    final warningMessages = await connection.query('''
      SELECT userName, partner
      FROM messages
      WHERE date < @warningLimit
      AND type NOT IN ('WARNING')
    ''', substitutionValues: {'warningLimit': warningLimit});

    for (final row in warningMessages) {
      final user = row[0];
      final partner = row[1];

      final deleteTimestamp = now + warningDeltaMs;

      await insertOrReplaceMessage(
        language: '',
        userName: user,
        expectedName: '',
        partner: partner,
        type: 'WARNING',
        message: deleteTimestamp.toString(),
      );

      await insertOrReplaceMessage(
        language: '',
        userName: partner,
        expectedName: '',
        partner: user,
        type: 'WARNING',
        message: deleteTimestamp.toString(),
      );
    }

    // DELETE
    await connection.query('''
      DELETE FROM messages
      WHERE date < @deleteLimit
    ''', substitutionValues: {'deleteLimit': deleteLimit});
  }

  Future<void> cleanupOldGames() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final warningLimit = now - messageLifetimeMs;
    final deleteLimit = now - messageLifetimeMs - warningDeltaMs;

    /// 1. Envoyer WARNING
    final oldGames = await connection.query('''
    SELECT userName, partner
    FROM players
    WHERE date < @warningLimit
    AND type NOT IN ('WARNING')
  ''', substitutionValues: {
      'warningLimit': warningLimit,
    });

    for (final row in oldGames) {
      final user = row[0];
      final partner = row[1];
      final deleteTimestamp = now + warningDeltaMs;

      await sendMessage(user, partner, MSG_WARNING, deleteTimestamp.toString());
      await sendMessage(partner, user, MSG_WARNING, deleteTimestamp.toString());
    }

    /// 2. Supprimer après délai
    await connection.query('''
    DELETE FROM players
    WHERE date < @deleteLimit
  ''', substitutionValues: {
      'deleteLimit': deleteLimit,
    });
  }
}
