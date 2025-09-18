import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool useGradient;
  const StatusChip({super.key, required this.status, this.useGradient = false});

  Color _color(String s) {
    switch (s.toUpperCase()) {
      case 'NOWE':
        return const Color(0xFFF59E0B);
      case 'W TOKU':
        return const Color(0xFF2563EB);
      case 'WERYFIKACJA':
        return const Color(0xFF7C3AED);
      case 'ZAMKNIĘTE':
        return const Color(0xFF16A34A);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    final gradient = LinearGradient(
      colors: [
        c,
        c.withOpacity(.75),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: useGradient ? null : c.withOpacity(.90),
        gradient: useGradient ? gradient : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
      ),
    );
  }
}