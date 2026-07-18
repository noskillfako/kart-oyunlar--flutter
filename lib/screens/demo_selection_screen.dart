import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'game_demo_screen.dart';

class DemoSelectionScreen extends StatefulWidget {
  const DemoSelectionScreen({super.key});

  @override
  State<DemoSelectionScreen> createState() => _DemoSelectionScreenState();
}

class _DemoSelectionScreenState extends State<DemoSelectionScreen> {
  // null = hiçbiri seçili değil
  String? _selected;

  void _onCardTap(String gameType) {
    if (_selected == gameType) {
      // 2. tıkla → oyuna geç
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameDemoScreen(gameType: gameType),
        ),
      );
    } else {
      // 1. tıkla → seç
      setState(() => _selected = gameType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      appBar: AppBar(
        title: const Text('Demo Oyun (Bot ile)'),
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [AppColors.midGreen, AppColors.deepGreen],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Başlık
                Text(
                  _selected == null
                      ? 'Hangi oyunu oynamak istersin?'
                      : '${_selected == 'pisti' ? 'Pişti' : 'Batak'} seçildi — tekrar dokunarak başlat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selected == null ? Colors.white70 : AppColors.gold,
                    fontSize: 14,
                    fontWeight: _selected == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Pişti Kartı
                _DemoCard(
                  icon: Icons.style_rounded,
                  title: 'Pişti',
                  subtitle: '2 kişilik • Bot ile',
                  badge: '2K',
                  description: 'Masaya kart oynayarak pişti yap, en yüksek puanı topla!',
                  isSelected: _selected == 'pisti',
                  isDeselected: _selected != null && _selected != 'pisti',
                  onTap: () => _onCardTap('pisti'),
                ),

                const SizedBox(height: 20),

                // Batak Kartı
                _DemoCard(
                  icon: Icons.casino_rounded,
                  title: 'Batak',
                  subtitle: '4 kişilik • 3 Bot ile',
                  badge: '4K',
                  description: 'İhale ver, koz belirle, kontratını tamamla!',
                  isSelected: _selected == 'batak',
                  isDeselected: _selected != null && _selected != 'batak',
                  onTap: () => _onCardTap('batak'),
                ),

                const Spacer(),

                // Alt not
                Text(
                  'Demo modunda bot hamleleri otomatik yapılır',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String description;
  final bool isSelected;
  final bool isDeselected;
  final VoidCallback onTap;

  const _DemoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.description,
    required this.isSelected,
    required this.isDeselected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Seçili kart → turuncu/altın; seçilmemiş kart → nötr teal/yeşil
    final Color accent = isSelected
        ? AppColors.gold
        : const Color(0xFF80CBC4); // ikisi de aynı nötr renk başta

    final double borderWidth = isSelected ? 2.0 : 0.8;
    final double borderAlpha = isSelected ? 0.85 : 0.25;
    final double bgAlpha = isSelected ? 0.22 : 0.10;
    final double opacity = isDeselected ? 0.45 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: bgAlpha),
                Colors.black.withValues(alpha: 0.28),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: borderAlpha),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isSelected ? 0.25 : 0.06),
                blurRadius: isSelected ? 28 : 12,
                spreadRadius: isSelected ? 3 : 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // İkon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isSelected ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: isSelected ? 0.60 : 0.25),
                  ),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              // Metin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.gold, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.play_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: accent.withValues(alpha: isSelected ? 0.9 : 0.4),
                size: isSelected ? 24 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
