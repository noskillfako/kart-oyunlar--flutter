import '../../models/playing_card.dart';
import '../../models/game_room.dart';
import '../game_engine.dart';
import 'batak_move.dart';
import 'batak_state.dart';

class BatakEngine implements GameEngine<BatakGameState, BatakMove> {
  static const int cardsPerPlayer = 13;
  static const int minBid = 7;   // Minimum ihale kontratı
  static const int forcedBid = 6; // Kimse girmezse ilk sorulana kalır
  static const int maxBid = 13;

  final _rankOrder = [
    Rank.two, Rank.three, Rank.four, Rank.five, Rank.six, Rank.seven,
    Rank.eight, Rank.nine, Rank.ten, Rank.jack, Rank.queen, Rank.king, Rank.ace,
  ];

  int _rankValue(Rank rank) => _rankOrder.indexOf(rank);

  @override
  BatakGameState initializeGame(GameRoom room) {
    final playerOrder = room.players.keys.toList();
    if (playerOrder.length != 4) {
      throw Exception('Batak tam olarak 4 oyuncu gerektirir');
    }

    final deck = Deck.standard52()..shuffle();
    final hands = <String, List<PlayingCard>>{};
    for (final id in playerOrder) {
      hands[id] = deck.draw(cardsPerPlayer);
    }

    final dealerId = playerOrder.first;
    final firstBidderIndex = (playerOrder.indexOf(dealerId) + 1) % playerOrder.length;

    return BatakGameState(
      hands: hands,
      playerOrder: playerOrder,
      dealerId: dealerId,
      phase: BatakPhase.bidding,
      bids: {},
      passedPlayers: {},
      currentTurnPlayerId: playerOrder[firstBidderIndex],
      tricksWon: {for (final id in playerOrder) id: 0},
    );
  }

  @override
  bool isValidMove(BatakGameState state, String playerId, BatakMove move) {
    if (state.currentTurnPlayerId != playerId) return false;

    switch (move.type) {
      case BatakMoveType.bid:
        if (state.phase != BatakPhase.bidding) return false;
        final amount = move.bidAmount;
        if (amount == null) return false;
        if (amount < minBid || amount > maxBid) return false;
        if (amount <= state.highestBid) return false;
        return true;

      case BatakMoveType.pass:
        if (state.phase != BatakPhase.bidding) return false;
        return true;

      case BatakMoveType.chooseTrump:
        if (state.phase != BatakPhase.chooseTrump) return false;
        if (state.declarerId != playerId) return false;
        return move.trumpSuit != null;

      case BatakMoveType.playCard:
        if (state.phase != BatakPhase.playing) return false;
        final card = move.card;
        if (card == null) return false;
        final hand = state.hands[playerId] ?? [];
        if (!hand.contains(card)) return false;

        final isNewTrick = state.currentTrick.isEmpty || state.currentTrick.length == 4;
        if (isNewTrick) {
          // Koz çekilmeden koz atılamaz (eğer elindeki tüm kartlar koz değilse)
          if (state.trumpSuit != null && card.suit == state.trumpSuit && !state.trumpBroken) {
            final hasOtherSuits = hand.any((c) => c.suit != state.trumpSuit);
            if (hasOtherSuits) return false;
          }
        } else {
          final ledSuit = state.currentTrick.first.card.suit;
          final ledCards = hand.where((c) => c.suit == ledSuit).toList();

          if (ledCards.isNotEmpty) {
            // Renk takip zorunluluğu — o renkte herhangi bir kartı oynayabilirsin
            if (card.suit != ledSuit) return false;
            // Kart yükseltme: trick'te koz yoksa büyük oynamak zorunlu
            final trumpInTrick = state.trumpSuit != null &&
                state.currentTrick.any((tc) => tc.card.suit == state.trumpSuit);
            if (!trumpInTrick) {
              PlayingCard? highestLedCard;
              for (final tc in state.currentTrick) {
                if (tc.card.suit == ledSuit) {
                  if (highestLedCard == null || _rankValue(tc.card.rank) > _rankValue(highestLedCard.rank)) {
                    highestLedCard = tc.card;
                  }
                }
              }
              if (highestLedCard != null) {
                final hasHigherLedCard = ledCards.any((c) => _rankValue(c.rank) > _rankValue(highestLedCard!.rank));
                if (hasHigherLedCard && _rankValue(card.rank) <= _rankValue(highestLedCard.rank)) {
                  return false;
                }
              }
            }
          } else {
            // Renk yoksa, çakma (koz atma) durumları
            final trumpSuit = state.trumpSuit;
            if (trumpSuit != null) {
              final trumpCards = hand.where((c) => c.suit == trumpSuit).toList();
              
              if (trumpCards.isNotEmpty) {
                // Yerdeki en büyük kozu bul
                PlayingCard? highestTrumpCard;
                for (final tc in state.currentTrick) {
                  if (tc.card.suit == trumpSuit) {
                    if (highestTrumpCard == null || _rankValue(tc.card.rank) > _rankValue(highestTrumpCard.rank)) {
                      highestTrumpCard = tc.card;
                    }
                  }
                }

                if (highestTrumpCard != null) {
                   // Yerde zaten koz var.
                   // Elinde koz varken başka renk atamazsın (koz atmak zorundasın).
                   if (card.suit != trumpSuit) return false;
                   
                   final hasHigherTrump = trumpCards.any((c) => _rankValue(c.rank) > _rankValue(highestTrumpCard!.rank));
                   if (hasHigherTrump) {
                     // Eğer daha büyük kozun varsa, onu geçmek zorundasın.
                     if (_rankValue(card.rank) <= _rankValue(highestTrumpCard.rank)) return false;
                   }
                } else {
                   // Yerde henüz koz yok (ilk çakan sen olacaksın)
                   // Elinde koz varken kesinlikle koz atmak zorundasın (mecburi çakış).
                   if (card.suit != trumpSuit) return false;
                }
              }
            }
          }
        }
        return true;
    }
  }

