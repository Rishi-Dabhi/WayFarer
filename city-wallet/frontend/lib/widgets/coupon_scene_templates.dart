import 'package:flutter/material.dart';
import '../models/coupon.dart';
import '../theme/game_theme.dart';

class CouponPixelScene extends StatelessWidget {
  final Coupon coupon;
  final double height;

  const CouponPixelScene({
    super.key,
    required this.coupon,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    final template = CouponSceneTemplate.fromCoupon(coupon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(GameTheme.radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _PixelScenePainter(template),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GameTheme.cream,
                  border: Border.all(color: GameTheme.bark, width: 2),
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                ),
                child: Text(
                  template.label,
                  style: const TextStyle(
                    color: GameTheme.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CouponSceneTemplate {
  final String weather;
  final String period;
  final String busyness;
  final String label;

  const CouponSceneTemplate({
    required this.weather,
    required this.period,
    required this.busyness,
    required this.label,
  });

  factory CouponSceneTemplate.fromCoupon(Coupon coupon) {
    final context = coupon.contextSnapshot;
    final weather = (context['weather'] as Map?) ?? const {};
    final time = (context['time'] as Map?) ?? const {};
    final busynessRaw = context['busyness'];
    final busyness = busynessRaw is Map ? busynessRaw : const {};
    final condition = (weather['condition'] ?? '').toString().toLowerCase();
    final period = (time['period'] ?? '').toString().toLowerCase();
    final busy = (busyness['level'] ?? (busynessRaw is String ? busynessRaw : '')).toString().toLowerCase();

    final weatherKey = condition.contains('rain') || condition.contains('drizzle')
        ? 'rain'
        : condition.contains('snow')
            ? 'snow'
            : condition.contains('cloud')
                ? 'cloud'
                : condition.contains('clear') || condition.contains('sun')
                    ? 'sun'
                    : 'mild';
    final periodKey = period.isEmpty ? 'now' : period;
    final busyKey = busy.isEmpty ? 'normal' : busy;
    final label = '${weatherKey.toUpperCase()} / ${periodKey.toUpperCase()} / ${busyKey.toUpperCase()}';

    return CouponSceneTemplate(
      weather: weatherKey,
      period: periodKey,
      busyness: busyKey,
      label: label,
    );
  }
}

class _PixelScenePainter extends CustomPainter {
  final CouponSceneTemplate template;

  const _PixelScenePainter(this.template);

  @override
  void paint(Canvas canvas, Size size) {
    const pixel = 6.0;
    final skyTop = _skyColor(template.period, template.weather);
    final skyBottom = template.period == 'night' ? GameTheme.night : const Color(0xFFAED7B2);
    final paint = Paint();

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [skyTop, skyBottom],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    _drawSky(canvas, paint, size, pixel);
    _drawHills(canvas, paint, size, pixel);
    _drawShop(canvas, paint, size, pixel);
    _drawPath(canvas, paint, size, pixel);
    _drawCrowd(canvas, paint, size, pixel);
    _drawWeather(canvas, paint, size, pixel);
  }

  Color _skyColor(String period, String weather) {
    if (period == 'night') return const Color(0xFF23314E);
    if (period == 'evening') return const Color(0xFFE09A6D);
    if (weather == 'rain' || weather == 'cloud') return const Color(0xFF8FB0AD);
    return const Color(0xFF91C7D9);
  }

  void _drawSky(Canvas canvas, Paint paint, Size size, double pixel) {
    if (template.period == 'night') {
      paint.color = GameTheme.wheat;
      for (final point in [const Offset(28, 18), const Offset(82, 14), const Offset(150, 24), const Offset(220, 12)]) {
        canvas.drawRect(Rect.fromLTWH(point.dx, point.dy, pixel, pixel), paint);
      }
      return;
    }

    paint.color = template.weather == 'cloud' || template.weather == 'rain' ? GameTheme.cream : GameTheme.wheat;
    final y = template.weather == 'cloud' || template.weather == 'rain' ? 18.0 : 14.0;
    _rect(canvas, paint, 24, y, 4, 2, pixel);
    _rect(canvas, paint, 36, y - 6, 4, 3, pixel);
    _rect(canvas, paint, 48, y, 5, 2, pixel);
  }

  void _drawHills(Canvas canvas, Paint paint, Size size, double pixel) {
    paint.color = GameTheme.grass;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 28, size.width, 28), paint);
    paint.color = GameTheme.mint;
    for (double x = 0; x < size.width; x += pixel * 4) {
      canvas.drawRect(Rect.fromLTWH(x, size.height - 34, pixel * 2, pixel), paint);
    }
  }

  void _drawShop(Canvas canvas, Paint paint, Size size, double pixel) {
    final x = size.width * 0.58;
    final y = size.height - 58;
    paint.color = GameTheme.soil;
    _rect(canvas, paint, x - 6, y + 8, 13, 7, pixel);
    paint.color = GameTheme.berry;
    _rect(canvas, paint, x - 12, y, 15, 2, pixel);
    paint.color = GameTheme.cream;
    _rect(canvas, paint, x + 10, y + 22, 3, 5, pixel);
    paint.color = GameTheme.water;
    _rect(canvas, paint, x - 2, y + 22, 3, 3, pixel);
    paint.color = GameTheme.wheat;
    _rect(canvas, paint, x - 10, y + 12, 15, 1, pixel);
  }

  void _drawPath(Canvas canvas, Paint paint, Size size, double pixel) {
    paint.color = GameTheme.wheat;
    final path = Path()
      ..moveTo(size.width * 0.50, size.height)
      ..lineTo(size.width * 0.62, size.height - 28)
      ..lineTo(size.width * 0.78, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawCrowd(Canvas canvas, Paint paint, Size size, double pixel) {
    final count = template.busyness == 'busy'
        ? 5
        : template.busyness == 'quiet'
            ? 1
            : 3;
    for (var i = 0; i < count; i++) {
      final x = 22.0 + i * 18;
      final y = size.height - 30 - (i.isEven ? 0 : 6);
      paint.color = i.isEven ? GameTheme.carrot : GameTheme.water;
      _rect(canvas, paint, x, y, 1, 2, pixel);
      paint.color = GameTheme.ink;
      canvas.drawRect(Rect.fromLTWH(x, y - pixel, pixel, pixel), paint);
    }
  }

  void _drawWeather(Canvas canvas, Paint paint, Size size, double pixel) {
    if (template.weather == 'rain') {
      paint.color = GameTheme.water;
      for (double x = 12; x < size.width; x += 28) {
        canvas.drawRect(Rect.fromLTWH(x, 42, pixel, pixel * 2), paint);
      }
    } else if (template.weather == 'snow') {
      paint.color = Colors.white;
      for (double x = 16; x < size.width; x += 30) {
        canvas.drawRect(Rect.fromLTWH(x, 38, pixel, pixel), paint);
      }
    }
  }

  void _rect(Canvas canvas, Paint paint, double x, double y, int w, int h, double pixel) {
    canvas.drawRect(Rect.fromLTWH(x, y, w * pixel, h * pixel), paint);
  }

  @override
  bool shouldRepaint(covariant _PixelScenePainter oldDelegate) {
    return oldDelegate.template != template;
  }
}
