import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_room.dart';
import '../engine/pisti/pisti_engine.dart';
import '../engine/pisti/pisti_state.dart';
import '../widgets/playing_card_widget.dart';

class PistiDemoScreen extends StatefulWidget {
  const PistiDemoScreen({super.key});

  @override
  State<PistiDemoScreen> createState() => _PistiDemoScreenState();
}

class _PistiDemoScreenState extends State<PistiDemoScreen> {
  final PistiEngine _engine = PistiEngine();
  late PistiGameState _state;
  Timer? _botTimer;

  String? _playingCardId;

  static const String me = 'me';
  static const String bot = 'bot';

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
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
      _playingCardId = null;
    });
    _maybeLetBotPlay();
  }

  Future<void> _playCard(PlayingCard card) async {
    final move = PistiMove(card);
    if (!_engine.isValidMove(_state, me, move)) return;
    if (_playingCardId != null) return;

    setState(() => _playingCardId = card.id);

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() {
      _state = _engine.applyMove(_state, me, move);
      _playingCardId = null;
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
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip('Sen', _state.collectedCards[me]!.length, _state.pistiCounts[me]!, isActive: myTurn),
                  _deckChip(_state.deck.length),
                  _infoChip('Bot', _state.collectedCards[bot]!.length, _state.pistiCounts[bot]!, isActive: !myTurn && !isGameOver),
                ],
              ),
            ),

            if (isGameOver) _buildGameOverPanel(),

            if (!isGameOver)
              Text(
                myTurn ? 'Senin sıran' : 'Bot oynuyor...',
                style: TextStyle(
                  color: myTurn ? Colors.amberAccent : Colors.white70,
                  fontSize: 16,
                  fontWeight: myTurn ? FontWeight.bold : FontWeight.normal,
                ),
              ),

            const SizedBox(height: 16),

            Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(
                (_state.hands[bot] ?? []).length,
                (i) => const CardBackWidget(),
              ),
            ),

            const Spacer(),

            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (int i = 0; i < _state.tableCards.length; i++)
                  Padding(
                    key: ValueKey('${_state.tableCards[i].id}_$i'),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _AnimatedTableCard(
                      child: PlayingCardWidget(card: _state.tableCards[i], width: 56, height: 80),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            Wrap(
              alignment: WrapAlignment.center,
              children: myHand.map((card) {
                final isPlaying = _playingCardId == card.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedScale(
                    scale: isPlaying ? 0.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeIn,
                    child: AnimatedOpacity(
                      opacity: isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: PlayingCardWidget(
                        card: card,
                        raised: myTurn && !isPlaying,
                        onTap: (myTurn && _playingCardId == null) ? () => _playCard(card) : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, int cardCount, int pistiCount, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFFFC107).withValues(alpha: 0.7) : Colors.white12,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '$cardCount kart · $pistiCount pişti',
            style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _deckChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text('DESTE', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
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

/// Masaya yeni giren bir kartın yukarıdan kayarak, büyüyerek ve belirerek
/// "yerine oturmasını" sağlayan giriş animasyonu.
class _AnimatedTableCard extends StatelessWidget {
  final Widget child;

  const _AnimatedTableCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, (1 - value) * 24),
          child: Transform.scale(
            scale: value,
            child: Opacity(opacity: clamped, child: child),
          ),
        );
      },
      child: child,
    );
  }
}