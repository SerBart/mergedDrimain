import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/admin_user.dart';
import '../../core/constants/app_roles.dart';
import '../../core/models/announcement.dart';
import '../../core/models/dzial.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Announcement> _items = [];
  List<AdminUser> _users = [];
  List<Dzial> _dzialy = [];

  final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(announcementsApiRepositoryProvider);
      final list = await repo.fetchAll();
      if (ref.read(authStateProvider)?.role == AppRoles.admin) {
        final adminRepo = ref.read(adminApiRepositoryProvider);
        final users = await adminRepo.getUsers();
        final dzialy = await adminRepo.getDzialy();
        if (!mounted) return;
        setState(() {
          _users = users;
          _dzialy = dzialy;
        });
      }
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String targetType = 'ALL';
    int? selectedDzialId;
    final selectedUserIds = <int>{};
    final selectedFiles = <PlatformFile>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Nowe ogłoszenie'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tytuł', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Treść', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: targetType,
                    decoration: const InputDecoration(labelText: 'Kogo dotyczy', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Wszyscy')),
                      DropdownMenuItem(value: 'DEPARTMENT', child: Text('Cały dział')),
                      DropdownMenuItem(value: 'USERS', child: Text('Konkretne osoby')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() {
                        targetType = v;
                        if (v != 'DEPARTMENT') selectedDzialId = null;
                        if (v != 'USERS') selectedUserIds.clear();
                      });
                    },
                  ),
                  if (targetType == 'DEPARTMENT') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedDzialId,
                      decoration: const InputDecoration(labelText: 'Dział', border: OutlineInputBorder()),
                      items: _dzialy
                          .map((d) => DropdownMenuItem<int>(value: d.id, child: Text(d.nazwa)))
                          .toList(),
                      onChanged: (v) => setLocalState(() => selectedDzialId = v),
                    ),
                  ],
                  if (targetType == 'USERS') ...[
                    const SizedBox(height: 12),
                    const Text('Wybierz użytkowników:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _users
                          .map(
                            (u) => FilterChip(
                              label: Text(u.username),
                              selected: selectedUserIds.contains(u.id),
                              onSelected: (sel) {
                                setLocalState(() {
                                  if (sel) {
                                    selectedUserIds.add(u.id);
                                  } else {
                                    selectedUserIds.remove(u.id);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: const [
                          'jpg',
                          'jpeg',
                          'png',
                          'gif',
                          'webp',
                          'pdf',
                          'txt',
                          'csv',
                          'xls',
                          'xlsx',
                          'doc',
                          'docx',
                          'zip',
                        ],
                      );
                      if (result == null || result.files.isEmpty) return;
                      setLocalState(() {
                        selectedFiles.addAll(result.files);
                      });
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Dodaj pliki/zdjęcia'),
                  ),
                  if (selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...selectedFiles.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined, size: 18),
                        title: Text(entry.value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setLocalState(() => selectedFiles.removeAt(entry.key)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Opublikuj')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    setState(() => _saving = true);
    try {
      if (targetType == 'DEPARTMENT' && selectedDzialId == null) {
        throw Exception('Wybierz dział dla tego ogłoszenia.');
      }
      if (targetType == 'USERS' && selectedUserIds.isEmpty) {
        throw Exception('Wybierz co najmniej jednego użytkownika.');
      }

      final repo = ref.read(announcementsApiRepositoryProvider);
      final created = await repo.create(
        title: titleCtrl.text.trim(),
        content: contentCtrl.text.trim(),
        targetType: targetType,
        targetDzialId: selectedDzialId,
        targetUserIds: selectedUserIds.toList(),
      );
      if (selectedFiles.isNotEmpty) {
        await repo.uploadAttachments(announcementId: created.id, files: selectedFiles);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano ogłoszenie')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
      titleCtrl.dispose();
      contentCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authStateProvider)?.role == AppRoles.admin;

    return Scaffold(
      appBar: TopAppBar(
        title: 'Ogłoszenia',
        showBack: true,
        extraActions: [
          IconButton(
            tooltip: 'Odśwież',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _openCreateDialog,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(_saving ? 'Zapisywanie...' : 'Nowe ogłoszenie'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Błąd: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Brak ogłoszeń'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        itemBuilder: (ctx, i) {
                          final a = _items[i];
                          final when = a.createdAt != null
                              ? _dtf.format(a.createdAt!.toLocal())
                              : '-';
                          final targetLabel = a.targetType == 'DEPARTMENT'
                              ? 'Dział: ${a.targetDzialNazwa ?? '-'}'
                              : a.targetType == 'USERS'
                                  ? 'Osoby: ${a.targetUserIds.length}'
                                  : 'Wszyscy';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${a.createdByUsername ?? 'system'} • $when',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    targetLabel,
                                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(a.content),
                                  if (a.attachments.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    ...a.attachments.map(
                                      (att) => Row(
                                        children: [
                                          const Icon(Icons.attach_file, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              att.originalFilename,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

