import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/direct_message.dart';
import '../../core/models/message_contact.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/top_app_bar.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _messageCtrl = TextEditingController();

  bool _loadingContacts = true;
  bool _loadingThread = false;
  bool _sending = false;
  String? _error;

  List<MessageContact> _contacts = [];
  MessageContact? _selected;
  List<DirectMessage> _messages = [];

  final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    await _loadContactsInternal(loadSelectedThread: true);
  }

  Future<void> _refreshContactsOnly() async {
    await _loadContactsInternal(loadSelectedThread: false);
  }

  Future<void> _loadContactsInternal({required bool loadSelectedThread}) async {
    setState(() {
      _loadingContacts = true;
      _error = null;
    });
    try {
      final repo = ref.read(messagesApiRepositoryProvider);
      final contacts = await repo.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _selected = contacts.isNotEmpty
            ? contacts.firstWhere(
                (c) => c.userId == _selected?.userId,
                orElse: () => contacts.first,
              )
            : null;
      });
      if (loadSelectedThread && _selected != null) {
        await _loadThread(_selected!.userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  Future<void> _loadThread(int userId) async {
    setState(() {
      _loadingThread = true;
      _error = null;
    });
    try {
      final repo = ref.read(messagesApiRepositoryProvider);
      final thread = await repo.fetchThread(userId, limit: 150);
      await repo.markThreadRead(userId);
      if (!mounted) return;
      setState(() => _messages = thread);
      await _refreshContactsOnly();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  Future<void> _send() async {
    final selected = _selected;
    if (selected == null || _sending) return;

    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final repo = ref.read(messagesApiRepositoryProvider);
      await repo.sendMessage(recipientUserId: selected.userId, content: text);
      _messageCtrl.clear();
      await _loadThread(selected.userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd wysyłki: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider);

    return Scaffold(
      appBar: TopAppBar(
        title: 'Wiadomości',
        showBack: true,
        extraActions: [
          IconButton(
            tooltip: 'Odśwież',
            onPressed: _loadingContacts ? null : _loadContacts,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _loadingContacts && _contacts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Błąd: $_error'))
              : Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: Card(
                        margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                        child: ListView.separated(
                          itemCount: _contacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = _contacts[i];
                            final active = _selected?.userId == c.userId;
                            final subtitle = c.lastMessage?.trim().isNotEmpty == true
                                ? c.lastMessage!
                                : 'Brak wiadomości';
                            return ListTile(
                              selected: active,
                              title: Text(c.username),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: c.unreadCount > 0
                                  ? CircleAvatar(
                                      radius: 12,
                                      child: Text('${c.unreadCount}', style: const TextStyle(fontSize: 12)),
                                    )
                                  : null,
                              onTap: () async {
                                setState(() => _selected = c);
                                await _loadThread(c.userId);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(.08))),
                              ),
                              child: Text(
                                _selected != null ? 'Rozmowa z ${_selected!.username}' : 'Wybierz rozmowę',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Expanded(
                              child: _loadingThread
                                  ? const Center(child: CircularProgressIndicator())
                                  : _selected == null
                                      ? const Center(child: Text('Brak użytkowników do rozmowy'))
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(12),
                                          itemCount: _messages.length,
                                          itemBuilder: (ctx, i) {
                                            final m = _messages[i];
                                            final mine = m.senderId == me?.id;
                                            return Align(
                                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(vertical: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                constraints: const BoxConstraints(maxWidth: 520),
                                                decoration: BoxDecoration(
                                                  color: mine ? const Color(0xFFE0F2FE) : const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(m.content),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _dtf.format(m.createdAt?.toLocal() ?? DateTime.now()),
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageCtrl,
                                      minLines: 1,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        hintText: 'Napisz wiadomość...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: (_selected == null || _sending) ? null : _send,
                                    icon: const Icon(Icons.send),
                                    label: Text(_sending ? 'Wysyłanie...' : 'Wyślij'),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}


