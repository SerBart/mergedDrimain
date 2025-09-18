// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import '../../core/providers/app_providers.dart';
// import '../../core/models/zgloszenie.dart';
// import '../../widgets/status_chip.dart';

// class ZgloszeniaListScreen extends ConsumerStatefulWidget {
//   const ZgloszeniaListScreen({super.key});

//   @override
//   ConsumerState<ZgloszeniaListScreen> createState() => _ZgloszeniaListScreenState();
// }

// class _ZgloszeniaListScreenState extends ConsumerState<ZgloszeniaListScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _imieCtrl = TextEditingController();
//   final _nazCtrl = TextEditingController();
//   final _opisCtrl = TextEditingController();
//   String _status = 'NOWE';
//   String _typ = 'Usterka';
//   String? _photoBase64;

//   final _searchCtrl = TextEditingController();
//   String _query = '';
//   String _statusFilter = 'WSZYSTKIE';
//   int _sortColumn = 1;
//   bool _sortAsc = false;

//   final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');
//   static const types = ['Usterka', 'Awaria', 'Przezbrojenie'];

//   @override
//   void dispose() {
//     _imieCtrl.dispose();
//     _nazCtrl.dispose();
//     _opisCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   void _reset() {
//     _imieCtrl.clear();
//     _nazCtrl.clear();
//     _opisCtrl.clear();
//     _status = 'NOWE';
//     _typ = 'Usterka';
//     _photoBase64 = null;
//   }

//   Future<void> _pickPhoto({bool camera = false}) async {
//     final picker = ImagePicker();
//     final file = await picker.pickImage(
//       source: camera ? ImageSource.camera : ImageSource.gallery,
//       maxWidth: 1600,
//       imageQuality: 80,
//     );
//     if (file != null) {
//       final bytes = await file.readAsBytes();
//       setState(() => _photoBase64 = base64Encode(bytes));
//     }
//   }

//   void _add() {
//     if (!_formKey.currentState!.validate()) return;
//     ref.read(mockRepoProvider).addZgloszenie(
//           Zgloszenie(
//             id: 0,
//             imie: _imieCtrl.text.trim(),
//             nazwisko: _nazCtrl.text.trim(),
//             typ: _typ,
//             dataGodzina: DateTime.now(),
//             opis: _opisCtrl.text.trim(),
//             status: _status,
//             photoBase64: _photoBase64,
//           ),
//         );
//     _reset();
//     setState(() {});
//   }

//   List<Zgloszenie> _filteredAndSorted(List<Zgloszenie> all) {
//     var base = all;
//     if (_query.isNotEmpty) {
//       final q = _query.toLowerCase();
//       base = base.where((z) {
//         return z.typ.toLowerCase().contains(q) ||
//             z.opis.toLowerCase().contains(q) ||
//             z.imie.toLowerCase().contains(q) ||
//             z.nazwisko.toLowerCase().contains(q) ||
//             z.status.toLowerCase().contains(q) ||
//             z.id.toString() == q;
//       }).toList();
//     }
//     if (_statusFilter != 'WSZYSTKIE') {
//       base = base.where((z) => z.status.toUpperCase() == _statusFilter).toList();
//     }
//     base.sort((a, b) {
//       int cmp;
//       switch (_sortColumn) {
//         case 0:
//           cmp = a.id.compareTo(b.id);
//           break;
//         case 1:
//           cmp = a.dataGodzina.compareTo(b.dataGodzina);
//           break;
//         case 2:
//           cmp = a.typ.compareTo(b.typ);
//           break;
//         case 3:
//           cmp = ('${a.imie} ${a.nazwisko}').compareTo('${b.imie} ${b.nazwisko}');
//           break;
//         case 4:
//           cmp = a.status.compareTo(b.status);
//           break;
//         default:
//           cmp = b.id.compareTo(a.id);
//       }
//       return _sortAsc ? cmp : -cmp;
//     });
//     return base;
//   }

//   void _onSort(int i, bool asc) => setState(() {
//         _sortColumn = i;
//         _sortAsc = asc;
//       });

//   void _editDialog(Zgloszenie z) {
//     final imie = TextEditingController(text: z.imie);
//     final nazw = TextEditingController(text: z.nazwisko);
//     final opis = TextEditingController(text: z.opis);
//     String status = z.status;
//     String typ = types.contains(z.typ) ? z.typ : types.first;
//     String? localPhoto = z.photoBase64;

