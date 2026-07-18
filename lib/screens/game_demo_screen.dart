import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_room.dart';
import '../engine/pisti/pisti_engine.dart';
import '../engine/pisti/pisti_state.dart';
import '../engine/batak/batak_engine.dart';
import '../engine/batak/batak_state.dart';
import '../engine/batak/batak_move.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/collect_animation_overlay.dart';
import '../theme/app_theme.dart';

// ─── Oyun Demo Ekranı (Pişti veya Batak) ─────────────────────────────────────
class GameDemoScreen extends StatelessWidget {
  final String gameType; // 'pisti' veya 'batak'
  const GameDemoScreen({super.key, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final isPisti = gameType == 'pisti';
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      appBar: AppBar(
        title: Text(isPisti ? 'Pişti Demo' : 'Batak Demo'),
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeni Oyun',
            onPressed: () {
              // Sayfayı yeniden yükle
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GameDemoScreen(gameType: gameType),
                ),
              );
            },
          ),
        ],
      ),
      body: isPisti ? const _PistiDemo() : const _BatakDemo(),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// PİŞTİ DEMO
// ═══════════════════════════════════════════════════════════════════════════════
class _PistiDemo extends StatefulWidget {
  const _PistiDemo();

  @override
  State<_PistiDemo> createState() => _PistiDemoState();
}

class _PistiDemoState extends State<_PistiDemo> {
  final PistiEngine _engine = PistiEngine();
  late PistiGameState _state;
  Timer? _botTimer;
  String? _playingCardId;

  List<PlayingCard>? _collectingCards;
  Alignment _collectTarget = Alignment.bottomCenter;

  static const me = 'me';
  static const bot = 'bot';

  @override
  void initState() {
    super.initState();
    _startNew();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _startNew() {
    final room = GameRoom(
      id: 'demo-pisti',
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
      _state = _engine.initializeGame(room);
      _playingCardId = null;
      _collectingCards = null;
    });
    _maybeLetBotPlay();
  }

