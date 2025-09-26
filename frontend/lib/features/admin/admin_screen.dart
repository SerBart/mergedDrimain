import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/app_roles.dart';
import '../../widgets/dialogs.dart';
import '../../core/models/dzial.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/osoba.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _dzialCtrl = TextEditingController();
  final _maszynaCtrl = TextEditingController();
  int? _maszynaDzialId;
  final _osobaCtrl = TextEditingController(); // imie i nazwisko
  final _userLoginCtrl = TextEditingController();
  String _userRole = 'USER';

  bool _loading = true;
  List<Dzial> _dzialy = [];
  List<Maszyna> _maszyny = [];
  List<Osoba> _osoby = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _dzialCtrl.dispose();
    _maszynaCtrl.dispose();
    _osobaCtrl.dispose();
    _userLoginCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(adminApiRepositoryProvider);
      final results = await Future.wait([
        api.getDzialy(),
        api.getMaszyny(),
        api.getOsoby(),
      ]);
      _dzialy = results[0] as List<Dzial>;
      _maszyny = results[1] as List<Maszyna>;
      _osoby = results[2] as List<Osoba>;
      // Jeżeli wybrany dział został usunięty, wyczyść wybór
      if (_maszynaDzialId != null && !_dzialy.any((d) => d.id == _maszynaDzialId)) {
        _maszynaDzialId = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania panelu admina: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addDzial() async {
    final name = _dzialCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(adminApiRepositoryProvider).addDzial(name);
      _dzialCtrl.clear();
      await _loadAll();
    } catch (e) {
      _showError('Błąd dodawania działu: $e');
    }
  }

  Future<void> _deleteDzial(int id) async {
    try {
      await ref.read(adminApiRepositoryProvider).deleteDzial(id);
      await _loadAll();
    } catch (e) {
      _showError('Błąd usuwania działu: $e');
    }
  }

  Future<void> _addMaszyna() async {
    final nazwa = _maszynaCtrl.text.trim();
    final dzialId = _maszynaDzialId;
    if (nazwa.isEmpty || dzialId == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).addMaszyna(nazwa, dzialId);
      _maszynaCtrl.clear();
      await _loadAll();
    } catch (e) {
      _showError('Błąd dodawania maszyny: $e');
    }
  }

  Future<void> _deleteMaszyna(int id) async {
    try {
      await ref.read(adminApiRepositoryProvider).deleteMaszyna(id);
      await _loadAll();
    } catch (e) {
      _showError('Błąd usuwania maszyny: $e');
    }
  }

  Future<void> _addOsobaDialog() async {
    final imieNazwisko = _osobaCtrl.text.trim();
    final loginCtrl = TextEditingController();
    final hasloCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa osoba'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loginCtrl,
              decoration: const InputDecoration(labelText: 'Login (wymagany)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hasloCtrl,
              decoration: const InputDecoration(labelText: 'Hasło (wymagane)'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: imieNazwisko),
              decoration: const InputDecoration(labelText: 'Imię i nazwisko (opcjonalne)'),
              onChanged: (v) {}, // tylko do pokazania wartości początkowej
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Zapisz')),
        ],
      ),
    );

    if (ok == true) {
      final login = loginCtrl.text.trim();
      final haslo = hasloCtrl.text.trim();
      if (login.isEmpty || haslo.isEmpty) {
        _showError('Login i hasło są wymagane.');
        return;
      }
      try {
        await ref.read(adminApiRepositoryProvider).addOsoba(
              login: login,
              haslo: haslo,
              imieNazwisko: imieNazwisko.isEmpty ? null : imieNazwisko,
            );
        _osobaCtrl.clear();
        await _loadAll();
      } catch (e) {
        _showError('Błąd dodawania osoby: $e');
      }
    }
  }

  Future<void> _deleteOsoba(int id) async {
    try {
      await ref.read(adminApiRepositoryProvider).deleteOsoba(id);
      await _loadAll();
    } catch (e) {
      _showError('Błąd usuwania osoby: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final mock = ref.watch(mockRepoProvider);

    if (auth?.role != AppRoles.admin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Brak dostępu'),
          leading: IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/dashboard'),
          ),
        ),
        body: const Center(child: Text('ADMIN wymagany.')),
      );
    }

    final users = mock.getUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admina'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CardSection(
                    title: 'Działy',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _dzialCtrl,
                                decoration: const InputDecoration(labelText: 'Nazwa działu'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addDzial,
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._dzialy.map((d) => ListTile(
                              title: Text(d.nazwa),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showConfirmDialog(context, 'Usuń dział', 'Usunąć ${d.nazwa}?');
                                  if (ok == true) await _deleteDzial(d.id);
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Maszyny',
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _maszynaDzialId,
                          decoration: const InputDecoration(labelText: 'Dział'),
                          items: _dzialy
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                              .toList(),
                          onChanged: (v) => setState(() => _maszynaDzialId = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _maszynaCtrl,
                                decoration: const InputDecoration(labelText: 'Nazwa maszyny'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addMaszyna,
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._maszyny.map((m) => ListTile(
                              title: Text(m.nazwa),
                              subtitle: Text(m.dzial?.nazwa ?? '-'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showConfirmDialog(context, 'Usuń maszynę', 'Usunąć ${m.nazwa}?');
                                  if (ok == true) await _deleteMaszyna(m.id);
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Osoby',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _osobaCtrl,
                                decoration: const InputDecoration(labelText: 'Imię i nazwisko'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addOsobaDialog,
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._osoby.map((o) => ListTile(
                              title: Text(o.imieNazwisko),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showConfirmDialog(context, 'Usuń osobę', 'Usunąć ${o.imieNazwisko}?');
                                  if (ok == true) await _deleteOsoba(o.id);
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Użytkownicy (DEMO)',
                    child: Column(
                      children: [
                        TextField(
                          controller: _userLoginCtrl,
                          decoration: const InputDecoration(labelText: 'Login użytkownika'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _userRole,
                          decoration: const InputDecoration(labelText: 'Rola'),
                          items: const [
                            DropdownMenuItem(value: 'USER', child: Text('USER')),
                            DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                          ],
                          onChanged: (v) => setState(() => _userRole = v ?? 'USER'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_userLoginCtrl.text.trim().isEmpty) return;
                              mock.addUser(_userLoginCtrl.text.trim(), _userRole);
                              _userLoginCtrl.clear();
                              setState(() {});
                            },
                            child: const Text('Dodaj użytkownika'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...users.map((u) => ListTile(
                              title: Text(u.username),
                              subtitle: Text(u.role),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  if (u.username == 'admin') {
                                    showErrorDialog(context, 'Błąd', 'Nie usuwaj głównego admina (demo).');
                                    return;
                                  }
                                  final ok = await showConfirmDialog(context, 'Usuń użytkownika', 'Usunąć ${u.username}?');
                                  if (ok == true) {
                                    mock.deleteUser(u.id);
                                    setState(() {});
                                  }
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Center(child: Text('Działy/Maszyny/Osoby zapisują się do bazy. Sekcja Użytkownicy to DEMO.')),
                ],
              ),
            ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}