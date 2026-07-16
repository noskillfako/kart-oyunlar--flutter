import '../../models/playing_card.dart';

enum BatakMoveType { bid, pass, chooseTrump, playCard }

class BatakMove {
  final BatakMoveType type;
  final int? bidAmount;
  final Suit? trumpSuit;
  final PlayingCard? card;

  const BatakMove.bid(int amount)
      : type = BatakMoveType.bid,
        bidAmount = amount,
        trumpSuit = null,
        card = null;

  const BatakMove.pass()
      : type = BatakMoveType.pass,
        bidAmount = null,
        trumpSuit = null,
        card = null;

  const BatakMove.chooseTrump(Suit suit)
      : type = BatakMoveType.chooseTrump,
        bidAmount = null,
        trumpSuit = suit,
        card = null;

  const BatakMove.playCard(PlayingCard playedCard)
      : type = BatakMoveType.playCard,
        bidAmount = null,
        trumpSuit = null,
        card = playedCard;
}