import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int totalItems;
  final int currentPage;
  final int pageSize;
  final List<int> pageSizes;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const PaginationControls({
    super.key,
    required this.totalItems,
    required this.currentPage,
    required this.pageSize,
    required this.pageSizes,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  int get _totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();

  List<int?> _visiblePageTokens() {
    if (_totalPages <= 7) {
      return List<int?>.generate(_totalPages, (i) => i);
    }

    final tokens = <int?>[0];
    final start = (currentPage - 1).clamp(1, _totalPages - 2);
    final end = (currentPage + 1).clamp(1, _totalPages - 2);

    if (start > 1) tokens.add(null);
    for (int i = start; i <= end; i++) {
      tokens.add(i);
    }
    if (end < _totalPages - 2) tokens.add(null);

    tokens.add(_totalPages - 1);
    return tokens;
  }

  Widget _buildPageButton(int pageIndex, bool active) {
    return FilledButton.tonal(
      onPressed: active ? null : () => onPageChanged(pageIndex),
      style: FilledButton.styleFrom(
        minimumSize: const Size(36, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text('${pageIndex + 1}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _totalPages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pozycje: $totalItems | Strona ${currentPage + 1} z $totalPages'),
              const SizedBox(width: 12),
              const Text('Rozmiar strony:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pageSize,
                items: pageSizes
                    .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onPageSizeChanged(v);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Pierwsza strona',
                onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                tooltip: 'Poprzednia strona',
                onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ..._visiblePageTokens().map((token) {
                if (token == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...'),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildPageButton(token, token == currentPage),
                );
              }),
              IconButton(
                tooltip: 'Następna strona',
                onPressed: (currentPage + 1) < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Ostatnia strona',
                onPressed: (currentPage + 1) < totalPages
                    ? () => onPageChanged(totalPages - 1)
                    : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

