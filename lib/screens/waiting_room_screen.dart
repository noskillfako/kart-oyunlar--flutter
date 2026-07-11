import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomId;

  const WaitingRoomScreen({super.key, required this.roomId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final RoomService _roomService = RoomService();
  bool _navigated = false;
  bool _isLeaving = false;

  Future<void> _leaveRoom() async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _roomService.leaveRoom(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _leaveRoom();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Oda: ${widget.roomId.substring(0, 6)}...'),
          centerTitle: true,
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _leaveRoom();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
        body: CasinoBackground(
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _roomService.watchRoom(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }

                final data = snapshot.data!.data()!;
                final players = Map<String, dynamic>.from(data['players'] ?? {});
                final maxPlayers = data['maxPlayers'] ?? 2;
                final status = data['status'] ?? 'waiting';

                if (status == 'waiting' && players.length >= maxPlayers) {
                  _roomService.startGameIfFull(widget.roomId);
                }

                if (status == 'playing' && !_navigated) {
                  _navigated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(roomId: widget.roomId),
                      ),
                    );
                  });
                }

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const Icon(Icons.hourglass_top_rounded, color: AppColors.goldDeep, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        '${players.length}/$maxPlayers oyuncu bekleniyor',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OYUNCULAR',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...players.entries.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, color: AppColors.gold, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        e.value['displayName'] ?? 'Oyuncu',
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GoldOutlineButton(
                        label: 'Odadan Ayrıl',
                        icon: Icons.exit_to_app,
                        onPressed: () async {
                          await _leaveRoom();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}