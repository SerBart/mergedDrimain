import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectTo;
  const LoginScreen({super.key, this.redirectTo});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(authServiceProvider).login(_u.text.trim(), _p.text);
    setState(() { _loading = false; });
    if (ok) {
      final to = widget.redirectTo;
      if (to != null) {
        // Użyj context.go (goUri może nie istnieć w Twojej wersji go_router)
        context.go(Uri.decodeComponent(to));
      } else {
        context.go('/');
      }
    } else {
      setState(() { _error = 'Błędny login lub hasło'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Zaloguj się', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _u,
                      decoration: const InputDecoration(labelText: 'Użytkownik'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Wpisz login' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _p,
                      decoration: const InputDecoration(labelText: 'Hasło'),
                      obscureText: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Wpisz hasło' : null,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Zaloguj'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}