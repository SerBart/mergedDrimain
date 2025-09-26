import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/maszyna.dart';
import '../../core/repositories/parts_api_repository.dart';

class InstrukcjaFormScreen extends ConsumerStatefulWidget {
  const InstrukcjaFormScreen({super.key});
  @override
  ConsumerState<InstrukcjaFormScreen> createState() => _InstrukcjaFormScreenState();
}

class _InstrukcjaFormScreenState extends ConsumerState<InstrukcjaFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  List<Maszyna> _maszyny = [];
  int? _selectedMaszynaId;

  List<PartRefModel> _parts = [];
  final Map<int, int> _selectedParts = {}; // partId -> ilosc

  List<PlatformFile> _files = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final maszyny = await ref.read(adminApiRepositoryProvider).getMaszyny();
      final parts = await ref.read(partsApiRepositoryProvider).listAll();
      setState(() {
        _maszyny = maszyny;
        _parts = parts;
        if (_maszyny.isNotEmpty && _selectedMaszynaId == null) _selectedMaszynaId = _maszyny.first.id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania danych: $e')),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf','png','jpg','jpeg','gif','webp'],
    );
    if (res != null) {
      setState(() => _files = res.files);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedMaszynaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tytuł i maszyna są wymagane.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final parts = _selectedParts.entries
          .where((e) => e.value > 0)
          .map((e) => {'partId': e.key, 'ilosc': e.value})
          .toList();

      final ins = await ref.read(instructionsApiRepositoryProvider).create(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        maszynaId: _selectedMaszynaId!,
        parts: parts,
      );

      if (_files.isNotEmpty) {
        final files = <MultipartFile>[];
        for (final f in _files) {
          if (kIsWeb && f.bytes != null) {
            files.add(MultipartFile.fromBytes(f.bytes!, filename: f.name));
          } else if (f.path != null) {
            files.add(await MultipartFile.fromFile(
              f.path!, filename: f.name,
            ));
          }
        }
        await ref.read(instructionsApiRepositoryProvider)
            .uploadAttachments(instructionId: ins.id, files: files);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodano instrukcję.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowa instrukcja'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _loadMeta,
            tooltip: 'Odśwież listy',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _pickFiles,
        icon: const Icon(Icons.attach_file),
        label: Text(_files.isEmpty ? 'Dodaj pliki' : 'Pliki: ${_files.length}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Zapisz'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Tytuł', border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _selectedMaszynaId,
          items: _maszyny.map((m) => DropdownMenuItem(
            value: m.id, child: Text(m.nazwa),
          )).toList(),
          onChanged: (v) => setState(() => _selectedMaszynaId = v),
          decoration: const InputDecoration(labelText: 'Maszyna', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Opis (opcjonalnie)', border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Części zamienne (opcjonalnie):', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_parts.isEmpty) ...[
          const Text('Brak danych części lub wczytywanie…'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loadMeta,
              icon: const Icon(Icons.refresh),
              label: const Text('Odśwież listę części'),
            ),
          ),
        ] else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parts.length,
              itemBuilder: (_, i) {
                final p = _parts[i];
                final qty = _selectedParts[p.id] ?? 0;
                return ListTile(
                  onTap: () => setState(() => _selectedParts[p.id] = qty + 1),
                  onLongPress: qty > 0 ? () => setState(() => _selectedParts[p.id] = qty - 1) : null,
                  title: Text('${p.nazwa} (${p.kod})'),
                  subtitle: Text(p.jednostka ?? ''),
                  trailing: SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: qty > 0 ? () => setState(() => _selectedParts[p.id] = qty - 1) : null,
                        ),
                        Text('$qty'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _selectedParts[p.id] = qty + 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
            ),
          ),
        const SizedBox(height: 80), // miejsce na FAB
      ],
    );
  }
}
