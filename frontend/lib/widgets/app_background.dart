import 'package:flutter/material.dart';

/// Global decorative background used across the whole app.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = Color.alphaBlend(scheme.primary.withOpacity(.14), scheme.surface);
    final mid = Color.alphaBlend(scheme.secondary.withOpacity(.22), scheme.surface);

    return Stack(
      children: [
        // Opaque base eliminates route flash-through between page transitions.
        ColoredBox(color: scheme.surface),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                top,
                mid,
                scheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withOpacity(.12),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary.withOpacity(.12),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

