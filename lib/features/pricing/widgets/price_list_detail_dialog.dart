import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_price_list.dart';
import '../../../services/api_service.dart';
import '../pricing_dashboard_page.dart';

class PriceListDetailDialog extends ConsumerStatefulWidget {
  final CustomerPriceList priceList;

  const PriceListDetailDialog({
    super.key,
    required this.priceList,
  });

  @override
  ConsumerState<PriceListDetailDialog> createState() => _PriceListDetailDialogState();
}

class _PriceListDetailDialogState extends ConsumerState<PriceListDetailDialog> {
  List<CustomerPriceListItem>? _items;
  bool _isLoading = true;
  String? _error;
  bool _isRegenerating = false;
  int? _selectedPricingRuleId;

  @override
  void initState() {
    super.initState();
    _selectedPricingRuleId = widget.priceList.pricingRule;
    _loadPriceListItems();
  }

  Future<void> _loadPriceListItems() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final items = await apiService.getCustomerPriceListItems(widget.priceList.id);
      
      setState(() {
        _items = items.map((item) => CustomerPriceListItem.fromJson(item)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price List Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Customer: ${widget.priceList.customerName} • ${widget.priceList.status}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Price List Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Effective: ${widget.priceList.effectiveFrom.toString().split(' ')[0]}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'Expires: ${widget.priceList.effectiveUntil.toString().split(' ')[0]}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Value: R${widget.priceList.totalListValue.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Items: ${widget.priceList.totalProducts}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons
                    Column(
                      children: [
                        // Pricing Rule Dropdown
                        Consumer(
                          builder: (context, ref, child) {
                            final pricingRulesAsync = ref.watch(pricingRulesProvider);
                            return pricingRulesAsync.when(
                              data: (rules) {
                                // Ensure the selected rule ID exists in the available rules
                                final availableRuleIds = rules.map((rule) => rule.id).toSet();
                                final validSelectedRuleId = availableRuleIds.contains(_selectedPricingRuleId) 
                                    ? _selectedPricingRuleId 
                                    : (rules.isNotEmpty ? rules.first.id : null);
                                
                                // Update the selected rule ID if it was invalid
                                if (validSelectedRuleId != _selectedPricingRuleId) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setState(() {
                                      _selectedPricingRuleId = validSelectedRuleId;
                                    });
                                  });
                                }
                                
                                return DropdownButtonFormField<int>(
                                  value: validSelectedRuleId,
                                  decoration: const InputDecoration(
                                    labelText: 'Pricing Rule',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: rules.map((rule) {
                                    return DropdownMenuItem<int>(
                                      value: rule.id,
                                      child: Text('${rule.name} (${rule.customerSegment})'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPricingRuleId = value;
                                    });
                                  },
                                );
                              },
                              loading: () => const SizedBox(
                                height: 48,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              error: (error, stack) => const SizedBox(
                                height: 48,
                                child: Center(child: Text('Error loading rules')),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        
                        // Regenerate Prices Button
                        ElevatedButton.icon(
                          onPressed: _selectedPricingRuleId != widget.priceList.pricingRule && !_isRegenerating
                              ? () => _regeneratePrices()
                              : null,
                          icon: _isRegenerating 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(_isRegenerating ? 'Regenerating...' : 'Regenerate Prices'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        if (widget.priceList.status == 'Draft')
                          ElevatedButton.icon(
                            onPressed: () => _activatePriceList(),
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Activate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _sendPriceList(),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Send'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showEditDetailsDialog(),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Items List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error loading items: $_error'),
                            ],
                          ),
                        )
                      : _items == null || _items!.isEmpty
                          ? const Center(
                              child: Text('No items found'),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price List Items',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _items!.length,
                                    itemBuilder: (context, index) {
                                      final item = _items![index];
                                      return _PriceListItemCard(item: item);
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activatePriceList() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.activateCustomerPriceList(widget.priceList.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list activated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true); // Return true to refresh parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate price list: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _sendPriceList() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.sendCustomerPriceList(widget.priceList.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list sent successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true); // Return true to refresh parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send price list: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _regeneratePrices() async {
    if (_selectedPricingRuleId == null) return;
    
    setState(() {
      _isRegenerating = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Update the price list with new pricing rule and regenerate
      await apiService.updateCustomerPriceListRule(
        widget.priceList.id, 
        _selectedPricingRuleId!
      );
      
      // Reload the items with new prices
      await _loadPriceListItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prices regenerated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate prices: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  void _showEditDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => _PriceListEditDialog(
        priceList: widget.priceList,
        onUpdated: () {
          // Refresh the dialog data
          Navigator.of(context).pop(true);
        },
      ),
    );
  }
}

class _PriceListEditDialog extends ConsumerStatefulWidget {
  final CustomerPriceList priceList;
  final VoidCallback onUpdated;

  const _PriceListEditDialog({
    required this.priceList,
    required this.onUpdated,
  });

  @override
  ConsumerState<_PriceListEditDialog> createState() => _PriceListEditDialogState();
}

class _PriceListEditDialogState extends ConsumerState<_PriceListEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  late DateTime _effectiveFrom;
  late DateTime _effectiveUntil;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.priceList.notes);
    _effectiveFrom = widget.priceList.effectiveFrom;
    _effectiveUntil = widget.priceList.effectiveUntil;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Price List Details'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Effective From Date
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Effective From'),
                subtitle: Text(_effectiveFrom.toString().split(' ')[0]),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _effectiveFrom,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _effectiveFrom = date;
                    });
                  }
                },
              ),
              
              // Effective Until Date
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Effective Until'),
                subtitle: Text(_effectiveUntil.toString().split(' ')[0]),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _effectiveUntil,
                    firstDate: _effectiveFrom,
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _effectiveUntil = date;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Add any notes about this price list...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Update the price list metadata
      await apiService.updateCustomerPriceListMetadata(
        widget.priceList.id,
        effectiveFrom: _effectiveFrom,
        effectiveUntil: _effectiveUntil,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list details updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update price list details: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _PriceListItemCard extends StatelessWidget {
  final CustomerPriceListItem item;

  const _PriceListItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.productDepartment != null && item.productDepartment!.isNotEmpty)
                    Text(
                      item.productDepartment!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Market: R${item.marketPriceInclVat.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Text(
                    'R${item.customerPriceInclVat.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getMarkupColor(item.markupPercentage).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${item.markupPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getMarkupColor(item.markupPercentage),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMarkupColor(double markup) {
    if (markup >= 50) return const Color(0xFFEF4444); // High markup - red
    if (markup >= 25) return const Color(0xFFF59E0B); // Medium markup - orange
    return const Color(0xFF10B981); // Low markup - green
  }
}
