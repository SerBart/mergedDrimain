import 'package:flutter/material.dart';

/// Centers a Card horizontally and lets it grow to its intrinsic content width.
/// If content is wider than the viewport, horizontal scroll is enabled.
/// Always aligns to the top vertically (no vertical centering).
class CenteredScrollableCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableHorizontalScroll;

  const CenteredScrollableCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.enableHorizontalScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = IntrinsicWidth(child: Card(child: child));

          if (!enableHorizontalScroll) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content],
            );
          }

          // Ensure the scroll area is at least as wide as the viewport, so centering works
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [content],
              ),
            ),
          );
        },
      ),
    );
  }
}
