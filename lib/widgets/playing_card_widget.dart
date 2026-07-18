import 'package:flutter/material.dart';
import '../models/playing_card.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool raised;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.onTap,
    this.width = 56,
    this.height = 80,
    this.raised = false,
  });

  // Asset dosyalarında clubs/spades isimleri takas edilmiş olduğundan
  // doğru görseli getirmek için suit adını düzeltiyoruz.
  String get _fixedSuitName {
    switch (card.suit) {
      case Suit.clubs:  return 'spades'; // clubs dosyası aslında maça içeriyor
      case Suit.spades: return 'clubs';  // spades dosyası aslında sinek içeriyor
      default:          return card.suit.name;
    }
  }

  // ✅ WebP asset yolu
  String get _assetPath => 'assets/cards/${_fixedSuitName}_${card.rank.name}.webp';


  @override
  Widget build(BuildContext context) {
    final isPlayable = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: raised
            ? (Matrix4.identity()..translate(0.0, -8.0, 0.0))
            : Matrix4.identity(),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPlayable ? const Color(0xFFFFA000) : Colors.black12,
            width: isPlayable ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlayable
                  ? const Color(0xFFFFB300).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: raised ? 10 : 3,
              spreadRadius: isPlayable ? 1 : 0,
              offset: Offset(0, raised ? 6 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset(
            _assetPath,
            fit: BoxFit.cover,
            cacheWidth: (width * 2).round(),   // bellek optimizasyonu
            cacheHeight: (height * 2).round(),
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Text(
                  '${card.rank.name}\n${card.suit.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8, color: Colors.red),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;

  const CardBackWidget({
    super.key,
    this.width = 56,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          'assets/cards/card_back.webp',   // ✅ WebP kart arkası
          fit: BoxFit.cover,
          cacheWidth: (width * 2).round(),
          cacheHeight: (height * 2).round(),
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B3A4B), Color(0xFF0F1E29)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}