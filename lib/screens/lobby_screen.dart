import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import 'waiting_room_screen.dart';
import 'room_list_screen.dart';
import 'game_screen.dart';
import 'batak_game_screen.dart';

// ─── Oyun türü modeli ─────────────────────────────────────────────────────────
class _GameType {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final List<int> playerOptions;

  const _GameType({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.playerOptions,
  });
}

const _gameTypes = [
  _GameType(
    id: 'pisti',
    label: 'Pişti',
    description: 'Kartları eşleştir,\npişti yap, puan topla!',
    icon: Icons.style_rounded,
    playerOptions: [2, 4],
  ),
  _GameType(
    id: 'batak',
    label: 'Batak',
    description: 'El al, kontrat yap,\nen çok eli topla!',
    icon: Icons.casino_rounded,
    playerOptions: [4],
  ),
];

// ─── Lobi Ekranı ──────────────────────────────────────────────────────────────
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final RoomService _roomService = RoomService();

  int _selectedGameIndex = 0;
  int _selectedPlayers = 2;
  int _selectedRounds = 3; // Varsayılan 3 tur
  bool _isCreating = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  _GameType get _selectedGame => _gameTypes[_selectedGameIndex];

  void _selectGame(int index) {
    if (_selectedGameIndex == index) return;
    setState(() {
      _selectedGameIndex = index;
      // Yeni oyunda ilk geçerli oyuncu sayısına sıfırla
      _selectedPlayers = _gameTypes[index].playerOptions.first;
    });
    _fadeCtrl
      ..reset()
      ..forward();
  }

  Future<void> _createRoom() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final roomId = await _roomService.createRoom(
        gameType: _selectedGame.id,
        maxPlayers: _selectedPlayers,
        totalRounds: _selectedRounds,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(roomId: roomId),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      appBar: const CasinoAppBar(title: 'Lobi'),
      body: CasinoBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Devam Eden Oyun Bildirim Kartı
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _roomService.watchActiveRoomForUser(),
                  builder: (context, activeSnap) {
                    final activeData = activeSnap.data;
                    if (activeData == null) return const SizedBox.shrink();

                    final roomId = activeData['roomId'] as String;
                    final gameType = activeData['gameType'] as String? ?? 'pisti';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFC107), width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withValues(alpha: 0.25),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🎮 Devam Eden Oyununuz Var!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(${gameType.toUpperCase()} - Tur: ${activeData['currentRound'] ?? 1})',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            ),
                            onPressed: () {
                              if (gameType == 'batak') {
                                final players = Map<String, dynamic>.from(activeData['players'] ?? {});
                                final names = <String, String>{};
                                players.forEach((k, v) {
                                  names[k] = (v as Map)['displayName'] as String? ?? 'Oyuncu';
                                });
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BatakGameScreen(
                                      roomId: roomId,
                                      playerNames: names,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GameScreen(roomId: roomId),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text('Oyuna Tekrar Katıl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Başlık ──────────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.videogame_asset_rounded,
                        color: AppColors.goldDeep, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Oyun Seç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Oyun Kartları ────────────────────────────────────────────
                Row(
                  children: List.generate(
                    _gameTypes.length,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < _gameTypes.length - 1 ? 10 : 0,
                        ),
                        child: _GameTypeCard(
                          game: _gameTypes[i],
                          selected: _selectedGameIndex == i,
                          onTap: () => _selectGame(i),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Oyuncu Sayısı ────────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded,
                              color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Oyuncu Sayısı',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _selectedGame.playerOptions
                            .map(
                              (count) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: count !=
                                            _selectedGame.playerOptions.last
                                        ? 10
                                        : 0,
                                  ),
                                  child: _PlayerCountChip(
                                    count: count,
                                    selected: _selectedPlayers == count,
                                    onTap: () =>
                                        setState(() => _selectedPlayers = count),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // ── Tur Sayısı ──────────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded,
                              color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tur Sayısı',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [1, 3, 5, 7]
                            .map(
                              (rounds) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: rounds != 7 ? 10 : 0,
                                  ),
                                  child: _RoundCountChip(
                                    rounds: rounds,
                                    selected: _selectedRounds == rounds,
                                    onTap: () =>
                                        setState(() => _selectedRounds = rounds),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Oda Oluştur ──────────────────────────────────────────────
                _isCreating
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold))
                    : GoldButton(
                        label: 'Oda Oluştur',
                        icon: Icons.add_circle_outline,
                        onPressed: _createRoom,
                      ),

                const SizedBox(height: 12),

                // ── Odaya Katıl ──────────────────────────────────────────────
                GoldOutlineButton(
                  label: 'Açık Odalara Bak',
                  icon: Icons.search,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomListScreen(
                          filterGameType: _selectedGame.id,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Tüm odaları gör linki
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomListScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Tüm açık odaları gör',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Oyun Türü Kartı ──────────────────────────────────────────────────────────
class _GameTypeCard extends StatelessWidget {
  final _GameType game;
  final bool selected;
  final VoidCallback onTap;

  const _GameTypeCard({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white12,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              game.icon,
              color: selected ? AppColors.goldDeep : Colors.white38,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              game.label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              game.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            // Oyuncu sayısı özeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                game.playerOptions.map((n) => '${n}K').join(' / '),
                style: TextStyle(
                  color: selected ? AppColors.goldDeep : Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Oyuncu Sayısı Chip ───────────────────────────────────────────────────────
class _PlayerCountChip extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerCountChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 16,
              color: selected ? AppColors.goldDeep : Colors.white30,
            ),
            const SizedBox(width: 6),
            Text(
              '$count Kişi',
               style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tur Sayısı Chip ──────────────────────────────────────────────────────────
class _RoundCountChip extends StatelessWidget {
  final int rounds;
  final bool selected;
  final VoidCallback onTap;

  const _RoundCountChip({
    required this.rounds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$rounds Tur',
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}