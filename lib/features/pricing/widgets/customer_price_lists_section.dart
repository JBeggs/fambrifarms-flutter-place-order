import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer_price_list.dart';
import '../../../services/api_service.dart';
import '../pricing_dashboard_page.dart';
import 'price_list_detail_dialog.dart';

class CustomerPriceListsSection extends ConsumerStatefulWidget {
  final AsyncValue<List<CustomerPriceList>> customerPriceListsAsync;

  const CustomerPriceListsSection({
    super.key,
    required this.customerPriceListsAsync,
  });

  @override
  ConsumerState<CustomerPriceListsSection> createState() => _CustomerPriceListsSectionState();
}

class _CustomerPriceListsSectionState extends ConsumerState<CustomerPriceListsSection> {
  final Set<int> _selectedPriceListIds = <int>{};
  bool _isSelectMode = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Customer Price Lists',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSelectMode) ...[
                  Text('${_selectedPriceListIds.length} selected'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _exitSelectMode(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel selection',
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => _showCreatePriceListDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Price List'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _enterSelectMode(),
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Select multiple',
                  ),
                ],
              ],
            ),
            if (_isSelectMode && _selectedPriceListIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _bulkActivate(),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Activate Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _bulkSend(),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkChangeRuleDialog(),
                    icon: const Icon(Icons.rule, size: 16),
                    label: const Text('Change Rules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: widget.customerPriceListsAsync.when(
                data: (priceLists) => priceLists.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No price lists found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Generate price lists from market data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: priceLists.length,
                        itemBuilder: (context, index) {
                          final priceList = priceLists[index];
                          return _CustomerPriceListCard(
                            priceList: priceList,
                            isSelected: _selectedPriceListIds.contains(priceList.id),
                            isSelectMode: _isSelectMode,
                            onTap: () => _isSelectMode 
                                ? _toggleSelection(priceList.id)
                                : _showPriceListDetail(context, priceList),
                            onActivate: () async {
                              try {
                                final apiService = ref.read(apiServiceProvider);
                                await apiService.activateCustomerPriceList(priceList.id);
                                
                                // Refresh the data
                                ref.invalidate(customerPriceListsProvider);
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Price list activated successfully'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
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
                            },
                            onSend: () async {
                              try {
                                final apiService = ref.read(apiServiceProvider);
                                await apiService.sendCustomerPriceListToCustomer(priceList.id);
                                
                                // Refresh the data
                                ref.invalidate(customerPriceListsProvider);
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Price list sent to customer'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
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
                            },
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load price lists',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceListDetail(BuildContext context, CustomerPriceList priceList) {
    showDialog(
      context: context,
      builder: (context) => PriceListDetailDialog(priceList: priceList),
    );
  }

  void _showCreatePriceListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreatePriceListDialog(
        onCreated: () {
          ref.invalidate(customerPriceListsProvider);
        },
      ),
    );
  }

  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
      _selectedPriceListIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedPriceListIds.clear();
    });
  }

  void _toggleSelection(int priceListId) {
    setState(() {
      if (_selectedPriceListIds.contains(priceListId)) {
        _selectedPriceListIds.remove(priceListId);
      } else {
        _selectedPriceListIds.add(priceListId);
      }
    });
  }

  Future<void> _bulkActivate() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      for (final id in _selectedPriceListIds) {
        await apiService.activateCustomerPriceList(id);
      }
      
      ref.invalidate(customerPriceListsProvider);
      _exitSelectMode();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedPriceListIds.length} price lists activated successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate price lists: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _bulkSend() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      for (final id in _selectedPriceListIds) {
        await apiService.sendCustomerPriceListToCustomer(id);
      }
      
      ref.invalidate(customerPriceListsProvider);
      _exitSelectMode();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedPriceListIds.length} price lists sent successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send price lists: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showBulkChangeRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => _BulkChangeRuleDialog(
        selectedIds: _selectedPriceListIds.toList(),
        onChanged: () {
          ref.invalidate(customerPriceListsProvider);
          _exitSelectMode();
        },
      ),
    );
  }
}

class _CustomerPriceListCard extends StatelessWidget {
  final CustomerPriceList priceList;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onSend;
  final bool isSelected;
  final bool isSelectMode;

