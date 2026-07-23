import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

// ─── Profil Ekranı ────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final _nameController = TextEditingController();

  bool _editingName = false;
  bool _savingName = false;
  String? _selectedAvatarId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── İsim kaydetme ─────────────────────────────────────────────────────────
  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(_goldSnackBar(
        name.isEmpty ? 'İsim boş bırakılamaz!' : 'İsim en fazla 20 karakter olabilir!',
      ));
      return;
    }

    setState(() => _savingName = true);
    try {
      await _userService.updateDisplayName(name);
      if (mounted) setState(() => _editingName = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(_goldSnackBar('Kaydedilemedi, tekrar dene.'));
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ── Avatar güncelleme ─────────────────────────────────────────────────────
  Future<void> _selectAvatar(String avatarId) async {
    setState(() => _selectedAvatarId = avatarId);
    try {
      await _userService.updateAvatar(avatarId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(_goldSnackBar('Avatar kaydedilemedi.'));
      }
    }
  }

  SnackBar _goldSnackBar(String message) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      backgroundColor: AppColors.gold,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = widget.uid == currentUserId;

    return Scaffold(
      appBar: CasinoAppBar(title: isOwnProfile ? 'Profilim' : 'Oyuncu Profili'),
      body: CasinoBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userService.watchProfile(uid: widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Profil bulunamadı.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final data = snapshot.data!.data()!;
            final displayName = data['displayName'] as String? ?? '';
            final avatarId =
                _selectedAvatarId ?? (data['avatarId'] as String? ?? kDefaultAvatarId);
            
            final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
            final totalGamesPlayed = (stats['totalGamesPlayed'] as int?) ?? 0;
            final totalGamesWon = (stats['totalGamesWon'] as int?) ?? 0;
            final longestWinStreak = (stats['longestWinStreak'] as int?) ?? 0;
            final currentWinStreak = (stats['currentWinStreak'] as int?) ?? 0;
            final abandonedGamesCount = (stats['abandonedGamesCount'] as int?) ?? 0;
            final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map? ?? {});

            final chipBalance = (data['chipBalance'] as int?) ?? 0;
            final diamondBalance = (data['diamondBalance'] as int?) ?? 0;
            final createdAt = data['createdAt'] as Timestamp?;

            // Genel kazanma oranı
            final winRate = totalGamesPlayed == 0
                ? '—'
                : '%${(totalGamesWon / totalGamesPlayed * 100).toStringAsFixed(0)}';

            // En çok oynanan/sevilen oyun tespiti
            String favoriteGame = '—';
            int maxPlayed = 0;
            gameStats.forEach((gameKey, gameVal) {
              final gameMap = Map<String, dynamic>.from(gameVal as Map? ?? {});
              final played = (gameMap['gamesPlayed'] as int?) ?? 0;
              if (played > maxPlayed) {
                maxPlayed = played;
                favoriteGame = gameKey == 'pisti' ? 'Pişti' : (gameKey == 'batak' ? 'Batak' : gameKey.toUpperCase());
              }
            });

            // Katılım tarihi
            final joinDate = createdAt != null
                ? _formatDate(createdAt.toDate())
                : '—';

            // İsim form başlangıç değeri
            if (!_editingName && _nameController.text != displayName) {
              _nameController.text = displayName;
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatar + isim başlığı ────────────────────────────────
                    _buildAvatarSection(avatarId, displayName, joinDate),
                    const SizedBox(height: 20),

                    // ── Avatar seçici grid (Sadece kendi profilinde) ──────────
                    if (isOwnProfile) ...[
                      _buildAvatarGrid(avatarId),
                      const SizedBox(height: 20),
                    ],

                    // ── İsim kartı (Kendi profilinde düzenlenebilir, aksi halde statik)
                    _buildNameCard(displayName, isOwnProfile),
                    const SizedBox(height: 16),

                    // ── Genel İstatistikler kartı ───────────────────────────
                    _buildGeneralStatsCard(
                      gamesPlayed: totalGamesPlayed,
                      winRate: winRate,
                      longestStreak: longestWinStreak,
                      currentStreak: currentWinStreak,
                      favoriteGame: favoriteGame,
                      abandonedGames: abandonedGamesCount,
                    ),
                    const SizedBox(height: 16),

                    // ── Oyun bazlı istatistikler kartı ───────────────────────
                    _buildGameDetailsList(gameStats),
                    const SizedBox(height: 16),

                    // ── Bakiye kartı (Elmas yalnızca kendi profilinde görünür) ─
                    _buildBalanceCard(
                      chipBalance: chipBalance,
                      diamondBalance: diamondBalance,
                      showDiamond: isOwnProfile,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Avatar + isim başlığı ─────────────────────────────────────────────────
  Widget _buildAvatarSection(String avatarId, String displayName, String joinDate) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Text(
                kAvatarEmojis[avatarId] ?? '🦁',
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Katıldı: $joinDate',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar seçici grid ────────────────────────────────────────────────────
  Widget _buildAvatarGrid(String currentAvatarId) {
    return _buildCard(
      title: 'AVATAR SEÇ',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: kAvatarEmojis.length,
        itemBuilder: (context, index) {
          final id = kAvatarEmojis.keys.elementAt(index);
          final emoji = kAvatarEmojis[id]!;
          final isSelected = id == currentAvatarId;

          return GestureDetector(
            onTap: () => _selectAvatar(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── İsim düzenleme kartı ──────────────────────────────────────────────────
  Widget _buildNameCard(String currentName, bool editable) {
    return _buildCard(
      title: 'OYUNCU ADI',
      child: _editingName && editable
          ? Column(
              children: [
                TextField(
                  controller: _nameController,
                  maxLength: 20,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  cursorColor: AppColors.gold,
                  decoration: InputDecoration(
                    hintText: 'Yeni isim gir',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.deepGreen.withValues(alpha: 0.4),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.3), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.gold, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _saveName(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _savingName ? null : _saveName,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            _savingName ? 'Kaydediliyor...' : 'Kaydet',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _editingName = false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('İptal'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    currentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (editable)
                  IconButton(
                    onPressed: () {
                      _nameController.text = currentName;
                      setState(() => _editingName = true);
                    },
                    icon: const Icon(Icons.edit, color: AppColors.gold, size: 20),
                    tooltip: 'İsmi düzenle',
                  ),
              ],
            ),
    );
  }

  // ── Genel İstatistikler kartı ─────────────────────────────────────────────
  Widget _buildGeneralStatsCard({
    required int gamesPlayed,
    required String winRate,
    required int longestStreak,
    required int currentStreak,
    required String favoriteGame,
    required int abandonedGames,
  }) {
    return _buildCard(
      title: 'GENEL İSTATİSTİKLER',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _statTile('🃏', 'Toplam El', '$gamesPlayed'),
          _statTile('🏆', 'Kazanma Oranı', winRate),
          _statTile('🔥', 'En Uzun Seri', '$longestStreak'),
          _statTile('⚡', 'Aktif Seri / En Sevilen', '$currentStreak / $favoriteGame'),
          _statTile('🚪', 'Terk Edilen', '$abandonedGames'),
        ],
      ),
    );
  }

  // ── Oyun bazlı istatistikler listesi ─────────────────────────────────────────
  Widget _buildGameDetailsList(Map<String, dynamic> gameStats) {
    final games = [
      {
        'id': 'pisti',
        'title': 'Pişti',
        'emoji': '🂠',
        'stats': gameStats['pisti'] ?? {},
        'detailLabel': (stats) => 'Pişti Sayısı: ${stats['pistiCount'] ?? 0}',
      },
      {
        'id': 'batak',
        'title': 'Batak',
        'emoji': '♠',
        'stats': gameStats['batak'] ?? {},
        'detailLabel': (stats) => 'En Yüksek Kontrat: ${stats['highestBid'] ?? 0}',
      },
    ];

    return _buildCard(
      title: 'OYUN DETAYLARI',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: games.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.white.withValues(alpha: 0.08),
          height: 16,
        ),
        itemBuilder: (context, index) {
          final game = games[index];
          final gStats = Map<String, dynamic>.from(game['stats'] as Map? ?? {});
          final played = gStats['gamesPlayed'] as int? ?? 0;
          final won = gStats['gamesWon'] as int? ?? 0;
          final winRate = played == 0 ? '—' : '%${(won / played * 100).toStringAsFixed(0)}';
          final detailText = game['detailLabel']!(gStats) as String;

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.midGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
                ),
                child: Text(
                  game['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$played El | $won Galibiyet ($winRate)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                detailText,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepGreen.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bakiye kartı (Elmas yalnızca showDiamond true ise görünür) ───────────────
  Widget _buildBalanceCard({
    required int chipBalance,
    required int diamondBalance,
    required bool showDiamond,
  }) {
    return _buildCard(
      title: 'BAKİYE',
      child: Row(
        children: [
          Expanded(child: _balanceTile('🪙', 'Çip', '$chipBalance')),
          if (showDiamond) ...[
            const SizedBox(width: 12),
            Expanded(child: _balanceTile('💎', 'Elmas', '$diamondBalance')),
          ],
        ],
      ),
    );
  }

  Widget _balanceTile(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.deepGreen.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Genel kart sarmalayıcı ────────────────────────────────────────────────
  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
