import 'dart:convert';

class PlayerEntry {
  String userName; // le joueur local
  String expectedName; // partenaire attendu ("" = aléatoire)
  String partner; // rempli après match
  int startTime; // startTime local (ms epoch)
  int? partnerStartTime; // startTime du partenaire après match
  Map<String, dynamic>? message; // message en attente

  PlayerEntry({
    required this.userName,
    required this.expectedName,
    required this.startTime,
    this.partner = '',
    this.partnerStartTime,
    this.message,
  });

  /// Conversion PlayerEntry → Map pour PostgreSQL
  Map<String, dynamic> asRow() => {
        'userName': userName,
        'expectedName': expectedName,
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
      userName: row[0]?.toString() ?? '',
      expectedName: row[1]?.toString() ?? '',
      partner: row[2]?.toString() ?? '',
      startTime: row[3] is int
          ? row[3] as int
          : int.tryParse(row[3]?.toString() ?? '0') ?? 0,
      partnerStartTime: row[4] != null ? int.tryParse(row[4].toString()) : null,
      message: row[5] is Map<String, dynamic>
          ? row[5] as Map<String, dynamic>
          : row[5] != null
              ? jsonDecode(row[5].toString()) as Map<String, dynamic>
              : null,
    );
  }
}
