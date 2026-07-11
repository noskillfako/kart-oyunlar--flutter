import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/room_service.dart';
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
          title: Text('Oda: ${widget.roomId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _leaveRoom();
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _roomService.watchRoom(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Oyun: ${data['gameType']}'),
                  Text('Durum: $status'),
                  const SizedBox(height: 16),
                  const Text('Oyuncular:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...players.entries.map((e) => Text('- ${e.value['displayName']}')),
                  const SizedBox(height: 16),
                  Text('${players.length}/$maxPlayers oyuncu bekleniyor...'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await _leaveRoom();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Odadan Ayrıl'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}