import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

class PanelShell extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const PanelShell({
    super.key,
    required this.children,
    this.gap = Spacing.xl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final width = constraints.maxWidth;
      int columns = 1;
      if (width > 1200) {
        columns = 3;
      } else if (width > 800) {
        columns = 2;
      }
      final itemWidth = (width - (gap * (columns - 1))) / columns;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((w) => SizedBox(width: itemWidth, child: w))
            .toList(),
      );
    });
  }
}