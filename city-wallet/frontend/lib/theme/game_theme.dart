import 'package:flutter/material.dart';

class GameTheme {
  static const ink = Color(0xFF352415);
  static const bark = Color(0xFF6E4A2C);
  static const soil = Color(0xFF8A5A32);
  static const cream = Color(0xFFFFF2D2);
  static const parchment = Color(0xFFFFE7AF);
  static const wheat = Color(0xFFF8C96B);
  static const carrot = Color(0xFFE97132);
  static const berry = Color(0xFFC84A3D);
  static const grass = Color(0xFF4F9A5A);
  static const mint = Color(0xFFA9D77D);
  static const sky = Color(0xFF7DB9A7);
  static const water = Color(0xFF4B86A6);
  static const night = Color(0xFF263B35);

  static const double radius = 6;

  static BoxDecoration panel({
    Color color = cream,
    Color border = bark,
    Color shadow = soil,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0xFF8A5A32),
          blurRadius: 0,
          offset: Offset(4, 4),
        ),
      ],
    );
  }

  static BoxDecoration inset({
    Color color = parchment,
    Color border = soil,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 2),
    );
  }

  static TextStyle get title => const TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      );

  static TextStyle get label => const TextStyle(
        color: bark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      );
}

class PixelMotif extends StatelessWidget {
  final Color color;
  final double size;

  const PixelMotif({
    super.key,
    this.color = GameTheme.mint,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 3,
      height: size * 3,
      child: Stack(
        children: [
          _pixel(size, size, size),
          _pixel(0, size, size),
          _pixel(size, 0, size),
          _pixel(size * 2, size, size),
          _pixel(size, size * 2, size),
        ],
      ),
    );
  }

  Positioned _pixel(double left, double top, double side) {
    return Positioned(
      left: left,
      top: top,
      child: Container(width: side, height: side, color: color),
    );
  }
}
