import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Add Product'), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 12),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), filled: true, fillColor: Colors.white), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (€)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, prefixText: '€ ')),
            const SizedBox(height: 20),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ChipGroup(options: ['coffee', 'food', 'drinks', 'retail', 'other'], selected: _category, onSelected: (v) => setState(() => _category = v)),
            const SizedBox(height: 16),
            const Text('Stock Level', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ChipGroup(options: ['low', 'normal', 'high'], selected: _stock, onSelected: (v) => setState(() => _stock = v)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Product', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelected;

  const _ChipGroup({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isSelected = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: isSelected,
          onSelected: (_) => onSelected(o),
          selectedColor: const Color(0xFFF97316),
          labelStyle: TextStyle(color: isSelected ? Colors.white : null),
        );
      }).toList(),
    );
  }
}