  @override
  BatakGameState applyMove(BatakGameState state, String playerId, BatakMove move) {
    switch (move.type) {
      case BatakMoveType.bid:
        return _applyBid(state, playerId, move.bidAmount!);
      case BatakMoveType.pass:
        return _applyPass(state, playerId);
      case BatakMoveType.chooseTrump:
        return _applyChooseTrump(state, move.trumpSuit!);
      case BatakMoveType.playCard:
        return _applyPlayCard(state, playerId, move.card!);
    }
  }

  BatakGameState _applyBid(BatakGameState state, String playerId, int amount) {
    final newBids = Map<String, int>.from(state.bids)..[playerId] = amount;
    final nextTurn = _nextActiveBidder(state, playerId);

    if (nextTurn == null) {
      // Sadece bu oyuncu bid yapmış ve herkes pas geçmiş: ihale kazandı
      return state.copyWith(
        bids: newBids,
        highestBidderId: playerId,
        highestBid: amount,
        phase: BatakPhase.chooseTrump,
        declarerId: playerId,
        currentTurnPlayerId: playerId,
      );
    }

    return state.copyWith(
      bids: newBids,
      highestBidderId: playerId,
      highestBid: amount,
      currentTurnPlayerId: nextTurn,
    );
  }

  BatakGameState _applyPass(BatakGameState state, String playerId) {
    final newPassed = Set<String>.from(state.passedPlayers)..add(playerId);
    final activeCount = state.playerOrder.length - newPassed.length;

    // Herkes pas geçtiyse: ilk ihale sorulana (dağıtıcının solu) 6 ihale kalır
    if (activeCount == 0 && state.highestBidderId == null) {
      final firstBidderId = state.playerOrder[
          (state.playerOrder.indexOf(state.dealerId) + 1) % state.playerOrder.length];
      return state.copyWith(
        passedPlayers: newPassed,
        highestBidderId: firstBidderId,
        highestBid: forcedBid,
        phase: BatakPhase.chooseTrump,
        declarerId: firstBidderId,
        currentTurnPlayerId: firstBidderId,
      );
    }

    // Sadece en yüksek bid'i yapan kaldıysa ihale biter
    if (activeCount <= 1 && state.highestBidderId != null) {
      return state.copyWith(
        passedPlayers: newPassed,
        phase: BatakPhase.chooseTrump,
        declarerId: state.highestBidderId,
        currentTurnPlayerId: state.highestBidderId,
      );
    }

    final nextTurn = _nextActiveBidder(state, playerId, updatedPassed: newPassed);
    return state.copyWith(
      passedPlayers: newPassed,
      currentTurnPlayerId: nextTurn ?? state.highestBidderId ?? state.dealerId,
    );
  }

