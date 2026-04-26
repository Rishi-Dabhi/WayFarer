import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

class NewProductScreen extends StatefulWidget {
  final String shopId;
  const NewProductScreen({super.key, required this.shopId});

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  String _category = 'food';
  String _stock = 'normal';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().createProduct({
        'shop_id': int.parse(widget.shopId),
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price_cents': (double.parse(_price.text) * 100).round(),
        'category': _category,
        'stock_level': _stock,
      });
      if (mounted) context.pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.panel(color: GameTheme.parchment),
              child: Column(
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price', prefixText: '€ '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.panel(color: GameTheme.parchment),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['coffee', 'food', 'drinks', 'retail', 'other'].map((o) => ChoiceChip(
                      label: Text(o),
                      selected: _category == o,
                      onSelected: (_) => setState(() => _category = o),
                    )).toList(),
                  ),
                  const Divider(color: GameTheme.wheat, height: 24),
                  const Text('Stock Level', style: TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['low', 'normal', 'high'].map((o) => ChoiceChip(
                      label: Text(o),
                      selected: _stock == o,
                      onSelected: (_) => setState(() => _stock = o),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add Product', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
