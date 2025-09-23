import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_scaffold.dart';
import '../../services/auth_service.dart';
import 'models.dart';

final _detailProvider = FutureProvider.family<Raport, String>((ref, id) async {
  final client = ref.read(authServiceProvider).client;
  final r = await client.dio.get('/api/raporty/$id');
  return Raport.fromJson(r.data as Map<String, dynamic>);
});

class RaportDetailScreen extends ConsumerWidget {
  final String id;
  const RaportDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_detailProvider(id));
    return AppScaffold(
      title: 'Raport',
      body: data.when(
        data: (r) => Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _row('Data', r.dataNaprawy),
                _row('Maszyna', r.maszyna),
                _row('Status', r.status),
                _row('Opis', r.opis),
              ],
            ),
          ),
        ),
        error: (e, st) => const Center(child: Text('Błąd')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _row(String k, String? v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 180, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(v ?? '')),
      ],
    ),
  );
}