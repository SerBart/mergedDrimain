import 'package:flutter/material.dart';

Future<void> showSuccessDialog(BuildContext context, String title, String message) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title, style: const TextStyle(color: Colors.green)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    ),
  );
}

Future<void> showErrorDialog(BuildContext context, String title, String message) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title, style: const TextStyle(color: Colors.red)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zamknij')),
      ],
    ),
  );
}

Future<bool?> showConfirmDialog(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Potwierdź')),
      ],
    ),
  );
}