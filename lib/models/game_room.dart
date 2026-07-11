class GameRoom {
  final String id;
  final String gameType;
  final String status; // "waiting" | "playing" | "finished"
  final int maxPlayers;
  final Map<String, dynamic> players; // uid -> {displayName, isReady, ...}
  final String hostId; // odayı kuran kişi

  GameRoom({
    required this.id,
    required this.gameType,
    required this.status,
    required this.maxPlayers,
    required this.players,
    required this.hostId,
  });

  factory GameRoom.fromMap(String id, Map<String, dynamic> data) {
    return GameRoom(
      id: id,
      gameType: data['gameType'] ?? 'pisti',
      status: data['status'] ?? 'waiting',
      maxPlayers: data['maxPlayers'] ?? 2,
      players: Map<String, dynamic>.from(data['players'] ?? {}),
      hostId: data['hostId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameType': gameType,
      'status': status,
      'maxPlayers': maxPlayers,
      'players': players,
      'hostId': hostId,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}