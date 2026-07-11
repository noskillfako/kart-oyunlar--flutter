import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import 'waiting_room_screen.dart';
import 'room_list_screen.dart';

class LobbyScreen extends StatelessWidget {
  LobbyScreen({super.key});

  final RoomService _roomService = RoomService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CasinoAppBar(title: 'Lobi'),
      body: CasinoBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.groups_rounded, color: AppColors.goldDeep, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Bir oda kur ya da\naçık bir odaya katıl',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 36),
                GoldButton(
                  label: 'Oda Oluştur',
                  icon: Icons.add_circle_outline,
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
                ),
                const SizedBox(height: 14),
                GoldOutlineButton(
                  label: 'Odaya Katıl',
                  icon: Icons.search,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoomListScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}