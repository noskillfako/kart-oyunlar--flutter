import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lobby_screen.dart';
import 'pisti_demo_screen.dart';
import 'set_name_screen.dart';
import '../services/user_prefs_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefsService = UserPrefsService();
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await _prefsService.getDisplayName();
    setState(() => _displayName = name);
  }

  Future<void> _goToLobby() async {
    final hasName = await _prefsService.hasDisplayName();

    if (!hasName) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetNameScreen(
            onSaved: () {
              Navigator.pop(context);
              _loadName();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LobbyScreen()),
              );
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  LobbyScreen()),
      );
    }
  }

  Future<void> _editName() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SetNameScreen()),
    );
    _loadName();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'Giriş yapılamadı';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Kart Oyunları',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_displayName != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _displayName!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: _editName,
                    tooltip: 'İsmi değiştir',
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'UID: $uid',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _goToLobby,
              child: const Text('Oyna'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PistiDemoScreen()),
                );
              },
              child: const Text('Pişti Motorunu Test Et (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}