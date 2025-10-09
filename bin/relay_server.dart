import 'dart:io';
import 'utils/json_utils.dart';
import 'handlers/connect_handler.dart';
import 'handlers/gamestate_handler.dart';
import 'handlers/gameover_handler.dart';
import 'handlers/poll_handler.dart';
import 'handlers/disconnect_handler.dart';
import 'handlers/quit_handler.dart';
import 'handlers/admin_handler.dart';
import 'constants.dart';
import 'package:postgres/postgres.dart';
import 'services/player_repository.dart';

void main() async {
  final connection = PostgreSQLConnection(
    // 'ep-divine-breeze-ag5usc79-pooler.c-2.eu-central-1.aws.neon.tech', // host
    'ep-divine-breeze-ag5usc79.c-2.eu-central-1.aws.neon.tech',
    5432, // port
    'scrabble_chen', // database
    // username: 'neondb_owner',
    // password: 'npg_Y8Qg0IqUFdBE',
    username: 'kmc',
    password: 'npg_0BgstIKJf6Lj',
    useSSL: true,
  );

  await connection.open();
  print('✅ Connected to Neon Postgres!');
  final repo = PlayerRepository(connection);
  await repo.init();
  // repo.clearAllPlayers(); // Nettoyer la BDD au démarrage
  await startServer(repo);
}

Future<void> startServer(repo) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
      "[$appName v${version}] démarré sur http://${server.address.address}:${server.port}");

  await for (final req in server) {
    final rqt = req.uri.path;

    try {
      if (req.method == 'POST' && rqt == '/connect') {
        await handleConnect(req, repo);
      } else if (req.method == 'POST' && rqt == '/gamestate') {
        await handleGameState(req, repo);
      } else if (req.method == 'POST' && rqt == '/gameover') {
        await handleGameOver(req, repo);
      } else if (req.method == 'GET' && rqt == '/poll') {
        await handlePoll(req, repo);
      } else if (req.method == 'GET' && rqt == '/disconnect') {
        await handleDisconnect(req, repo);
      } else if (req.method == 'POST' && rqt == '/quit') {
        await handleQuit(req, repo);
      } else if (rqt.startsWith('/admin')) {
        await handleAdmin(req, repo);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        jsonResponse(req.response, {
          'error': 'page_not_found',
          'message': 'Endpoint non trouvé',
        });
      }
    } catch (e, st) {
      if (debug) {
        print("[$appName v$version] ❌ Exception: $e");
        print(st);
      }
      jsonResponse(
          req.response,
          {
            'error': 'server_error',
            'details': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    } finally {
      await req.response.close();
    }
  }
}
