import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/messages_provider.dart';

class PaginationControls extends ConsumerWidget {
  const PaginationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(messagesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);

    // Don't show pagination if there's only one page or no messages
    if (messagesState.totalPages <= 1 || messagesState.totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          Text(
            'Page ${messagesState.currentPage} of ${messagesState.totalPages} (${messagesState.totalCount} total)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          
          // Pagination controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First page button
              IconButton(
                onPressed: messagesState.currentPage > 1
                    ? () => messagesNotifier.goToPage(1)
                    : null,
                icon: const Icon(Icons.first_page),
                tooltip: 'First page',
                iconSize: 20,
              ),
              
              // Previous page button
              IconButton(
                onPressed: messagesState.currentPage > 1
                    ? () => messagesNotifier.previousPage()
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
                iconSize: 20,
              ),
              
              // Page number input
              Container(
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    hintText: '${messagesState.currentPage}',
                  ),
                  onSubmitted: (value) {
                    final page = int.tryParse(value);
                    if (page != null && page >= 1 && page <= messagesState.totalPages) {
                      messagesNotifier.goToPage(page);
                    }
                  },
                ),
              ),
              
              // Next page button
              IconButton(
                onPressed: messagesState.currentPage < messagesState.totalPages
                    ? () => messagesNotifier.nextPage()
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
                iconSize: 20,
              ),
              
              // Last page button
              IconButton(
                onPressed: messagesState.currentPage < messagesState.totalPages
                    ? () => messagesNotifier.goToPage(messagesState.totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
                tooltip: 'Last page',
                iconSize: 20,
              ),
              
              const SizedBox(width: 16),
              
              // Page size selector
              DropdownButton<int>(
                value: messagesState.pageSize,
                onChanged: (newSize) {
                  if (newSize != null) {
                    messagesNotifier.changePageSize(newSize);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 per page')),
                  DropdownMenuItem(value: 20, child: Text('20 per page')),
                  DropdownMenuItem(value: 50, child: Text('50 per page')),
                  DropdownMenuItem(value: 100, child: Text('100 per page')),
                ],
                underline: const SizedBox.shrink(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