  const _CustomerPriceListCard({
    required this.priceList,
    required this.onTap,
    required this.onActivate,
    required this.onSend,
    required this.isSelected,
    required this.isSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (isSelectMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        priceList.customerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priceList.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priceList.statusDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: priceList.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Pricing Rule
                Text(
                  priceList.pricingRuleName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Stats
                Row(
                  children: [
                    _buildStat(
                      context,
                      'Products',
                      '${priceList.totalProducts}',
                      Icons.inventory,
                    ),
                    const SizedBox(width: 16),
                    _buildStat(
                      context,
                      'Avg Markup',
                      priceList.formattedAverageMarkup,
                      Icons.percent,
                    ),
                    const SizedBox(width: 16),
                    _buildStat(
                      context,
                      'Total Value',
                      priceList.formattedTotalValue,
                      Icons.attach_money,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Effective Period
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      priceList.formattedEffectivePeriod,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const Spacer(),
                    if (priceList.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      )
                    else if (priceList.daysUntilExpiry > 0)
                      Text(
                        '${priceList.daysUntilExpiry} days left',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                
                // Actions
                if (priceList.status == 'generated' || priceList.status == 'draft') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onActivate,
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Activate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onSend,
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Send'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BulkChangeRuleDialog extends ConsumerStatefulWidget {
  final List<int> selectedIds;
  final VoidCallback onChanged;

  const _BulkChangeRuleDialog({
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  ConsumerState<_BulkChangeRuleDialog> createState() => _BulkChangeRuleDialogState();
}

class _BulkChangeRuleDialogState extends ConsumerState<_BulkChangeRuleDialog> {
  int? _selectedRuleId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final pricingRulesAsync = ref.watch(pricingRulesProvider);

    return AlertDialog(
      title: Text('Change Pricing Rule for ${widget.selectedIds.length} Price Lists'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a new pricing rule to apply to all selected price lists. This will regenerate all prices.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            pricingRulesAsync.when(
              data: (rules) {
                // Ensure the selected rule ID exists in the available rules
                final availableRuleIds = rules.map((rule) => rule.id).toSet();
                final validSelectedRuleId = _selectedRuleId != null && availableRuleIds.contains(_selectedRuleId) 
                    ? _selectedRuleId 
                    : null;
                
                // Update the selected rule ID if it was invalid
                if (validSelectedRuleId != _selectedRuleId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedRuleId = validSelectedRuleId;
                    });
                  });
                }
                
                return DropdownButtonFormField<int>(
                  value: validSelectedRuleId,
                  decoration: const InputDecoration(
                    labelText: 'New Pricing Rule',
                    border: OutlineInputBorder(),
                  ),
                  items: rules.map((rule) {
                    return DropdownMenuItem<int>(
                      value: rule.id,
                      child: Text('${rule.name} (${rule.customerSegment})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRuleId = value;
                    });
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading rules: $error'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedRuleId != null && !_isLoading ? _applyBulkChange : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Changes'),
        ),
      ],
    );
  }

  Future<void> _applyBulkChange() async {
    if (_selectedRuleId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      for (final id in widget.selectedIds) {
        await apiService.updateCustomerPriceListRule(id, _selectedRuleId!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.selectedIds.length} price lists updated successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update price lists: $e'),
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

class _CreatePriceListDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _CreatePriceListDialog({
    required this.onCreated,
  });

  @override
  ConsumerState<_CreatePriceListDialog> createState() => _CreatePriceListDialogState();
}

class _CreatePriceListDialogState extends ConsumerState<_CreatePriceListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  
  int? _selectedCustomerId;
  int? _selectedPricingRuleId;
  DateTime _effectiveFrom = DateTime.now();
  DateTime? _effectiveUntil;
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _pricingRules = [];
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Load customers and pricing rules in parallel
      final results = await Future.wait([
        apiService.getCustomers(),
        apiService.getPricingRules(),
      ]);
      
      setState(() {
        _customers = (results[0] as List).cast<Map<String, dynamic>>();
        _pricingRules = (results[1] as List).cast<Map<String, dynamic>>();
        _loadingData = false;
      });
    } catch (e) {
      setState(() {
        _loadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Customer Price List'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: _loadingData
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Customer Selection
                      DropdownButtonFormField<int>(
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(
                          labelText: 'Customer *',
                          border: OutlineInputBorder(),
                        ),
                        items: _customers.map((customer) {
                          return DropdownMenuItem<int>(
                            value: customer['id'],
                            child: Text(customer['business_name'] ?? customer['email']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCustomerId = value;
                            _nameController.text = value != null 
                                ? 'Price List for ${_customers.firstWhere((c) => c['id'] == value)['business_name'] ?? 'Customer'}'
                                : '';
                          });
                        },
                        validator: (value) => value == null ? 'Please select a customer' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Price List Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Price List Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a price list name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Pricing Rule Selection
                      DropdownButtonFormField<int>(
                        value: _selectedPricingRuleId,
                        decoration: const InputDecoration(
                          labelText: 'Base Pricing Rule *',
                          border: OutlineInputBorder(),
                          helperText: 'Starting point for pricing calculations',
                        ),
                        items: _pricingRules.map((rule) {
                          return DropdownMenuItem<int>(
                            value: rule['id'],
                            child: Text('${rule['name']} (${rule['customer_segment']})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPricingRuleId = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a pricing rule' : null,
                      ),
                      const SizedBox(height: 24),
                      
                      // Effective Period
                      Text(
                        'Effective Period',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Effective From *',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  '${_effectiveFrom.day}/${_effectiveFrom.month}/${_effectiveFrom.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Effective Until (Optional)',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _effectiveUntil != null
                                      ? '${_effectiveUntil!.day}/${_effectiveUntil!.month}/${_effectiveUntil!.year}'
                                      : 'No end date',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          helperText: 'Any additional information about this price list',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Product Selection Section
                      Row(
                        children: [
                          Text(
                            'Products & Custom Pricing',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showProductSelectionDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Products'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Selected Products List
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _selectedProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No products selected\nClick "Add Products" to customize pricing',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _selectedProducts.length,
                                itemBuilder: (context, index) {
                                  final product = _selectedProducts[index];
                                  return ListTile(
                                    title: Text(product['name']),
                                    subtitle: Text('Custom Price: R${product['custom_price']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedProducts.removeAt(index);
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createPriceList,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Price List'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _effectiveFrom : (_effectiveUntil ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _effectiveFrom = picked;
        } else {
          _effectiveUntil = picked;
        }
      });
    }
  }

  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductSelectionDialog(
        onProductsSelected: (products) {
          setState(() {
            _selectedProducts.addAll(products);
          });
        },
      ),
    );
  }

  Future<void> _createPriceList() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      final priceListData = {
        'customer': _selectedCustomerId,
        'name': _nameController.text.trim(),
        'pricing_rule': _selectedPricingRuleId,
        'effective_from': _effectiveFrom.toIso8601String().split('T')[0],
        'effective_until': _effectiveUntil?.toIso8601String().split('T')[0],
        'notes': _notesController.text.trim(),
        'status': 'draft',
        'custom_products': _selectedProducts.map((product) => {
          'product': product['id'],
          'custom_price': product['custom_price'],
        }).toList(),
      };

      await apiService.createCustomerPriceList(priceListData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list created successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create price list: $e'),
            backgroundColor: Colors.red,
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

class _ProductSelectionDialog extends ConsumerStatefulWidget {
  final Function(List<Map<String, dynamic>>) onProductsSelected;

  const _ProductSelectionDialog({
    required this.onProductsSelected,
  });

  @override
  ConsumerState<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends ConsumerState<_ProductSelectionDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadProducts() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final products = await apiService.getProducts();
      
      setState(() {
        _products = (products as List).cast<Map<String, dynamic>>();
        _filteredProducts = _products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final name = (product['name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Products'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            // Search
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            
            // Products List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);
                        
                        return Card(
                          child: ListTile(
                            title: Text(product['name'] ?? 'Unknown Product'),
                            subtitle: Text('Base Price: R${product['price'] ?? '0.00'}'),
                            trailing: isSelected
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          initialValue: _selectedProducts
                                              .firstWhere((p) => p['id'] == product['id'])['custom_price']
                                              .toString(),
                                          decoration: const InputDecoration(
                                            labelText: 'Price',
                                            prefixText: 'R',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            final selectedProduct = _selectedProducts
                                                .firstWhere((p) => p['id'] == product['id']);
                                            selectedProduct['custom_price'] = double.tryParse(value) ?? 0.0;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _selectedProducts.removeWhere((p) => p['id'] == product['id']);
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                    onPressed: () {
                                      setState(() {
                                        _selectedProducts.add({
                                          'id': product['id'],
                                          'name': product['name'],
                                          'custom_price': product['price'] ?? 0.0,
                                        });
                                      });
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedProducts.isEmpty
              ? null
              : () {
                  widget.onProductsSelected(_selectedProducts);
                  Navigator.of(context).pop();
                },
          child: Text('Add ${_selectedProducts.length} Products'),
        ),
      ],
    );
  }
}
