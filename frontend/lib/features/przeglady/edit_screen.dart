import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';

class PrzegladEditScreen extends ConsumerStatefulWidget {
  final String? id;
  const PrzegladEditScreen({super.key, required this.id});

  @override
  ConsumerState<PrzegladEditScreen> createState() => _PrzegladEditScreenState();
}

class _PrzegladEditScreenState extends ConsumerState<PrzegladEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = TextEditingController();
  final _typ = TextEditingController();
  final _opis = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _data.dispose();
    _typ.dispose();
    _opis.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final dio = ref.read(authServiceProvider).client.dio;
    try {
      final payload = {
        'data': _data.text.trim(),
        'typ': _typ.text.trim(), // MIESIECZNY, ROCZNY itd.
        'opis': _opis.text.trim(),
      };
      if (widget.id == null) {
        await dio.post('/api/przeglady', data: payload);
      } else {
        await dio.put('/api/przeglady/${widget.id}', data: payload);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _error = 'Nie udało się zapisać'; });
    } finally {
      setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final canEdit = auth.hasAnyRole(const ['ROLE_ADMIN','ROLE_BIURO']);

    return AppScaffold(
      title: widget.id == null ? 'Nowy przegląd' : 'Edytuj przegląd',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: AbsorbPointer(
                    absorbing: !canEdit,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _data,
                          decoration: const InputDecoration(labelText: 'Data (yyyy-MM-dd)'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Wymagane' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _typ,
                          decoration: const InputDecoration(labelText: 'Typ (np. MIESIECZNY)'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Wymagane' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _opis,
                          decoration: const InputDecoration(labelText: 'Opis'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.save),
                              label: const Text('Zapisz'),
                            ),
                          ],
                        )
                      ],
                    ),
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