  Future<void> _playCard(PlayingCard card) async {
    if (_playingCardId != null) return;
    final move = PistiMove(card);
    if (!_engine.isValidMove(_state, me, move)) return;

    setState(() => _playingCardId = card.id);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final tableBeforeMove = List<PlayingCard>.from(_state.tableCards);
    final newState = _engine.applyMove(_state, me, move);
    final didCollect = newState.tableCards.isEmpty && tableBeforeMove.isNotEmpty;

    setState(() {
      _state = newState;
      _playingCardId = null;
      if (didCollect) {
        _collectingCards = [...tableBeforeMove, card];
        _collectTarget = Alignment.bottomCenter;
      }
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
      final card = hand[Random().nextInt(hand.length)];

      final tableBeforeMove = List<PlayingCard>.from(_state.tableCards);
      final newState = _engine.applyMove(_state, bot, PistiMove(card));
      final didCollect = newState.tableCards.isEmpty && tableBeforeMove.isNotEmpty;

      setState(() {
        _state = newState;
        if (didCollect) {
          _collectingCards = [...tableBeforeMove, card];
          _collectTarget = Alignment.topCenter;
        }
      });
      _maybeLetBotPlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final over = _engine.isGameOver(_state);
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me && !over;
    final scores = _engine.calculateScores(_state);
    final myScore = scores[me] ?? 0;
    final botScore = scores[bot] ?? 0;
    final botHandCount = (_state.hands[bot] ?? []).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.3,
          colors: [AppColors.midGreen, AppColors.deepGreen],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [

            // ── Kompakt Üst Şerit: Skor | Deste | Bot kartları ────────────
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              color: Colors.black.withValues(alpha: 0.15),
              child: Row(
                children: [
                  // Sen tarafı
                  Expanded(
                    child: _pistiChip('Sen',
                      _state.collectedCards[me]!.length,
                      _state.pistiCounts[me]!,
                      score: myScore,
                      isActive: myTurn,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Orta: Deste + Sıra göstergesi
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _deckChip(_state.deck.length),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: myTurn
                              ? AppColors.gold.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: myTurn ? AppColors.gold.withValues(alpha: 0.5) : Colors.white12,
                          ),
                        ),
                        child: Text(
                          over ? 'Oyun bitti' : (myTurn ? '▶ Senin sıran' : 'Bot oynuyor'),
                          style: TextStyle(
                            color: myTurn ? AppColors.gold : Colors.white38,
                            fontSize: 9,
                            fontWeight: myTurn ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  // Bot tarafı: skor chip + mini kartlar
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _pistiChip('Bot',
                          _state.collectedCards[bot]!.length,
                          _state.pistiCounts[bot]!,
                          score: botScore,
                          isActive: !myTurn && !over,
                        ),
                        if (botHandCount > 0) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (int i = 0; i < botHandCount; i++)
                                  Positioned(
                                    right: i * 14.0,
                                    child: const CardBackWidget(width: 28, height: 36),
                                  ),
                                SizedBox(width: botHandCount * 14.0 + 28),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Kaydırılabilir orta bölüm: sadece masa ───────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (over)
                      _pistiGameOver()
                    else
                      // ── Masa ──────────────────────────────────────────────
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _tableArea(
                            children: [
                              for (int i = 0; i < _state.tableCards.length; i++)
                                _AnimCard(
                                  key: ValueKey('${_state.tableCards[i].id}_$i'),
                                  child: PlayingCardWidget(
                                    card: _state.tableCards[i],
                                    width: 54,
                                    height: 76,
                                  ),
                                ),
                            ],
                          ),
                          if (_collectingCards != null)
                            CollectAnimationOverlay(
                              cards: _collectingCards!,
                              targetAlignment: _collectTarget,
                              onCompleted: () {
                                if (mounted) setState(() => _collectingCards = null);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // ── Sabit alt bölüm: oyuncunun el kartları her zaman görünür ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ELİNDEKİ KARTLAR',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _myHandWrap(myHand, myTurn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pistiGameOver() {
    final scores = _engine.calculateScores(_state);
    final ms = scores[me] ?? 0;
    final bs = scores[bot] ?? 0;
    final text = ms > bs ? '🎉 Sen kazandın!' : (ms == bs ? 'Berabere!' : '🤖 Bot kazandı!');
    return _gameOverBanner(text, [
      ('Senin puan', ms.toString()),
      ('Bot puanı', bs.toString()),
    ], _startNew);
  }

  Widget _myHandWrap(List<PlayingCard> hand, bool myTurn) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: hand.map((card) {
        final playing = _playingCardId == card.id;
        return AnimatedScale(
          scale: playing ? 0.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeIn,
          child: AnimatedOpacity(
            opacity: playing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: PlayingCardWidget(
              card: card,
              width: 56,
              height: 80,
              raised: myTurn && !playing,
              onTap: (myTurn && _playingCardId == null) ? () => _playCard(card) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATAK DEMO
// ═══════════════════════════════════════════════════════════════════════════════
class _BatakDemo extends StatefulWidget {
  const _BatakDemo();

  @override
  State<_BatakDemo> createState() => _BatakDemoState();
}

class _BatakDemoState extends State<_BatakDemo> {
  final BatakEngine _engine = BatakEngine();
  late BatakGameState _state;
  Timer? _botTimer;
  String? _playingCardId;

  bool _trickJustCompleted = false;
  Timer? _trickClearTimer;

  static const me = 'p0';
  static const List<String> allPlayers = ['p0', 'p1', 'p2', 'p3'];
  static const botNames = {'p0': 'Sen', 'p1': 'Bot 1', 'p2': 'Bot 2', 'p3': 'Bot 3'};

  int _myBid = BatakEngine.minBid;

  @override
  void initState() {
    super.initState();
    _startNew();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _trickClearTimer?.cancel();
    super.dispose();
  }

  void _startNew() {
    final room = GameRoom(
      id: 'demo-batak',
      gameType: 'batak',
      status: 'playing',
      maxPlayers: 4,
      hostId: me,
      players: {
        for (final id in allPlayers) id: {'displayName': botNames[id]!},
      },
    );
    setState(() {
      _state = _engine.initializeGame(room);
      _playingCardId = null;
      _myBid = BatakEngine.minBid;
      _trickJustCompleted = false;
    });
    _trickClearTimer?.cancel();
    _scheduleBotAction();
  }

  void _afterMoveApplied() {
    if (_state.currentTrick.length == 4) {
      _trickJustCompleted = true;
      _trickClearTimer?.cancel();
      _trickClearTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _trickJustCompleted = false);
      });
    } else {
      _trickJustCompleted = false;
    }
  }

  void _scheduleBotAction() {
    _botTimer?.cancel();
    if (_state.currentTurnPlayerId == me) return;
    if (_engine.isGameOver(_state)) return;

    int delayMs = 800;
    if (_state.currentTrick.length == 4) {
      delayMs = 1600;
    }

    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _doBotAction();
    });
  }

  void _doBotAction() {
    final bot = _state.currentTurnPlayerId;
    if (bot == me) return;

    if (_state.phase == BatakPhase.bidding && _state.passedPlayers.contains(bot)) {
      _scheduleBotAction();
      return;
    }

    BatakMove move;
    switch (_state.phase) {
      case BatakPhase.bidding:
        final rng = Random();
        final currentBid = _state.highestBid;
        int nextBid = currentBid + 1;
        bool willBid = false;

        if (currentBid < 7) {
          willBid = rng.nextDouble() < 0.7;
        } else if (currentBid == 7) {
          willBid = rng.nextDouble() < 0.25;
        } else if (currentBid == 8) {
          willBid = rng.nextDouble() < 0.05;
        } else {
          willBid = false;
        }

        if (willBid && nextBid <= BatakEngine.maxBid) {
          move = BatakMove.bid(nextBid);
        } else {
          move = const BatakMove.pass();
        }
        break;
      case BatakPhase.chooseTrump:
        if (_state.declarerId != bot) return;
        final suits = Suit.values.toList()..shuffle();
        move = BatakMove.chooseTrump(suits.first);
        break;
      case BatakPhase.playing:
        final hand = _state.hands[bot] ?? [];
        if (hand.isEmpty) return;
        final playable = hand.where((c) => _engine.isValidMove(_state, bot, BatakMove.playCard(c))).toList();
        PlayingCard card;
        if (playable.isNotEmpty) {
          card = playable[Random().nextInt(playable.length)];
        } else {
          card = hand[Random().nextInt(hand.length)];
        }
        move = BatakMove.playCard(card);
        break;
      case BatakPhase.finished:
        return;
    }

    if (!_engine.isValidMove(_state, bot, move)) {
      if (_state.phase == BatakPhase.bidding) {
        move = const BatakMove.pass();
      } else {
        return;
      }
    }

    setState(() {
      _state = _engine.applyMove(_state, bot, move);
      final newMin = (_state.highestBid + 1).clamp(BatakEngine.minBid, BatakEngine.maxBid);
      if (_myBid < newMin) _myBid = newMin;
      _afterMoveApplied();
    });
    _scheduleBotAction();
  }

  void _doMyAction(BatakMove move) {
    if (_state.currentTurnPlayerId != me) return;
    if (!_engine.isValidMove(_state, me, move)) return;
    setState(() {
      _state = _engine.applyMove(_state, me, move);
      _afterMoveApplied();
    });
    _scheduleBotAction();
  }

  Future<void> _playCard(PlayingCard card) async {
    if (_playingCardId != null) return;
    final move = BatakMove.playCard(card);
    if (!_engine.isValidMove(_state, me, move)) return;

    setState(() => _playingCardId = card.id);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() {
      _state = _engine.applyMove(_state, me, move);
      _playingCardId = null;
      _afterMoveApplied();
    });
    _scheduleBotAction();
  }

  @override
  Widget build(BuildContext context) {
    final over = _engine.isGameOver(_state);
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.3,
          colors: [AppColors.midGreen, AppColors.deepGreen],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _batakHeader(),
            const SizedBox(height: 6),
            if (over)
              Expanded(child: Center(child: _batakGameOver()))
            else
              Expanded(child: _batakBody()),
          ],
        ),
      ),
    );
  }

  Widget _batakHeader() {
    final isBidding = _state.phase == BatakPhase.bidding;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      color: Colors.black.withValues(alpha: 0.15),
      child: Row(
        children: allPlayers.map((id) {
          final tricks = _state.tricksWon[id] ?? 0;
          final isMe = id == me;
          final isTurn = _state.currentTurnPlayerId == id;
          final isDeclarer = _state.declarerId == id;
          final isPassed = _state.passedPlayers.contains(id);
          final currentBid = _state.bids[id];

          String subLabel;
          if (isBidding) {
            if (isPassed) {
              subLabel = 'Pas';
            } else if (currentBid != null) {
              subLabel = '$currentBid el';
            } else {
              subLabel = '-';
            }
          } else {
            subLabel = '$tricks el';
          }

          Color subColor;
          if (isBidding) {
            subColor = isPassed
                ? Colors.red.shade300
                : currentBid != null
                    ? const Color(0xFFD4AF37)
                    : Colors.white38;
          } else {
            subColor = isTurn ? AppColors.gold : Colors.white54;
          }

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              decoration: BoxDecoration(
                color: isTurn
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTurn ? AppColors.gold : Colors.white12,
                  width: isTurn ? 1.5 : 0.7,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    botNames[id]!,
                    style: TextStyle(
                      color: isMe ? AppColors.goldDeep : Colors.white70,
                      fontSize: 10,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isDeclarer && _state.phase != BatakPhase.bidding)
                    Text(
                      'Elci · ${_state.highestBid}',
                      style: const TextStyle(
                        color: Color(0xFF80CBC4),
                        fontSize: 9,
                      ),
                    ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _batakBody() {
    switch (_state.phase) {
      case BatakPhase.bidding:
        return _biddingUI();
      case BatakPhase.chooseTrump:
        return _chooseTrumpUI();
      case BatakPhase.playing:
        return _playingUI();
      case BatakPhase.finished:
        return Center(child: _batakGameOver());
    }
  }

  Widget _biddingUI() {
    final isMyTurn = _state.currentTurnPlayerId == me;
    final passed = _state.passedPlayers.contains(me);
    final iAmHighestBidder = _state.highestBidderId == me;

    final sliderMin = (_state.highestBid + 1)
        .clamp(BatakEngine.minBid, BatakEngine.maxBid)
        .toDouble();
    final sliderMax = BatakEngine.maxBid.toDouble();
    final sliderValue = _myBid.toDouble().clamp(sliderMin, sliderMax);
    final divisions = (sliderMax - sliderMin).round();

    final canAct = isMyTurn && !passed;

    return SingleChildScrollView(  // ← dikey scroll ekledik
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _phaseBanner('⚡ İhale Aşaması'),
            const SizedBox(height: 16),
            _handReadOnly(_state.hands[me] ?? []),
            const SizedBox(height: 8),
            if (canAct) ...[
              if (_state.highestBid > 0 && !iAmHighestBidder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Güncel en yüksek: ${_state.highestBid} el (${botNames[_state.highestBidderId ?? '']})',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                iAmHighestBidder
                    ? 'Lider sensin! Uzatmak ister misin?'
                    : 'Kontratın: ${sliderValue.round()} el',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (divisions > 0)
                Slider(
                  value: sliderValue,
                  min: sliderMin,
                  max: sliderMax,
                  divisions: divisions,
                  activeColor: AppColors.gold,
                  inactiveColor: Colors.white24,
                  label: '${sliderValue.round()}',
                  onChanged: (v) => setState(() => _myBid = v.round()),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Maksimum kontrat ($sliderMax el) zaten verildi',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _doMyAction(const BatakMove.pass()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text('Pas Geç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: divisions > 0
                          ? () => _doMyAction(BatakMove.bid(sliderValue.round()))
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                      ),
                      child: Text('${sliderValue.round()} El Kontrat'),
                    ),
                  ),
                ],
              ),
            ] else if (!isMyTurn) ...[
              _turnBanner('${botNames[_state.currentTurnPlayerId]} ihale yapıyor...', false),
            ] else ...[
              _turnBanner('Pas geçtin — diğerleri bekleniyor', false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chooseTrumpUI() {
    final isMyTurn = _state.currentTurnPlayerId == me;
    return SingleChildScrollView(  // ← dikey scroll eklendi
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _phaseBanner('🃏 Koz Seç'),
            const SizedBox(height: 8),
            Text(
              'Elci: ${botNames[_state.declarerId ?? '']!}  —  Kontrat: ${_state.highestBid} el',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (isMyTurn) ...[
              const Text(
                'Koz olarak hangi rengi seçiyorsun?',
                style: TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: Suit.values.map((suit) {
                  return GestureDetector(
                    onTap: () => _doMyAction(BatakMove.chooseTrump(suit)),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CustomPaint(
                              painter: _SuitIconPainter(suit: suit),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _suitName(suit),
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              _turnBanner('${botNames[_state.declarerId ?? '']!} koz seçiyor...', false),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _playingUI() {
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me;
    final waitingToStartNewTrick = myTurn && _state.currentTrick.length == 4;

    final bannerText = waitingToStartNewTrick
        ? 'Eli aldın!'
        : (myTurn ? '▶ Senin sıran' : '${botNames[_state.currentTurnPlayerId]} oynuyor...');
    final bannerActive = myTurn || waitingToStartNewTrick;

    return Column(
      children: [
        // ── Koz / Kontrat: header altında ince şerit ──────────────────────
        if (_state.trumpSuit != null || _state.declarerId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Text(
              [
                if (_state.trumpSuit != null) 'Koz: ${_suitName(_state.trumpSuit!)}',
                'Kontrat: ${_state.highestBid} el',
                'Kontratçı: ${botNames[_state.declarerId ?? '']}',
              ].join('  •  '),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Masa: kalan dikey alanı tam doldurur + banner overlay ─────────
        Expanded(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final availW = constraints.maxWidth.isFinite ? constraints.maxWidth - 8 : 280.0;
            final availH = constraints.maxHeight.isFinite ? constraints.maxHeight - 8 : 280.0;
            final size = (availW < availH ? availW : availH).clamp(180.0, 500.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                _buildBatakTable(tableSize: size),
                // Sıra banneri: masanın alt kenarına overlay
                Positioned(
                  bottom: (constraints.maxHeight - size) / 2 + 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bannerActive
                          ? AppColors.gold.withValues(alpha: 0.88)
                          : Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bannerText,
                      style: TextStyle(
                        color: bannerActive ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: bannerActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),

        // ── Sabit alt panel: el kartları her zaman görünür ───────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          child: _myHand2Rows(myHand, myTurn),
        ),
      ],
    );
  }




  Widget _myHand2Rows(List<PlayingCard> hand, bool myTurn) {
    if (hand.isEmpty) return const SizedBox.shrink();
    final sorted = List<PlayingCard>.from(hand)
      ..sort((a, b) => a.suit != b.suit
          ? a.suit.index.compareTo(b.suit.index)
          : a.rank.index.compareTo(b.rank.index));
    final mid = (sorted.length / 2).ceil();
    final topRow = sorted.sublist(0, mid);
    final botRow = sorted.sublist(mid);
    final ledSuit = (_state.currentTrick.isNotEmpty && _state.currentTrick.length < 4)
        ? _state.currentTrick.first.card.suit
        : null;
    final hasLedSuitInHand = ledSuit != null && hand.any((c) => c.suit == ledSuit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fanRow(topRow, myTurn, ledSuit, hasLedSuitInHand),
          const SizedBox(height: 4),
          _fanRow(botRow, myTurn, ledSuit, hasLedSuitInHand),
        ],
      ),
    );
  }

  // ─── Düzeltilmiş _fanRow: taşma durumunda yatay kaydırma ──────────────────
  Widget _fanRow(
    List<PlayingCard> cards,
    bool myTurn,
    Suit? ledSuit,
    bool hasLedSuitInHand,
  ) {
    const cardW = 52.0;
    const cardH = 72.0;
    const liftH = 8.0;
    final n = cards.length;
    if (n == 0) return const SizedBox.shrink();

    return LayoutBuilder(builder: (ctx, constraints) {
      final availW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 16;

      // Kartların sığabilmesi için maksimum adım
      final maxStep = n > 1 ? (availW - cardW) / (n - 1) : 0.0;
      // Adımı 10..46 aralığında tut, ama maxStep'ten büyük olmasın
      final step = n > 1 ? maxStep.clamp(10.0, 46.0) : 0.0;
      final actualStep = step > maxStep ? maxStep : step;

      final totalW = n > 1 ? cardW + actualStep * (n - 1) : cardW;
      final needsScroll = totalW > availW;

      Widget rowContent = SizedBox(
        width: totalW,
        height: cardH + liftH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = n - 1; i >= 0; i--) () {
              final card = cards[i];
              final canPlay = myTurn &&
                  _playingCardId == null &&
                  _engine.isValidMove(_state, me, BatakMove.playCard(card));
              final isInvalid = myTurn && hasLedSuitInHand && card.suit != ledSuit;
              final playing = _playingCardId == card.id;

              return Positioned(
                left: i * actualStep,
                bottom: canPlay ? liftH : 0.0,
                child: AnimatedSlide(
                  offset: playing ? const Offset(0, -1) : Offset.zero,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn,
                  child: AnimatedOpacity(
                    opacity: playing ? 0.0 : isInvalid ? 0.25 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (canPlay && !playing) ? () => _playCard(card) : null,
                      child: PlayingCardWidget(
                        card: card,
                        width: cardW,
                        height: cardH,
                        raised: canPlay && !playing,
                      ),
                    ),
                  ),
                ),
              );
            }(),
          ],
        ),
      );

      if (needsScroll) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: rowContent,
        );
      } else {
        return rowContent;
      }
    });
  }

  Widget _batakGameOver() {
    final scores = _engine.calculateScores(_state);
    final pairs = allPlayers
        .map((id) => (botNames[id]!, scores[id] ?? 0))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final winner = pairs.first.$1;
    final iWon = pairs.first.$1 == 'Sen';

    return _gameOverBanner(
      iWon ? '🎉 Sen kazandın!' : '🤖 $winner kazandı!',
      pairs.map((p) => (p.$1, p.$2.toString())).toList(),
      _startNew,
    );
  }

  Widget _handReadOnly(List<PlayingCard> hand) {
    if (hand.isEmpty) return const SizedBox.shrink();

    // Önce renge göre sırala, sonra 2 satıra böl
    final sorted = List<PlayingCard>.from(hand)
      ..sort((a, b) => a.suit != b.suit
          ? a.suit.index.compareTo(b.suit.index)
          : a.rank.index.compareTo(b.rank.index));

    final mid = (sorted.length / 2).ceil();
    final row1 = sorted.sublist(0, mid);
    final row2 = sorted.sublist(mid);

    Widget buildRow(List<PlayingCard> cards) {
      if (cards.isEmpty) return const SizedBox.shrink();
      const cardW = 44.0;
      const cardH = 62.0;
      return LayoutBuilder(builder: (ctx, constraints) {
        final availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 16;
        final n = cards.length;
        final step = n > 1
            ? ((availW - cardW) / (n - 1)).clamp(10.0, 42.0)
            : 0.0;
        final totalW = n > 1 ? cardW + step * (n - 1) : cardW;
        return Center(
          child: SizedBox(
            width: totalW,
            height: cardH,
            child: Stack(
              children: [
                for (int i = n - 1; i >= 0; i--)
                  Positioned(
                    left: i * step,
                    child: PlayingCardWidget(
                        card: cards[i], width: cardW, height: cardH),
                  ),
              ],
            ),
          ),
        );
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildRow(row1),
          const SizedBox(height: 8),
          buildRow(row2),
        ],
      ),
    );
  }


  Widget _buildBatakTable({double tableSize = 270}) {
    final trickToShow = (_state.currentTrick.length == 4 && !_trickJustCompleted)
        ? const <TrickCard>[]
        : _state.currentTrick;

    PlayingCard? southCard;
    PlayingCard? westCard;
    PlayingCard? northCard;
    PlayingCard? eastCard;

    for (final tc in trickToShow) {
      if (tc.playerId == 'p0') {
        southCard = tc.card;
      } else if (tc.playerId == 'p1') {
        westCard = tc.card;
      } else if (tc.playerId == 'p2') {
        northCard = tc.card;
      } else if (tc.playerId == 'p3') {
        eastCard = tc.card;
      }
    }

    const cardW = 48.0;
    const cardH = 67.0;
    const edge = 16.0;

    return Center(
      child: Container(
        width: tableSize,
        height: tableSize,
        margin: const EdgeInsets.symmetric(vertical: 4),

          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFF22683A), Color(0xFF0D3018)],
              center: Alignment.center,
              radius: 0.9,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18, spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                blurRadius: 6, spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (northCard != null)
                Positioned(
                  top: edge,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Bot 2',
                          style: TextStyle(color: Colors.white60, fontSize: 8)),
                      const SizedBox(height: 2),
                      _AnimCard(
                        key: ValueKey('${northCard.id}_n'),
                        child: PlayingCardWidget(
                            card: northCard, width: cardW, height: cardH),
                      ),
                    ],
                  ),
                ),
              if (westCard != null)
                Positioned(
                  left: edge,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RotatedBox(
                        quarterTurns: 1,
                        child: Text('Bot 1',
                            style: TextStyle(color: Colors.white60, fontSize: 8)),
                      ),
                      const SizedBox(width: 3),
                      _AnimCard(
                        key: ValueKey('${westCard.id}_w'),
                        child: PlayingCardWidget(
                            card: westCard, width: cardW, height: cardH),
                      ),
                    ],
                  ),
                ),
              if (eastCard != null)
                Positioned(
                  right: edge,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimCard(
                        key: ValueKey('${eastCard.id}_e'),
                        child: PlayingCardWidget(
                            card: eastCard, width: cardW, height: cardH),
                      ),
                      const SizedBox(width: 3),
                      const RotatedBox(
                        quarterTurns: 3,
                        child: Text('Bot 3',
                            style: TextStyle(color: Colors.white60, fontSize: 8)),
                      ),
                    ],
                  ),
                ),
              if (southCard != null)
                Positioned(
                  bottom: edge,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimCard(
                        key: ValueKey('${southCard.id}_s'),
                        child: PlayingCardWidget(
                            card: southCard, width: cardW, height: cardH),
                      ),
                      const SizedBox(height: 2),
                      const Text('Sen',
                          style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              if (trickToShow.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_state.trumpSuit != null) ...[
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CustomPaint(
                            painter: _SuitIconPainter(suit: _state.trumpSuit!),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Koz: ${_suitName(_state.trumpSuit!)}',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else
                        Text(
                          'Yeni el başlıyor…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// Ortak Yardımcı Widget'lar
// ═══════════════════════════════════════════════════════════════════════════════

Widget _tableArea({required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    // maxHeight kaldırıldı → ikinci satır sığsın
    constraints: const BoxConstraints(minHeight: 90),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1.5),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: children.isEmpty
        ? Center(
            child: Text(
              'Masa boş',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          )
        : Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 6,
            children: children,
          ),
  );
}

Widget _phaseBanner(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
    ),
    child: Text(
      text,
      style: const TextStyle(
          color: AppColors.goldDeep, fontSize: 14, fontWeight: FontWeight.bold),
    ),
  );
}

Widget _turnBanner(String text, bool active) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: active
          ? AppColors.gold.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: active ? AppColors.gold.withValues(alpha: 0.4) : Colors.white12,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.play_arrow_rounded : Icons.hourglass_empty_rounded,
          size: 14,
          color: active ? AppColors.gold : Colors.white38,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: active ? AppColors.gold : Colors.white54,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

Widget _gameOverBanner(
  String title,
  List<(String, String)> rows,
  VoidCallback onRestart,
) {
  return Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: AppColors.goldDeep.withValues(alpha: 0.5), width: 1.5),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.$1, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  Text(r.$2,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Yeni Oyun', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

Widget _pistiChip(String label, int cards, int pisti, {required bool isActive, int score = 0}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isActive
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isActive ? AppColors.gold.withValues(alpha: 0.6) : Colors.white12,
        width: isActive ? 1.3 : 0.8,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text('$cards kart · $pisti pişti',
            style: const TextStyle(
                color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text('$score puan',
            style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

Widget _deckChip(int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('DESTE',
            style: TextStyle(
                color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

String _suitName(Suit suit) {
  switch (suit) {
    case Suit.hearts: return 'Kupa';
    case Suit.diamonds: return 'Karo';
    case Suit.spades: return 'Maça';
    case Suit.clubs: return 'Sinek';
  }
}

// ─── Animasyonlu Tablo Kartı ──────────────────────────────────────────────────
class _AnimCard extends StatelessWidget {
  final Widget child;
  const _AnimCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, v, c) {
        final cl = v.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, (1 - v) * 20),
          child: Transform.scale(scale: v, child: Opacity(opacity: cl, child: c)),
        );
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: child),
    );
  }
}

// ─── Suit İkon Painter (Koz seçme ekranı için) ───────────────────────────────
// ─── Suit İkon Painter (Koz seçme ekranı için) ───────────────────────────────
class _SuitIconPainter extends CustomPainter {
  final Suit suit;
  const _SuitIconPainter({required this.suit});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.35;

    // Premium radial gradients for a 3D glassmorphic card suit look
    final Gradient gradient;
    switch (suit) {
      case Suit.hearts:
        gradient = const RadialGradient(
          colors: [Color(0xFFE53935), Color(0xFF8E0000)],
          center: Alignment(0, -0.25),
          radius: 0.85,
        );
        break;
      case Suit.diamonds:
        gradient = const RadialGradient(
          colors: [Color(0xFFFF7043), Color(0xFFD84315)],
          center: Alignment.center,
          radius: 0.85,
        );
        break;
      case Suit.spades:
        gradient = const RadialGradient(
          colors: [Color(0xFF4E4E4E), Color(0xFF141414)],
          center: Alignment(0, -0.3),
          radius: 0.9,
        );
        break;
      case Suit.clubs:
        gradient = const RadialGradient(
          colors: [Color(0xFF555555), Color(0xFF1D1D1D)],
          center: Alignment(0, -0.2),
          radius: 0.9,
        );
        break;
    }

    final p = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Soft blur drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final Path path;
    switch (suit) {
      case Suit.hearts:
        path = _getHeartPath(c, r);
        break;
      case Suit.diamonds:
        path = _getDiamondPath(c, r);
        break;
      case Suit.spades:
        path = _getSpadePath(c, r);
        break;
      case Suit.clubs:
        path = _getClubPath(c, r);
        break;
    }

    // Draw shadow shifted down
    canvas.drawPath(path.shift(const Offset(0, 1.8)), shadowPaint);

    // Draw body
    canvas.drawPath(path, p);

    // Subtle premium gold outline
    final borderPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    
    canvas.drawPath(path, borderPaint);
  }

  Path _getHeartPath(Offset c, double r) {
    final path = Path();
    path.moveTo(c.dx, c.dy - r * 0.45);
    path.cubicTo(c.dx - r * 0.8, c.dy - r * 1.1, c.dx - r * 1.4, c.dy - r * 0.5, c.dx - r * 1.4, c.dy + r * 0.1);
    path.cubicTo(c.dx - r * 1.4, c.dy + r * 0.65, c.dx - r * 0.6, c.dy + r * 1.05, c.dx, c.dy + r * 1.4);
    path.cubicTo(c.dx + r * 0.6, c.dy + r * 1.05, c.dx + r * 1.4, c.dy + r * 0.65, c.dx + r * 1.4, c.dy + r * 0.1);
    path.cubicTo(c.dx + r * 1.4, c.dy - r * 0.5, c.dx + r * 0.8, c.dy - r * 1.1, c.dx, c.dy - r * 0.45);
    path.close();
    return path;
  }

  Path _getDiamondPath(Offset c, double r) {
    final path = Path();
    path.moveTo(c.dx, c.dy - r * 1.25);
    path.cubicTo(c.dx + r * 0.12, c.dy - r * 0.4, c.dx + r * 0.4, c.dy - r * 0.12, c.dx + r * 1.15, c.dy);
    path.cubicTo(c.dx + r * 0.4, c.dy + r * 0.12, c.dx + r * 0.12, c.dy + r * 0.4, c.dx, c.dy + r * 1.25);
    path.cubicTo(c.dx - r * 0.12, c.dy + r * 0.4, c.dx - r * 0.4, c.dy + r * 0.12, c.dx - r * 1.15, c.dy);
    path.cubicTo(c.dx - r * 0.4, c.dy - r * 0.12, c.dx - r * 0.12, c.dy - r * 0.4, c.dx, c.dy - r * 1.25);
    path.close();
    return path;
  }

  Path _getSpadePath(Offset c, double r) {
    final path = Path();
    path.moveTo(c.dx, c.dy - r * 1.05);
    path.cubicTo(c.dx - r * 0.65, c.dy - r * 1.05, c.dx - r * 1.25, c.dy - r * 0.45, c.dx - r * 1.25, c.dy + r * 0.15);
    path.cubicTo(c.dx - r * 1.25, c.dy + r * 0.65, c.dx - r * 0.65, c.dy + r * 0.85, c.dx, c.dy + r * 0.35);
    path.cubicTo(c.dx + r * 0.65, c.dy + r * 0.85, c.dx + r * 1.25, c.dy + r * 0.65, c.dx + r * 1.25, c.dy + r * 0.15);
    path.cubicTo(c.dx + r * 1.25, c.dy - r * 0.45, c.dx + r * 0.65, c.dy - r * 1.05, c.dx, c.dy - r * 1.05);
    path.close();

    final stem = Path()
      ..moveTo(c.dx, c.dy + r * 0.25)
      ..quadraticBezierTo(c.dx - r * 0.08, c.dy + r * 0.75, c.dx - r * 0.45, c.dy + r * 1.15)
      ..lineTo(c.dx + r * 0.45, c.dy + r * 1.15)
      ..quadraticBezierTo(c.dx + r * 0.08, c.dy + r * 0.75, c.dx, c.dy + r * 0.25)
      ..close();

    path.addPath(stem, Offset.zero);
    return path;
  }

  Path _getClubPath(Offset c, double r) {
    final path = Path();
    final double leafR = r * 0.54;

    path.addOval(Rect.fromCircle(center: Offset(c.dx, c.dy - r * 0.36), radius: leafR));
    path.addOval(Rect.fromCircle(center: Offset(c.dx - r * 0.48, c.dy + r * 0.22), radius: leafR));
    path.addOval(Rect.fromCircle(center: Offset(c.dx + r * 0.48, c.dy + r * 0.22), radius: leafR));

    final stem = Path()
      ..moveTo(c.dx, c.dy + r * 0.1)
      ..quadraticBezierTo(c.dx - r * 0.08, c.dy + r * 0.75, c.dx - r * 0.45, c.dy + r * 1.15)
      ..lineTo(c.dx + r * 0.45, c.dy + r * 1.15)
      ..quadraticBezierTo(c.dx + r * 0.08, c.dy + r * 0.75, c.dx, c.dy + r * 0.1)
      ..close();

    path.addPath(stem, Offset.zero);
    return path;
  }

  @override
  bool shouldRepaint(covariant _SuitIconPainter old) => old.suit != suit;
}