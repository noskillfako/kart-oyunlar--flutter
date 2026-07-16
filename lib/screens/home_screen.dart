import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lobby_screen.dart';
import 'game_demo_screen.dart';
import 'set_name_screen.dart';
import '../services/user_prefs_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefsService = UserPrefsService();
  final _authService = AuthService();
  String? _displayName;
  bool _linkingInProgress = false;

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
                MaterialPageRoute(builder: (_) =>  LobbyScreen()),
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

  Future<void> _linkGoogle() async {
    setState(() => _linkingInProgress = true);

    final result = await _authService.linkWithGoogle();

    if (!mounted) return;
    setState(() => _linkingInProgress = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google hesabına başarıyla bağlandı!')),
      );
      setState(() {}); // Google bağlantı durumunu yeniden çiz
    } else if (!result.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Bir hata oluştu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'Giriş yapılamadı';
    final isLinked = _authService.isLinkedWithGoogle;

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
                  const SizedBox(height: 10),

                  // Google hesabı bağlama durumu
                  if (isLinked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _authService.googleEmail ?? 'Google hesabına bağlı',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _linkingInProgress ? null : _linkGoogle,
                      icon: _linkingInProgress
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            )
                          : const Icon(Icons.link, size: 16, color: Colors.white70),
                      label: Text(
                        _linkingInProgress ? 'Bağlanıyor...' : 'Google ile hesabını kalıcı yap',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 6),
                  Text(
                    'UID: $uid',
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(height: 32),
                  GoldButton(
                    label: 'Oyna',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _goToLobby,
                  ),
                  const SizedBox(height: 14),
                  GoldOutlineButton(
                    label: 'Demo Oyun (Bot ile)',
                    icon: Icons.smart_toy_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameDemoScreen()),
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