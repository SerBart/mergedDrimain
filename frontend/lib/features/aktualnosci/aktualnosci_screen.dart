import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/harmonogram.dart';
import '../../core/models/raport.dart';
import '../../core/models/zgloszenie.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/notification_router.dart';
import '../../widgets/app_card.dart';
import '../../widgets/top_app_bar.dart';

class AktualnosciScreen extends ConsumerStatefulWidget {
  const AktualnosciScreen({super.key});

  @override
  ConsumerState<AktualnosciScreen> createState() => _AktualnosciScreenState();
}

class _AktualnosciScreenState extends ConsumerState<AktualnosciScreen> {
  bool _loading = true;
  String? _error;
  List<Harmonogram> _recentHarmonogramy = const [];
  List<Zgloszenie> _recentAwarie = const [];
  List<Raport> _recentRaporty = const [];
  List<Zgloszenie> _recentZgloszenia = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final harmonogramyRepo = ref.read(harmonogramyApiRepositoryProvider);
      final raportyRepo = ref.read(raportyApiRepositoryProvider);
      final zgloszeniaRepo = ref.read(zgloszeniaApiRepositoryProvider);

      final results = await Future.wait([
        harmonogramyRepo.fetchAll(),
        raportyRepo.fetchAll(page: 0, size: 5),
        zgloszeniaRepo.fetchAll(),
      ]);

      final harmonogramy = results[0] as List<Harmonogram>;
      final raporty = results[1] as List<Raport>;
      final zgloszenia = results[2] as List<Zgloszenie>;
      harmonogramy.sort((a, b) {
        final ad = a.data ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.data ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      zgloszenia.sort((a, b) => b.dataGodzina.compareTo(a.dataGodzina));
      final awarie = zgloszenia.where(_isAwaria).take(5).toList();

      if (!mounted) return;
      setState(() {
        _recentHarmonogramy = harmonogramy.take(5).toList();
        _recentAwarie = awarie;
        _recentRaporty = raporty.take(5).toList();
        _recentZgloszenia = zgloszenia.take(5).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(notificationsListProvider);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopAppBar(title: 'Aktualności', showBack: true),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppCard(
              title: 'Ostatnie awarie',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/zgloszenia'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentAwarie.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać awarii: $_error',
                          onRetry: _loadData,
                        )
                      : _RecentAwarieList(items: _recentAwarie),
            ),
            AppCard(
              title: 'Ostatnie harmonogramy',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/harmonogramy'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentHarmonogramy.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać harmonogramów: $_error',
                          onRetry: _loadData,
                        )
                      : _RecentHarmonogramyList(items: _recentHarmonogramy),
            ),
            AppCard(
              title: 'Ostatnie raporty',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/raporty'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentRaporty.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać raportów: $_error',
                          onRetry: _loadData,
                        )
                      : _RecentRaportyList(items: _recentRaporty),
            ),
            AppCard(
              title: 'Ostatnie zgłoszenia',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/zgloszenia'),
                child: const Text('Wszystkie'),
              ),
              child: _loading && _recentZgloszenia.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? _ErrorBlock(
                          message: 'Nie udało się pobrać zgłoszeń: $_error',
                          onRetry: _loadData,
                        )
                      : _RecentZgloszeniaList(items: _recentZgloszenia),
            ),
            AppCard(
              title: 'Ostatnie powiadomienia',
              divided: true,
              action: TextButton(
                onPressed: () => context.go('/notifications'),
                child: const Text('Wszystkie'),
              ),
              child: const _RecentNotificationsWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRaportyList extends StatelessWidget {
  final List<Raport> items;

  const _RecentRaportyList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak raportów do wyświetlenia.'),
      );
    }

    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(r.typNaprawy),
              subtitle: Text(
                '${r.maszyna?.nazwa ?? '-'} • ${r.dataNaprawy.toIso8601String().substring(0, 10)}',
              ),
              trailing: Text(r.status),
              onTap: () => GoRouter.of(context).go('/raporty'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentAwarieList extends StatelessWidget {
  final List<Zgloszenie> items;

  const _RecentAwarieList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak awarii do wyświetlenia.'),
      );
    }

    return Column(
      children: items
          .map(
            (z) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              title: Text(z.temat.isNotEmpty ? z.temat : z.typ),
              subtitle: Text(
                '${z.maszyna?.nazwa ?? '-'} • ${z.dataGodzina.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
              ),
              trailing: Text(z.status),
              onTap: () => GoRouter.of(context).go('/zgloszenia/${z.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentZgloszeniaList extends StatelessWidget {
  final List<Zgloszenie> items;

  const _RecentZgloszeniaList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak zgłoszeń do wyświetlenia.'),
      );
    }

    return Column(
      children: items
          .map(
            (z) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_problem_outlined),
              title: Text(z.temat.isNotEmpty ? z.temat : z.typ),
              subtitle: Text(
                '${z.maszyna?.nazwa ?? '-'} • ${z.dataGodzina.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
              ),
              trailing: Text(z.status),
              onTap: () => GoRouter.of(context).go('/zgloszenia/${z.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentHarmonogramyList extends StatelessWidget {
  final List<Harmonogram> items;

  const _RecentHarmonogramyList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Brak harmonogramów do wyświetlenia.'),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd');
    return Column(
      children: items
          .map(
            (h) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(h.opis.isNotEmpty ? h.opis : 'Harmonogram #${h.id}'),
              subtitle: Text(
                '${h.maszyna?.nazwa ?? '-'} • ${h.data != null ? dateFormat.format(h.data!) : '-'}',
              ),
              trailing: Text(h.status),
              onTap: () => GoRouter.of(context).go('/harmonogramy'),
            ),
          )
          .toList(),
    );
  }
}

class _RecentNotificationsWidget extends ConsumerWidget {
  const _RecentNotificationsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return notifsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Brak powiadomień.'),
          );
        }

        final recent = notifications.take(5).toList();
        return Column(
          children: recent
              .map(
                (n) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    n.read ? Icons.notifications_none : Icons.notifications_active,
                    color: n.read ? Colors.grey : Colors.orange,
                  ),
                  title: Text(
                    n.title ?? 'Powiadomienie',
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
                      color: n.read ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    n.message ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Text(
                    n.createdAt != null ? _formatTime(n.createdAt!) : '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    final target = routeFromNotificationModel(n);
                    GoRouter.of(context).go(target);
                  },
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Błąd ładowania powiadomień'),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'teraz';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return DateFormat('MM-dd').format(dt);
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}

bool _isAwaria(Zgloszenie zgloszenie) {
  final type = zgloszenie.typ.trim().toUpperCase();
  return type == 'AWARIA' || type == 'USTERKA';
}

