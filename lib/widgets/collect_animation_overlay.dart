import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import 'playing_card_widget.dart';

/// Bir elin toplandığı anda, kartların kazananın yönüne doğru
/// küçülüp kayarak kaybolmasını sağlayan overlay.
class CollectAnimationOverlay extends StatefulWidget {
  final List<PlayingCard> cards;
  final Alignment targetAlignment;
  final VoidCallback onCompleted;

  const CollectAnimationOverlay({
    super.key,
    required this.cards,
    required this.targetAlignment,
    required this.onCompleted,
  });

  @override
  State<CollectAnimationOverlay> createState() => _CollectAnimationOverlayState();
}

class _CollectAnimationOverlayState extends State<CollectAnimationOverlay> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < widget.cards.length; i++)
            _FlyingCard(
              key: ValueKey('${widget.cards[i].id}_fly_$i'),
              card: widget.cards[i],
              index: i,
              targetAlignment: widget.targetAlignment,
              isLast: i == widget.cards.length - 1,
              onCompleted: i == widget.cards.length - 1 ? widget.onCompleted : null,
            ),
        ],
      ),
    );
  }
}

class _FlyingCard extends StatefulWidget {
  final PlayingCard card;
  final int index;
  final Alignment targetAlignment;
  final bool isLast;
  final VoidCallback? onCompleted;

  const _FlyingCard({
    super.key,
    required this.card,
    required this.index,
    required this.targetAlignment,
    required this.isLast,
    this.onCompleted,
  });

  @override
  State<_FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<_FlyingCard> {
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    // Kartlar hafif gecikmeli sırayla uçsun (arka arkaya toplanma hissi)
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) setState(() => _flying = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInCubic,
      alignment: _flying ? widget.targetAlignment : Alignment.center,
      onEnd: widget.onCompleted,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInCubic,
        scale: _flying ? 0.25 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeIn,
          opacity: _flying ? 0.0 : 1.0,
          child: PlayingCardWidget(card: widget.card, width: 54, height: 76),
        ),
      ),
    );
  }
}