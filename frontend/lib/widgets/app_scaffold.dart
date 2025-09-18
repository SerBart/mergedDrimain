import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;
  final bool constrained;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.constrained = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: constrained ? Layout.maxContentWidth : double.infinity,
        ),
        child: Padding(
          padding: padding,
          child: body,
        ),
      ),
    );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const _NoGlowBehavior(),
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}