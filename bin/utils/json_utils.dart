import 'dart:convert';
import 'dart:io';

void jsonResponse(HttpResponse res, Map<String, dynamic> json,
    {int statusCode = HttpStatus.ok}) {
  res.statusCode = statusCode;
  res.headers.contentType = ContentType.json;
  res.write(jsonEncode(json));
}
