import 'package:flutter/material.dart';

/// A reusable wrapper that centers a card horizontally and lets its width
/// grow to match its content. If the content is wider than the viewport,
/// a horizontal scrollbar is provided.
class CenteredScrollableCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableHorizontalScroll;

  const CenteredScrollableCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(0),
    this.enableHorizontalScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = IntrinsicWidth(child: Card(child: child));
    if (enableHorizontalScroll) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: content),
      );
    }
    return Padding(
      padding: padding,
      child: content,
    );
  }
}

