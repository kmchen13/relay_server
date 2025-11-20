import 'dart:io';
import 'dart:async';
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

Future<void> main() async {
  PostgreSQLConnection? connection;
  final isLocal = Directory('/data').existsSync();

  // Fonction utilitaire pour créer une nouvelle connexion
  Future<PostgreSQLConnection> createConnection({required bool isLocal}) async {
    final host = isLocal
        ? 'ep-divine-breeze-ag5usc79-pooler.c-2.eu-central-1.aws.neon.tech'
        : 'ep-divine-breeze-ag5usc79.c-2.eu-central-1.aws.neon.tech';

    final dbName = isLocal ? 'dev' : 'scrabble_chen';

    final conn = PostgreSQLConnection(
      host,
      5432,
      dbName,
      username: 'kmc',
      password: 'npg_0BgstIKJf6Lj',
      useSSL: true,
    );

    await conn.open();
    print('✅ Connected to Neon Postgres (${isLocal ? "pooler" : "direct"})');
    return conn;
  }

// Détermination du mode de connexion
  try {
    connection = await createConnection(isLocal: isLocal);
  } catch (e) {
    print('⚠️ Erreur lors de la détection du serveur local: $e');
    connection = await createConnection(isLocal: false);
  }

  final repo = PlayerRepository(connection);
  await repo.init();

  // ✅ Boucle de surveillance pour rouvrir la connexion en cas de déconnexion
  Timer.periodic(Duration(minutes: 1), (timer) async {
    if (connection == null) return;
    if (connection!.isClosed) {
      print('🔄 Connection to Neon lost. Reconnecting...');
      try {
        await connection!.close();
      } catch (_) {}
      try {
        connection = await createConnection(isLocal: isLocal);
        repo.connection = connection!; // 🔁 Réinjecte la connexion dans le repo
        print('[$appName v$version] ✅ Reconnected to Neon Postgres.');
      } catch (e) {
        print('[$appName v$version] ❌ Failed to reconnect: $e');
      }
    }
  });

  // Lancer ton serveur principal
  await startServer(repo);
}

bool isLocalServer() {
  final dir = Directory('/data');
  return dir.existsSync();
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
      print(
          "[$appName v$version] ❌ Exception dans le serveur: $e\n Stack: $st");
    } finally {
      await req.response.close();
    }
  }
}
