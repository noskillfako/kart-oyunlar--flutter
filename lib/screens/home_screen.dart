import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lobby_screen.dart';
import 'pisti_demo_screen.dart';
import 'set_name_screen.dart';
import '../services/user_prefs_service.dart';
import '../theme/app_theme.dart';

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
      body: CasinoBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style_rounded, color: AppColors.goldDeep, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Kart Oyunları',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Online Multiplayer Pişti',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_displayName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, color: AppColors.gold, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _displayName!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _editName,
                            child: const Icon(Icons.edit, size: 14, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'UID: $uid',
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(height: 44),
                  GoldButton(
                    label: 'Oyna',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _goToLobby,
                  ),
                  const SizedBox(height: 14),
                  GoldOutlineButton(
                    label: 'Pişti Motorunu Test Et (Demo)',
                    icon: Icons.smart_toy_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PistiDemoScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}