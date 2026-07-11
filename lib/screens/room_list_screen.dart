import 'package:flutter/material.dart';
import '../services/room_service.dart';
import 'waiting_room_screen.dart';

class RoomListScreen extends StatelessWidget {
  RoomListScreen({super.key});

  final RoomService _roomService = RoomService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Açık Odalar')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _roomService.watchOpenRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return const Center(child: Text('Şu an açık oda yok.'));
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final players = Map<String, dynamic>.from(room['players'] ?? {});

              return ListTile(
                title: Text('Oyun: ${room['gameType']}'),
                subtitle: Text('${players.length}/${room['maxPlayers']} oyuncu'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await _roomService.joinRoom(room['id']);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WaitingRoomScreen(roomId: room['id']),
                        ),
                      );
                    }
                  },
                  child: const Text('Katıl'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}