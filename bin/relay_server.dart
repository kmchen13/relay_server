import 'dart:io';
import 'utils/json_utils.dart';
import 'handlers/register_handler.dart';
import 'handlers/gamestate_handler.dart';
import 'handlers/gameover_handler.dart';
import 'handlers/poll_handler.dart';
import 'handlers/disconnect_handler.dart';
import 'constants.dart';

void main() async {
  await startServer();
}

Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print(
      "[$appName v$version] HTTP polling sur http://${server.address.address}:${server.port}");

  await for (final req in server) {
    try {
      if (req.method == 'POST' && req.uri.path == '/register') {
        await handleRegister(req);
      } else if (req.method == 'POST' && req.uri.path == '/gamestate') {
        await handleGameState(req);
      } else if (req.method == 'POST' && req.uri.path == '/gameover') {
        await handleGameOver(req);
      } else if (req.method == 'GET' && req.uri.path == '/poll') {
        await handlePoll(req);
      } else if (req.method == 'GET' && req.uri.path == '/disconnect') {
        await handleDisconnect(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        jsonResponse(req.response, {
          'error': 'not_found',
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
