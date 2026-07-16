import '../../models/playing_card.dart';

enum BatakPhase { bidding, chooseTrump, playing, finished }

class TrickCard {
  final String playerId;
  final PlayingCard card;
  const TrickCard(this.playerId, this.card);
}

class BatakGameState {
  final Map<String, List<PlayingCard>> hands;
  final List<String> playerOrder;
  final String dealerId;
  final BatakPhase phase;

  final Map<String, int> bids; // sadece bid yapanlar
  final Set<String> passedPlayers;
  final String? highestBidderId;
  final int highestBid;

  final String currentTurnPlayerId;
  final Suit? trumpSuit;
  final bool trumpBroken; // Koz çekildi/kırıldı mı?
  final String? declarerId;

  final List<TrickCard> currentTrick;
  final String? trickLeaderId;
  final Map<String, int> tricksWon;

  const BatakGameState({
    required this.hands,
    required this.playerOrder,
    required this.dealerId,
    required this.phase,
    required this.bids,
    required this.passedPlayers,
    required this.currentTurnPlayerId,
    required this.tricksWon,
    this.highestBidderId,
    this.highestBid = 0,
    this.trumpSuit,
    this.trumpBroken = false,
    this.declarerId,
    this.currentTrick = const [],
    this.trickLeaderId,
  });

  BatakGameState copyWith({
    Map<String, List<PlayingCard>>? hands,
    BatakPhase? phase,
    Map<String, int>? bids,
    Set<String>? passedPlayers,
    String? highestBidderId,
    int? highestBid,
    String? currentTurnPlayerId,
    Suit? trumpSuit,
    bool? trumpBroken,
    String? declarerId,
    List<TrickCard>? currentTrick,
    String? trickLeaderId,
    Map<String, int>? tricksWon,
  }) {
    return BatakGameState(
      hands: hands ?? this.hands,
      playerOrder: playerOrder,
      dealerId: dealerId,
      phase: phase ?? this.phase,
      bids: bids ?? this.bids,
      passedPlayers: passedPlayers ?? this.passedPlayers,
      highestBidderId: highestBidderId ?? this.highestBidderId,
      highestBid: highestBid ?? this.highestBid,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      trumpBroken: trumpBroken ?? this.trumpBroken,
      declarerId: declarerId ?? this.declarerId,
      currentTrick: currentTrick ?? this.currentTrick,
      trickLeaderId: trickLeaderId ?? this.trickLeaderId,
      tricksWon: tricksWon ?? this.tricksWon,
    );
  }
}