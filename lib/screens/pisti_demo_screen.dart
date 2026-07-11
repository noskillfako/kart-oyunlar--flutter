import 'dart:math';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_room.dart';
import '../engine/pisti/pisti_engine.dart';
import '../engine/pisti/pisti_state.dart';
import '../widgets/playing_card_widget.dart';
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
    _botTimer = Timer(const Duration(milliseconds: 1000), () {
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
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGameOver = _engine.isGameOver(_state);
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me && !isGameOver;

    // Canlı skor hesaplama
    final scores = _engine.calculateScores(_state);
    final myScore = scores[me] ?? 0;
    final botScore = scores[bot] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pişti (Demo - Bot ile)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F3A1D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _startNewGame,
            tooltip: 'Yeni Oyun',
          ),
        ],
      ),
      body: Container(
        // Radyal yeşil oyun masası arka planı
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1E5B32), // Açık yeşil çuha merkez
              Color(0xFF0D321A), // Koyu orman yeşili kenarlar
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Üst Skor Paneli (Dashboard)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip('Sen', _state.collectedCards[me]!.length, _state.pistiCounts[me]!, myScore, isMyTurn: myTurn),
                    _deckChip(_state.deck.length),
                    _infoChip('Bot', _state.collectedCards[bot]!.length, _state.pistiCounts[bot]!, botScore, isMyTurn: !myTurn && !isGameOver),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Rakip (Bot) Kartları
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  spacing: -16, // Kartların eldeki gibi üst üste binmesi
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    (_state.hands[bot] ?? []).length,
                    (i) => const CardBackWidget(width: 50, height: 72),
                  ),
                ),
              ),

              // 3. Orta Oyun Alanı (Masa)
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    height: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 220), // BoxConstraints ile düzeltildi
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(120), // Oval hatlı masa halkası
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 2.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_state.tableCards.isEmpty)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.style_outlined, color: Colors.white.withValues(alpha: 0.2), size: 36),
                              const SizedBox(height: 6),
                              Text(
                                'Masa Boş',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        
                        // Üst üste açılı duran masa kartları
                        for (int i = 0; i < _state.tableCards.length; i++)
                          Positioned(
                            left: (MediaQuery.of(context).size.width - 40 - 32 - 54) / 2 + (i - (_state.tableCards.length - 1) / 2) * 12.0,
                            child: Transform.rotate(
                              angle: (i == _state.tableCards.length - 1) ? 0 : (i * 0.08 - 0.12),
                              child: PlayingCardWidget(
                                card: _state.tableCards[i],
                                width: 54,
                                height: 76,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Oyun Bittiğinde Çıkacak Panel
              if (isGameOver)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildGameOverPanel(myScore, botScore),
                )
              else
                // 4. Sıra Kimde Göstergesi
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: myTurn 
                        ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: myTurn ? const Color(0xFFFFB300).withValues(alpha: 0.4) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        myTurn ? Icons.play_arrow_rounded : Icons.hourglass_empty_rounded,
                        color: myTurn ? const Color(0xFFFFB300) : Colors.white60,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        myTurn ? 'Senin Sıran' : 'Bot Düşünüyor...',
                        style: TextStyle(
                          color: myTurn ? const Color(0xFFFFB300) : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // 5. Oyuncu Kartları (Alt Kısım)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: myHand.map((card) {
                    return PlayingCardWidget(
                      card: card,
                      width: 58,
                      height: 82,
                      raised: myTurn,
                      onTap: myTurn ? () => _playCard(card) : null,
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, int cardCount, int pistiCount, int score, {required bool isMyTurn}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      width: 110,
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? const Color(0xFFFFC107).withValues(alpha: 0.7) : Colors.white12,
          width: isMyTurn ? 1.5 : 1.0,
        ),
        boxShadow: isMyTurn ? [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.1),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isMyTurn ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score Puan',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$cardCount k. | $pistiCount p.',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
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
          const Text(
            'DESTE',
            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 1),
          const Text(
            'Kalan',
            style: TextStyle(color: Colors.white30, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverPanel(int myScore, int botScore) {
    final winner = myScore > botScore
        ? 'Tebrikler, Kazandın! 🎉'
        : (myScore == botScore ? 'Beraberlik!' : 'Bot Kazandı.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            winner,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Senin Puanın', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$myScore', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  const Text('Botun Puanı', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$botScore', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              onPressed: _startNewGame,
              child: const Text('Yeniden Oyna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}