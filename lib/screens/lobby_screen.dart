import 'package:flutter/material.dart';
import '../services/room_service.dart';
import 'waiting_room_screen.dart';
import 'room_list_screen.dart';

class LobbyScreen extends StatelessWidget {
  LobbyScreen({super.key});

  final RoomService _roomService = RoomService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobi')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final roomId = await _roomService.createRoom();
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaitingRoomScreen(roomId: roomId),
                    ),
                  );
                }
              },
              child: const Text('Oda Oluştur'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: odaya katılma mantığı buraya gelecek (sonraki adım)
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomListScreen()),
                );
              },
              child: const Text('Odaya Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}