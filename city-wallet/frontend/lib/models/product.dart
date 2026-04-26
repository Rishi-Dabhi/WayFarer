class Product {
  final int id;
  final String name;
  final String? description;
  final int priceCents;
  final String? category;
  final String stockLevel;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.priceCents,
    this.category,
    required this.stockLevel,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'],
        priceCents: j['price_cents'] ?? 0,
        category: j['category'],
        stockLevel: j['stock_level'] ?? 'normal',
      );

  double get priceEur => priceCents / 100.0;
}
