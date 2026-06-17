class MessageEntry {
  final String user;
  final String? partner;
  final int date;
  final String type;
  final String? message;

  MessageEntry({
    required this.user,
    this.partner,
    required this.date,
    required this.type,
    this.message,
  });

  Map<String, dynamic> asRow() => {
        'user': user,
        'partner': partner,
        'date': date,
        'type': type,
        'message': message,
      };

  factory MessageEntry.fromRow(List<dynamic> row) {
    return MessageEntry(
      user: row[0].toString(),
      partner: row[1]?.toString(),
      date: row[2] is int ? row[2] : int.parse(row[2].toString()),
      type: row[3].toString(),
      message: row[4]?.toString(),
    );
  }
}
