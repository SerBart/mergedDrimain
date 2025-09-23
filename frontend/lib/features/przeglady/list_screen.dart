import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import 'models.dart';

final _provider = FutureProvider.autoDispose<List<Przeglad>>((ref) async {
  final client = ref.read(authServiceProvider).client;
  final r = await client.dio.get('/api/przeglady');
  return (r.data as List)
      .map((e) => Przeglad.fromJson(e as Map<String, dynamic>))
      .toList();
});

class PrzegladyListScreen extends ConsumerWidget {
  const PrzegladyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final data = ref.watch(_provider);

    return AppScaffold(
      title: 'Przeglądy',
      floatingActionButton: auth.hasAnyRole(const ['ROLE_ADMIN','ROLE_BIURO'])
          ? FloatingActionButton(
        onPressed: () => context.go('/przeglady/new'),
        child: const Icon(Icons.add),
      )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: data.when(
          data: (items) => Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Data')),
                DataColumn(label: Text('Typ')),
                DataColumn(label: Text('Maszyna')),
                DataColumn(label: Text('Osoba')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Opis')),
              ],
              rows: [
                for (final r in items)
                  DataRow(cells: [
                    DataCell(Text(r.data ?? '')),
                    DataCell(Text(r.typ ?? '')),
                    DataCell(Text(r.maszyna ?? '')),
                    DataCell(Text(r.osoba ?? '')),
                    DataCell(Text(r.status ?? '')),
                    DataCell(Text(r.opis ?? '')),
                  ]),
              ],
            ),
          ),
          error: (e, st) => const Center(child: Text('Błąd')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}