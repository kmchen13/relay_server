import 'dart:async';
import 'dart:io';

import '../constants.dart';
import '../services/messages_repository.dart';
import '../utils/json_utils.dart';

Future<void> handlePoll(
  HttpRequest req,
  PlayersRepository repo,
) async {
  try {
    final user = req.uri.queryParameters['user'] ?? '';

    if (user.isEmpty) {
      jsonResponse(
        req.response,
        {
          'error': 'missing_user',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    var message = await repo.getOldestMessage(user);

    if (message == null) {
      jsonResponse(
        req.response,
        {
          'result': 'NO_MESSAGE',
        },
      );
      return;
    }

    jsonResponse(
      req.response,
      {
        'user': message.user,
        'partner': message.partner,
        'date': message.date,
        'type': message.type,
        'message': message.message,
      },
    );
  } catch (e) {
    jsonResponse(
      req.response,
      {
        'error': e.toString(),
      },
      statusCode: HttpStatus.internalServerError,
    );
  }
}
