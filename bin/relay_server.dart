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

void main() async {
  await startServer();
}

Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
      "[$appName v$version] HTTP relay_server started sur http://${server.address.address}:${server.port}");

  await for (final req in server) {
    final rqt = req.uri.path;

    try {
      if (req.method == 'POST' && rqt == '/connect') {
        await handleConnect(req);
      } else if (req.method == 'POST' && rqt == '/gamestate') {
        await handleGameState(req);
      } else if (req.method == 'POST' && rqt == '/gameover') {
        await handleGameOver(req);
      } else if (req.method == 'GET' && rqt == '/poll') {
        await handlePoll(req);
      } else if (req.method == 'GET' && rqt == '/disconnect') {
        await handleDisconnect(req);
      } else if (req.method == 'POST' && rqt == '/quit') {
        await handleQuit(req);
      } else if (rqt.startsWith('/admin')) {
        await handleAdmin(req);
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
