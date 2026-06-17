import 'package:postgres/postgres.dart';

import '../constants.dart';
import '../models/message.dart';

class PlayersRepository {
  PostgreSQLConnection connection;

  PlayersRepository(this.connection);

  Future<void> init() async {
    await connection.query('''
      CREATE TABLE IF NOT EXISTS messages (
        user_name TEXT NOT NULL,
        partner_name TEXT NOT NULL DEFAULT '',
        date BIGINT NOT NULL,
        type TEXT NOT NULL,
        message TEXT NULL,
        PRIMARY KEY (user_name, partner_name, date)
      )
    ''');

    await connection.query('''
      CREATE INDEX IF NOT EXISTS idx_messages_date
      ON messages(date)
    ''');

    await connection.query('DISCARD ALL;');
  }

  bool isUniqueMessage(String type) {
    return type != 'CHAT';
  }

  Future<void> insertMessage({
    required String user,
    required String partner,
    required String type,
    required String message,
  }) async {
    if (isUniqueMessage(type)) {
      await connection.query(
        '''
        DELETE FROM messages
        WHERE user_name=@user_name
          AND partner_name=@partner_name
          AND type=@type
        ''',
        substitutionValues: {
          'user_name': user,
          'partner_name': partner,
          'type': type,
        },
      );
    }

    await connection.query(
      '''
      INSERT INTO messages
      (
        user_name,
        partner_name,
        date,
        type,
        message
      )
      VALUES
      (
        @user_name,
        @partner_name,
        @date,
        @type,
        @message
      )
      ''',
      substitutionValues: {
        'user_name': user,
        'partner_name': partner,
        'date': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'message': message,
      },
    );
  }

  Future<MessageEntry?> getOldestMessage(
    String user,
  ) async {
    final result = await connection.query(
      '''
      SELECT
        user_name,
        partner_name,
        date,
        type,
        message
      FROM messages
      WHERE user_name=@user_name
      ORDER BY date ASC
      LIMIT 1
      ''',
      substitutionValues: {
        'user_name': user,
      },
    );

    if (result.isEmpty) return null;

    return MessageEntry.fromRow(result.first);
  }

  Future<void> ack({
    required String user,
    required String? partner,
    required int date,
    required String type,
  }) async {
    final result = await connection.query(
      '''
      DELETE FROM messages
      WHERE user_name=@user_name
        AND partner_name=@partner_name
        AND date=@date
        AND type=@type
      ''',
      substitutionValues: {
        'user_name': user,
        'partner_name': partner,
        'date': date,
        'type': type,
      },
    );
    print(
      "ACK DELETE $user/$partner $type $date => ${result.length} ligne(s)",
    );
  }

  Future<void> deleteConnectMessages(
    String user,
  ) async {
    await connection.query(
      '''
      DELETE FROM messages
      WHERE user_name=@user_name
        AND type='CONNECT'
      ''',
      substitutionValues: {
        'user_name': user,
      },
    );
  }

  Future<void> deleteGameMessages(
    String user,
    String partner,
  ) async {
    await connection.query(
      '''
      DELETE FROM messages
      WHERE user_name=@user_name
        AND partner_name=@partner_name
        AND type IN ('GAMESTATE','GAMEOVER')
      ''',
      substitutionValues: {
        'user_name': user,
        'partner_name': partner,
      },
    );
  }

  Future<List<MessageEntry>> getAllMessages() async {
    final result = await connection.query(
      '''
      SELECT
        user_name,
        partner_name,
        date,
        type,
        message
      FROM messages
      ORDER BY date ASC
      ''',
    );

    return result.map((row) => MessageEntry.fromRow(row)).toList();
  }

  Future<void> deleteMessage(
    String user,
    String? partner,
    int date,
  ) async {
    await connection.query(
      '''
      DELETE FROM messages
      WHERE user_name=@user_name
        AND partner_name=@partner_name
        AND date=@date
      ''',
      substitutionValues: {
        'user_name': user,
        'partner_name': partner,
        'date': date,
      },
    );
  }

  Future<void> clear() async {
    await connection.execute(
      'DELETE FROM messages',
    );
  }

  Future<void> purgeExpiredMessages(
    Duration ttl,
  ) async {
    final limit = DateTime.now().millisecondsSinceEpoch - ttl.inMilliseconds;

    await connection.query(
      '''
      DELETE FROM messages
      WHERE date < @limit
      ''',
      substitutionValues: {
        'limit': limit,
      },
    );
  }

  Future<MessageEntry?> claimMatch(
    String user,
    String expected,
  ) async {
    return await connection.transaction((ctx) async {
      final result = await ctx.query(
        '''
        SELECT
          user_name,
          partner_name,
          date,
          type,
          message
        FROM messages
        WHERE type='CONNECT'
        AND (
          (
            @expected <> ''
            AND user_name=@expected
            AND (partner_name='' OR partner_name=@user)
          )
          OR
          (
            @expected=''
            AND user_name<>@user
            AND (partner_name='' OR partner_name=@user)
          )
        )
        ORDER BY date ASC
        LIMIT 1
        FOR UPDATE
        ''',
        substitutionValues: {
          'user': user,
          'expected': expected,
        },
      );

      if (result.isEmpty) return null;

      return MessageEntry.fromRow(result.first);
    });
  }

  Future<void> deleteMatchedConnect(
    MessageEntry match,
  ) async {
    await connection.query(
      '''
      DELETE FROM messages
      WHERE user_name=@user_name
        AND partner_name=@partner_name
        AND date=@date
        AND type='CONNECT'
      ''',
      substitutionValues: {
        'user_name': match.user,
        'partner_name': match.partner,
        'date': match.date,
      },
    );
  }
}
