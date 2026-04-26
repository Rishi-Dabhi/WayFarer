import 'package:flutter/material.dart';
import '../models/coupon.dart';
import '../theme/game_theme.dart';
import 'coupon_scene_templates.dart';

class CouponCard extends StatelessWidget {
  final Coupon coupon;
  final VoidCallback? onTap;

  const CouponCard({super.key, required this.coupon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final inactive = coupon.status != 'active';
    final accent = inactive ? GameTheme.soil : GameTheme.carrot;
    final reward = inactive ? GameTheme.bark : GameTheme.grass;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: GameTheme.panel(color: GameTheme.parchment),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GameTheme.radius),
          child: CustomPaint(
            painter: _CouponPixelPainter(accent: accent, reward: reward),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DiscountStamp(
                    accent: accent,
                    reward: reward,
                    discount: coupon.discountPct,
                    cashback: coupon.cashbackEur,
                  ),
                  const SizedBox(
                    width: 14,
                    child: CustomPaint(
                      painter: _PerforationPainter(color: GameTheme.bark),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  coupon.headline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: GameTheme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusPill(status: coupon.status, color: accent),
                            ],
                          ),
                          if (coupon.shopName != null) ...[
                            const SizedBox(height: 5),
                            Text(coupon.shopName!, style: GameTheme.label),
                          ],
                          const SizedBox(height: 10),
                          CouponPixelScene(coupon: coupon, height: 78),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: GameTheme.inset(color: const Color(0xFFFFF8DF), border: GameTheme.wheat),
                            child: Text(
                              'ON: ${coupon.offerTarget}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GameTheme.bark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            coupon.bodyText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GameTheme.ink,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (coupon.whyNow != null && coupon.whyNow!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: GameTheme.inset(
                                color: const Color(0xFFFFF8DF),
                                border: GameTheme.wheat,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.auto_awesome, size: 15, color: accent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      coupon.whyNow!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: GameTheme.bark,
                                        fontSize: 12,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscountStamp extends StatelessWidget {
  final Color accent;
  final Color reward;
  final double discount;
  final double cashback;

  const _DiscountStamp({
    required this.accent,
    required this.reward,
    required this.discount,
    required this.cashback,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: accent)),
          const Positioned(top: 10, left: 10, child: PixelMotif(color: GameTheme.wheat, size: 5)),
          Positioned(bottom: 10, right: 10, child: PixelMotif(color: reward, size: 5)),
          Center(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.bark),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${discount.toStringAsFixed(0)}%',
                    style: TextStyle(color: accent, fontSize: 30, fontWeight: FontWeight.w900, height: 1),
                  ),
                  const SizedBox(height: 2),
                  const Text('OFF', style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(width: 48, height: 3, color: GameTheme.bark),
                  const SizedBox(height: 8),
                  Text(
                    'EUR ${cashback.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: reward, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  Text('BACK', style: TextStyle(color: reward, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameTheme.cream,
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(GameTheme.radius),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CouponPixelPainter extends CustomPainter {
  final Color accent;
  final Color reward;

  const _CouponPixelPainter({required this.accent, required this.reward});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = GameTheme.wheat.withValues(alpha: 0.42);
    for (double x = 132; x < size.width; x += 34) {
      canvas.drawRect(Rect.fromLTWH(x, 10, 8, 8), paint);
    }
    paint.color = reward.withValues(alpha: 0.22);
    for (double x = 146; x < size.width; x += 44) {
      canvas.drawRect(Rect.fromLTWH(x, size.height - 18, 10, 10), paint);
    }
    paint.color = accent.withValues(alpha: 0.18);
    canvas.drawRect(Rect.fromLTWH(size.width - 42, 0, 12, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CouponPixelPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.reward != reward;
  }
}

class _PerforationPainter extends CustomPainter {
  final Color color;

  const _PerforationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double y = 8; y < size.height; y += 14) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter oldDelegate) => oldDelegate.color != color;
}
