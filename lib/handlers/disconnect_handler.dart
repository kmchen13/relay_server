import 'dart:io';
import '../services/player_repository.dart';

Future<void> handleDisconnect(HttpRequest req, PlayerRepository repo) async {
  print("handleDisconnect should never be called");
  // This endpoint is no longer used. Si un joueur s'est connecté, puis déconnecté, il reste elligible pour une nouvelle partie.
  // Todo: remove player from repo if needed or after a timeout
}
