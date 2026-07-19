import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';
import '../services/game_service.dart';
import '../widgets/playing_card_widget.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  String? _playedCardId;

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

    return Scaffold(
      appBar: AppBar(
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
              debugPrint('GameScreen build edildi. Status: $status, OpponentId: $opponentId, MyTurn: $myTurn, PlayerOrder: $playerOrder');

              if (status == 'abandoned') {
                return _buildAbandonedPanel();
              }

              if (status == 'finished') {
                return _buildFinishedPanel(pub, playerOrder);
              }

              return Column(
                children: [
                  // 1. Dashboard
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoChip('Sen', pistiCounts[_myUid] ?? 0, isMyTurn: myTurn),
                        _deckChip(deckCount),
                        _infoChip('Rakip', pistiCounts[opponentId] ?? 0, isMyTurn: !myTurn && status != 'finished'),
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
                          myTurn ? 'Senin Sıran' : 'Rakip Düşünüyor...',
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
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, int pistiCount, {required bool isMyTurn}) {
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
            '$pistiCount Pişti',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 15,
              fontWeight: FontWeight.bold,
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

  Widget _buildAbandonedPanel() {
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
            const Text(
              'Rakip oyunu terk etti',
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
      ),
    );
  }

  Widget _buildFinishedPanel(Map<String, dynamic> pub, List<String> playerOrder) {
    final scores = Map<String, dynamic>.from(pub['scores'] ?? {});
    final myScore = scores[_myUid] ?? 0;
    final opponentId = playerOrder.firstWhere((id) => id != _myUid, orElse: () => '');
    final opponentScore = scores[opponentId] ?? 0;

    final resultText = myScore > opponentScore
        ? 'Tebrikler, Kazandın! 🎉'
        : (myScore == opponentScore ? 'Beraberlik!' : 'Kaybettin.');

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
              resultText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Senin Puanın', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$myScore', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Rakip Puanı', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$opponentScore', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 40,
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