import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';

class RaportEditScreen extends ConsumerStatefulWidget {
  final String? id;
  const RaportEditScreen({super.key, required this.id});

  @override
  ConsumerState<RaportEditScreen> createState() => _RaportEditScreenState();
}

class _RaportEditScreenState extends ConsumerState<RaportEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opis = TextEditingController();
  final _data = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _opis.dispose();
    _data.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final dio = ref.read(authServiceProvider).client.dio;
    try {
      if (widget.id == null) {
        await dio.post('/api/raporty', data: {
          'opis': _opis.text.trim(),
          'dataNaprawy': _data.text.trim(), // yyyy-MM-dd
        });
      } else {
        await dio.put('/api/raporty/${widget.id}', data: {
          'opis': _opis.text.trim(),
          'dataNaprawy': _data.text.trim(),
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = 'Nie udało się zapisać'; });
    } finally {
      setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final canEdit = auth.hasAnyRole(const ['ROLE_ADMIN']);

    return AppScaffold(
      title: widget.id == null ? 'Nowy raport' : 'Edytuj raport',
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
                          decoration: const InputDecoration(
                            labelText: 'Data naprawy (yyyy-MM-dd)',
                          ),
                          validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wymagane' : null,
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