import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/player_repository.dart';

class handleGetFreePlayers {
  final PlayerRepository playerRepository;

  handleGetFreePlayers(this.playerRepository);

  Future<Response> handle(Request request) async {
    try {
      final language = request.url.queryParameters['language'] ?? 'fr';

      final players = await playerRepository.getFreePlayers(language);

      return Response.ok(
        jsonEncode({
          "status": "ok",
          "players": players,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          "status": "error",
          "message": e.toString(),
        }),
      );
    }
  }
}
