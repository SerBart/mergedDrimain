import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/models/part.dart';

class CzesciListScreen extends ConsumerStatefulWidget {
  const CzesciListScreen({super.key});

  @override
  ConsumerState<CzesciListScreen> createState() => _CzesciListScreenState();
}

class _CzesciListScreenState extends ConsumerState<CzesciListScreen> {
  final _nazwaCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();
  final _iloscCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _jednCtrl = TextEditingController(text: 'szt');

  @override
  void dispose() {
    _nazwaCtrl.dispose();
    _kodCtrl.dispose();
    _iloscCtrl.dispose();
    _minCtrl.dispose();
    _jednCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final repo = ref.read(mockRepoProvider);
    if (_nazwaCtrl.text.isEmpty || _kodCtrl.text.isEmpty) return;
    final ilosc = int.tryParse(_iloscCtrl.text) ?? 0;
    final min = int.tryParse(_minCtrl.text) ?? 0;
    repo.addPart(
      nazwa: _nazwaCtrl.text.trim(),
      kod: _kodCtrl.text.trim(),
      ilosc: ilosc,
      minIlosc: min,
      jednostka: _jednCtrl.text.trim(),
    );
    _nazwaCtrl.clear();
    _kodCtrl.clear();
    _iloscCtrl.clear();
    _minCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(mockRepoProvider);
    final parts = repo.getParts();

    return Scaffold(
      appBar: AppBar(title: const Text('Części – magazyn')),
      body: Column(
        children: [
          ExpansionTile(
            title: const Text('Dodaj część'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nazwaCtrl,
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _kodCtrl,
                      decoration: const InputDecoration(labelText: 'Kod'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _iloscCtrl,
                            decoration: const InputDecoration(labelText: 'Ilość startowa'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _minCtrl,
                            decoration: const InputDecoration(labelText: 'Min. ilość'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _jednCtrl,
                            decoration: const InputDecoration(labelText: 'Jednostka'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _add,
                        child: const Text('Dodaj'),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: parts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = parts[i];
                return ListTile(
                  title: Text('${p.nazwa} (${p.kod})'),
                  subtitle: Text(
                      'Stan: ${p.iloscMagazyn} ${p.jednostka} (min: ${p.minIlosc})'),
                  trailing: p.belowMin
                      ? const Icon(Icons.warning, color: Colors.red)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}