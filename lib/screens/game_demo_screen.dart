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
import '../theme/app_theme.dart';

// ─── Oyun Modu Seçici ─────────────────────────────────────────────────────────
class GameDemoScreen extends StatefulWidget {
  const GameDemoScreen({super.key});

  @override
  State<GameDemoScreen> createState() => _GameDemoScreenState();
}

class _GameDemoScreenState extends State<GameDemoScreen> {
  String _selectedGame = 'pisti'; // 'pisti' | 'batak'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      appBar: AppBar(
        title: const Text('Demo Oyun (Bot ile)'),
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeni Oyun',
            onPressed: () => setState(() {}), // Ekranı sıfırla
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AppColors.darkGreen,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _tabBtn('pisti', 'Pişti  (2K)', Icons.style_rounded),
                const SizedBox(width: 8),
                _tabBtn('batak', 'Batak  (4K)', Icons.casino_rounded),
              ],
            ),
          ),
        ),
      ),
      body: KeyedSubtree(
        key: ValueKey(_selectedGame),
        child: _selectedGame == 'pisti'
            ? const _PistiDemo()
            : const _BatakDemo(),
      ),
    );
  }

  Widget _tabBtn(String id, String label, IconData icon) {
    final sel = _selectedGame == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGame = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.gold.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? AppColors.gold : Colors.white24,
              width: sel ? 1.5 : 0.7,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: sel ? AppColors.gold : Colors.white54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: sel ? AppColors.gold : Colors.white54,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
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
      final card = hand[Random().nextInt(hand.length)];
      setState(() => _state = _engine.applyMove(_state, bot, PistiMove(card)));
      _maybeLetBotPlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final over = _engine.isGameOver(_state);
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me && !over;

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
            // ── Skor ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pistiChip('Sen', _state.collectedCards[me]!.length,
                      _state.pistiCounts[me]!, isActive: myTurn),
                  _deckChip(_state.deck.length),
                  _pistiChip('Bot', _state.collectedCards[bot]!.length,
                      _state.pistiCounts[bot]!,
                      isActive: !myTurn && !over),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (over)
              _pistiGameOver()
            else ...[
              _turnBanner(myTurn ? 'Senin sıran' : 'Bot oynuyor...', myTurn),
              const SizedBox(height: 6),
            ],

            // ── Bot Kartları ───────────────────────────────────────────────
            Wrap(
              alignment: WrapAlignment.center,
              spacing: -6,
              children: List.generate(
                (_state.hands[bot] ?? []).length,
                (i) => const CardBackWidget(width: 44, height: 63),
              ),
            ),

            const Spacer(),

            // ── Masa ───────────────────────────────────────────────────────
            _tableArea(
              children: [
                for (int i = 0; i < _state.tableCards.length; i++)
                  _AnimCard(
                    key: ValueKey('${_state.tableCards[i].id}_$i'),
                    child: PlayingCardWidget(
                      card: _state.tableCards[i],
                      width: 58,
                      height: 82,
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // ── Benim Kartlarım ────────────────────────────────────────────
            _myHandWrap(myHand, myTurn),
            const SizedBox(height: 20),
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

  static const me = 'p0';


  static const List<String> allPlayers = ['p0', 'p1', 'p2', 'p3'];
  static const botNames = {'p0': 'Sen', 'p1': 'Bot 1', 'p2': 'Bot 2', 'p3': 'Bot 3'};

  int _myBid = 7; // Bid slider değeri

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
      _myBid = 7;
    });
    _scheduleBotAction();
  }

  // ── Bot Karar Mantığı ──────────────────────────────────────────────────────
  void _scheduleBotAction() {
    _botTimer?.cancel(); // Her zaman önce iptal et
    if (_state.currentTurnPlayerId == me) return;
    if (_engine.isGameOver(_state)) return;

    int delayMs = 800; // Normal bot düşünme süresi
    if (_state.currentTrick.length == 4) {
      delayMs = 2000; // El bitmişse 2 saniye bekle ki son atılan kart görülebilsin
    }

    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _doBotAction();
    });
  }

  void _doBotAction() {
    final bot = _state.currentTurnPlayerId;
    if (bot == me) return;

    // Güvenlik: Pas geçmiş bot SADECE ihale fazında tekrar aksiyon yapmamalı
    // (playing fazında passedPlayers önceki ihaleden kalıyor, oynamayı engellememeli)
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

        // Gerçekçi bot ihale mantığı:
        if (currentBid < 7) {
          willBid = rng.nextDouble() < 0.7; // İlk ihaleye girme şansı %70
        } else if (currentBid == 7) {
          willBid = rng.nextDouble() < 0.25; // 8 demesi %25 şans
        } else if (currentBid == 8) {
          willBid = rng.nextDouble() < 0.05; // 9 demesi %5 şans
        } else {
          willBid = false; // 9 ve üzerine bot rastgele girmesin
        }

        if (willBid && nextBid <= BatakEngine.maxBid) {
          move = BatakMove.bid(nextBid);
        } else {
          move = const BatakMove.pass();
        }
        break;
      case BatakPhase.chooseTrump:
        // Sadece elci koz seçebilir
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
      // Son çare: pas geç (sadece ihale fazında geçerli)
      if (_state.phase == BatakPhase.bidding) {
        move = const BatakMove.pass();
      } else {
        return;
      }
    }

    setState(() {
      _state = _engine.applyMove(_state, bot, move);
      // _myBid'i her zaman geçerli aralıkta tut
      final newMin = (_state.highestBid + 1).clamp(BatakEngine.minBid, BatakEngine.maxBid);
      if (_myBid < newMin) _myBid = newMin;
    });
    _scheduleBotAction();
  }

  // ── Kullanıcı Aksiyonları ──────────────────────────────────────────────────
  void _doMyAction(BatakMove move) {
    if (_state.currentTurnPlayerId != me) return;
    if (!_engine.isValidMove(_state, me, move)) return;
    setState(() => _state = _engine.applyMove(_state, me, move));
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
    });
    _scheduleBotAction();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
            // ── Skor / Bilgi ──────────────────────────────────────────────
            _batakHeader(),

            const SizedBox(height: 6),

            // ── Faz ───────────────────────────────────────────────────────
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
          final currentBid = _state.bids[id]; // null = henüz girmedi

          // İhale fazı alt yazısı
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

          // Renk
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

  // ── İhale Aşaması ─────────────────────────────────────────────────────────
  Widget _biddingUI() {
    final isMyTurn = _state.currentTurnPlayerId == me;
    final passed = _state.passedPlayers.contains(me);
    // Mevcut en yüksek teklifin benim teklifim olup olmadığı
    final iAmHighestBidder = _state.highestBidderId == me;

    // Slider için geçerli min/max hesapla
    final sliderMin = (_state.highestBid + 1)
        .clamp(BatakEngine.minBid, BatakEngine.maxBid)
        .toDouble();
    final sliderMax = BatakEngine.maxBid.toDouble();
    // Mevcut değerin aralık dışında olmaması için clamp
    final sliderValue = _myBid.toDouble().clamp(sliderMin, sliderMax);
    final divisions = (sliderMax - sliderMin).round();

    // Sıra bende ve pas geçmedim → her zaman ihaleye girebilirim
    // (daha önce bid yapsam bile biri daha yüksek bid yaparsa tekrar sıram gelebilir)
    final canAct = isMyTurn && !passed;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _phaseBanner('⚡ İhale Aşaması'),
          const SizedBox(height: 12),
          // İhale geçmişi (en yüksek teklif vurgulanmış)
          ..._state.bids.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_state.highestBidderId == e.key)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.arrow_upward, size: 12, color: Color(0xFFD4AF37)),
                      ),
                    Text(
                      '${botNames[e.key]} → ${e.value} el',
                      style: TextStyle(
                        color: _state.highestBidderId == e.key
                            ? const Color(0xFFD4AF37)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: _state.highestBidderId == e.key
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              )),
          ..._state.passedPlayers.map((id) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${botNames[id]} → Pas',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )),
          const SizedBox(height: 16),
          // ━ Oyuncunun eli (daima görünür, bilgili ihale için)
          _handReadOnly(_state.hands[me] ?? []),
          const SizedBox(height: 8),
          if (canAct) ...[
            // Mevcut en yüksek teklif bilgisi
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
            // Pas geçildi
            _turnBanner('Pas geçtin — diğerleri bekleniyor', false),
          ],
        ],
      ),
    );
  }

  // ── Koz Seçme Aşaması ────────────────────────────────────────────────────
  Widget _chooseTrumpUI() {
    final isMyTurn = _state.currentTurnPlayerId == me;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
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
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
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
    );
  }

  // ── Oynama Aşaması ────────────────────────────────────────────────────────
  Widget _playingUI() {
    final myHand = _state.hands[me] ?? [];
    final myTurn = _state.currentTurnPlayerId == me;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_state.trumpSuit != null) ...[
                Text(
                  'Koz: ${_suitName(_state.trumpSuit!)}  •  ',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              Text(
                'Kontrat: ${_state.highestBid} el  •  Kontratçı: ${botNames[_state.declarerId ?? '']}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),

        // Mevcut el (2D Daire Masa Düzeni)
        _buildBatakTable(),

        if (!myTurn)
          _turnBanner(
              '${botNames[_state.currentTurnPlayerId]} oynuyor...', false)
        else
          _turnBanner('Senin sıran', true),

        // Benim kartlarım — 2 satır düzeni
        _myHand2Rows(myHand, myTurn),
        const SizedBox(height: 6),
      ],
    );
  }

  // İki satır kart düzeni: 13 kart üst+alt, sıralanmış, örtüşerek
  Widget _myHand2Rows(List<PlayingCard> hand, bool myTurn) {
    if (hand.isEmpty) return const SizedBox.shrink();
    // Renk önce, sonra değer sırası
    final sorted = List<PlayingCard>.from(hand)
      ..sort((a, b) => a.suit != b.suit
          ? a.suit.index.compareTo(b.suit.index)
          : a.rank.index.compareTo(b.rank.index));
    final mid = (sorted.length / 2).ceil();
    final topRow = sorted.sublist(0, mid);
    final botRow = sorted.sublist(mid);
    final ledSuit = _state.currentTrick.isNotEmpty
        ? _state.currentTrick.first.card.suit
        : null;
    final hasLedSuitInHand = ledSuit != null && hand.any((c) => c.suit == ledSuit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fanRow(topRow, myTurn, ledSuit, hasLedSuitInHand, hand),
          const SizedBox(height: 4),
          _fanRow(botRow, myTurn, ledSuit, hasLedSuitInHand, hand),
        ],
      ),
    );
  }

  // Tek satır örtüşen kart fanı (z-order: soldaki üstte)
  Widget _fanRow(
    List<PlayingCard> cards,
    bool myTurn,
    Suit? ledSuit,
    bool hasLedSuitInHand,
    List<PlayingCard> fullHand,
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
      final step = n > 1
          ? ((availW - cardW) / (n - 1)).clamp(14.0, 46.0)
          : 0.0;
      final totalW = n > 1 ? cardW + step * (n - 1) : cardW;

      return SizedBox(
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
                left: i * step,
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

  /// Sadece görüntüleme amaçlı el (ihale ekranı) — Renk satır düzeni
  Widget _handReadOnly(List<PlayingCard> hand) {
    if (hand.isEmpty) return const SizedBox.shrink();
    final bySuit = <Suit, List<PlayingCard>>{};
    for (final card in hand) {
      bySuit.putIfAbsent(card.suit, () => []).add(card);
    }
    for (final cards in bySuit.values) {
      cards.sort((a, b) => a.rank.index.compareTo(b.rank.index));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: Suit.values.where((s) => bySuit.containsKey(s)).map((suit) {
          final cards = bySuit[suit]!;
          final n = cards.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: LayoutBuilder(builder: (ctx, constraints) {
              const cardW = 44.0;
              const cardH = 62.0;
              final availW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width - 16;
              final step = n > 1
                  ? ((availW - cardW) / (n - 1)).clamp(10.0, 40.0)
                  : 0.0;
              final totalW = n > 1 ? cardW + step * (n - 1) : cardW;
              return SizedBox(
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
              );
            }),
          );
        }).toList(),
      ),
    );
  }



  /// Batak Masası — Büyütülmüş (280px), ortaya hizalı, koz göstergeli
  Widget _buildBatakTable() {
    PlayingCard? southCard;
    PlayingCard? westCard;
    PlayingCard? northCard;
    PlayingCard? eastCard;

    for (final tc in _state.currentTrick) {
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

    const tableSize = 280.0;
    const cardW = 48.0;
    const cardH = 67.0;
    const edge = 16.0;

    return Center(
      child: Container(
        width: tableSize,
        height: tableSize,
        margin: const EdgeInsets.symmetric(vertical: 6),
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
            // North (Bot 2)
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
            // West (Bot 1)
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
            // East (Bot 3)
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
            // South (Sen)
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
            // Koz göstergesi (boş masa)
            if (_state.currentTrick.isEmpty)
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
    margin: const EdgeInsets.symmetric(horizontal: 20),
    constraints: const BoxConstraints(minHeight: 90, maxHeight: 110),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1.5),
    ),
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
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

Widget _pistiChip(String label, int cards, int pisti, {required bool isActive}) {
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
        const SizedBox(height: 3),
        Text('$cards kart · $pisti pişti',
            style: const TextStyle(
                color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
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
class _SuitIconPainter extends CustomPainter {
  final Suit suit;
  const _SuitIconPainter({required this.suit});

  Color get _color {
    switch (suit) {
      case Suit.hearts: return const Color(0xFFE53935);
      case Suit.diamonds: return const Color(0xFFD81B60);
      case Suit.spades: return const Color(0xFF5C6BC0);
      case Suit.clubs: return const Color(0xFF43A047);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _color..style = PaintingStyle.fill;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.35;
    switch (suit) {
      case Suit.hearts:
        _heart(canvas, c, r, p);
        break;
      case Suit.diamonds:
        _diamond(canvas, c, r, p);
        break;
      case Suit.spades:
        _spade(canvas, c, r, p);
        break;
      case Suit.clubs:
        _club(canvas, c, r, p);
        break;
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    path.moveTo(c.dx, c.dy + r * 0.85);
    path.cubicTo(c.dx - r * 2.0, c.dy + r * 0.2, c.dx - r * 2.0, c.dy - r * 1.2, c.dx, c.dy - r * 0.35);
    path.cubicTo(c.dx + r * 2.0, c.dy - r * 1.2, c.dx + r * 2.0, c.dy + r * 0.2, c.dx, c.dy + r * 0.85);
    path.close();
    canvas.drawPath(path, p);
  }

  void _diamond(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.7, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.7, c.dy)
      ..close();
    canvas.drawPath(path, p);
  }

  void _spade(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    path.moveTo(c.dx, c.dy - r);
    path.cubicTo(c.dx + r * 2.0, c.dy - r * 0.0, c.dx + r * 2.0, c.dy + r * 0.8, c.dx, c.dy + r * 0.3);
    path.cubicTo(c.dx - r * 2.0, c.dy + r * 0.8, c.dx - r * 2.0, c.dy - r * 0.0, c.dx, c.dy - r);
    path.close();
    canvas.drawPath(path, p);
    final stemW = r * 0.3;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.85), width: stemW, height: r * 0.75),
        Radius.circular(stemW / 2)), p);
    canvas.drawCircle(Offset(c.dx - r * 0.45, c.dy + r * 0.85), r * 0.28, p);
    canvas.drawCircle(Offset(c.dx + r * 0.45, c.dy + r * 0.85), r * 0.28, p);
  }

  void _club(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawCircle(Offset(c.dx, c.dy - r * 0.55), r * 0.5, p);
    canvas.drawCircle(Offset(c.dx - r * 0.82, c.dy + r * 0.25), r * 0.5, p);
    canvas.drawCircle(Offset(c.dx + r * 0.82, c.dy + r * 0.25), r * 0.5, p);
    final stemW = r * 0.28;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + r * 1.15), width: stemW, height: r * 0.8),
        Radius.circular(stemW / 2)), p);
    canvas.drawCircle(Offset(c.dx - r * 0.45, c.dy + r * 1.4), r * 0.28, p);
    canvas.drawCircle(Offset(c.dx + r * 0.45, c.dy + r * 1.4), r * 0.28, p);
  }

  @override
  bool shouldRepaint(covariant _SuitIconPainter old) => old.suit != suit;
}
