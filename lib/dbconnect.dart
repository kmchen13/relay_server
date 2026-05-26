import 'dart:io';
import 'package:postgres/postgres.dart';

Future<PostgreSQLConnection> openDb() async {
  final dbUrl = Platform.environment['DATABASE_URL'];

  if (dbUrl != null) {
    // --- MODE PROD (Render / Neon / etc.) ---
    final uri = Uri.parse(dbUrl);

    final conn = PostgreSQLConnection(
      uri.host,
      uri.port,
      uri.pathSegments.first,
      username: uri.userInfo.split(':').first,
      password: uri.userInfo.split(':').last,
      useSSL: true,
    );

    await conn.open();
    return conn;
  }

  // --- MODE LOCAL ---
  final conn = PostgreSQLConnection(
    'localhost',
    5432,
    'scrabble_p2p',
    username: 'kmc',
    password: 'qeladC?46',
    useSSL: false,
  );

  await conn.open();
  return conn;
}