  String? _nextActiveBidder(BatakGameState state, String fromPlayerId, {Set<String>? updatedPassed}) {
    final passed = updatedPassed ?? state.passedPlayers;
    final order = state.playerOrder;
    final startIndex = order.indexOf(fromPlayerId);

    for (int offset = 1; offset < order.length; offset++) {
      final candidate = order[(startIndex + offset) % order.length];
      if (!passed.contains(candidate)) return candidate;
    }
    return null;
  }

  BatakGameState _applyChooseTrump(BatakGameState state, Suit trumpSuit) {
    final declarer = state.declarerId!;
    return state.copyWith(
      trumpSuit: trumpSuit,
      phase: BatakPhase.playing,
      currentTurnPlayerId: declarer,
      trickLeaderId: declarer,
    );
  }

  BatakGameState _applyPlayCard(BatakGameState state, String playerId, PlayingCard card) {
    final newHands = {
      for (final entry in state.hands.entries)
        entry.key: List<PlayingCard>.from(entry.value),
    };
    newHands[playerId]!.remove(card);

    var currentTrick = state.currentTrick;
    if (currentTrick.length == 4) {
      currentTrick = const [];
    }

    final newTrick = List<TrickCard>.from(currentTrick)
      ..add(TrickCard(playerId, card));

    bool newTrumpBroken = state.trumpBroken;
    // Eğer oynanan kart koz ise ve daha önce kırılmadıysa, koz kırılır.
    if (!newTrumpBroken && state.trumpSuit != null && card.suit == state.trumpSuit) {
      newTrumpBroken = true;
    }

    if (newTrick.length < state.playerOrder.length) {
      final nextIndex = (state.playerOrder.indexOf(playerId) + 1) % state.playerOrder.length;
      return state.copyWith(
        hands: newHands,
        currentTrick: newTrick,
        currentTurnPlayerId: state.playerOrder[nextIndex],
        trumpBroken: newTrumpBroken,
      );
    }

    // Trick tamamlandı: kazananı bul
    final winnerId = _determineTrickWinner(newTrick, state.trumpSuit);
    final newTricksWon = Map<String, int>.from(state.tricksWon);
    newTricksWon[winnerId] = (newTricksWon[winnerId] ?? 0) + 1;

    final allHandsEmpty = newHands.values.every((h) => h.isEmpty);

    return state.copyWith(
      hands: newHands,
      currentTrick: newTrick, // 4 kart olarak bırakıyoruz, UI gösterebilsin
      trickLeaderId: winnerId,
      currentTurnPlayerId: winnerId,
      tricksWon: newTricksWon,
      phase: allHandsEmpty ? BatakPhase.finished : BatakPhase.playing,
      trumpBroken: newTrumpBroken,
    );
  }

  String _determineTrickWinner(List<TrickCard> trick, Suit? trumpSuit) {
    final ledSuit = trick.first.card.suit;

    final trumpCards = trumpSuit != null
        ? trick.where((t) => t.card.suit == trumpSuit).toList()
        : <TrickCard>[];

    if (trumpCards.isNotEmpty) {
      trumpCards.sort((a, b) => _rankValue(b.card.rank) - _rankValue(a.card.rank));
      return trumpCards.first.playerId;
    }

    final ledSuitCards = trick.where((t) => t.card.suit == ledSuit).toList();
    ledSuitCards.sort((a, b) => _rankValue(b.card.rank) - _rankValue(a.card.rank));
    return ledSuitCards.first.playerId;
  }

  @override
  bool isGameOver(BatakGameState state) => state.phase == BatakPhase.finished;

  @override
  Map<String, int> calculateScores(BatakGameState state) {
    final scores = <String, int>{for (final id in state.playerOrder) id: 0};
    final declarer = state.declarerId;
    if (declarer == null) return scores;

    final highestBid = state.highestBid;

    // Declarer (İhaleyi alan)
    final declarerTricks = state.tricksWon[declarer] ?? 0;
    scores[declarer] = declarerTricks >= highestBid
        ? highestBid * 10
        : -(highestBid * 10);

    // Non-Declarers (İhaleye girmeyenler)
    for (final id in state.playerOrder) {
      if (id == declarer) continue;
      final tricks = state.tricksWon[id] ?? 0;
      if (tricks > 0) {
        scores[id] = tricks * 10; // İhaleye girmeyip el alanlara el sayısı * 10
      } else {
        scores[id] = -(highestBid * 10); // İhaleye girmeyip 0 çekenlere ihale bedeli kadar ceza
      }
    }

    return scores;
  }
}