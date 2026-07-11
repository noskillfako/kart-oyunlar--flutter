enum Suit { spades, hearts, diamonds, clubs } // maça, kupa, karo, sinek

enum Rank {
  two, three, four, five, six, seven, eight, nine, ten,
  jack, queen, king, ace
}

class PlayingCard {
  final Suit suit;
  final Rank rank;

  const PlayingCard(this.suit, this.rank);

  String get id => '${rank.name}_${suit.name}';

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => id;
  Map<String, dynamic> toMap() => {'suit': suit.name, 'rank': rank.name};

  factory PlayingCard.fromMap(Map<String, dynamic> map) {
    return PlayingCard(
      Suit.values.firstWhere((s) => s.name == map['suit']),
      Rank.values.firstWhere((r) => r.name == map['rank']),
    );
  }
}

class Deck {
  final List<PlayingCard> cards;

  Deck._(this.cards);

  factory Deck.standard52() {
    final cards = [
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(suit, rank)
    ];
    return Deck._(cards);
  }

  void shuffle() => cards.shuffle();

  bool get isEmpty => cards.isEmpty;
  int get length => cards.length;

  List<PlayingCard> draw(int count) {
    final actualCount = count > cards.length ? cards.length : count;
    final drawn = cards.take(actualCount).toList();
    cards.removeRange(0, actualCount);
    return drawn;
  }
  
}