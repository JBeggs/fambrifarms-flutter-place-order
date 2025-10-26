import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/customers_provider.dart';

class CustomerSearch extends ConsumerStatefulWidget {
  const CustomerSearch({super.key});

  @override
  ConsumerState<CustomerSearch> createState() => _CustomerSearchState();
}

class _CustomerSearchState extends ConsumerState<CustomerSearch> {
  final _searchController = TextEditingController();
  String _selectedType = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search customers by name, email, or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: customersState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(customersProvider.notifier).clearSearch();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              ref.read(customersProvider.notifier).searchCustomers(value);
            },
          ),
          
          const SizedBox(height: 16),
          
          // Filter chips
          Row(
            children: [
              Text(
                'Filter by type:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All', Icons.people),
                      const SizedBox(width: 8),
                      _buildFilterChip('restaurant', 'Restaurants', Icons.restaurant),
                      const SizedBox(width: 8),
                      _buildFilterChip('private', 'Private', Icons.person),
                      const SizedBox(width: 8),
                      _buildFilterChip('internal', 'Internal', Icons.business),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Results summary
          _buildResultsSummary(context, customersState),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedType = value;
        });
        ref.read(customersProvider.notifier).filterByType(value);
      },
      selectedColor: const Color(0xFF2D5016), // Farm green
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildResultsSummary(BuildContext context, CustomersState state) {
    final totalCustomers = state.customers.length;
    final filteredCustomers = state.filteredCustomers.length;
    final hasFilters = state.searchQuery.isNotEmpty || state.selectedType != 'all';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFilters
                  ? 'Showing $filteredCustomers of $totalCustomers customers'
                  : 'Showing all $totalCustomers customers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          if (hasFilters) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedType = 'all';
                });
                ref.read(customersProvider.notifier).clearSearch();
                ref.read(customersProvider.notifier).filterByType('all');
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear filters',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

