import 'dart:io';

import '../services/messages_repository.dart';
import '../utils/json_utils.dart';

Future<void> handleAck(HttpRequest req, PlayersRepository repo) async {
  try {
    final user = req.uri.queryParameters['user'] ?? '';

    final partner = req.uri.queryParameters['partner'];

    final type = req.uri.queryParameters['type'] ?? '';

    final dateStr = req.uri.queryParameters['date'] ?? '';

    if (user.isEmpty || type.isEmpty || dateStr.isEmpty) {
      jsonResponse(
          req.response,
          {
            'error': 'missing_parameter',
          },
          statusCode: HttpStatus.badRequest);
      return;
    }

    final date = int.tryParse(dateStr);

    if (date == null) {
      jsonResponse(
          req.response,
          {
            'error': 'invalid_date',
          },
          statusCode: HttpStatus.badRequest);
      return;
    }

    await repo.ack(user: user, partner: partner, date: date, type: type);

    jsonResponse(req.response, {'status': 'OK'});
  } catch (e) {
    jsonResponse(
        req.response,
        {
          'error': e.toString(),
        },
        statusCode: HttpStatus.internalServerError);
  }
}
