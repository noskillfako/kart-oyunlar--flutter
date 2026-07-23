import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'demo_selection_screen.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';
import 'set_name_screen.dart';
import 'game_screen.dart';
import 'batak_game_screen.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _userService = UserService();
  final _prefsService = UserPrefsService(); // RoomService fallback için
  final _authService = AuthService();
  final _roomService = RoomService();
  bool _linkingInProgress = false; // ignore: prefer_final_fields

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _goToLobby() async {
    // Profil stream'den ya da yerel önbellekten isim var mı kontrol et
    final hasName = await _prefsService.hasDisplayName();
    if (!hasName) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetNameScreen(
            onSaved: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LobbyScreen()),
      );
    }
  }

  void _goToProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
      );
    }
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
      setState(() {});
    } else if (!result.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Bir hata oluştu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [
              Color(0xFF1B3B1E), // Açık çuha yeşili
              Color(0xFF0E2410), // Hafif gölgeli kenar
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style_rounded,
                      color: Color(0xFFD4A24E), size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    'İskambil', // <-- Sadece İskambil olarak değiştirildi
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 12)
                      ],
                    ),
                  ),
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
                        margin: const EdgeInsets.only(bottom: 24),
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

                  // OYNA butonu (koyu bordo) - Genişliği kısaltıldı
                  _buildPulseButton(
                    emoji: '🃏',
                    label: 'Oyna',
                    subtitle: 'Online / Lobi',
                    colors: const [Color(0xFF5C1A2A), Color(0xFF8B2A3A)],
                    borderColor: const Color(0xFFD88A96),
                    glowColor: const Color(0xFFD88A96),
                    onPressed: _goToLobby,
                  ),
                  const SizedBox(height: 16),

                  // DEMO butonu (koyu petrol) - Genişliği kısaltıldı
                  _buildPulseButton(
                    emoji: '🤖',
                    label: 'Demo Oyun',
                    subtitle: 'Bot ile oyna',
                    colors: const [Color(0xFF0A3B3C), Color(0xFF1A5A5C)],
                    borderColor: const Color(0xFF7DD8DC),
                    glowColor: const Color(0xFF7DD8DC),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DemoSelectionScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // İleride eklenecek Ayarlar / Kredi butonları için boşluk
                  // Örnek:
                  // _buildTextButton('Ayarlar', Icons.settings, () {}),
                  // const SizedBox(height: 8),
                  // _buildTextButton('Krediler', Icons.info_outline, () {}),

                  // ── İsim rozeti (Firestore stream'den) ─────────────────
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _userService.watchProfile(),
                    builder: (context, snapshot) {
                      final name = snapshot.data?.data()?['displayName'] as String?;
                      if (name == null || name.isEmpty) return const SizedBox.shrink();

                      return GestureDetector(
                        onTap: _goToProfile,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final glowOpacity =
                                0.2 + (_pulseAnimation.value - 1.0) * 3;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4A24E)
                                        .withValues(alpha: glowOpacity),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person,
                                      color: Color(0xFFD4A24E), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.account_circle_outlined,
                                      size: 14, color: Colors.white54),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Google bağlantı durumu ────────────────────────────────
                  if (!_authService.isLinkedWithGoogle)
                    TextButton.icon(
                      onPressed: _linkingInProgress ? null : _linkGoogle,
                      icon: _linkingInProgress
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70),
                            )
                          : const Icon(Icons.link,
                              size: 16, color: Colors.white70),
                      label: Text(
                        _linkingInProgress
                            ? 'Bağlanıyor...'
                            : 'Hesabı kalıcı yap',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    )
                  else
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 14),
                        SizedBox(width: 6),
                        Text('Google hesabına bağlı',
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 12)),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'UID: ${FirebaseAuth.instance.currentUser?.uid ?? ""}',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Buton genişliğini kısalttık (max 300 px) ve ortalamak için Center eklendi
  Widget _buildPulseButton({
    required String emoji,
    required String label,
    required String subtitle,
    required List<Color> colors,
    required Color borderColor,
    required Color glowColor,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _pulseAnimation.value;
        final glowOpacity = 0.25 + (scale - 1.0) * 4;

        return Transform.scale(
          scale: scale,
          child: Center( // Ortalamak için Center eklendi
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 300, // <-- Sabit genişlik, enlemesine kısaltıldı
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: glowOpacity),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // İleride Ayarlar/Kredi için kullanabileceğin basit buton şablonu
  /*
  Widget _buildTextButton(String text, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white70),
      label: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
  */
}