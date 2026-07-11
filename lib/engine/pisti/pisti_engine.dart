import '../../models/playing_card.dart';
import '../../models/game_room.dart';
import '../game_engine.dart';
import 'pisti_state.dart';

class PistiEngine implements GameEngine<PistiGameState, PistiMove> {
  static const int cardsPerDeal = 4;

  @override
  PistiGameState initializeGame(GameRoom room) {
    final deck = Deck.standard52()..shuffle();
    final playerOrder = room.players.keys.toList();

    final hands = <String, List<PlayingCard>>{};
    for (final playerId in playerOrder) {
      hands[playerId] = deck.draw(cardsPerDeal);
    }

    // Masaya 4 kart aç. Not: gerçek Pişti kurallarında masaya açılan kartlardan
    // biri Vale ise genelde yeniden dağıtılır; basitlik için bu MVP'de atlıyoruz.
    final tableCards = deck.draw(cardsPerDeal);

    final collectedCards = <String, List<PlayingCard>>{
      for (final playerId in playerOrder) playerId: [],
    };
    final pistiCounts = <String, int>{
      for (final playerId in playerOrder) playerId: 0,
    };

    return PistiGameState(
      hands: hands,
      tableCards: tableCards,
      deck: deck.cards,
      playerOrder: playerOrder,
      currentTurnPlayerId: playerOrder.first,
      collectedCards: collectedCards,
      pistiCounts: pistiCounts,
    );
  }

  @override
  bool isValidMove(PistiGameState state, String playerId, PistiMove move) {
    if (state.currentTurnPlayerId != playerId) return false;
    final hand = state.hands[playerId] ?? [];
    return hand.contains(move.cardPlayed);
  }

  @override
  PistiGameState applyMove(PistiGameState state, String playerId, PistiMove move) {
    final card = move.cardPlayed;

    // Elden kartı çıkar
    final newHands = {
      for (final entry in state.hands.entries)
        entry.key: List<PlayingCard>.from(entry.value),
    };
    newHands[playerId]!.remove(card);

    var newTableCards = List<PlayingCard>.from(state.tableCards);
    final newCollected = {
      for (final entry in state.collectedCards.entries)
        entry.key: List<PlayingCard>.from(entry.value),
    };
    final newPistiCounts = Map<String, int>.from(state.pistiCounts);
    String? newLastCollector = state.lastCollectorId;

    final tableWasSingleCard = newTableCards.length == 1;
    final topCard = newTableCards.isNotEmpty ? newTableCards.last : null;

    final isJack = card.rank == Rank.jack;
    final isMatch = topCard != null && topCard.rank == card.rank;

    if (newTableCards.isNotEmpty && (isJack || isMatch)) {
      // Masayı topla (Vale her zaman toplar / masayı yakar; eşleşme de toplar)
      newCollected[playerId]!.addAll(newTableCards);
      newCollected[playerId]!.add(card);
      newLastCollector = playerId;

      // Pişti bonusu: masada tek kart varken eşleşme ile toplandıysa (Vale ile değil)
      if (isMatch && tableWasSingleCard) {
        newPistiCounts[playerId] = (newPistiCounts[playerId] ?? 0) + 1;
      }

      newTableCards = [];
    } else {
      // Toplama yok, kartı masaya bırak
      newTableCards.add(card);
    }

    // Sıradaki oyuncuyu belirle
    final currentIndex = state.playerOrder.indexOf(playerId);
    final nextIndex = (currentIndex + 1) % state.playerOrder.length;
    var nextPlayerId = state.playerOrder[nextIndex];

    var newDeck = List<PlayingCard>.from(state.deck);

    // Tüm eller boşaldıysa yeni tur dağıt (deste yetiyorsa)
    final allHandsEmpty = newHands.values.every((h) => h.isEmpty);
    if (allHandsEmpty && newDeck.isNotEmpty) {
      for (final id in state.playerOrder) {
        final drawCount = cardsPerDeal > newDeck.length ? newDeck.length : cardsPerDeal;
        newHands[id] = newDeck.take(drawCount).toList();
        newDeck = newDeck.skip(drawCount).toList();
      }
    }

    // Deste de bittiyse ve eller boşsa: oyun bitiyor, masada kalan kartlar
    // son toplayan oyuncuya gider
    final trulyFinished = newHands.values.every((h) => h.isEmpty) && newDeck.isEmpty;
    if (trulyFinished && newTableCards.isNotEmpty && newLastCollector != null) {
      newCollected[newLastCollector]!.addAll(newTableCards);
      newTableCards = [];
    }

    return state.copyWith(
      hands: newHands,
      tableCards: newTableCards,
      deck: newDeck,
      currentTurnPlayerId: nextPlayerId,
      collectedCards: newCollected,
      pistiCounts: newPistiCounts,
      lastCollectorId: newLastCollector,
    );
  }

  @override
  bool isGameOver(PistiGameState state) {
    final allHandsEmpty = state.hands.values.every((h) => h.isEmpty);
    return allHandsEmpty && state.deck.isEmpty;
  }

  @override
  Map<String, int> calculateScores(PistiGameState state) {
    final scores = <String, int>{
      for (final id in state.playerOrder) id: 0,
    };

    for (final id in state.playerOrder) {
      scores[id] = scores[id]! + state.pistiCounts[id]! * 10;
    }

    String? mostCardsPlayer;
    var mostCards = -1;
    for (final id in state.playerOrder) {
      final count = state.collectedCards[id]!.length;
      if (count > mostCards) {
        mostCards = count;
        mostCardsPlayer = id;
      }
    }
    if (mostCardsPlayer != null) {
      scores[mostCardsPlayer] = scores[mostCardsPlayer]! + 3;
    }

    String? mostClubsPlayer;
    var mostClubs = -1;
    for (final id in state.playerOrder) {
      final count = state.collectedCards[id]!.where((c) => c.suit == Suit.clubs).length;
      if (count > mostClubs) {
        mostClubs = count;
        mostClubsPlayer = id;
      }
    }
    if (mostClubsPlayer != null) {
      scores[mostClubsPlayer] = scores[mostClubsPlayer]! + 1;
    }

    for (final id in state.playerOrder) {
      final hasDiamondTen = state.collectedCards[id]!
          .any((c) => c.suit == Suit.diamonds && c.rank == Rank.ten);
      if (hasDiamondTen) {
        scores[id] = scores[id]! + 3;
      }
    }

    for (final id in state.playerOrder) {
      final bonusCards = state.collectedCards[id]!
          .where((c) => c.rank == Rank.ace || c.rank == Rank.jack)
          .length;
      scores[id] = scores[id]! + bonusCards;
    }

    return scores;
  }
}