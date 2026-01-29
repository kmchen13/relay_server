import 'dart:convert';

class PlayerEntry {
  String userName; // le joueur local
  String expectedName; // partenaire attendu ("" = aléatoire)
  String partner; // rempli après match
  String language; // langue du joueur
  int startTime; // startTime local (ms epoch)
  int? partnerStartTime; // startTime du partenaire après match
  Map<String, dynamic>? message; // message en attente

  PlayerEntry({
    required this.userName,
    required this.expectedName,
    required this.startTime,
    required this.language,
    this.partner = '',
    this.partnerStartTime,
    this.message,
  });

  /// Conversion PlayerEntry → Map pour PostgreSQL
  Map<String, dynamic> asRow() => {
        'userName': userName,
        'expectedName': expectedName,
        'language': language,
        'partner': partner,
        'startTime': startTime,
        'partnerStartTime': partnerStartTime,
        'message': message != null ? jsonEncode(message) : null,
      };

  /// Conversion Map JSON → PlayerEntry (ex : fichier local)
  factory PlayerEntry.fromRow(Map<String, dynamic> row) {
    return PlayerEntry(
      userName: row['username']?.toString() ?? '',
      expectedName: row['expectedname']?.toString() ?? '',
      language: row['language']?.toString() ?? '',
      startTime: row['starttime'] is int
          ? row['starttime'] as int
          : int.tryParse(row['starttime']?.toString() ?? '0') ?? 0,
      partner: row['partner']?.toString() ?? '',
      partnerStartTime: row['partnerStarttime'] != null
          ? int.tryParse(row['partnerStarttime'].toString())
          : null,
      message: row['message'] != null
          ? jsonDecode(row['message'].toString()) as Map<String, dynamic>
          : null,
    );
  }

  /// Conversion PostgreSQL row (List) → PlayerEntry
  factory PlayerEntry.fromPgRow(List row) {
    return PlayerEntry(
      userName: row[1]?.toString() ?? '',
      expectedName: row[2]?.toString() ?? '',
      partner: row[3]?.toString() ?? '',
      language: row[4]?.toString() ?? '',
      startTime: row[5] is int
          ? row[5] as int
          : int.tryParse(row[4]?.toString() ?? '0') ?? 0,
      partnerStartTime: row[6] != null ? int.tryParse(row[6].toString()) : null,
      message: row[7] is Map<String, dynamic>
          ? row[7] as Map<String, dynamic>
          : row[7] != null
              ? jsonDecode(row[7].toString()) as Map<String, dynamic>
              : null,
    );
  }
}
