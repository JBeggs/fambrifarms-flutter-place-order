import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/suppliers_provider.dart';
import '../../../models/supplier.dart';

class SupplierSearch extends ConsumerStatefulWidget {
  const SupplierSearch({super.key});

  @override
  ConsumerState<SupplierSearch> createState() => _SupplierSearchState();
}

class _SupplierSearchState extends ConsumerState<SupplierSearch> {
  final _searchController = TextEditingController();
  SupplierType _selectedType = SupplierType.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersState = ref.watch(suppliersProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search suppliers by name, email, phone, or specialties...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: suppliersState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(suppliersProvider.notifier).clearSearch();
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
              ref.read(suppliersProvider.notifier).searchSuppliers(value);
            },
          ),
          
          const SizedBox(height: 16),
          
          // Supplier type filter chips
          Row(
            children: [
              Text(
                'Supplier Type:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SupplierType.values.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTypeChip(type),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Results summary
          _buildResultsSummary(context, suppliersState),
        ],
      ),
    );
  }

  Widget _buildTypeChip(SupplierType type) {
    final isSelected = _selectedType == type;
    
    return FilterChip(
      selected: isSelected,
      label: Text(type.fullDisplay),
      onSelected: (selected) {
        setState(() {
          _selectedType = type;
        });
        ref.read(suppliersProvider.notifier).filterByType(type);
      },
      selectedColor: _getSupplierTypeColor(type),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResultsSummary(BuildContext context, SuppliersState state) {
    final totalSuppliers = state.suppliers.length;
    final filteredSuppliers = state.filteredSuppliers.length;
    final hasFilters = state.searchQuery.isNotEmpty || 
                      state.selectedType != SupplierType.all;

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
                  ? 'Showing $filteredSuppliers of $totalSuppliers suppliers'
                  : 'Showing all $totalSuppliers suppliers',
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
                  _selectedType = SupplierType.all;
                });
                ref.read(suppliersProvider.notifier).clearAllFilters();
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

  Color _getSupplierTypeColor(SupplierType type) {
    switch (type) {
      case SupplierType.all:
        return const Color(0xFF2D5016); // Farm green
      case SupplierType.internal:
        return const Color(0xFF2D5016); // Farm green
      case SupplierType.external:
        return const Color(0xFF3498DB); // Blue
      case SupplierType.wholesale:
        return const Color(0xFF9B59B6); // Purple
      case SupplierType.retail:
        return const Color(0xFFE67E22); // Orange
    }
  }
}

