import 'dart:math';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_room.dart';
import '../engine/pisti/pisti_engine.dart';
import '../engine/pisti/pisti_state.dart';
import 'dart:async';

class PistiDemoScreen extends StatefulWidget {
  const PistiDemoScreen({super.key});

  @override
  State<PistiDemoScreen> createState() => _PistiDemoScreenState();
}

class _PistiDemoScreenState extends State<PistiDemoScreen> {
  final PistiEngine _engine = PistiEngine();
  late PistiGameState _state;
  Timer? _botTimer;

  static const String me = 'me';
  static const String bot = 'bot';

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    final fakeRoom = GameRoom(
      id: 'demo-room',
      gameType: 'pisti',
      status: 'playing',
      maxPlayers: 2,
      hostId: me,
      players: {
        me: {'displayName': 'Sen'},
        bot: {'displayName': 'Bot'},
      },
    );
    setState(() {
      _state = _engine.initializeGame(fakeRoom);
    });
    _maybeLetBotPlay();
  }

  void _playCard(PlayingCard card) {
    final move = PistiMove(card);
    if (!_engine.isValidMove(_state, me, move)) return;

    setState(() {
      _state = _engine.applyMove(_state, me, move);
    });

    _maybeLetBotPlay();
  }

  void _maybeLetBotPlay() {
    if (_engine.isGameOver(_state)) return;
    if (_state.currentTurnPlayerId != bot) return;

    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final hand = _state.hands[bot] ?? [];
      if (hand.isEmpty) return;

      final randomCard = hand[Random().nextInt(hand.length)];
      final move = PistiMove(randomCard);

      setState(() {
        _state = _engine.applyMove(_state, bot, move);
      });

      _maybeLetBotPlay();
    });
  }

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
  
  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGameOver = _engine.isGameOver(_state);
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me && !isGameOver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pişti (Demo - Bot ile)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: 'Yeni Oyun',
          ),
        ],
      ),
      backgroundColor: Colors.green[800],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip('Sen', _state.collectedCards[me]!.length, _state.pistiCounts[me]!),
                  _infoChip('Bot', _state.collectedCards[bot]!.length, _state.pistiCounts[bot]!),
                  Chip(label: Text('Deste: ${_state.deck.length}')),
                ],
              ),
            ),

            if (isGameOver) _buildGameOverPanel(),

            if (!isGameOver)
              Text(
                myTurn ? 'Senin sıran' : 'Bot oynuyor...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(
                (_state.hands[bot] ?? []).length,
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
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: _state.tableCards.map((c) => _buildCard(c)).toList(),
              ),
            ),

            const Spacer(),

            Wrap(
              alignment: WrapAlignment.center,
              children: myHand.map((card) {
                return _buildCard(
                  card,
                  onTap: myTurn ? () => _playCard(card) : null,
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, int cardCount, int pistiCount) {
    return Chip(
      label: Text('$label: $cardCount kart, $pistiCount pişti'),
    );
  }

  Widget _buildGameOverPanel() {
    final scores = _engine.calculateScores(_state);
    final myScore = scores[me] ?? 0;
    final botScore = scores[bot] ?? 0;
    final winner = myScore > botScore ? 'Sen kazandın! 🎉' : (myScore == botScore ? 'Berabere!' : 'Bot kazandı.');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(winner, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Senin puanın: $myScore'),
            Text('Bot puanı: $botScore'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startNewGame,
              child: const Text('Yeni Oyun'),
            ),
          ],
        ),
      ),
    );
  }
}