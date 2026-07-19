import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';
import '../services/batak_game_service.dart';
import '../widgets/playing_card_widget.dart';
import '../theme/app_theme.dart';
import '../engine/batak/batak_engine.dart';

class _TrickEntry {
  final String playerId;
  final PlayingCard card;
  const _TrickEntry(this.playerId, this.card);
}

class BatakGameScreen extends StatefulWidget {
  final String roomId;
  final Map<String, String> playerNames; // uid -> displayName

  const BatakGameScreen({
    super.key,
    required this.roomId,
    required this.playerNames,
  });

  @override
  State<BatakGameScreen> createState() => _BatakGameScreenState();
}

class _BatakGameScreenState extends State<BatakGameScreen> {
  final BatakGameService _service = BatakGameService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  String? _playingCardId;
  int _myBid = BatakEngine.minBid;

  // Tamamlanan bir eli kısa süre görünür tutup sonra otomatik gizlemek için
  int _prevTrickLength = 0;
  bool _trickJustCompleted = false;
  Timer? _trickClearTimer;

  String _nameOf(String uid) => widget.playerNames[uid] ?? 'Oyuncu';

  String _suitName(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return 'Kupa';
      case Suit.diamonds:
        return 'Karo';
      case Suit.spades:
        return 'Maça';
      case Suit.clubs:
        return 'Sinek';
    }
  }

  @override
  void dispose() {
    _trickClearTimer?.cancel();
    super.dispose();
  }

  void _trackTrickCompletion(int currentTrickLength) {
    if (currentTrickLength == 4 && _prevTrickLength != 4) {
      _trickJustCompleted = true;
      _trickClearTimer?.cancel();
      _trickClearTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _trickJustCompleted = false);
      });
    }
    if (currentTrickLength != 4) {
      _trickJustCompleted = false;
    }
    _prevTrickLength = currentTrickLength;
  }

  Future<void> _playCard(PlayingCard card) async {
    if (_playingCardId != null) return;
    setState(() => _playingCardId = card.id);
    await _service.playCard(widget.roomId, card);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _playingCardId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapılmamış')));
    }

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      appBar: AppBar(
        title: const Text('Batak'),
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.watchPublicState(widget.roomId),
        builder: (context, publicSnap) {
          if (!publicSnap.hasData || !publicSnap.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final pub = publicSnap.data!.data()!;
          final phase = pub['phase'] ?? 'bidding';
          final status = pub['status'] ?? 'playing';
          final playerOrder = List<String>.from(pub['playerOrder'] ?? []);
          final dealerId = pub['dealerId'] as String?;
          final bids = Map<String, dynamic>.from(pub['bids'] ?? {});
          final passedPlayers = List<String>.from(pub['passedPlayers'] ?? []);
          final highestBidderId = pub['highestBidderId'] as String?;
          final highestBid = pub['highestBid'] ?? 0;
          final currentTurnPlayerId = pub['currentTurnPlayerId'] as String?;
          final trumpSuitStr = pub['trumpSuit'] as String?;
          final trumpSuit = trumpSuitStr != null
              ? Suit.values.firstWhere((s) => s.name == trumpSuitStr)
              : null;
          final declarerId = pub['declarerId'] as String?;
          debugPrint('BatakGameScreen build edildi. Status: $status, Phase: $phase, CurrentTurnPlayerId: $currentTurnPlayerId, PlayerOrder: $playerOrder');
          final tricksWon = Map<String, dynamic>.from(pub['tricksWon'] ?? {});
          final currentTrickRaw = List<Map<String, dynamic>>.from(pub['currentTrick'] ?? []);
          final currentTrick = currentTrickRaw
              .map((t) => _TrickEntry(t['playerId'], PlayingCard.fromMap(t['card'])))
              .toList();

          // Trick tamamlanma durumunu takip et (state değişikliği build sırasında,
          // sadece Timer'ın kendisi setState tetikler)
          _trackTrickCompletion(currentTrick.length);

          if (status == 'abandoned') {
            return Center(child: _buildAbandonedPanel());
          }

          if (status == 'finished' || phase == 'finished') {
            return Center(child: _buildGameOver(pub, playerOrder));
          }

          return Column(
            children: [
              _buildHeader(playerOrder, dealerId, bids, passedPlayers,
                  highestBidderId, currentTurnPlayerId, declarerId,
                  tricksWon, phase, highestBid),
              const SizedBox(height: 6),
              Expanded(
                child: StreamBuilder<List<PlayingCard>>(
                  stream: _service.watchMyHand(widget.roomId),
                  builder: (context, handSnap) {
                    final myHand = handSnap.data ?? [];
                    switch (phase) {
                      case 'bidding':
                        return _buildBiddingUI(
                          myHand, bids, passedPlayers, highestBidderId,
                          highestBid, currentTurnPlayerId,
                        );
                      case 'chooseTrump':
                        return _buildChooseTrumpUI(
                          declarerId, highestBid, currentTurnPlayerId,
                        );
                      case 'playing':
                        return _buildPlayingUI(
                          myHand, currentTrick, trumpSuit, declarerId,
                          highestBid, currentTurnPlayerId, playerOrder,
                        );
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    List<String> playerOrder,
    String? dealerId,
    Map<String, dynamic> bids,
    List<String> passedPlayers,
    String? highestBidderId,
    String? currentTurnPlayerId,
    String? declarerId,
    Map<String, dynamic> tricksWon,
    String phase,
    int highestBid,
  ) {
    final isBidding = phase == 'bidding';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      color: Colors.black.withValues(alpha: 0.15),
      child: Row(
        children: playerOrder.map((id) {
          final tricks = tricksWon[id] ?? 0;
          final isMe = id == _myUid;
          final isTurn = currentTurnPlayerId == id;
          final isDeclarer = declarerId == id;
          final isPassed = passedPlayers.contains(id);
          final currentBid = bids[id];

          String subLabel;
          if (isBidding) {
            subLabel = isPassed ? 'Pas' : (currentBid != null ? '$currentBid el' : '-');
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
                    _nameOf(id),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? AppColors.goldDeep : Colors.white70,
                      fontSize: 10,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isDeclarer && phase != 'bidding')
                    Text(
                      'Elci · $highestBid',
                      style: const TextStyle(color: Color(0xFF80CBC4), fontSize: 9),
                    ),
                  Text(
                    subLabel,
                    style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBiddingUI(
    List<PlayingCard> myHand,
    Map<String, dynamic> bids,
    List<String> passedPlayers,
    String? highestBidderId,
    int highestBid,
    String? currentTurnPlayerId,
  ) {
    final isMyTurn = currentTurnPlayerId == _myUid;
    final passed = passedPlayers.contains(_myUid);
    final iAmHighestBidder = highestBidderId == _myUid;
    final canAct = isMyTurn && !passed;

    final minBid = BatakEngine.minBid;
    final maxBid = BatakEngine.maxBid;
    final sliderMin = (highestBid + 1).clamp(minBid, maxBid).toDouble();
    final sliderMax = maxBid.toDouble();
    final sliderValue = _myBid.toDouble().clamp(sliderMin, sliderMax);
    final divisions = (sliderMax - sliderMin).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _phaseBanner('⚡ İhale Aşaması'),
          const SizedBox(height: 12),
          ...bids.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (highestBidderId == e.key)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.arrow_upward, size: 12, color: Color(0xFFD4AF37)),
                      ),
                    Text(
                      '${_nameOf(e.key)} → ${e.value} el',
                      style: TextStyle(
                        color: highestBidderId == e.key ? const Color(0xFFD4AF37) : Colors.white70,
                        fontSize: 13,
                        fontWeight: highestBidderId == e.key ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              )),
          ...passedPlayers.map((id) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${_nameOf(id)} → Pas',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              )),
          const SizedBox(height: 16),
          _handReadOnly(myHand),
          const SizedBox(height: 8),
          if (canAct) ...[
            if (highestBid > 0 && !iAmHighestBidder)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Güncel en yüksek: $highestBid el (${_nameOf(highestBidderId ?? '')})',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              'Kontratın: ${sliderValue.round()} el',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _service.pass(widget.roomId),
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
                        ? () => _service.bid(widget.roomId, sliderValue.round())
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
          ] else
            _turnBanner(
              isMyTurn
                  ? 'Pas geçtin — diğerleri bekleniyor'
                  : '${_nameOf(currentTurnPlayerId ?? '')} ihale yapıyor...',
              false,
            ),
        ],
      ),
    );
  }

  Widget _buildChooseTrumpUI(String? declarerId, int highestBid, String? currentTurnPlayerId) {
    final isMyTurn = currentTurnPlayerId == _myUid;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _phaseBanner('🃏 Koz Seç'),
          const SizedBox(height: 8),
          Text(
            'Elci: ${_nameOf(declarerId ?? '')}  —  Kontrat: $highestBid el',
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
                  onTap: () => _service.chooseTrump(widget.roomId, suit),
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
                        Text(
                          {
                            Suit.hearts: '♥',
                            Suit.diamonds: '♦',
                            Suit.spades: '♠',
                            Suit.clubs: '♣',
                          }[suit]!,
                          style: TextStyle(
                            fontSize: 28,
                            color: (suit == Suit.hearts || suit == Suit.diamonds)
                                ? const Color(0xFFE53935)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_suitName(suit),
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else
            _turnBanner('${_nameOf(declarerId ?? '')} koz seçiyor...', false),
        ],
      ),
    );
  }

  Widget _buildPlayingUI(
    List<PlayingCard> myHand,
    List<_TrickEntry> currentTrick,
    Suit? trumpSuit,
    String? declarerId,
    int highestBid,
    String? currentTurnPlayerId,
    List<String> playerOrder,
  ) {
    final myTurn = currentTurnPlayerId == _myUid;
    final waitingToStartNewTrick = myTurn && currentTrick.length == 4;

    final myIndex = playerOrder.indexOf(_myUid!);
    final rotated = List<String>.generate(
      playerOrder.length,
      (i) => playerOrder[(myIndex + i) % playerOrder.length],
    );
    final southId = rotated[0];
    final westId = rotated.length > 1 ? rotated[1] : null;
    final northId = rotated.length > 2 ? rotated[2] : null;
    final eastId = rotated.length > 3 ? rotated[3] : null;

    final trickToShow = (currentTrick.length == 4 && !_trickJustCompleted)
        ? const <_TrickEntry>[]
        : currentTrick;

    PlayingCard? cardOf(String? uid) {
      if (uid == null) return null;
      final entry = trickToShow.where((t) => t.playerId == uid);
      return entry.isNotEmpty ? entry.first.card : null;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (trumpSuit != null)
                Text(
                  'Koz: ${_suitName(trumpSuit)}  •  ',
                  style: const TextStyle(
                      color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              Text(
                'Kontrat: $highestBid el  •  Kontratçı: ${_nameOf(declarerId ?? '')}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        _buildTable(southId, westId, northId, eastId, cardOf, trumpSuit, trickToShow.isEmpty),
        if (waitingToStartNewTrick)
          _turnBanner('Eli aldın! Yeni eli başlatmak için bir kart oyna', true)
        else
          _turnBanner(
            myTurn ? 'Senin sıran' : '${_nameOf(currentTurnPlayerId ?? '')} oynuyor...',
            myTurn,
          ),
        Expanded(child: _myHand2Rows(myHand, myTurn, currentTrick)),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildTable(
    String southId,
    String? westId,
    String? northId,
    String? eastId,
    PlayingCard? Function(String?) cardOf,
    Suit? trumpSuit,
    bool trickEmpty,
  ) {
    const tableSize = 260.0;
    const cardW = 46.0;
    const cardH = 64.0;
    const edge = 14.0;

    final southCard = cardOf(southId);
    final westCard = cardOf(westId);
    final northCard = cardOf(northId);
    final eastCard = cardOf(eastId);

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
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, spreadRadius: 1),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (northCard != null && northId != null)
              Positioned(
                top: edge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_nameOf(northId), style: const TextStyle(color: Colors.white60, fontSize: 8)),
                    const SizedBox(height: 2),
                    PlayingCardWidget(card: northCard, width: cardW, height: cardH),
                  ],
                ),
              ),
            if (westCard != null && westId != null)
              Positioned(
                left: edge,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(_nameOf(westId), style: const TextStyle(color: Colors.white60, fontSize: 8)),
                    ),
                    const SizedBox(width: 3),
                    PlayingCardWidget(card: westCard, width: cardW, height: cardH),
                  ],
                ),
              ),
            if (eastCard != null && eastId != null)
              Positioned(
                right: edge,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCardWidget(card: eastCard, width: cardW, height: cardH),
                    const SizedBox(width: 3),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(_nameOf(eastId), style: const TextStyle(color: Colors.white60, fontSize: 8)),
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
                    PlayingCardWidget(card: southCard, width: cardW, height: cardH),
                    const SizedBox(height: 2),
                    const Text('Sen',
                        style: TextStyle(
                            color: Color(0xFFD4AF37), fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (trickEmpty)
              Center(
                child: trumpSuit != null
                    ? Text(
                        'Koz: ${_suitName(trumpSuit)}',
                        style: const TextStyle(
                            color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    : Text(
                        'Yeni el başlıyor…',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _myHand2Rows(List<PlayingCard> hand, bool myTurn, List<_TrickEntry> currentTrick) {
    if (hand.isEmpty) return const SizedBox.shrink();
    final sorted = List<PlayingCard>.from(hand)
      ..sort((a, b) => a.suit != b.suit
          ? a.suit.index.compareTo(b.suit.index)
          : a.rank.index.compareTo(b.rank.index));
    final mid = (sorted.length / 2).ceil();
    final topRow = sorted.sublist(0, mid);
    final botRow = sorted.sublist(mid);
    final ledSuit = (currentTrick.isNotEmpty && currentTrick.length < 4)
        ? currentTrick.first.card.suit
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

  Widget _fanRow(List<PlayingCard> cards, bool myTurn, Suit? ledSuit, bool hasLedSuitInHand) {
    const cardW = 52.0;
    const cardH = 72.0;
    const liftH = 8.0;
    final n = cards.length;
    if (n == 0) return const SizedBox.shrink();

    return LayoutBuilder(builder: (ctx, constraints) {
      final availW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 16;
      final step = n > 1 ? ((availW - cardW) / (n - 1)).clamp(14.0, 46.0) : 0.0;
      final totalW = n > 1 ? cardW + step * (n - 1) : cardW;

      return SizedBox(
        width: totalW,
        height: cardH + liftH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = n - 1; i >= 0; i--) () {
              final card = cards[i];
              final isInvalid = myTurn && hasLedSuitInHand && card.suit != ledSuit;
              final canPlay = myTurn && _playingCardId == null && !isInvalid;
              final playing = _playingCardId == card.id;

              return Positioned(
                left: i * step,
                bottom: canPlay ? liftH : 0.0,
                child: AnimatedOpacity(
                  opacity: playing ? 0.0 : (isInvalid ? 0.25 : 1.0),
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
              );
            }(),
          ],
        ),
      );
    });
  }

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
              final step = n > 1 ? ((availW - cardW) / (n - 1)).clamp(10.0, 40.0) : 0.0;
              final totalW = n > 1 ? cardW + step * (n - 1) : cardW;
              return SizedBox(
                width: totalW,
                height: cardH,
                child: Stack(
                  children: [
                    for (int i = n - 1; i >= 0; i--)
                      Positioned(
                        left: i * step,
                        child: PlayingCardWidget(card: cards[i], width: cardW, height: cardH),
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

  Widget _buildAbandonedPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Bir oyuncu odayı terk etti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Oyun sonlandırıldı.',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Ana Ekrana Dön', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver(Map<String, dynamic> pub, List<String> playerOrder) {
    final scores = Map<String, dynamic>.from(pub['scores'] ?? {});
    final pairs = playerOrder.map((id) => (id, (scores[id] ?? 0) as int)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final winnerId = pairs.first.$1;
    final iWon = winnerId == _myUid;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldDeep.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            iWon ? '🎉 Sen kazandın!' : '${_nameOf(winnerId)} kazandı!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...pairs.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_nameOf(p.$1), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    Text('${p.$2}',
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Ana Ekrana Dön', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
      child: Text(text,
          style: const TextStyle(color: AppColors.goldDeep, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _turnBanner(String text, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.gold.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? AppColors.gold.withValues(alpha: 0.4) : Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.play_arrow_rounded : Icons.hourglass_empty_rounded,
              size: 14, color: active ? AppColors.gold : Colors.white38),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: active ? AppColors.gold : Colors.white54,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}