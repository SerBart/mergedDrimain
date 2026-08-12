import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).changePassword(
            currentPassword: _currentPasswordCtrl.text.trim(),
            newPassword: _newPasswordCtrl.text.trim(),
          );
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasło zostało zmienione')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się zmienić hasła: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const TopAppBar(title: 'Mój profil', showBack: true),
      body: user == null
          ? const Center(child: Text('Brak zalogowanego użytkownika.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: scheme.primary.withOpacity(.12),
                              child: Text(
                                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.username, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(user.email ?? 'Brak e-maila'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Rola', value: user.role),
                        _InfoRow(label: 'Dział', value: user.dzialNazwa ?? '-'),
                        _InfoRow(label: 'Uprawnienia modułów', value: user.modules.isEmpty ? '-' : user.modules.join(', ')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zmień hasło', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _currentPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Aktualne hasło'),
                            validator: (v) => (v == null || v.isEmpty) ? 'Podaj aktualne hasło' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Nowe hasło'),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Podaj nowe hasło';
                              if (v.length < 8) return 'Hasło musi mieć co najmniej 8 znaków';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Powtórz nowe hasło'),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Powtórz nowe hasło';
                              if (v != _newPasswordCtrl.text) return 'Hasła muszą być takie same';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _changePassword,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.lock_reset),
                              label: Text(_saving ? 'Zapisywanie...' : 'Zmień hasło'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

