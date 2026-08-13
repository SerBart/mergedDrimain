import 'package:flutter/material.dart';

class KpiAlertItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const KpiAlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class KpiAlertBanner extends StatelessWidget {
  final List<KpiAlertItem> items;
  final ValueChanged<KpiAlertItem>? onMute;

  const KpiAlertBanner({
    super.key,
    required this.items,
    this.onMute,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Brak alertów krytycznych.');
    }

    return Column(
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.color.withOpacity(.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.color.withOpacity(.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(item.message, style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                  if (onMute != null)
                    IconButton(
                      tooltip: 'Wycisz ten alert',
                      onPressed: () => onMute?.call(item),
                      icon: const Icon(Icons.volume_off_outlined, size: 20),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

