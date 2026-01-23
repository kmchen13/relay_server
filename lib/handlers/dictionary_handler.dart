import 'dart:io';

/// Handler HTTP pour /dictionary
///
/// - Paramètre requis : ?lang=fr|en|es
/// - Retourne le dictionnaire en texte brut (1 mot par ligne)
/// - Ferme la connexion après envoi (stateless)

Future<void> handleDictionary(HttpRequest request) async {
  final lang = request.uri.queryParameters['lang'] ?? 'fr';

  final file = File(
    Platform.script.resolve('../assets/${lang}_words.txt').toFilePath(),
  );

  if (!await file.exists()) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Dictionnaire $lang introuvable');
    await request.response.close();
    return;
  }

  request.response.headers.contentType = ContentType.text;

  // Envoi du fichier tel quel (texte brut)
  await request.response.addStream(file.openRead());
  await request.response.close();
}
