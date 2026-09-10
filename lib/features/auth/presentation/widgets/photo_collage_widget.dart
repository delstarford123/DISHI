import 'package:flutter/material.dart';

class _CollageCard {
  final String imagePath;
  final String semanticLabel;
  final double top;
  final double left;
  final double width;
  final double height;
  final double rotation;

  const _CollageCard({
    required this.imagePath,
    required this.semanticLabel,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    required this.rotation,
  });
}

class PhotoCollageWidget extends StatefulWidget {
  final bool isTablet;

  const PhotoCollageWidget({super.key, this.isTablet = false});

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _cardAnimations = [];

  static const List<_CollageCard> _cards = [
    _CollageCard(
      imagePath: 'assets/img/collage_1.jpg',
      semanticLabel: 'African college student smiling on campus',
      top: 20,
      left: -10,
      width: 160,
      height: 200,
      rotation: -0.12,
    ),
    _CollageCard(
      imagePath: 'assets/img/collage_2.jpg',
      semanticLabel: 'Professional portrait of a young African man outdoors',
      top: 0,
      left: 120,
      width: 140,
      height: 170,
      rotation: 0.08,
    ),
    _CollageCard(
      imagePath: 'assets/img/collage_3.jpg',
      semanticLabel: 'Smiling young African woman in bright sunlight',
      top: 60,
      left: 220,
      width: 150,
      height: 190,
      rotation: 0.15,
    ),
    _CollageCard(
      imagePath: 'assets/img/collage_4.jpg',
      semanticLabel: 'Group of African friends laughing together',
      top: 170,
      left: -20,
      width: 170,
      height: 160,
      rotation: 0.06,
    ),
    _CollageCard(
      imagePath: 'assets/img/collage_5.jpg',
      semanticLabel: 'African woman taking a photo at sunset',
      top: 180,
      left: 160,
      width: 145,
      height: 175,
      rotation: -0.09,
    ),
    _CollageCard(
      imagePath: 'assets/img/collage_6.jpg',
      semanticLabel: 'Two African friends sharing a joyful moment',
      top: 330,
      left: 60,
      width: 155,
      height: 150,
      rotation: 0.11,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    for (int i = 0; i < _cards.length; i++) {
      final start = (i * 0.12).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      _cardAnimations.add(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final collageHeight = widget.isTablet ? screenHeight : screenHeight * 0.62;

    return SizedBox(
      height: collageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(_cards.length, (i) {
          final card = _cards[i];
          return Positioned(
            top: card.top,
            left: card.left,
            child: AnimatedBuilder(
              animation: _cardAnimations[i],
              builder: (context, child) {
                return Transform.scale(
                  scale: _cardAnimations[i].value,
                  child: Opacity(
                    opacity: _cardAnimations[i].value,
                    child: child,
                  ),
                );
              },
              child: Transform.rotate(
                angle: card.rotation,
                child: Container(
                  width: card.width,
                  height: card.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      card.imagePath,
                      width: card.width,
                      height: card.height,
                      fit: BoxFit.cover,
                      semanticLabel: card.semanticLabel,
                      errorBuilder: (context, error, stackTrace) => 
                        Container(color: Colors.grey.shade300, child: const Icon(Icons.image)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
