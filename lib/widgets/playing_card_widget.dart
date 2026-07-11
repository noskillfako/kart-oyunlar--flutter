import 'package:flutter/material.dart';
import '../models/playing_card.dart';

const _rankLabels = {
  Rank.two: '2', Rank.three: '3', Rank.four: '4', Rank.five: '5',
  Rank.six: '6', Rank.seven: '7', Rank.eight: '8', Rank.nine: '9',
  Rank.ten: '10', Rank.jack: 'V', Rank.queen: 'K', Rank.king: 'Ş', Rank.ace: 'A',
};

const _suitSymbols = {
  Suit.spades: '♠', Suit.hearts: '♥', Suit.diamonds: '♦', Suit.clubs: '♣',
};

Color _suitColor(Suit suit) {
  return (suit == Suit.hearts || suit == Suit.diamonds)
      ? const Color(0xFFD32F2F) // Canlı Kırmızı
      : const Color(0xFF1E1E1E); // Koyu Siyah
}

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
          color: const Color(0xFFFAFAFA),
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
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: _CardFacePainter(card: card),
            child: Container(),
          ),
        ),
      ),
    );
  }
}

class _CardFacePainter extends CustomPainter {
  final PlayingCard card;

  _CardFacePainter({required this.card});

  @override
  void paint(Canvas canvas, Size size) {
    final color = _suitColor(card.suit);
    final rankLabel = _rankLabels[card.rank]!;
    final suitSymbol = _suitSymbols[card.suit]!;

    // İç casino çerçevesi
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Radius.circular(5),
      ),
      borderPaint,
    );

    // Sol Üst Semboller
    _paintCornerIndex(canvas, size, rankLabel, suitSymbol, color);

    // Sağ Alt Semboller (Ters döndürülmüş)
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(3.14159);
    _paintCornerIndex(canvas, size, rankLabel, suitSymbol, color);
    canvas.restore();

    // Merkezdeki Görsel
    final center = Offset(size.width / 2, size.height / 2);

    if (card.rank == Rank.jack || card.rank == Rank.queen || card.rank == Rank.king) {
      // Resimli kartlar için orta çerçeve
      final frameRect = Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.22,
        size.width * 0.56,
        size.height * 0.56,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: 0.04),
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(4)),
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      final emblemSize = size.width * 0.22;
      final emblemPaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      if (card.rank == Rank.king) {
        // Şah (Ş) için Taç
        final crownPath = Path()
          ..moveTo(center.dx - emblemSize / 2, center.dy + emblemSize / 3)
          ..lineTo(center.dx + emblemSize / 2, center.dy + emblemSize / 3)
          ..lineTo(center.dx + emblemSize * 0.35, center.dy - emblemSize / 4)
          ..lineTo(center.dx + emblemSize * 0.15, center.dy)
          ..lineTo(center.dx, center.dy - emblemSize / 3)
          ..lineTo(center.dx - emblemSize * 0.15, center.dy)
          ..lineTo(center.dx - emblemSize * 0.35, center.dy - emblemSize / 4)
          ..close();
        canvas.drawPath(crownPath, emblemPaint);
      } else if (card.rank == Rank.queen) {
        // Kız (K) için Taç
        final tiaraPath = Path()
          ..moveTo(center.dx - emblemSize / 2, center.dy + emblemSize / 3)
          ..quadraticBezierTo(center.dx, center.dy + emblemSize / 5, center.dx + emblemSize / 2, center.dy + emblemSize / 3)
          ..lineTo(center.dx + emblemSize * 0.3, center.dy - emblemSize / 4)
          ..lineTo(center.dx, center.dy - emblemSize / 8)
          ..lineTo(center.dx - emblemSize * 0.3, center.dy - emblemSize / 4)
          ..close();
        canvas.drawPath(tiaraPath, emblemPaint);
      } else {
        // Vale (V) için Kalkan
        final shieldPath = Path()
          ..moveTo(center.dx - emblemSize / 2.5, center.dy - emblemSize / 3)
          ..lineTo(center.dx + emblemSize / 2.5, center.dy - emblemSize / 3)
          ..lineTo(center.dx + emblemSize / 2.5, center.dy)
          ..quadraticBezierTo(center.dx + emblemSize / 2.5, center.dy + emblemSize / 2.2, center.dx, center.dy + emblemSize / 1.8)
          ..quadraticBezierTo(center.dx - emblemSize / 2.5, center.dy + emblemSize / 2.2, center.dx - emblemSize / 2.5, center.dy)
          ..close();
        canvas.drawPath(shieldPath, emblemPaint);
      }

      // Çerçevenin altındaki küçük simge
      final miniSuitPainter = TextPainter(
        text: TextSpan(
          text: suitSymbol,
          style: TextStyle(
            fontSize: size.width * 0.13,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      miniSuitPainter.paint(
        canvas,
        Offset(
          center.dx - miniSuitPainter.width / 2,
          center.dy + emblemSize * 0.38 - miniSuitPainter.height / 2,
        ),
      );
    } else {
      // Sayılar ve As (A) tasarımı
      if (card.rank == Rank.ace) {
        // As arka plan süs halkası
        canvas.drawCircle(
          center,
          size.width * 0.26,
          Paint()
            ..color = color.withValues(alpha: 0.04)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          size.width * 0.26,
          Paint()
            ..color = color.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }

      // Büyük merkez simgesi
      final centerPainter = TextPainter(
        text: TextSpan(
          text: suitSymbol,
          style: TextStyle(
            fontSize: card.rank == Rank.ace ? size.width * 0.44 : size.width * 0.38,
            color: color.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      centerPainter.paint(
        canvas,
        Offset(
          (size.width - centerPainter.width) / 2,
          (size.height - centerPainter.height) / 2,
        ),
      );
    }
  }

  void _paintCornerIndex(
    Canvas canvas,
    Size size,
    String rankLabel,
    String suitSymbol,
    Color color,
  ) {
    final rankPainter = TextPainter(
      text: TextSpan(
        text: rankLabel,
        style: TextStyle(
          fontSize: size.width * 0.17,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final suitPainter = TextPainter(
      text: TextSpan(
        text: suitSymbol,
        style: TextStyle(
          fontSize: size.width * 0.13,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const marginX = 6.0;
    const marginY = 6.0;
    rankPainter.paint(canvas, const Offset(marginX, marginY));
    suitPainter.paint(canvas, Offset(marginX + (rankPainter.width - suitPainter.width) / 2, marginY + rankPainter.height + 1.0));
  }

  @override
  bool shouldRepaint(covariant _CardFacePainter oldDelegate) {
    return oldDelegate.card != card;
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
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3A4B), // Kraliyet Laciverti
            Color(0xFF0F1E29), // Gece Mavisi
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _CardBackPatternPainter(),
        ),
      ),
    );
  }
}

class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Altın iç çizgi
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
        const Radius.circular(5),
      ),
      goldPaint,
    );

    // Çapraz baklava deseni
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 7.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), patternPaint);
      canvas.drawLine(Offset(size.width - i, 0), Offset(size.width, i), patternPaint);
    }

    // Ortadaki altın arma
    final center = Offset(size.width / 2, size.height / 2);
    final emblemSize = size.width * 0.15;
    
    final emblemPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - emblemSize)
      ..lineTo(center.dx + emblemSize * 0.8, center.dy)
      ..lineTo(center.dx, center.dy + emblemSize)
      ..lineTo(center.dx - emblemSize * 0.8, center.dy)
      ..close();
    canvas.drawPath(path, emblemPaint);

    // Arma içi detaylar
    canvas.drawCircle(
      center,
      emblemSize * 0.4,
      Paint()..color = const Color(0xFF1B3A4B),
    );
    canvas.drawCircle(
      center,
      emblemSize * 0.2,
      Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) => false;
}