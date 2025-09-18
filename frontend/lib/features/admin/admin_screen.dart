import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/app_roles.dart';
import '../../widgets/dialogs.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _dzialCtrl = TextEditingController();
  final _maszynaCtrl = TextEditingController();
  int? _maszynaDzialId;
  final _osobaCtrl = TextEditingController();
  final _userLoginCtrl = TextEditingController();
  String _userRole = 'USER';

  @override
  void dispose() {
    _dzialCtrl.dispose();
    _maszynaCtrl.dispose();
    _osobaCtrl.dispose();
    _userLoginCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final repo = ref.watch(mockRepoProvider);

    if (auth?.role != AppRoles.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brak dostępu')),
        body: const Center(child: Text('ADMIN wymagany.')),
      );
    }

    final dzialy = repo.getDzialy();
    final maszyny = repo.getMaszyny();
    final osoby = repo.getOsoby();
    final users = repo.getUsers();

    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admina')),
      body: ListView(
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
                      onPressed: () {
                        if (_dzialCtrl.text.trim().isEmpty) return;
                        repo.addDzial(_dzialCtrl.text.trim());
                        _dzialCtrl.clear();
                        setState(() {});
                      },
                      child: const Text('Dodaj'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...dzialy.map((d) => ListTile(
                      title: Text(d.nazwa),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showConfirmDialog(context, 'Usuń dział', 'Usunąć ${d.nazwa}?');
                          if (ok == true) {
                            repo.deleteDzial(d.id);
                            setState(() {});
                          }
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
                  items: dzialy
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
                      onPressed: () {
                        if (_maszynaCtrl.text.trim().isEmpty || _maszynaDzialId == null) return;
                        repo.addMaszyna(_maszynaCtrl.text.trim(), _maszynaDzialId!);
                        _maszynaCtrl.clear();
                        setState(() {});
                      },
                      child: const Text('Dodaj'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...maszyny.map((m) => ListTile(
                      title: Text(m.nazwa),
                      subtitle: Text(m.dzial?.nazwa ?? '-'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showConfirmDialog(context, 'Usuń maszynę', 'Usunąć ${m.nazwa}?');
                          if (ok == true) {
                            repo.deleteMaszyna(m.id);
                            setState(() {});
                          }
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
                      onPressed: () {
                        if (_osobaCtrl.text.trim().isEmpty) return;
                        repo.addOsoba(_osobaCtrl.text.trim());
                        _osobaCtrl.clear();
                        setState(() {});
                      },
                      child: const Text('Dodaj'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...osoby.map((o) => ListTile(
                      title: Text(o.imieNazwisko),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showConfirmDialog(context, 'Usuń osobę', 'Usunąć ${o.imieNazwisko}?');
                          if (ok == true) {
                            repo.deleteOsoba(o.id);
                            setState(() {});
                          }
                        },
                      ),
                    )),
              ],
            ),
          ),
            _CardSection(
            title: 'Użytkownicy',
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
                      repo.addUser(_userLoginCtrl.text.trim(), _userRole);
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
                            repo.deleteUser(u.id);
                            setState(() {});
                          }
                        },
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Center(child: Text('To jest wersja DEMO (mock). Później podłączymy prawdziwe API.')),
        ],
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