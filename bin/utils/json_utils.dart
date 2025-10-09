import 'dart:convert';
import 'dart:io';

/// Envoie une réponse JSON au client HTTP.
///
/// - [res] : HttpResponse sur lequel écrire.
/// - [json] : Map<String, dynamic> représentant le contenu à envoyer.
/// - [statusCode] : code HTTP, par défaut 200 (OK).
void jsonResponse(HttpResponse res, Map<String, dynamic> json,
    {int statusCode = HttpStatus.ok}) {
  res.statusCode = statusCode;
  res.headers.contentType = ContentType.json;

  try {
    // Convertir la Map en JSON valide
    final jsonString = jsonEncode(json);
    res.write(jsonString);
  } catch (e) {
    // En cas d'erreur de sérialisation
    res.statusCode = HttpStatus.internalServerError;
    res.write(jsonEncode({
      'error': 'json_serialization_failed',
      'details': e.toString(),
    }));
  } finally {
    res.close();
  }
}
