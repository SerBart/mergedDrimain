import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final String? title;
  final Widget? action;
  final Widget? footer;
  final bool divided;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.title,
    this.action,
    this.footer,
    this.divided = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || action != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.l, vertical: Spacing.m),
              decoration: BoxDecoration(
                border: divided
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withOpacity(.6),
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const Spacer(),
                  if (action != null) action!,
                ],
              ),
            ),
          Padding(
            padding: padding,
            child: child,
          ),
          if (footer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.l, vertical: Spacing.m),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(.6),
                  ),
                ),
              ),
              child: footer,
            )
        ],
      ),
    );

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: Spacing.xl),
      child: c,
    );
  }
}