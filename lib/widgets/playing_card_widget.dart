import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/playing_card.dart';

// ─── Rank etiketleri ──────────────────────────────────────────────────────────
const _rankLabels = {
  Rank.two:   '2',  Rank.three: '3',  Rank.four:  '4',  Rank.five:  '5',
  Rank.six:   '6',  Rank.seven: '7',  Rank.eight: '8',  Rank.nine:  '9',
  Rank.ten:   '10', Rank.jack:  'J',  Rank.queen: 'Q',  Rank.king:  'K',
  Rank.ace:   'A',
};

Color _suitColor(Suit s) => (s == Suit.hearts || s == Suit.diamonds)
    ? const Color(0xFFC62828) // Premium Koyu Yakut Kırmızısı
    : const Color(0xFF000000); // Saf Gece Siyahı

const Color _goldColor = Color(0xFFD4AF37); // Venedik Altını

// ─── Kart Yüzü Widget ────────────────────────────────────────────────────────
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
    final color  = _suitColor(card.suit);
    final active = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: raised
            ? Matrix4.translationValues(0, -12, 0)
            : Matrix4.identity(),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7), // Fildişi/Krem Premium Kağıt Rengi
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _goldColor : Colors.grey.shade300,
            width: active ? 2.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? _goldColor.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: raised ? 16 : 6,
              offset: Offset(0, raised ? 8 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CustomPaint(
            size: Size(width, height),
            painter: _FacePainter(card: card, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Face Painter (Premium Detaylı Çizimler) ─────────────────────────────────
class _FacePainter extends CustomPainter {
  final PlayingCard card;
  final Color color;
  const _FacePainter({required this.card, required this.color});

  @override
  void paint(Canvas canvas, Size sz) {
    final label = _rankLabels[card.rank]!;

    // 1. Premium Altın Çerçeve Çizimi
    final framePaint = Paint()
      ..color = _goldColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3.5, 3.5, sz.width - 7, sz.height - 7),
        const Radius.circular(5.5),
      ),
      framePaint,
    );

    // 2. Sol Üst Köşe İndeksi
    _corner(canvas, sz, label);

    // 3. Sağ Alt Köşe İndeksi (180° Ters)
    canvas.save();
    canvas.translate(sz.width, sz.height);
    canvas.rotate(math.pi);
    _corner(canvas, sz, label);
    canvas.restore();

    // 4. Merkez Sanatı
    switch (card.rank) {
      case Rank.ace:   _centerAce(canvas, sz);           break;
      case Rank.king:  _centerFigure(canvas, sz, 'K');   break;
      case Rank.queen: _centerFigure(canvas, sz, 'Q');   break;
      case Rank.jack:  _centerFigure(canvas, sz, 'J');   break;
      default:         _pips(canvas, sz, card.rank);     break;
    }
  }

  // ── Köşe Tasarımı ──────────────────────────────────────────────────────────
  void _corner(Canvas canvas, Size sz, String label) {
    const lx = 5.0, ly = 4.0;
    final rankFs = (sz.width * 0.22).clamp(11.0, 18.0);
    final suitSz = (sz.width * 0.17).clamp(8.0, 14.0);

    final rankTp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: rankFs,
          fontWeight: FontWeight.w900,
          color: color,
          fontFamily: 'serif',
          letterSpacing: -0.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rankTp.paint(canvas, const Offset(lx, ly));

    _suit(canvas,
        Offset(lx + rankTp.width / 2, ly + rankTp.height + suitSz * 0.65),
        suitSz,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  // ── Premium Ornate As Tasarımı ─────────────────────────────────────────────
  void _centerAce(Canvas canvas, Size sz) {
    final c = Offset(sz.width / 2, sz.height / 2);
    final r = sz.width * 0.26;

    // Altın Mandala / Güneş Işınları
    final sunPaint = Paint()
      ..color = _goldColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    // Işınlar
    for (int i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final start = Offset(c.dx + r * 0.55 * math.cos(angle), c.dy + r * 0.55 * math.sin(angle));
      final end   = Offset(c.dx + r * 0.95 * math.cos(angle), c.dy + r * 0.95 * math.sin(angle));
      canvas.drawLine(start, end, sunPaint);
    }

    // İnce dekoratif altın halka
    canvas.drawCircle(c, r * 0.95, sunPaint);
    canvas.drawCircle(c, r * 0.55, sunPaint);

    // Merkezdeki Dev Premium Simgesi
    _suit(canvas, c, sz.width * 0.50,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  // ── Saray Kartları Tasarımı (Kral, Kraliçe, Vale) ───────────────────────────
  void _centerFigure(Canvas canvas, Size sz, String letter) {
    final c   = Offset(sz.width / 2, sz.height / 2);
    final r   = sz.width * 0.28;

    // Altın Dekoratif Çerçeve
    final borderPaint = Paint()
      ..color = _goldColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawCircle(c, r, borderPaint);
    canvas.drawCircle(c, r - 3,
        Paint()
          ..color = _goldColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);

    // Arka Plan Hafif Simge
    _suit(canvas, c, r * 0.9,
        Paint()..color = color.withValues(alpha: 0.05)..style = PaintingStyle.fill);

    // Kraliyet Simgeleri Çizimi (Taç, Tiara, Kalkan)
    final figPaint = Paint()
      ..color = _goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final fillPaint = Paint()
      ..color = _goldColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    if (letter == 'K') {
      // Kral Tacı
      final crown = Path()
        ..moveTo(c.dx - r * 0.5, c.dy + r * 0.3)
        ..lineTo(c.dx + r * 0.5, c.dy + r * 0.3)
        ..lineTo(c.dx + r * 0.45, c.dy - r * 0.1)
        ..lineTo(c.dx + r * 0.22, c.dy + r * 0.1)
        ..lineTo(c.dx, c.dy - r * 0.35)
        ..lineTo(c.dx - r * 0.22, c.dy + r * 0.1)
        ..lineTo(c.dx - r * 0.45, c.dy - r * 0.1)
        ..close();
      canvas.drawPath(crown, fillPaint);
      canvas.drawPath(crown, figPaint);

      // Taç Tepe Yuvarlakları
      canvas.drawCircle(Offset(c.dx - r * 0.45, c.dy - r * 0.1), 2.5, Paint()..color = _goldColor);
      canvas.drawCircle(Offset(c.dx, c.dy - r * 0.35), 3, Paint()..color = _goldColor);
      canvas.drawCircle(Offset(c.dx + r * 0.45, c.dy - r * 0.1), 2.5, Paint()..color = _goldColor);
    } else if (letter == 'Q') {
      // Kraliçe Tacı (Tiara)
      final tiara = Path()
        ..moveTo(c.dx - r * 0.45, c.dy + r * 0.3)
        ..lineTo(c.dx + r * 0.45, c.dy + r * 0.3)
        ..lineTo(c.dx + r * 0.32, c.dy - r * 0.05)
        ..quadraticBezierTo(c.dx, c.dy + r * 0.15, c.dx - r * 0.32, c.dy - r * 0.05)
        ..close();
      canvas.drawPath(tiara, fillPaint);
      canvas.drawPath(tiara, figPaint);
      
      // Merkez Mücevher
      canvas.drawCircle(Offset(c.dx, c.dy + r * 0.02), 3, Paint()..color = color);
    } else {
      // Vale Kalkanı
      final shield = Path()
        ..moveTo(c.dx - r * 0.38, c.dy - r * 0.25)
        ..lineTo(c.dx + r * 0.38, c.dy - r * 0.25)
        ..lineTo(c.dx + r * 0.38, c.dy + r * 0.15)
        ..quadraticBezierTo(c.dx + r * 0.38, c.dy + r * 0.45, c.dx, c.dy + r * 0.58)
        ..quadraticBezierTo(c.dx - r * 0.38, c.dy + r * 0.45, c.dx - r * 0.38, c.dy + r * 0.15)
        ..close();
      canvas.drawPath(shield, fillPaint);
      canvas.drawPath(shield, figPaint);
      
      // Kalkan İçi Haç Çizgisi
      canvas.drawLine(Offset(c.dx, c.dy - r * 0.25), Offset(c.dx, c.dy + r * 0.58), borderPaint);
    }

    // Küçük asil harf etiketi
    final letterTp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: sz.width * 0.20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letterTp.paint(canvas, Offset(c.dx - letterTp.width / 2, c.dy + r * 0.42));
  }

  // ── Pip Düzeni ─────────────────────────────────────────────────────────────
  void _pips(Canvas canvas, Size sz, Rank rank) {
    final ps   = (sz.width * 0.23).clamp(10.0, 18.0);
    final fp   = Paint()..color = color..style = PaintingStyle.fill;

    for (final pos in _positions(rank, sz)) {
      final flip = pos.dy > sz.height * 0.501;
      if (flip) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(math.pi);
        _suit(canvas, Offset.zero, ps, fp);
        canvas.restore();
      } else {
        _suit(canvas, pos, ps, fp);
      }
    }
  }

  List<Offset> _positions(Rank r, Size s) {
    final cx = s.width  * 0.50;
    final l  = s.width  * 0.28;
    final ri = s.width  * 0.72;
    final t  = s.height * 0.20;
    final tm = s.height * 0.35;
    final m  = s.height * 0.50;
    final bm = s.height * 0.65;
    final b  = s.height * 0.80;

    switch (r) {
      case Rank.two:   return [Offset(cx,t), Offset(cx,b)];
      case Rank.three: return [Offset(cx,t), Offset(cx,m), Offset(cx,b)];
      case Rank.four:  return [Offset(l,t), Offset(ri,t), Offset(l,b), Offset(ri,b)];
      case Rank.five:  return [Offset(l,t), Offset(ri,t), Offset(cx,m), Offset(l,b), Offset(ri,b)];
      case Rank.six:   return [Offset(l,t), Offset(ri,t), Offset(l,m), Offset(ri,m), Offset(l,b), Offset(ri,b)];
      case Rank.seven: return [Offset(l,t), Offset(ri,t), Offset(cx,tm), Offset(l,m), Offset(ri,m), Offset(l,b), Offset(ri,b)];
      case Rank.eight: return [Offset(l,t), Offset(ri,t), Offset(cx,tm), Offset(l,m), Offset(ri,m), Offset(cx,bm), Offset(l,b), Offset(ri,b)];
      case Rank.nine:  return [Offset(l,t), Offset(ri,t), Offset(l,tm), Offset(ri,tm), Offset(cx,m), Offset(l,bm), Offset(ri,bm), Offset(l,b), Offset(ri,b)];
      case Rank.ten:   return [Offset(l,t), Offset(ri,t), Offset(cx,s.height*0.275), Offset(l,tm), Offset(ri,tm), Offset(l,bm), Offset(ri,bm), Offset(cx,s.height*0.725), Offset(l,b), Offset(ri,b)];
      default: return [];
    }
  }

  // ── Suit path'ları (Pürüzsüz Bezier Eğrileri) ───────────────────────────────
  void _suit(Canvas canvas, Offset c, double s, Paint p) {
    switch (card.suit) {
      case Suit.hearts:   _heart(canvas, c, s, p);   break;
      case Suit.diamonds: _diamond(canvas, c, s, p); break;
      case Suit.spades:   _spade(canvas, c, s, p);   break;
      case Suit.clubs:    _club(canvas, c, s, p);    break;
    }
  }

  /// Pürüzsüz Cubic Bezier Kupa Tasarımı
  void _heart(Canvas canvas, Offset c, double s, Paint p) {
    final path = Path();
    path.moveTo(c.dx, c.dy + s * 0.45);
    path.cubicTo(c.dx - s * 0.65, c.dy - s * 0.12, c.dx - s * 0.52, c.dy - s * 0.60, c.dx, c.dy - s * 0.28);
    path.cubicTo(c.dx + s * 0.52, c.dy - s * 0.60, c.dx + s * 0.65, c.dy - s * 0.12, c.dx, c.dy + s * 0.45);
    path.close();
    canvas.drawPath(path, p);
  }

  /// Kusursuz Karo Tasarımı
  void _diamond(Canvas canvas, Offset c, double s, Paint p) {
    final rw = s * 0.48, rh = s * 0.62;
    final path = Path()
      ..moveTo(c.dx,      c.dy - rh)
      ..lineTo(c.dx + rw, c.dy)
      ..lineTo(c.dx,      c.dy + rh)
      ..lineTo(c.dx - rw, c.dy)
      ..close();
    canvas.drawPath(path, p);
  }

  /// Pürüzsüz Maça Tasarımı + Klasik Alt Ayak
  void _spade(Canvas canvas, Offset c, double s, Paint p) {
    final r = s * 0.49;
    // Bolder, fuller Spade leaf (Ters Kalp benzeri ama ucu sivri)
    final path = Path();
    path.moveTo(c.dx, c.dy - r * 0.95);
    path.cubicTo(c.dx + r * 1.15, c.dy - r * 0.85, 
                 c.dx + r * 1.15, c.dy + r * 0.45, 
                 c.dx,            c.dy + r * 0.25);
    path.cubicTo(c.dx - r * 1.15, c.dy + r * 0.45, 
                 c.dx - r * 1.15, c.dy - r * 0.85, 
                 c.dx,            c.dy - r * 0.95);
    path.close();
    canvas.drawPath(path, p);

    // Ayak (Sap) - Bolder and stylized triangle-like pedestal
    final sw = s * 0.18;
    final stemPath = Path()
      ..moveTo(c.dx, c.dy + r * 0.15)
      ..quadraticBezierTo(c.dx, c.dy + r * 0.95, c.dx - sw * 1.25, c.dy + r * 0.95)
      ..lineTo(c.dx + sw * 1.25, c.dy + r * 0.95)
      ..quadraticBezierTo(c.dx, c.dy + r * 0.95, c.dx, c.dy + r * 0.15)
      ..close();
    canvas.drawPath(stemPath, p);
  }

  /// Asil Sinek Tasarımı (3 Yaprak + Taban)
  void _club(Canvas canvas, Offset c, double s, Paint p) {
    final r = s * 0.32; // Slightly larger circles
    // 3 Yonca Yaprağı (Bolder overlapping)
    canvas.drawCircle(Offset(c.dx,          c.dy - r * 0.58), r, p);
    canvas.drawCircle(Offset(c.dx - r * 0.85, c.dy + r * 0.25), r, p);
    canvas.drawCircle(Offset(c.dx + r * 0.85, c.dy + r * 0.25), r, p);
    
    // Pedestal stem (Zarif üçgen taban)
    final sw = s * 0.18;
    final stemPath = Path()
      ..moveTo(c.dx, c.dy + r * 0.1)
      ..quadraticBezierTo(c.dx, c.dy + r * 1.45, c.dx - sw * 1.25, c.dy + r * 1.45)
      ..lineTo(c.dx + sw * 1.25, c.dy + r * 1.45)
      ..quadraticBezierTo(c.dx, c.dy + r * 1.45, c.dx, c.dy + r * 0.1)
      ..close();
    canvas.drawPath(stemPath, p);
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.card != card || old.color != color;
}

// ─── Kart Arkası (Premium Casino Tasarımı) ───────────────────────────────────
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027), // Derin Safir/Gece Mavisi
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
        border: Border.all(
          color: _goldColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(painter: _BackPainter()),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    // 1. Çift Altın Çerçeve
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3.5, 3.5, sz.width - 7, sz.height - 7),
        const Radius.circular(4.5),
      ),
      Paint()
        ..color = _goldColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6.0, 6.0, sz.width - 12, sz.height - 12),
        const Radius.circular(3.5),
      ),
      Paint()
        ..color = _goldColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // 2. Lüks Çapraz Kafes Deseni
    final lp = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (double i = -sz.height; i < sz.width + sz.height; i += 7.0) {
      canvas.drawLine(Offset(i, 0), Offset(i + sz.height, sz.height), lp);
      canvas.drawLine(Offset(sz.width - i, 0), Offset(-i, sz.height), lp);
    }

    // 3. Merkezde Büyük Muazzam Altın Yıldız / Mandala
    final cx = sz.width / 2, cy = sz.height / 2;
    final r  = sz.width * 0.23;

    final goldPaint = Paint()..color = _goldColor..style = PaintingStyle.stroke..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), r, goldPaint..color = _goldColor.withValues(alpha: 0.35));
    canvas.drawCircle(Offset(cx, cy), r * 0.6, goldPaint..color = _goldColor.withValues(alpha: 0.2));

    // 8 Kollu Asil Yıldız
    final starPaint = Paint()..color = _goldColor.withValues(alpha: 0.75)..style = PaintingStyle.fill;
    final star = Path();
    for (int i = 0; i < 8; i++) {
      final a  = i * math.pi / 4 - math.pi / 2;
      final ma = a + math.pi / 8;
      final ox = cx + r * 0.85 * math.cos(a);
      final oy = cy + r * 0.85 * math.sin(a);
      final ix = cx + r * 0.38 * math.cos(ma);
      final iy = cy + r * 0.38 * math.sin(ma);
      if (i == 0) { star.moveTo(ox, oy); } else { star.lineTo(ox, oy); }
      star.lineTo(ix, iy);
    }
    star.close();
    canvas.drawPath(star, starPaint);

    // Merkezdeki Parlak Küre
    canvas.drawCircle(Offset(cx, cy), r * 0.16, Paint()..color = _goldColor);
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => false;
}