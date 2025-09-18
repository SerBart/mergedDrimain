import 'package:flutter/material.dart';

class DataTablePro extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget? header;
  final double? minWidth;
  final EdgeInsetsGeometry padding;

  const DataTablePro({
    super.key,
    required this.columns,
    required this.rows,
    this.header,
    this.minWidth,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final table = DataTable(
      columns: columns,
      rows: rows,
      headingTextStyle: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
      dataRowColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.hovered)) {
            return Theme.of(context).colorScheme.primary.withOpacity(.04);
          }
          return null;
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: header!,
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth ?? 900),
            child: Padding(
              padding: padding,
              child: table,
            ),
          ),
        ),
      ],
    );
  }
}