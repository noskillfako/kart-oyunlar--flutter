import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

// ─── Oyuncu Adı & Hesap Kurtarma Ekranı ──────────────────────────────────────
class SetNameScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const SetNameScreen({super.key, this.onSaved});

  @override
  State<SetNameScreen> createState() => _SetNameScreenState();
}

class _SetNameScreenState extends State<SetNameScreen> {
  final _controller = TextEditingController();
  final _userService = UserService();
  final _authService = AuthService();

  bool _loading = true;
  bool _saving = false;
  bool _googleSigningIn = false;

  @override
  void initState() {
    super.initState();
    _loadExistingName();
  }

  /// Mevcut ismi Firestore'dan yükle; yoksa SharedPreferences'tan fallback
  Future<void> _loadExistingName() async {
    try {
      final snapshot = await _userService.watchProfile().first;
      if (snapshot.exists) {
        final name = snapshot.data()?['displayName'] as String?;
        if (name != null && name.isNotEmpty) {
          _controller.text = name;
        }
      }
    } catch (_) {
      // Stream boşsa (henüz profil yoksa) bir şey yapma
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Lütfen bir isim gir!');
      return;
    }
    if (name.length > 20) {
      _showSnackBar('İsim en fazla 20 karakter olabilir!');
      return;
    }

    setState(() => _saving = true);
    try {
      // Önce profil yoksa oluştur, ardından ismi güncelle
      await _userService.ensureProfileExists();
      await _userService.updateDisplayName(name);

      if (!mounted) return;

      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Kaydedilemedi, lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Google ile giriş → hesap kurtarma akışı
  Future<void> _onGoogleSignInTapped() async {
    // Kullanıcıyı önceden uyar: misafir ilerlemesi kaybolabilir
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hesap Kurtarma',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu işlem mevcut misafir ilerlemeni (isim, istatistikler) kaybettirebilir.\n\n'
          'Eğer bu Google hesabıyla daha önce oynadıysan eski profiline kavuşursun. '
          'Yeni bir Google hesabıysa misafir verilerini kaybedebilirsin.\n\n'
          'Devam etmek istiyor musun?',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _googleSigningIn = true);

    final result = await _authService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _googleSigningIn = false);

    if (result.isSuccess) {
      // Yeni UID için profil yoksa oluştur
      await _userService.ensureProfileExists();
      // Profildeki ismi forma yükle
      await _loadExistingName();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Google hesabınla giriş yapıldı!',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      }
    } else if (!result.isCancelled) {
      _showSnackBar(result.errorMessage ?? 'Giriş sırasında bir hata oluştu.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CasinoAppBar(title: 'Oyuncu Adı'),
      body: CasinoBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Avatar rozet ─────────────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.style, size: 64, color: AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Başlık ────────────────────────────────────────────────
                  const Text(
                    'Profilini Özelleştir',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diğer oyuncuların masada seni bu isimle görecek.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── İsim giriş kartı ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OYUNCU ADIN',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _controller,
                          maxLength: 20,
                          autofocus: true,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          cursorColor: AppColors.gold,
                          decoration: InputDecoration(
                            hintText: 'Örn. Ahmet',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            prefixIcon: const Icon(Icons.badge, color: AppColors.gold),
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.deepGreen.withValues(alpha: 0.4),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.gold.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.gold,
                                width: 2.0,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, child) {
                              final length = value.text.length;
                              return Text(
                                '$length / 20',
                                style: TextStyle(
                                  color:
                                      length > 15 ? Colors.redAccent : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Kaydet butonu ─────────────────────────────────────────
                  GoldButton(
                    label: _saving ? 'Kaydediliyor...' : 'Kaydet ve Devam Et',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 24),

                  // ── Ayırıcı ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Google ile hesap kurtarma ─────────────────────────────
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _googleSigningIn ? null : _onGoogleSignInTapped,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _googleSigningIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            )
                          : const Icon(Icons.login, size: 18),
                      label: Text(
                        _googleSigningIn
                            ? 'Bağlanıyor...'
                            : 'Zaten hesabın var mı? Google ile giriş yap',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}