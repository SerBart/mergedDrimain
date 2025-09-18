import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= Breakpoints.desktop && desktop != null) return desktop!;
    if (w >= Breakpoints.tablet && tablet != null) return tablet!;
    return mobile;
  }
}