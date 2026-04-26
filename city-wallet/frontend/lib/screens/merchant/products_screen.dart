import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  int? _shopId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final shopData = await context.read<ApiService>().getMerchantShop(user.id);
      _shopId = shopData['id'] ?? shopData['shop_id'];
      if (_shopId == null) { setState(() => _loading = false); return; }
      final products = await context.read<ApiService>().getProducts(_shopId!);
      if (mounted) setState(() { _products = products; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product', style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900)),
        content: Text('Remove "${p.name}"?', style: const TextStyle(color: GameTheme.bark)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: GameTheme.bark))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<ApiService>().deleteProduct(p.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: _shopId == null ? null : () => context.push('/merchant/products/new?shopId=$_shopId').then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GameTheme.carrot))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PixelMotif(color: GameTheme.bark, size: 10),
                      const SizedBox(height: 16),
                      const Text('No products yet', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Tap + to add one', style: TextStyle(color: GameTheme.soil, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: GameTheme.carrot,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => _ProductCard(product: _products[i], onDelete: () => _delete(_products[i])),
                  ),
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onDelete;
  const _ProductCard({required this.product, required this.onDelete});

  Color get _stockColor => switch (product.stockLevel) {
    'low' => GameTheme.berry,
    'high' => GameTheme.grass,
    _ => GameTheme.carrot,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
                if (product.description != null)
                  Text(product.description!, style: const TextStyle(color: GameTheme.bark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('€${product.priceEur.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
                    const SizedBox(width: 8),
                    if (product.category != null)
                      _badge(product.category!, GameTheme.water),
                    const SizedBox(width: 6),
                    _badge(product.stockLevel, _stockColor),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: GameTheme.berry),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(GameTheme.radius),
      border: Border.all(color: color.withOpacity(0.4), width: 1),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );
}
