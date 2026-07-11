import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';
import '../services/game_service.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  String _cardLabel(PlayingCard card) {
    const rankLabels = {
      Rank.two: '2', Rank.three: '3', Rank.four: '4', Rank.five: '5',
      Rank.six: '6', Rank.seven: '7', Rank.eight: '8', Rank.nine: '9',
      Rank.ten: '10', Rank.jack: 'V', Rank.queen: 'K', Rank.king: 'Ş', Rank.ace: 'A',
    };
    const suitSymbols = {
      Suit.spades: '♠', Suit.hearts: '♥', Suit.diamonds: '♦', Suit.clubs: '♣',
    };
    return '${rankLabels[card.rank]}${suitSymbols[card.suit]}';
  }

  Color _cardColor(PlayingCard card) {
    return (card.suit == Suit.hearts || card.suit == Suit.diamonds)
        ? Colors.red
        : Colors.black;
  }

  Widget _buildCard(PlayingCard card, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
        alignment: Alignment.center,
        child: Text(
          _cardLabel(card),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _cardColor(card),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceDownCards(int count) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: List.generate(
        count,
        (i) => Container(
          width: 40,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.blue[900],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapılmamış')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Pişti - Oda: ${widget.roomId}')),
      backgroundColor: Colors.green[800],
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _gameService.watchPublicState(widget.roomId),
          builder: (context, publicSnap) {
            if (!publicSnap.hasData || !publicSnap.data!.exists) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Oyun hazırlanıyor...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              );
            }

            final pub = publicSnap.data!.data()!;
            final status = pub['status'] ?? 'playing';
            final currentTurnPlayerId = pub['currentTurnPlayerId'] as String?;
            final playerOrder = List<String>.from(pub['playerOrder'] ?? []);
            final handCounts = Map<String, dynamic>.from(pub['handCounts'] ?? {});
            final pistiCounts = Map<String, dynamic>.from(pub['pistiCounts'] ?? {});
            final tableCardsRaw = List<Map<String, dynamic>>.from(pub['tableCards'] ?? []);
            final tableCards = tableCardsRaw.map((c) => PlayingCard.fromMap(c)).toList();
            final deckCount = pub['deckCount'] ?? 0;

            final opponentId = playerOrder.firstWhere(
              (id) => id != _myUid,
              orElse: () => '',
            );
            final myTurn = currentTurnPlayerId == _myUid;

            if (status == 'finished') {
              return _buildFinishedPanel(pub, playerOrder);
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Chip(label: Text('Rakip pişti: ${pistiCounts[opponentId] ?? 0}')),
                      Chip(label: Text('Sen pişti: ${pistiCounts[_myUid] ?? 0}')),
                      Chip(label: Text('Deste: $deckCount')),
                    ],
                  ),
                ),
                Text(
                  myTurn ? 'Senin sıran' : 'Rakip oynuyor...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildFaceDownCards(
                  (handCounts[opponentId] ?? 0) is int
                      ? handCounts[opponentId] ?? 0
                      : 0,
                ),
                const Spacer(),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: tableCards.map((c) => _buildCard(c)).toList(),
                ),
                const Spacer(),
                StreamBuilder<List<PlayingCard>>(
                  stream: _gameService.watchMyHand(widget.roomId),
                  builder: (context, handSnap) {
                    final myHand = handSnap.data ?? [];
                    return Wrap(
                      alignment: WrapAlignment.center,
                      children: myHand.map((card) {
                        return _buildCard(
                          card,
                          onTap: myTurn
                              ? () => _gameService.playCard(widget.roomId, card)
                              : null,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinishedPanel(Map<String, dynamic> pub, List<String> playerOrder) {
    final scores = Map<String, dynamic>.from(pub['scores'] ?? {});
    final myScore = scores[_myUid] ?? 0;
    final opponentId = playerOrder.firstWhere((id) => id != _myUid, orElse: () => '');
    final opponentScore = scores[opponentId] ?? 0;

    final resultText = myScore > opponentScore
        ? 'Kazandın! 🎉'
        : (myScore == opponentScore ? 'Berabere!' : 'Kaybettin.');

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(resultText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Senin puanın: $myScore'),
              Text('Rakip puanı: $opponentScore'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Ana Ekrana Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}