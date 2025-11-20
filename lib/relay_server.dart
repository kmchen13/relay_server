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
import 'package:dotenv/dotenv.dart';

import 'package:postgres/postgres.dart';
import 'services/player_repository.dart';

Future<void> main() async {
  late PostgreSQLConnection connection;
  final isLocal = Directory('/data').existsSync();

  /// Détermine l'environnement en fonction de l'URL du serveur ou d'une variable.
  String _detectEnvironment() {
    final env = Platform.environment;
    // 2️⃣ Render.com fournit RENDER_EXTERNAL_URL automatiquement
    final serverUrl = env['RENDER_EXTERNAL_URL'] ?? '';
    if (serverUrl.contains('-eu')) return 'prod';
    if (serverUrl.contains('3lv4')) return 'test';
    return 'dev';
  }

  /// Charge la configuration depuis le fichier .env correspondant.
  Map<String, String> _loadConfig(String environment) {
    final envFile = '/etc/secrets/.env.$environment';
    final env = DotEnv()..load([envFile]);
    return {
      'host': env['DB_HOST']!,
      'name': env['DB_NAME']!,
      'user': env['DB_USER']!,
      'password': env['DB_PASSWORD']!,
      'port': env['DB_PORT']!,
    };
  }

  /// Fonction utilitaire pour créer la connexion DB.
  Future<PostgreSQLConnection> createConnection() async {
    final environment = _detectEnvironment();
    final config = _loadConfig(environment);

    final conn = PostgreSQLConnection(
      config['host']!,
      int.parse(config['port']!),
      config['name']!,
      username: config['user']!,
      password: config['password']!,
      useSSL: true,
    );

    await conn.open();
    print('✅ Connexion à la BDD ${config['name']} (env: $environment)');
    return conn;
  }

// Détermination du mode de connexion
  try {
    connection = await createConnection();
  } catch (e) {
    print('⚠️ Erreur lors de la détection du serveur local: $e');
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
        connection = await createConnection();
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
