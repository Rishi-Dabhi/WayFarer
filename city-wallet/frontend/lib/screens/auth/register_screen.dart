import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/game_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'consumer';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(_name.text.trim(), _email.text.trim(), _password.text, _role);
    if (!mounted) return;
    if (ok) context.go(_role == 'merchant' ? '/merchant' : '/consumer');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7DF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: GameTheme.panel(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: GameTheme.panel(color: GameTheme.parchment),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'I am a…',
                      style: TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _RoleChip(label: 'Consumer', value: 'consumer', selected: _role, onTap: (v) => setState(() => _role = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _RoleChip(label: 'Merchant', value: 'merchant', selected: _role, onTap: (v) => setState(() => _role = v))),
                      ],
                    ),
                  ],
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: GameTheme.inset(color: const Color(0xFFFFE0DC), border: GameTheme.berry),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: auth.loading ? null : _register,
                  child: auth.loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;

  const _RoleChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? GameTheme.carrot : GameTheme.cream,
          border: Border.all(color: isSelected ? GameTheme.carrot : GameTheme.bark, width: 2),
          borderRadius: BorderRadius.circular(GameTheme.radius),
          boxShadow: isSelected
              ? const [BoxShadow(color: GameTheme.soil, blurRadius: 0, offset: Offset(3, 3))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : GameTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
