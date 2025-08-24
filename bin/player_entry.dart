class PlayerEntry {
  String userName; // le joueur local
  String expectedName; // partenaire attendu ("" = aléatoire)
  String partner; // rempli après match
  int startTime; // startTime local (ms epoch)
  int? partnerStartTime; // startTime du partenaire après match
  String gameId; // rempli au match
  Map<String, dynamic>? message; // message en attente

  PlayerEntry({
    required this.userName,
    required this.expectedName,
    required this.startTime,
    this.partner = '',
    this.partnerStartTime,
    this.gameId = '',
    this.message,
  });

  Map<String, dynamic> asRow() => {
        'userName': userName,
        'expectedName': expectedName,
        'partner': partner,
        'startTime': startTime,
        'partnerStartTime': partnerStartTime,
        'gameId': gameId,
        'message': message,
      };
}
