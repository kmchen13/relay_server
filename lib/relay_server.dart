import 'dart:io';
import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';
import 'utils/json_utils.dart';
import 'handlers/connect_handler.dart';
import 'handlers/gamestate_handler.dart';
import 'handlers/gameover_handler.dart';
import 'handlers/poll_handler.dart';
import 'handlers/disconnect_handler.dart';
import 'handlers/quit_handler.dart';
import 'handlers/admin_handler.dart';
import 'handlers/ack_handler.dart';
import 'handlers/dictionary_handler.dart';
import 'handlers/get_free_players.dart';
import 'constants.dart';
import 'services/messages_repository.dart';

///Affichage des logs de requêtes HTTP avec un formatage spécifique.
String? _lastLogKey;
int _repeatCount = 0;
String? _lastTimestamp;

void _logRequest(String rqt, Map<String, String> queryParameters) {
  final sortedParams = queryParameters.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final key =
      '$rqt?${sortedParams.map((e) => '${e.key}=${e.value}').join('&')}';

  if (key == _lastLogKey) {
    _repeatCount++;

    // Ajouter uniquement le compteur
    stdout.write('\r'); // retour au début de la ligne
    stdout.write(
      '[v$version] $_lastTimestamp ➡️ $rqt / $queryParameters, x$_repeatCount',
    );
  } else {
    // Valider la ligne précédente
    if (_lastLogKey != null) {
      stdout.writeln();
    }

    _lastLogKey = key;
    _repeatCount = 1;
    _lastTimestamp = DateTime.now().toString();

    stdout.write(
      '[v$version] $_lastTimestamp ➡️ $rqt / $queryParameters',
    );
  }

  stdout.flush();
}

Future<void> main() async {
  late PostgreSQLConnection connection;

  /// Détermine si l'application s'exécute en local
  bool isLocalEnvironment() {
    final env = Platform.environment;
    return !env.containsKey('RENDER_EXTERNAL_URL');
  }

  /// Charge la configuration en fonction de l'environnement
  Map<String, String> loadConfig() {
    if (isLocalEnvironment()) {
      // En local, charge le fichier .env.dev
      print(
          '[$appName v$version] ⚙️ Chargement de la configuration en mode local');
      final env = DotEnv()..load(['.env.dev']);
      return {
        'host': env['DB_HOST'] ?? (throw Exception('DB_HOST non défini')),
        'name': env['DB_NAME'] ?? (throw Exception('DB_NAME non défini')),
        'user': env['DB_USER'] ?? (throw Exception('DB_USER non défini')),
        'password':
            env['DB_PASSWORD'] ?? (throw Exception('DB_PASSWORD non défini')),
        'port': env['DB_PORT'] ?? '5432',
      };
    } else {
      // En production (Render.com), utilise Platform.environment
      print(
          '[$appName v$version] ⚙️ Chargement de la configuration en mode production');
      final env = Platform.environment;
      return {
        'host': env['DB_HOST'] ?? (throw Exception('DB_HOST non défini')),
        'name': env['DB_NAME'] ?? (throw Exception('DB_NAME non défini')),
        'user': env['DB_USER'] ?? (throw Exception('DB_USER non défini')),
        'password':
            env['DB_PASSWORD'] ?? (throw Exception('DB_PASSWORD non défini')),
        'port': env['DB_PORT'] ?? '5432',
      };
    }
  }

  /// Fonction utilitaire pour créer la connexion DB
  Future<PostgreSQLConnection> createConnection() async {
    final config = loadConfig();
    final conn = PostgreSQLConnection(
      config['host']!,
      int.parse(config['port']!),
      config['name']!,
      username: config['user']!,
      password: config['password']!,
      useSSL: true,
    );
    await conn.open();
    final environment = isLocalEnvironment() ? 'dev' : 'prod';
    print('✅ Connexion à la BDD ${config['name']} (env: $environment)');
    return conn;
  }

  // Détermination du mode de connexion
  try {
    connection = await createConnection();
  } catch (e) {
    print('⚠️ Erreur lors de la connexion à la BDD: $e');
    rethrow;
  }

  final repo = PlayersRepository(connection);
  await repo.init();

  // Boucle de surveillance pour rouvrir la connexion en cas de déconnexion
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (connection.isClosed) {
      print('🔄 Connection to Neon lost. Reconnecting...');
      try {
        await connection.close();
      } catch (_) {}
      try {
        connection = await createConnection();
        repo.connection = connection; // Réinjecte la connexion dans le repo
        print('[$appName v$version] ✅ Reconnected to Neon Postgres.');
      } catch (e) {
        print('[$appName v$version] ❌ Failed to reconnect: $e');
      }
    }
  });

  // Lancer le serveur principal
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
    if (debug) {
      _logRequest(rqt, req.uri.queryParameters);
    }
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
      } else if (rqt.startsWith('/acknowledgement')) {
        await handleAck(req, repo);
      } else if (rqt == '/dictionary') {
        await handleDictionary(req);
      } else if (req.method == 'GET' && rqt == '/freeplayers') {
        await getFreePlayersList(req, repo);
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
