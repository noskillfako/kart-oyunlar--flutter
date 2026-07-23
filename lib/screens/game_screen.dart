import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';
import '../services/game_service.dart';
import '../services/room_service.dart';
import '../widgets/playing_card_widget.dart';

import '../services/presence_service.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  final PresenceService _presenceService = PresenceService();
  final RoomService _roomService = RoomService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  String? _playedCardId;

  Timer? _watchdogTimer;
  String? _watchdogTurnPlayerId;

  int _turnSecondsLeft = 30;
  Timer? _turnCountdownTimer;
  bool _isTurnCountdownActive = false;
  Timer? _presenceTickerTimer;

  @override
  void initState() {
    super.initState();
    _presenceService.startHeartbeat(widget.roomId);
    if (_myUid != null) {
      _roomService.reclaimSeat(widget.roomId, _myUid);
    }
    _presenceTickerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presenceService.stopHeartbeat();
    _presenceTickerTimer?.cancel();
    _watchdogTimer?.cancel();
    _turnCountdownTimer?.cancel();
    super.dispose();
  }

  void _syncTurnTimer(bool isMyTurn, List<PlayingCard> myHand) {
    if (isMyTurn && !_isTurnCountdownActive) {
      _isTurnCountdownActive = true;
      _turnSecondsLeft = 30;
      _turnCountdownTimer?.cancel();
      _turnCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_turnSecondsLeft > 1) {
          setState(() => _turnSecondsLeft--);
        } else {
          timer.cancel();
          _isTurnCountdownActive = false;
          _autoPlayRandomCard(myHand);
        }
      });
    } else if (!isMyTurn && _isTurnCountdownActive) {
      _isTurnCountdownActive = false;
      _turnCountdownTimer?.cancel();
      _turnSecondsLeft = 30;
    }
  }

  void _autoPlayRandomCard(List<PlayingCard> myHand) {
    if (myHand.isEmpty || _playedCardId != null) return;
    final randomCard = (List<PlayingCard>.from(myHand)..shuffle()).first;
    _onPlayCard(randomCard);
  }

  void _updateWatchdog(String? currentTurn, List<String> botSeats) {
    if (currentTurn != null && currentTurn != _myUid && !botSeats.contains(currentTurn)) {
      if (_watchdogTurnPlayerId != currentTurn) {
        _watchdogTimer?.cancel();
        _watchdogTurnPlayerId = currentTurn;
        _watchdogTimer = Timer(const Duration(seconds: 35), () {
          _roomService.claimBotTakeover(widget.roomId, currentTurn);
        });
      }
    } else {
      _watchdogTimer?.cancel();
      _watchdogTurnPlayerId = null;
    }
  }

  Future<void> _onPlayCard(PlayingCard card) async {
    if (_playedCardId != null) return;
    setState(() => _playedCardId = card.id);

    await _gameService.playCard(widget.roomId, card);

    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) setState(() => _playedCardId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapılmamış')));
    }

    final roomService = RoomService();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        await _roomService.leaveRoom(widget.roomId);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _roomService.leaveRoom(widget.roomId);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            'Pişti - Oda: ${widget.roomId}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF0F3A1D),
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF1E5B32),
                Color(0xFF0D321A),
              ],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: roomService.watchRoom(widget.roomId),
              builder: (context, roomSnap) {
                final roomData = roomSnap.data?.data();
                final players = Map<String, dynamic>.from(roomData?['players'] ?? {});

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _gameService.watchPublicState(widget.roomId),
                  builder: (context, publicSnap) {
                    if (!publicSnap.hasData || !publicSnap.data!.exists) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFFFFC107)),
                              SizedBox(height: 16),
                              Text(
                                'Oyun hazırlanıyor...',
                                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final pub = publicSnap.data!.data()!;
                    final status = pub['status'] ?? 'playing';
                    final currentTurnPlayerId = pub['currentTurnPlayerId'] as String?;
                    final botControlledSeats = List<String>.from(pub['botControlledSeats'] ?? (roomData?['botControlledSeats'] ?? []));
                    
                    if (botControlledSeats.contains(_myUid)) {
                      _roomService.reclaimSeat(widget.roomId, _myUid);
                    }

                    _updateWatchdog(currentTurnPlayerId, botControlledSeats);

                    final playerOrder = List<String>.from(pub['playerOrder'] ?? []);
                    final handCounts = Map<String, dynamic>.from(pub['handCounts'] ?? {});
                    final pistiCounts = Map<String, dynamic>.from(pub['pistiCounts'] ?? {});
                    final currentScores = pub['currentScores'] as Map<String, dynamic>?;
                    final tableCardsRaw = List<Map<String, dynamic>>.from(pub['tableCards'] ?? []);
                    final tableCards = tableCardsRaw.map((c) => PlayingCard.fromMap(c)).toList();

                    final opponentId = playerOrder.firstWhere(
                      (id) => id != _myUid,
                      orElse: () => '',
                    );
                    final myTurn = currentTurnPlayerId == _myUid;

                    // Usernames from the room document
                    final myInfo = players[_myUid] as Map<String, dynamic>?;
                    final myName = myInfo?['displayName'] as String? ?? 'Sen';

                    final opponentInfo = players[opponentId] as Map<String, dynamic>?;
                    final opponentName = opponentInfo?['displayName'] as String? ?? 'Rakip';

                    final isOpponentBot = botControlledSeats.contains(opponentId);
                    final opponentDisplayName = isOpponentBot ? '$opponentName (Bot)' : opponentName;

                    final myScore = currentScores?[_myUid] as int? ?? 0;
                    final opponentScore = currentScores?[opponentId] as int? ?? 0;

                    debugPrint('GameScreen build edildi. Status: $status, OpponentId: $opponentId, MyTurn: $myTurn, PlayerOrder: $playerOrder');

                    if (status == 'abandoned') {
                      return _buildAbandonedPanel(opponentName);
                    }

                    if (status == 'roundFinished') {
                      return _buildRoundFinishedPanel(pub, playerOrder, players);
                    }

                    if (status == 'matchFinished' || status == 'finished') {
                      return _buildMatchFinishedPanel(pub, playerOrder, players);
                    }

                    return Column(
                      children: [
                        // Tur Göstergesi
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Tur: ${pub['currentRound'] ?? 1} / ${pub['totalRounds'] ?? 1}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Canlı Bildirim Çubuğu (Koptu / Bot Devraldı / Terk Etti)
                        if (opponentId.isNotEmpty)
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('rooms')
                                .doc(widget.roomId)
                                .collection('presence')
                                .doc(opponentId)
                                .snapshots(),
                            builder: (context, presSnap) {
                              final presData = presSnap.data?.data();
                              final lastActiveTimestamp = presData?['lastActiveAt'] as Timestamp?;
                              final lastActiveMs = lastActiveTimestamp?.millisecondsSinceEpoch;
                              final nowMs = DateTime.now().millisecondsSinceEpoch;

                              final isStale = lastActiveMs != null && (nowMs - lastActiveMs > 8000);
                              final is60sStale = lastActiveMs != null && (nowMs - lastActiveMs > 60000);

                              String? bannerText;
                              Color bannerColor = Colors.orange;

                              if (isOpponentBot) {
                                if (is60sStale) {
                                  bannerText = '🚪 $opponentName oyunu terk etti.';
                                  bannerColor = Colors.redAccent;
                                } else {
                                  bannerText = '🤖 Bot devraldı. $opponentName oyundan çıktı / bekleniyor...';
                                  bannerColor = Colors.amber.shade800;
                                }
                              } else if (isStale) {
                                bannerText = '⚠️ $opponentName oyundan çıktı / bağlantısı koptu (Bot devralacak)...';
                                bannerColor = Colors.orange.shade800;
                                if (nowMs - lastActiveMs > 10000) {
                                  _roomService.claimBotTakeover(widget.roomId, opponentId);
                                }
                              }

                              if (bannerText == null) return const SizedBox.shrink();

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: bannerColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: bannerColor, width: 1.2),
                                ),
                                child: Center(
                                  child: Text(
                                    bannerText,
                                    style: TextStyle(color: bannerColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoChip(
                              opponentDisplayName,
                              handCounts[opponentId] as int?,
                              pistiCounts[opponentId] as int? ?? 0,
                              opponentScore,
                              isMyTurn: !myTurn,
                            ),
                            _infoChip(
                              myName,
                              null,
                              pistiCounts[_myUid] as int? ?? 0,
                              myScore,
                              isMyTurn: myTurn,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 2. Rakip Kartları
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Wrap(
                          spacing: -16,
                          alignment: WrapAlignment.center,
                          children: List.generate(
                            (handCounts[opponentId] ?? 0) is int ? handCounts[opponentId] ?? 0 : 0,
                            (i) => const CardBackWidget(width: 50, height: 72),
                          ),
                        ),
                      ),

                      // 3. Oyun Masası
                      Expanded(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            height: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(120),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 2.0,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (tableCards.isEmpty)
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

                                for (int i = 0; i < tableCards.length; i++)
                                  Positioned(
                                    key: ValueKey('${tableCards[i].id}_$i'),
                                    left: (MediaQuery.of(context).size.width - 40 - 32 - 54) / 2 + (i - (tableCards.length - 1) / 2) * 12.0,
                                    child: Transform.rotate(
                                      angle: (i == tableCards.length - 1) ? 0 : (i * 0.08 - 0.12),
                                      child: _AnimatedTableCard(
                                        child: PlayingCardWidget(
                                          card: tableCards[i],
                                          width: 54,
                                          height: 76,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 4. Durum Göstergesi
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
                              myTurn ? 'Senin Sıran (⏱️ ${_turnSecondsLeft}s)' : '$opponentDisplayName Düşünüyor...',
                              style: TextStyle(
                                color: myTurn ? const Color(0xFFFFB300) : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Kendi Kartlarım
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: StreamBuilder<List<PlayingCard>>(
                          stream: _gameService.watchMyHand(widget.roomId),
                          builder: (context, handSnap) {
                            final myHand = handSnap.data ?? [];
                            
                            // 30 saniyelik hamle geriye sayım sayacını senkronize et
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _syncTurnTimer(myTurn && status == 'playing', myHand);
                            });

                            return Wrap(
                              spacing: 10,
                              alignment: WrapAlignment.center,
                              children: myHand.map((card) {
                                final isPlaying = _playedCardId == card.id;
                                return AnimatedScale(
                                  scale: isPlaying ? 0.2 : 1.0,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeIn,
                                  child: AnimatedOpacity(
                                    opacity: isPlaying ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 220),
                                    child: PlayingCardWidget(
                                      card: card,
                                      width: 58,
                                      height: 82,
                                      raised: myTurn && !isPlaying,
                                      onTap: (myTurn && _playedCardId == null)
                                          ? () => _onPlayCard(card)
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _infoChip(String label, int? cardCount, int pistiCount, int score, {required bool isMyTurn}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      width: 125,
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? const Color(0xFFFFC107).withValues(alpha: 0.7) : Colors.white12,
          width: isMyTurn ? 1.5 : 1.0,
        ),
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
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$score Puan',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            cardCount != null
                ? '$cardCount kart · $pistiCount pişti'
                : '$pistiCount pişti',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Widget _buildAbandonedPanel(String opponentName) {
    return Center(
      child: Container(
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
            Text(
              '$opponentName oyunu terk etti',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                onPressed: () async {
                  await _roomService.leaveRoom(widget.roomId);
                  if (!mounted) return;
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text('Ana Ekrana Dön', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundFinishedPanel(Map<String, dynamic> pub, List<String> playerOrder, Map<String, dynamic> players) {
    final scores = Map<String, dynamic>.from(pub['scores'] ?? {});
    final cumulativeScores = Map<String, dynamic>.from(pub['cumulativeScores'] ?? {});
    final roundReady = Map<String, dynamic>.from(pub['roundReady'] ?? {});
    final isReady = roundReady[_myUid] == true;

    final opponentId = playerOrder.firstWhere((id) => id != _myUid, orElse: () => '');

    final myInfo = players[_myUid] as Map<String, dynamic>?;
    final myName = myInfo?['displayName'] as String? ?? 'Sen';

    final opponentInfo = players[opponentId] as Map<String, dynamic>?;
    final opponentName = opponentInfo?['displayName'] as String? ?? 'Rakip';

    final myScoreThisRound = scores[_myUid] ?? 0;
    final opponentScoreThisRound = scores[opponentId] ?? 0;

    final myCumulativeScore = cumulativeScores[_myUid] ?? 0;
    final opponentCumulativeScore = cumulativeScores[opponentId] ?? 0;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tur ${pub['currentRound'] ?? 1} / ${pub['totalRounds'] ?? 1} Tamamlandı!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    const Text('', style: TextStyle(color: Colors.white)),
                    Text(myName, style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                    Text(opponentName, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Bu Tur', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('+$myScoreThisRound', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('+$opponentScoreThisRound', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Toplam Puan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('$myCumulativeScore', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('$opponentCumulativeScore', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            isReady
                ? const Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFFC107)),
                      SizedBox(height: 12),
                      Text('Diğer oyuncu bekleniyor...', style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.roomId)
                            .collection('moves')
                            .add({
                          'type': 'roundReady',
                          'playerId': _myUid,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      },
                      child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFinishedPanel(Map<String, dynamic> pub, List<String> playerOrder, Map<String, dynamic> players) {
    final cumulativeScores = Map<String, dynamic>.from(pub['cumulativeScores'] ?? {});
    final finalRanking = List<String>.from(pub['finalRanking'] ?? playerOrder);

    final winnerId = finalRanking.isNotEmpty ? finalRanking.first : '';
    final isMeWinner = winnerId == _myUid;

    final opponentId = playerOrder.firstWhere((id) => id != _myUid, orElse: () => '');

    final myInfo = players[_myUid] as Map<String, dynamic>?;
    final myName = myInfo?['displayName'] as String? ?? 'Sen';

    final opponentInfo = players[opponentId] as Map<String, dynamic>?;
    final opponentName = opponentInfo?['displayName'] as String? ?? 'Rakip';

    final myTotal = cumulativeScores[_myUid] ?? 0;
    final opponentTotal = cumulativeScores[opponentId] ?? 0;

    String resultText = 'Kaybettin.';
    if (winnerId.isEmpty || myTotal == opponentTotal) {
      resultText = 'Beraberlik!';
    } else if (isMeWinner) {
      resultText = 'Tebrikler, Şampiyonsun! 🏆';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.7), width: 2.0),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resultText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Maç Sonu Puan Tablosu',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    if (myTotal >= opponentTotal && myTotal != opponentTotal)
                      const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 28),
                    const SizedBox(height: 4),
                    Text(myName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$myTotal Puan', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    if (opponentTotal >= myTotal && myTotal != opponentTotal)
                      const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 28),
                    const SizedBox(height: 4),
                    Text(opponentName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$opponentTotal Puan', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await _roomService.leaveRoom(widget.roomId);
                  if (!mounted) return;
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text('Ana Ekrana Dön', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
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