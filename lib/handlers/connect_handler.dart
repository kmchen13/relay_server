import 'dart:io';
import 'dart:convert';
import '../utils/json_utils.dart';
import '../services/messages_repository.dart';

Future<void> handleConnect(HttpRequest req, PlayersRepository repo) async {
  final body = await utf8.decoder.bind(req).join();

  final params = jsonDecode(body) as Map<String, dynamic>;

  final user = params['user']?.toString() ?? '';
  final partner = params['expectedName']?.toString() ?? '';

  if (user.isEmpty) {
    jsonResponse(
        req.response,
        {
          'status': 'ERROR',
          'message': 'missing user',
        },
        statusCode: HttpStatus.badRequest);
    return;
  }

  final match = await repo.claimMatch(user, partner);

  if (match != null) {
    // Suppression du CONNECT ayant servi au match
    await repo.deleteMatchedConnect(match);

    // Notification du partenaire
    await repo.insertMessage(
      user: match.user,
      partner: user,
      type: 'MATCHED',
      message: '',
    );

    jsonResponse(req.response, {'status': 'MATCHED', 'partner': match.user});

    return;
  }

  await repo.insertMessage(
    user: user,
    partner: partner,
    type: 'CONNECT',
    message: '',
  );

  jsonResponse(req.response, {'status': 'WAITING'});
}
