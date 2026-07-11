import '../../models/playing_card.dart';

class PistiGameState {
  final Map<String, List<PlayingCard>> hands;
  final List<PlayingCard> tableCards;
  final List<PlayingCard> deck; // henüz dağıtılmamış kartlar
  final List<String> playerOrder;
  final String currentTurnPlayerId;
  final Map<String, List<PlayingCard>> collectedCards; // her oyuncunun topladığı kartlar
  final Map<String, int> pistiCounts; // her oyuncunun yaptığı "pişti" sayısı
  final String? lastCollectorId; // son kartları toplayan oyuncu (oyun sonu kalan kartlar buna gider)

  PistiGameState({
    required this.hands,
    required this.tableCards,
    required this.deck,
    required this.playerOrder,
    required this.currentTurnPlayerId,
    required this.collectedCards,
    required this.pistiCounts,
    this.lastCollectorId,
  });

  PistiGameState copyWith({
    Map<String, List<PlayingCard>>? hands,
    List<PlayingCard>? tableCards,
    List<PlayingCard>? deck,
    String? currentTurnPlayerId,
    Map<String, List<PlayingCard>>? collectedCards,
    Map<String, int>? pistiCounts,
    String? lastCollectorId,
  }) {
    return PistiGameState(
      hands: hands ?? this.hands,
      tableCards: tableCards ?? this.tableCards,
      deck: deck ?? this.deck,
      playerOrder: playerOrder,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      collectedCards: collectedCards ?? this.collectedCards,
      pistiCounts: pistiCounts ?? this.pistiCounts,
      lastCollectorId: lastCollectorId ?? this.lastCollectorId,
    );
  }
}

class PistiMove {
  final PlayingCard cardPlayed;

  const PistiMove(this.cardPlayed);
}