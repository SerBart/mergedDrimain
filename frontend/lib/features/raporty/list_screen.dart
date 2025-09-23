import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import 'models.dart';

final _raportyProvider = FutureProvider.autoDispose<List<Raport>>((ref) async {
  final client = ref.read(authServiceProvider).client;
  final r = await client.dio.get('/api/raporty', queryParameters: {
    'page': 0,
    'size': 25,
    'sort': 'dataNaprawy:desc',
  });
  final content = (r.data['content'] as List?) ?? [];
  return content.map((e) => Raport.fromJson(e as Map<String, dynamic>)).toList();
});

class RaportyListScreen extends ConsumerWidget {
  const RaportyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final data = ref.watch(_raportyProvider);

    return AppScaffold(
      title: 'Raporty',
      floatingActionButton: auth.hasAnyRole(const ['ROLE_ADMIN'])
          ? FloatingActionButton(
        onPressed: () => context.go('/raporty/new'),
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
                DataColumn(label: Text('Maszyna')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Opis')),
              ],
              rows: [
                for (final r in items)
                  DataRow(
                    cells: [
                      DataCell(Text(r.dataNaprawy ?? '')),
                      DataCell(Text(r.maszyna ?? '')),
                      DataCell(Text(r.status ?? '')),
                      DataCell(Text(r.opis ?? '')),
                    ],
                    onSelectChanged: (_) => context.go('/raporty/${r.id}'),
                  ),
              ],
            ),
          ),
          error: (e, st) => _ErrorView(error: e),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  final Object error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    String msg = 'Błąd';
    if (e is DioException) {
      msg = 'Błąd API: ${e.response?.statusCode ?? ''}';
    }
    return Center(child: Text(msg));
  }
}