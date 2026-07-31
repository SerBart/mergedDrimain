import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).login(
            _userCtrl.text.trim(),
            _passCtrl.text.trim(),
            rememberMe: _rememberMe,
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      String errorMessage = 'Login lub haslo sa niepoprawne';

      if (e is DioException) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
          errorMessage = 'Login lub haslo sa niepoprawne';
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Nie mozna polaczyc sie z serwerem. Sprawdz polaczenie.';
        } else if (e.type == DioExceptionType.unknown) {
          errorMessage = 'Blad polaczenia z serwerem';
        }
      }

      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [scheme.primary.withOpacity(.35), scheme.secondary.withOpacity(.25)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(.15),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Image.asset('assets/images/logo.png', height: 72),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DriMain',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'System zarzadzania utrzymaniem ruchu',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(labelText: 'Login lub e-mail'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Podaj login lub e-mail' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Haslo'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Podaj haslo' : null,
                        textInputAction: TextInputAction.go,
                        onFieldSubmitted: (_) {
                          if (!_loading) {
                            _submit();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          const Text('Zapamietaj mnie'),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_loading ? 'Logowanie...' : 'Zaloguj'),
                        ),
                      ),
                    ],
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