import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import 'waiting_room_screen.dart';

// Oyun türü etiket bilgileri
const _gameLabels = {
  'pisti': ('Pişti', Icons.style_rounded, AppColors.gold),
  'batak': ('Batak', Icons.casino_rounded, Color(0xFF7C5CBF)),
};

class RoomListScreen extends StatelessWidget {
  /// null → tüm odaları göster, belirtilmişse sadece o oyun türünü filtrele
  final String? filterGameType;

  RoomListScreen({super.key, this.filterGameType});

  final RoomService _roomService = RoomService();

  String get _title {
    if (filterGameType == null) return 'Tüm Odalar';
    return '${_gameLabels[filterGameType]?.$1 ?? filterGameType} Odaları';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CasinoAppBar(title: _title),
      body: CasinoBackground(
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _roomService.watchOpenRooms(gameType: filterGameType),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                );
              }

              final rooms = snapshot.data ?? [];

              if (rooms.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          filterGameType != null
                              ? 'Açık ${_gameLabels[filterGameType]?.$1 ?? filterGameType} odası yok.\nLobiden bir oda kur!'
                              : 'Şu an açık oda yok.\nBir oda kurup ilk oyuncu sen ol!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return _RoomTile(
                    room: room,
                    onJoin: () async {
                      await _roomService.joinRoom(room['id']);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WaitingRoomScreen(roomId: room['id']),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Oda Kartı Widget ─────────────────────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onJoin;

  const _RoomTile({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final players = Map<String, dynamic>.from(room['players'] ?? {});
    final maxPlayers = room['maxPlayers'] ?? 2;
    final hostName = players.values.isNotEmpty
        ? (players.values.first['displayName'] ?? 'Oyuncu')
        : 'Oyuncu';
    final gameType = room['gameType'] ?? 'pisti';
    final info = _gameLabels[gameType];
    final gameLabel = info?.$1 ?? gameType;
    final gameIcon = info?.$2 ?? Icons.style_rounded;
    final gameColor = info?.$3 ?? AppColors.gold;

    final filled = players.length;
    final isFull = filled >= maxPlayers;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Oyun ikonу
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: gameColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(gameIcon, color: gameColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Bilgi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Oyun türü + host adı
                Row(
                  children: [
                    _GameBadge(label: gameLabel, color: gameColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$hostName\'in Odası',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Oyuncu sayısı göstergesi
                _PlayerBar(filled: filled, max: maxPlayers),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Katıl butonu
          ElevatedButton(
            onPressed: isFull ? null : onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: isFull ? Colors.white12 : AppColors.gold,
              foregroundColor: isFull ? Colors.white38 : Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isFull ? 'Dolu' : 'Katıl',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Oyun Türü Rozeti ─────────────────────────────────────────────────────────
class _GameBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _GameBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Oyuncu Dolu/Boş Göstergesi ──────────────────────────────────────────────
class _PlayerBar extends StatelessWidget {
  final int filled;
  final int max;

  const _PlayerBar({required this.filled, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(
          max,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < filled ? Icons.person : Icons.person_outline,
              size: 14,
              color: i < filled
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$filled/$max oyuncu',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}