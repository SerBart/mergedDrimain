import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/constants/app_roles.dart';
import '../../widgets/dialogs.dart';
import '../../core/models/dzial.dart';
import '../../core/models/maszyna.dart';
import '../../core/models/sekcja.dart';
import '../../core/models/osoba.dart';
import '../../core/models/admin_user.dart';
import '../../widgets/top_app_bar.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _dzialCtrl = TextEditingController();
  final _sekcjaCtrl = TextEditingController();
  int? _sekcjaDzialId;
  final _maszynaCtrl = TextEditingController();
  int? _maszynaDzialId;
  Set<int> _maszynaSekcjaIds = <int>{};
  final _osobaCtrl = TextEditingController(); // imie i nazwisko
  int? _osobaDzialId; // nowy: dział dla osoby
  final _userLoginCtrl = TextEditingController();
  String _userRole = 'USER';

  // API Users (systemowi) – formularz
  final _apiUserUsernameCtrl = TextEditingController();
  final _apiUserPasswordCtrl = TextEditingController();
  final _apiUserEmailCtrl = TextEditingController();
  int? _apiUserDzialId;
  Set<String> _apiUserModules = {};
  String _apiUserRole = 'USER';

  bool _loading = true;
  List<Dzial> _dzialy = [];
  List<Sekcja> _sekcje = [];
  List<Maszyna> _maszyny = [];
  List<Osoba> _osoby = [];

  // API Users + katalog modułów
  List<AdminUser> _users = [];
  List<String> _modulesCatalog = [];

  String _dzialSearch = '';
  String _sekcjaSearch = '';
  String _maszynaSearch = '';
  String _osobaSearch = '';
  String _apiUserSearch = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _dzialCtrl.dispose();
    _sekcjaCtrl.dispose();
    _maszynaCtrl.dispose();
    _osobaCtrl.dispose();
    _userLoginCtrl.dispose();
    _apiUserUsernameCtrl.dispose();
    _apiUserPasswordCtrl.dispose();
    _apiUserEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(adminApiRepositoryProvider);
      final results = await Future.wait([
        api.getDzialy(),
        api.getSekcje(),
        api.getMaszyny(),
        api.getOsoby(),
        api.getUsers(),
        api.getModulesCatalog(),
      ]);
      _dzialy = results[0] as List<Dzial>;
      _sekcje = results[1] as List<Sekcja>;
      _maszyny = results[2] as List<Maszyna>;
      _osoby = results[3] as List<Osoba>;
      _users = results[4] as List<AdminUser>;
      _modulesCatalog = (results[5] as List).cast<String>();
      // sanity: wyczyść nieistniejące wybory działu
      if (_maszynaDzialId != null && !_dzialy.any((d) => d.id == _maszynaDzialId)) _maszynaDzialId = null;
      if (_sekcjaDzialId != null && !_dzialy.any((d) => d.id == _sekcjaDzialId)) _sekcjaDzialId = null;
      _maszynaSekcjaIds = _maszynaSekcjaIds
          .where((id) => _sekcje.any((s) => s.id == id && (_maszynaDzialId == null || s.dzial?.id == _maszynaDzialId)))
          .toSet();
      if (_apiUserDzialId != null && !_dzialy.any((d) => d.id == _apiUserDzialId)) _apiUserDzialId = null;
      if (_osobaDzialId != null && !_dzialy.any((d) => d.id == _osobaDzialId)) _osobaDzialId = null;
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

  Future<void> _editDzial(Dzial d) async {
    final name = await _showTextEditDialog(
      title: 'Edytuj dział',
      label: 'Nazwa działu',
      initialValue: d.nazwa,
    );
    if (name == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).updateDzial(id: d.id, nazwa: name);
      await _loadAll();
    } catch (e) {
      _showError('Błąd edycji działu: $e');
    }
  }

  Future<void> _addSekcja() async {
    final name = _sekcjaCtrl.text.trim();
    final dzialId = _sekcjaDzialId;
    if (name.isEmpty || dzialId == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).addSekcja(nazwa: name, dzialId: dzialId);
      _sekcjaCtrl.clear();
      await _loadAll();
    } catch (e) {
      _showError('Błąd dodawania sekcji: $e');
    }
  }

  Future<void> _deleteSekcja(int id) async {
    try {
      await ref.read(adminApiRepositoryProvider).deleteSekcja(id);
      await _loadAll();
    } catch (e) {
      _showError('Błąd usuwania sekcji: $e');
    }
  }

  Future<void> _editSekcja(Sekcja s) async {
    final result = await _showSekcjaEditDialog(s);
    if (result == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).updateSekcja(
            id: s.id,
            nazwa: result.nazwa,
            dzialId: result.dzialId,
          );
      await _loadAll();
    } catch (e) {
      _showError('Błąd edycji sekcji: $e');
    }
  }

  Future<void> _addMaszyna() async {
    final nazwa = _maszynaCtrl.text.trim();
    final dzialId = _maszynaDzialId;
    final sekcjaIds = _maszynaSekcjaIds.toList();
    if (nazwa.isEmpty || dzialId == null || sekcjaIds.isEmpty) return;
    try {
      await ref.read(adminApiRepositoryProvider).addMaszyna(nazwa, dzialId, sekcjaIds: sekcjaIds);
      _maszynaCtrl.clear();
      _maszynaSekcjaIds = <int>{};
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

  Future<void> _editMaszyna(Maszyna m) async {
    final result = await _showMaszynaEditDialog(m);
    if (result == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).updateMaszyna(
            id: m.id,
            nazwa: result.nazwa,
            dzialId: result.dzialId,
            sekcjaIds: result.sekcjaIds,
          );
      await _loadAll();
    } catch (e) {
      _showError('Błąd edycji maszyny: $e');
    }
  }

  Future<void> _addOsoba() async {
    final imieNazwisko = _osobaCtrl.text.trim();
    final dzialId = _osobaDzialId;
    if (imieNazwisko.isEmpty) {
      _showError('Podaj imię i nazwisko.');
      return;
    }
    try {
      await ref.read(adminApiRepositoryProvider).addOsoba(
            imieNazwisko: imieNazwisko,
            dzialId: dzialId,
          );
      _osobaCtrl.clear();
      await _loadAll();
    } catch (e) {
      _showError('Błąd dodawania osoby: $e');
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

  Future<void> _editOsoba(Osoba o) async {
    final result = await _showOsobaEditDialog(o);
    if (result == null) return;
    try {
      await ref.read(adminApiRepositoryProvider).updateOsoba(
            id: o.id,
            imieNazwisko: result.imieNazwisko,
            dzialId: result.dzialId,
            login: result.login,
            haslo: result.haslo,
            rola: result.rola,
          );
      await _loadAll();
    } catch (e) {
      _showError('Błąd edycji osoby: $e');
    }
  }

  Future<void> _createApiUser() async {
    final username = _apiUserUsernameCtrl.text.trim();
    final password = _apiUserPasswordCtrl.text.trim();
    final email = _apiUserEmailCtrl.text.trim();
    if (username.isEmpty || password.isEmpty || email.isEmpty) {
      _showError('Uzupełnij login, hasło i e-mail.');
      return;
    }
    try {
      final roles = _apiUserRole == 'ADMIN'
          ? {'ROLE_ADMIN', 'ROLE_USER'}
          : {'ROLE_USER'};
      await ref.read(adminApiRepositoryProvider).createUser(
            username: username,
            password: password,
            email: email,
            dzialId: _apiUserDzialId,
            roles: roles,
            modules: _apiUserModules,
          );
      _apiUserUsernameCtrl.clear();
      _apiUserPasswordCtrl.clear();
      _apiUserEmailCtrl.clear();
      _apiUserDzialId = null;
      _apiUserModules = {};
      _apiUserRole = 'USER';
      await _loadAll();
    } catch (e) {
      _showError('Błąd tworzenia użytkownika: $e');
    }
  }

  Future<void> _deleteApiUser(int id) async {
    try {
      await ref.read(adminApiRepositoryProvider).deleteUser(id);
      await _loadAll();
    } catch (e) {
      _showError('Błąd usuwania użytkownika: $e');
    }
  }

  Future<void> _editApiUser(AdminUser u) async {
    final result = await _showApiUserEditDialog(u);
    if (result == null) return;
    try {
      final roles = result.isAdmin ? {'ROLE_ADMIN', 'ROLE_USER'} : {'ROLE_USER'};
      await ref.read(adminApiRepositoryProvider).updateUser(
            id: u.id,
            username: result.username,
            password: result.password,
            email: result.email,
            dzialId: result.dzialId,
            roles: roles,
            modules: result.modules,
          );
      await _loadAll();
    } catch (e) {
      _showError('Błąd edycji użytkownika: $e');
    }
  }

  Future<String?> _showTextEditDialog({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<_SekcjaEditData?> _showSekcjaEditDialog(Sekcja s) {
    final nameCtrl = TextEditingController(text: s.nazwa);
    int? selectedDzialId = s.dzial?.id;
    return showDialog<_SekcjaEditData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edytuj sekcję'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedDzialId,
                decoration: const InputDecoration(labelText: 'Dział'),
                items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                onChanged: (v) => setLocal(() => selectedDzialId = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nazwa sekcji')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || selectedDzialId == null) return;
                Navigator.pop(ctx, _SekcjaEditData(name, selectedDzialId!));
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  Future<_MaszynaEditData?> _showMaszynaEditDialog(Maszyna m) {
    final nameCtrl = TextEditingController(text: m.nazwa);
    int? selectedDzialId = m.dzial?.id;
    Set<int> selectedSekcjaIds = m.sekcje.map((s) => s.id).toSet();
    return showDialog<_MaszynaEditData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edytuj maszynę'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedDzialId,
                decoration: const InputDecoration(labelText: 'Dział'),
                items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                onChanged: (v) => setLocal(() {
                  selectedDzialId = v;
                  selectedSekcjaIds = selectedSekcjaIds
                      .where((id) => _sekcje.any((s) => s.id == id && (v == null || s.dzial?.id == v)))
                      .toSet();
                }),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sekcje',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _sekcje
                    .where((s) => selectedDzialId == null || s.dzial?.id == selectedDzialId)
                    .map((s) {
                  final selected = selectedSekcjaIds.contains(s.id);
                  return FilterChip(
                    label: Text(s.nazwa),
                    selected: selected,
                    onSelected: (_) => setLocal(() {
                      if (selected) {
                        selectedSekcjaIds = {...selectedSekcjaIds}..remove(s.id);
                      } else {
                        selectedSekcjaIds = {...selectedSekcjaIds, s.id};
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nazwa maszyny')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty || selectedDzialId == null || selectedSekcjaIds.isEmpty) return;
                Navigator.pop(ctx, _MaszynaEditData(name, selectedDzialId!, selectedSekcjaIds.toList()));
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  Future<_OsobaEditData?> _showOsobaEditDialog(Osoba o) {
    final imieCtrl = TextEditingController(text: o.imieNazwisko);
    final loginCtrl = TextEditingController(text: o.login ?? '');
    final hasloCtrl = TextEditingController();
    final rolaCtrl = TextEditingController(text: o.rola ?? '');
    int? selectedDzialId = o.dzialId;
    return showDialog<_OsobaEditData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edytuj osobę'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: imieCtrl, decoration: const InputDecoration(labelText: 'Imię i nazwisko')),
                const SizedBox(height: 8),
                TextField(controller: loginCtrl, decoration: const InputDecoration(labelText: 'Login (opcjonalnie)')),
                const SizedBox(height: 8),
                TextField(controller: hasloCtrl, decoration: const InputDecoration(labelText: 'Nowe hasło (opcjonalnie)')),
                const SizedBox(height: 8),
                TextField(controller: rolaCtrl, decoration: const InputDecoration(labelText: 'Rola (opcjonalnie)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDzialId,
                  decoration: const InputDecoration(labelText: 'Dział (opcjonalnie)'),
                  items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                  onChanged: (v) => setLocal(() => selectedDzialId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () {
                final imie = imieCtrl.text.trim();
                if (imie.isEmpty) return;
                Navigator.pop(
                  ctx,
                  _OsobaEditData(
                    imieNazwisko: imie,
                    login: loginCtrl.text.trim().isEmpty ? null : loginCtrl.text.trim(),
                    haslo: hasloCtrl.text.trim().isEmpty ? null : hasloCtrl.text.trim(),
                    rola: rolaCtrl.text.trim().isEmpty ? null : rolaCtrl.text.trim(),
                    dzialId: selectedDzialId,
                  ),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      imieCtrl.dispose();
      loginCtrl.dispose();
      hasloCtrl.dispose();
      rolaCtrl.dispose();
    });
  }

  Future<_ApiUserEditData?> _showApiUserEditDialog(AdminUser u) {
    final usernameCtrl = TextEditingController(text: u.username);
    final emailCtrl = TextEditingController(text: u.email ?? '');
    final passwordCtrl = TextEditingController();
    bool isAdmin = u.roles.contains('ROLE_ADMIN');
    int? selectedDzialId = u.dzialId;
    Set<String> selectedModules = {...u.modules};

    return showDialog<_ApiUserEditData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edytuj użytkownika API'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Login')),
                const SizedBox(height: 8),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-mail')),
                const SizedBox(height: 8),
                TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Nowe hasło (opcjonalnie)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDzialId,
                  decoration: const InputDecoration(labelText: 'Dział (opcjonalnie)'),
                  items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                  onChanged: (v) => setLocal(() => selectedDzialId = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Admin'),
                  value: isAdmin,
                  onChanged: (v) => setLocal(() => isAdmin = v),
                ),
                const SizedBox(height: 4),
                const Text('Kafelki:'),
                Wrap(
                  spacing: 8,
                  children: _modulesCatalog.map((m) {
                    final selected = selectedModules.contains(m);
                    return FilterChip(
                      label: Text(m),
                      selected: selected,
                      onSelected: (v) => setLocal(() {
                        if (v) {
                          selectedModules = {...selectedModules, m};
                        } else {
                          selectedModules = {...selectedModules}..remove(m);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () {
                final username = usernameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (username.isEmpty || email.isEmpty) return;
                Navigator.pop(
                  ctx,
                  _ApiUserEditData(
                    username: username,
                    email: email,
                    password: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
                    dzialId: selectedDzialId,
                    isAdmin: isAdmin,
                    modules: selectedModules,
                  ),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      usernameCtrl.dispose();
      emailCtrl.dispose();
      passwordCtrl.dispose();
    });
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
        appBar: const TopAppBar(title: 'Brak dostępu', showBack: true),
        body: const Center(child: Text('ADMIN wymagany.')),
      );
    }

    final usersDemo = mock.getUsers();
    final dzialQuery = _dzialSearch.trim().toLowerCase();
    final sekcjaQuery = _sekcjaSearch.trim().toLowerCase();
    final maszynaQuery = _maszynaSearch.trim().toLowerCase();
    final osobaQuery = _osobaSearch.trim().toLowerCase();
    final apiUserQuery = _apiUserSearch.trim().toLowerCase();

    final filteredDzialy = _dzialy.where((d) {
      return d.nazwa.toLowerCase().contains(dzialQuery);
    }).toList();
    final filteredSekcje = _sekcje.where((s) {
      final dzialName = s.dzial?.nazwa.toLowerCase() ?? '';
      return s.nazwa.toLowerCase().contains(sekcjaQuery) || dzialName.contains(sekcjaQuery);
    }).toList();
    final filteredMaszyny = _maszyny.where((m) {
      final dzialName = m.dzial?.nazwa.toLowerCase() ?? '';
      final sekcjaName = m.sekcje.map((s) => s.nazwa.toLowerCase()).join(' ');
      return m.nazwa.toLowerCase().contains(maszynaQuery) ||
          dzialName.contains(maszynaQuery) ||
          sekcjaName.contains(maszynaQuery);
    }).toList();
    final filteredOsoby = _osoby.where((o) {
      return o.imieNazwisko.toLowerCase().contains(osobaQuery);
    }).toList();
    final filteredUsers = _users.where((u) {
      final roles = u.roles.join(', ').toLowerCase();
      final modules = u.modules.join(', ').toLowerCase();
      final dzial = u.dzialNazwa?.toLowerCase() ?? '';
      return u.username.toLowerCase().contains(apiUserQuery) ||
          roles.contains(apiUserQuery) ||
          modules.contains(apiUserQuery) ||
          dzial.contains(apiUserQuery);
    }).toList();

    return Scaffold(
      appBar: const TopAppBar(title: 'Panel Admina', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CardSection(
                    title: 'Działy',
                    badgeText: '${filteredDzialy.length}/${_dzialy.length}',
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
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj działu',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _dzialSearch = v),
                        ),
                        const SizedBox(height: 8),
                        ...filteredDzialy.map((d) => ListTile(
                              title: Text(d.nazwa),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editDzial(d),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showConfirmDialog(context, 'Usuń dział', 'Usunąć ${d.nazwa}?');
                                      if (ok == true) await _deleteDzial(d.id);
                                    },
                                  ),
                                ],
                              ),
                            )),
                        if (filteredDzialy.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brak działów pasujących do wyszukiwania.'),
                          ),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Sekcje',
                    badgeText: '${filteredSekcje.length}/${_sekcje.length}',
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _sekcjaDzialId,
                          decoration: const InputDecoration(labelText: 'Dział sekcji'),
                          items: _dzialy
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                              .toList(),
                          onChanged: (v) => setState(() => _sekcjaDzialId = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _sekcjaCtrl,
                                decoration: const InputDecoration(labelText: 'Nazwa sekcji'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addSekcja,
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj sekcji',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _sekcjaSearch = v),
                        ),
                        const SizedBox(height: 8),
                        ...filteredSekcje.map((s) => ListTile(
                              title: Text(s.nazwa),
                              subtitle: Text(s.dzial?.nazwa ?? '-'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editSekcja(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showConfirmDialog(context, 'Usuń sekcję', 'Usunąć ${s.nazwa}?');
                                      if (ok == true) await _deleteSekcja(s.id);
                                    },
                                  ),
                                ],
                              ),
                            )),
                        if (filteredSekcje.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brak sekcji pasujących do wyszukiwania.'),
                          ),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Maszyny',
                    badgeText: '${filteredMaszyny.length}/${_maszyny.length}',
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _maszynaDzialId,
                          decoration: const InputDecoration(labelText: 'Dział'),
                          items: _dzialy
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _maszynaDzialId = v;
                            _maszynaSekcjaIds = _maszynaSekcjaIds
                                .where((id) => _sekcje.any((s) => s.id == id && (v == null || s.dzial?.id == v)))
                                .toSet();
                          }),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sekcje (możesz wybrać wiele)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _sekcje
                              .where((s) => _maszynaDzialId == null || s.dzial?.id == _maszynaDzialId)
                              .map((s) {
                            final selected = _maszynaSekcjaIds.contains(s.id);
                            return FilterChip(
                              label: Text(s.nazwa),
                              selected: selected,
                              onSelected: (_) => setState(() {
                                if (selected) {
                                  _maszynaSekcjaIds = {..._maszynaSekcjaIds}..remove(s.id);
                                } else {
                                  _maszynaSekcjaIds = {..._maszynaSekcjaIds, s.id};
                                }
                              }),
                            );
                          }).toList(),
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
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj maszyny / działu / sekcji',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _maszynaSearch = v),
                        ),
                        const SizedBox(height: 8),
                        ...filteredMaszyny.map((m) => ListTile(
                              title: Text(m.nazwa),
                              subtitle: Text('${m.dzial?.nazwa ?? '-'} / ${m.sekcje.isEmpty ? '-' : m.sekcje.map((s) => s.nazwa).join(', ')}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editMaszyna(m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showConfirmDialog(context, 'Usuń maszynę', 'Usunąć ${m.nazwa}?');
                                      if (ok == true) await _deleteMaszyna(m.id);
                                    },
                                  ),
                                ],
                              ),
                            )),
                        if (filteredMaszyny.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brak maszyn pasujących do wyszukiwania.'),
                          ),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Osoby',
                    badgeText: '${filteredOsoby.length}/${_osoby.length}',
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _osobaDzialId,
                          decoration: const InputDecoration(labelText: 'Dział (opcjonalnie)'),
                          items: _dzialy.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa))).toList(),
                          onChanged: (v) => setState(() => _osobaDzialId = v),
                        ),
                        const SizedBox(height: 8),
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
                              onPressed: _addOsoba,
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj osoby',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _osobaSearch = v),
                        ),
                        const SizedBox(height: 8),
                        ...filteredOsoby.map((o) => ListTile(
                              title: Text(o.imieNazwisko),
                              subtitle: Text('${o.dzialNazwa ?? '-'} / ${o.rola ?? '-'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editOsoba(o),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showConfirmDialog(context, 'Usuń osobę', 'Usunąć ${o.imieNazwisko}?');
                                      if (ok == true) await _deleteOsoba(o.id);
                                    },
                                  ),
                                ],
                              ),
                            )),
                        if (filteredOsoby.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brak osób pasujących do wyszukiwania.'),
                          ),
                      ],
                    ),
                  ),
                  _CardSection(
                    title: 'Użytkownicy (API) – role i kafelki',
                    badgeText: '${filteredUsers.length}/${_users.length}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          value: _apiUserDzialId,
                          decoration: const InputDecoration(labelText: 'Dział (opcjonalnie)'),
                          items: _dzialy
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nazwa)))
                              .toList(),
                          onChanged: (v) => setState(() => _apiUserDzialId = v),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiUserUsernameCtrl,
                          decoration: const InputDecoration(labelText: 'Login (username) – wymagany'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiUserPasswordCtrl,
                          decoration: const InputDecoration(labelText: 'Hasło – wymagane'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiUserEmailCtrl,
                          decoration: const InputDecoration(labelText: 'E-mail – wymagany'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _apiUserRole,
                          decoration: const InputDecoration(labelText: 'Rola'),
                          items: const [
                            DropdownMenuItem(value: 'USER', child: Text('USER')),
                            DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                          ],
                          onChanged: (v) => setState(() => _apiUserRole = v ?? 'USER'),
                        ),
                        const SizedBox(height: 8),
                        const Text('Kafelki (modules):'),
                        Wrap(
                          spacing: 8,
                          children: _modulesCatalog.map((m) {
                            final selected = _apiUserModules.contains(m);
                            return FilterChip(
                              label: Text(m),
                              selected: selected,
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _apiUserModules = {..._apiUserModules, m};
                                } else {
                                  _apiUserModules = {..._apiUserModules}..remove(m);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _createApiUser,
                            child: const Text('Utwórz użytkownika'),
                          ),
                        ),
                        const Divider(height: 24),
                        const Text('Lista użytkowników:'),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Szukaj użytkownika API',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _apiUserSearch = v),
                        ),
                        const SizedBox(height: 8),
                        ...filteredUsers.map((u) => ListTile(
                              title: Text(u.username),
                              subtitle: Text('Role: ' + (u.roles.join(', ')) + '\nKafelki: ' + (u.modules.join(', '))),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editApiUser(u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showConfirmDialog(context, 'Usuń użytkownika', 'Usunąć ${u.username}?');
                                      if (ok == true) await _deleteApiUser(u.id);
                                    },
                                  ),
                                ],
                              ),
                            )),
                        if (filteredUsers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Brak użytkowników API pasujących do wyszukiwania.'),
                          ),
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
                        ...usersDemo.map((u) => ListTile(
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
                  const Center(child: Text('Działy/Sekcje/Maszyny/Osoby zapisują się do bazy. Sekcja Użytkownicy (API) to realni użytkownicy z rolami i kafelkami. Sekcja Użytkownicy (DEMO) to lokalny mock.')),
                ],
              ),
            ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? badgeText;
  final bool initiallyExpanded;
  const _CardSection({
    required this.title,
    required this.child,
    this.badgeText,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: badgeText != null ? Text('Pozycji: $badgeText') : null,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SekcjaEditData {
  final String nazwa;
  final int dzialId;
  _SekcjaEditData(this.nazwa, this.dzialId);
}

class _MaszynaEditData {
  final String nazwa;
  final int dzialId;
  final List<int> sekcjaIds;
  _MaszynaEditData(this.nazwa, this.dzialId, this.sekcjaIds);
}

class _OsobaEditData {
  final String imieNazwisko;
  final int? dzialId;
  final String? login;
  final String? haslo;
  final String? rola;

  _OsobaEditData({
    required this.imieNazwisko,
    required this.dzialId,
    required this.login,
    required this.haslo,
    required this.rola,
  });
}

class _ApiUserEditData {
  final String username;
  final String email;
  final String? password;
  final int? dzialId;
  final bool isAdmin;
  final Set<String> modules;

  _ApiUserEditData({
    required this.username,
    required this.email,
    required this.password,
    required this.dzialId,
    required this.isAdmin,
    required this.modules,
  });
}