//     showDialog(
//       context: context,
//       builder: (_) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 520),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: StatefulBuilder(
//               builder: (ctx, setLocal) => SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Row(
//                       children: [
//                         Text('Edytuj #${z.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//                         const Spacer(),
//                         IconButton(
//                           icon: const Icon(Icons.close),
//                           onPressed: () => Navigator.pop(context),
//                         )
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: TextField(
//                             controller: imie,
//                             decoration: const InputDecoration(labelText: 'Imię'),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: TextField(
//                             controller: nazw,
//                             decoration: const InputDecoration(labelText: 'Nazwisko'),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     DropdownButtonFormField<String>(
//                       value: typ,
//                       decoration: const InputDecoration(labelText: 'Typ'),
//                       items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
//                       onChanged: (v) => setLocal(() => typ = v ?? typ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: opis,
//                       maxLines: 3,
//                       decoration: const InputDecoration(labelText: 'Opis'),
//                     ),
//                     const SizedBox(height: 12),
//                     DropdownButtonFormField<String>(
//                       value: status,
//                       decoration: const InputDecoration(labelText: 'Status'),
//                       items: const [
//                         DropdownMenuItem(value: 'NOWE', child: Text('NOWE')),
//                         DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
//                         DropdownMenuItem(value: 'WERYFIKACJA', child: Text('WERYFIKACJA')),
//                         DropdownMenuItem(value: 'ZAMKNIĘTE', child: Text('ZAMKNIĘTE')),
//                       ],
//                       onChanged: (v) => setLocal(() => status = v ?? status),
//                     ),
//                     const SizedBox(height: 16),
//                     _EditPhotoBlock(
//                       base64: localPhoto,
//                       onChanged: (b) => setLocal(() => localPhoto = b),
//                     ),
//                     const SizedBox(height: 20),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             'Ost. modyfikacja: ${_dtf.format(z.lastUpdated)}',
//                             style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                           ),
//                         ),
//                         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
//                         const SizedBox(width: 8),
//                         ElevatedButton(
//                           onPressed: () {
//                             ref.read(mockRepoProvider).updateZgloszenie(
//                                   z.copyWith(
//                                     imie: imie.text.trim(),
//                                     nazwisko: nazw.text.trim(),
//                                     typ: typ,
//                                     opis: opis.text.trim(),
//                                     status: status,
//                                     photoBase64: localPhoto,
//                                   ),
//                                 );
//                             Navigator.pop(context);
//                             setState(() {});
//                           },
//                           child: const Text('Zapisz'),
//                         ),
//                       ],
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _confirmDelete(Zgloszenie z) async {
//     final res = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Usuń zgłoszenie #${z.id}?'),
//         content: const Text('Tej operacji nie można cofnąć (demo).'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
//           ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń')),
//         ],
//       ),
//     );
//     if (res == true) {
//       ref.read(mockRepoProvider).deleteZgloszenie(z.id);
//       setState(() {});
//     }
//   }

//   Widget _statusFilterChip(String label) {
//     final selected = _statusFilter == label;
//     return Padding(
//       padding: const EdgeInsets.only(right: 8),
//       child: ChoiceChip(
//         label: Text(label),
//         selected: selected,
//         onSelected: (_) => setState(() => _statusFilter = label),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final repo = ref.watch(mockRepoProvider);
//     final lista = _filteredAndSorted(repo.getZgloszenia());
//     final isWide = MediaQuery.of(context).size.width > 900;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Zgłoszenia')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
//             child: TextField(
//               controller: _searchCtrl,
//               decoration: InputDecoration(
//                 labelText: 'Szukaj (id / typ / opis / imię / nazwisko / status)',
//                 prefixIcon: const Icon(Icons.search),
//                 suffixIcon: _query.isNotEmpty
//                     ? IconButton(
//                         icon: const Icon(Icons.clear),
//                         onPressed: () {
//                           _searchCtrl.clear();
//                           setState(() => _query = '');
//                         },
//                       )
//                     : null,
//               ),
//               onChanged: (v) => setState(() => _query = v),
//             ),
//           ),
//           SizedBox(
//             height: 40,
//             child: ListView(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               children: [
//                 _statusFilterChip('WSZYSTKIE'),
//                 _statusFilterChip('NOWE'),
//                 _statusFilterChip('W TOKU'),
//                 _statusFilterChip('WERYFIKACJA'),
//                 _statusFilterChip('ZAMKNIĘTE'),
//               ],
//             ),
//           ),
//           ExpansionTile(
//             title: const Text('Dodaj zgłoszenie'),
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       if (isWide)
//                         Row(
//                           children: [
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _imieCtrl,
//                                 decoration: const InputDecoration(labelText: 'Imię'),
//                                 validator: (v) => v == null || v.trim().isEmpty ? 'Wymagane' : null,
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _nazCtrl,
//                                 decoration: const InputDecoration(labelText: 'Nazwisko'),
//                                 validator: (v) => v == null || v.trim().isEmpty ? 'Wymagane' : null,
//                               ),
//                             ),
//                           ],
//                         )
//                       else ...[
//                         TextFormField(
//                           controller: _imieCtrl,
//                           decoration: const InputDecoration(labelText: 'Imię'),
//                           validator: (v) => v == null || v.trim().isEmpty ? 'Wymagane' : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _nazCtrl,
//                           decoration: const InputDecoration(labelText: 'Nazwisko'),
//                           validator: (v) => v == null || v.trim().isEmpty ? 'Wymagane' : null,
//                         ),
//                       ],
//                       const SizedBox(height: 12),
//                       DropdownButtonFormField<String>(
//                         value: _typ,
//                         decoration: const InputDecoration(labelText: 'Typ'),
//                         items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
//                         onChanged: (v) => setState(() => _typ = v ?? _typ),
//                       ),
//                       const SizedBox(height: 12),
//                       TextFormField(
//                         controller: _opisCtrl,
//                         maxLines: 3,
//                         decoration: const InputDecoration(labelText: 'Opis'),
//                       ),
//                       const SizedBox(height: 12),
//                       DropdownButtonFormField<String>(
//                         value: _status,
//                         decoration: const InputDecoration(labelText: 'Status'),
//                         items: const [
//                           DropdownMenuItem(value: 'NOWE', child: Text('NOWE')),
//                           DropdownMenuItem(value: 'W TOKU', child: Text('W TOKU')),
//                           DropdownMenuItem(value: 'WERYFIKACJA', child: Text('WERYFIKACJA')),
//                           DropdownMenuItem(value: 'ZAMKNIĘTE', child: Text('ZAMKNIĘTE')),
//                         ],
//                         onChanged: (v) => setState(() => _status = v ?? 'NOWE'),
//                       ),
//                       const SizedBox(height: 16),
//                       _AddPhotoBlock(
//                         base64: _photoBase64,
//                         onPickGallery: () => _pickPhoto(),
//                         onPickCamera: () => _pickPhoto(camera: true),
//                         onRemove: () => setState(() => _photoBase64 = null),
//                       ),
//                       const SizedBox(height: 16),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: ElevatedButton.icon(
//                           onPressed: _add,
//                           icon: const Icon(Icons.add),
//                           label: const Text('Dodaj'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const Divider(height: 1),
//           Expanded(
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: DataTable(
//                 sortColumnIndex: _sortColumn,
//                 sortAscending: _sortAsc,
//                 columns: [
//                   DataColumn(label: const Text('ID'), numeric: true, onSort: _onSort),
//                   DataColumn(label: const Text('Czas'), onSort: _onSort),
//                   DataColumn(label: const Text('Typ'), onSort: _onSort),
//                   DataColumn(label: const Text('Zgłaszający'), onSort: _onSort),
//                   DataColumn(label: const Text('Status'), onSort: _onSort),
//                   const DataColumn(label: Text('Opis')),
//                   const DataColumn(label: Text('Foto')),
//                   const DataColumn(label: Text('Akcje')),
//                 ],
//                 rows: lista.map((z) {
//                   return DataRow(
//                     cells: [
//                       DataCell(Text(z.id.toString())),
//                       DataCell(Text(_dtf.format(z.dataGodzina))),
//                       DataCell(Text(z.typ)),
//                       DataCell(Text('${z.imie} ${z.nazwisko}')),
//                       DataCell(StatusChip(status: z.status)),
//                       DataCell(SizedBox(
//                         width: 200,
//                         child: Tooltip(
//                           message: z.opis,
//                           child: Text(z.opis, maxLines: 2, overflow: TextOverflow.ellipsis),
//                         ),
//                       )),
//                       DataCell(_Thumb(base64: z.photoBase64, onTap: z.photoBase64 == null ? null : () => _showPhoto(z.photoBase64!))),
//                       DataCell(
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             IconButton(
//                               tooltip: 'Edytuj',
//                               icon: const Icon(Icons.edit, color: Colors.blue),
//                               onPressed: () => _editDialog(z),
//                             ),
//                             IconButton(
//                               tooltip: 'Usuń',
//                               icon: const Icon(Icons.delete, color: Colors.red),
//                               onPressed: () => _confirmDelete(z),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showPhoto(String b64) {
//     try {
//       final bytes = base64Decode(b64);
//       showDialog(
//         context: context,
//         builder: (_) => Dialog(
//           child: GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: InteractiveViewer(
//               child: Image.memory(bytes, fit: BoxFit.contain),
//             ),
//           ),
//         ),
//       );
//     } catch (_) {}
//   }
// }

// class _AddPhotoBlock extends StatelessWidget {
//   final String? base64;
//   final VoidCallback onPickGallery;
//   final VoidCallback onPickCamera;
//   final VoidCallback onRemove;
//   const _AddPhotoBlock({
//     required this.base64,
//     required this.onPickGallery,
//     required this.onPickCamera,
//     required this.onRemove,
//   });

//   @override
//   Widget build(BuildContext context) {
//     Widget preview;
//     if (base64 != null) {
//       try {
//         preview = ClipRRect(
//           borderRadius: BorderRadius.circular(12),
//           child: Image.memory(
//             base64Decode(base64!),
//             width: 80,
//             height: 80,
//             fit: BoxFit.cover,
//           ),
//         );
//       } catch (_) {
//         preview = const Icon(Icons.error, color: Colors.red);
//       }
//     } else {
//       preview = Container(
//         width: 80,
//         height: 80,
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.grey.shade400),
//         ),
//         child: const Icon(Icons.image, color: Colors.grey),
//       );
//     }

//     return Row(
//       children: [
//         preview,
//         const SizedBox(width: 16),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ElevatedButton.icon(
//               onPressed: onPickGallery,
//               icon: const Icon(Icons.photo),
//               label: Text(base64 == null ? 'Wybierz zdjęcie' : 'Zmień'),
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 OutlinedButton.icon(
//                   onPressed: onPickCamera,
//                   icon: const Icon(Icons.camera_alt_outlined),
//                   label: const Text('Aparat'),
//                 ),
//                 if (base64 != null) ...[
//                   const SizedBox(width: 8),
//                   TextButton.icon(
//                     onPressed: onRemove,
//                     icon: const Icon(Icons.delete_outline, color: Colors.red),
//                     label: const Text('Usuń', style: TextStyle(color: Colors.red)),
//                   ),
//                 ]
//               ],
//             ),
//           ],
//         )
//       ],
//     );
//   }
// }

// class _Thumb extends StatelessWidget {
//   final String? base64;
//   final VoidCallback? onTap;
//   const _Thumb({this.base64, this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     if (base64 == null) {
//       return const SizedBox(
//         width: 44,
//         height: 44,
//         child: Icon(Icons.image_not_supported, size: 18, color: Colors.grey),
//       );
//     }
//     try {
//       final bytes = base64Decode(base64!);
//       return InkWell(
//         onTap: onTap,
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(6),
//           child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
//         ),
//       );
//     } catch (_) {
//       return const Icon(Icons.error, color: Colors.redAccent);
//     }
//   }
// }

// class _EditPhotoBlock extends StatelessWidget {
//   final String? base64;
//   final ValueChanged<String?> onChanged;
//   const _EditPhotoBlock({required this.base64, required this.onChanged});

//   Future<void> _pick(bool camera) async {
//     final picker = ImagePicker();
//     final f = await picker.pickImage(
//       source: camera ? ImageSource.camera : ImageSource.gallery,
//       maxWidth: 1600,
//       imageQuality: 80,
//     );
//     if (f != null) {
//       final bytes = await f.readAsBytes();
//       onChanged(base64Encode(bytes));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget thumb;
//     if (base64 != null) {
//       try {
//         thumb = ClipRRect(
//           borderRadius: BorderRadius.circular(12),
//           child: Image.memory(base64Decode(base64!), width: 80, height: 80, fit: BoxFit.cover),
//         );
//       } catch (_) {
//         thumb = const Icon(Icons.error, color: Colors.redAccent);
//       }
//     } else {
//       thumb = Container(
//         width: 80,
//         height: 80,
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.grey.shade400),
//         ),
//         child: const Icon(Icons.image, color: Colors.grey),
//       );
//     }
//     return Row(
//       children: [
//         thumb,
//         const SizedBox(width: 16),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ElevatedButton.icon(
//               onPressed: () => _pick(false),
//               icon: const Icon(Icons.photo),
//               label: Text(base64 == null ? 'Wybierz' : 'Zmień'),
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 OutlinedButton.icon(
//                   onPressed: () => _pick(true),
//                   icon: const Icon(Icons.camera_alt_outlined),
//                   label: const Text('Aparat'),
//                 ),
//                 if (base64 != null) ...[
//                   const SizedBox(width: 8),
//                   TextButton.icon(
//                     onPressed: () => onChanged(null),
//                     icon: const Icon(Icons.delete_outline, color: Colors.red),
//                     label: const Text('Usuń', style: TextStyle(color: Colors.red)),
//                   )
//                 ]
//               ],
//             ),
//           ],
//         )
//       ],
//     );
//   }
// }