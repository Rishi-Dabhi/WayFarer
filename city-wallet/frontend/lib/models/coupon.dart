class Coupon {
  final int id;
  final String headline;
  final String bodyText;
  final String? whyNow;
  final double discountPct;
  final int cashbackCents;
  final String? qrToken;
  final String? shopName;
  final String? address;
  final String? expiresAt;
  final String status;
  final String? generatedAt;

  const Coupon({
    required this.id,
    required this.headline,
    required this.bodyText,
    this.whyNow,
    required this.discountPct,
    required this.cashbackCents,
    this.qrToken,
    this.shopName,
    this.address,
    this.expiresAt,
    required this.status,
    this.generatedAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'] ?? 0,
        headline: j['headline'] ?? '',
        bodyText: j['body_text'] ?? '',
        whyNow: j['why_now'],
        discountPct: (j['discount_pct'] ?? 0).toDouble(),
        cashbackCents: j['cashback_cents'] ?? 0,
        qrToken: j['qr_token'],
        shopName: j['shop_name'],
        address: j['address'],
        expiresAt: j['expires_at'],
        status: j['status'] ?? 'active',
        generatedAt: j['generated_at'],
      );

  bool get isActive => status == 'active';
  bool get isRedeemed => status == 'redeemed';
  double get cashbackEur => cashbackCents / 100.0;
}
