import 'dart:io';
import '../utils/player_utils.dart';
import '../utils/json_utils.dart';
import '../constants.dart';

Future<void> handleDisconnect(HttpRequest req) async {
  if (debug) {
    print(
        "[$appName v$version] ❌ /disconnect should not be called in web mode");
    showPlayers();
  }
}
