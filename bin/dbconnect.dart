import 'dart:io';
import 'package:postgres/postgres.dart';

Future<PostgreSQLConnection> openDb() async {
  final dbUrl = Platform.environment['DATABASE_URL'];
  if (dbUrl == null) {
    throw Exception('DATABASE_URL not set');
  }

  final uri = Uri.parse(dbUrl);

  final conn = PostgreSQLConnection(
    uri.host,
    uri.port,
    uri.pathSegments.first, // database name (neondb)
    username: uri.userInfo.split(':').first,
    password: uri.userInfo.split(':').last,
    useSSL: true,
  );

  await conn.open();
  return conn;
}
