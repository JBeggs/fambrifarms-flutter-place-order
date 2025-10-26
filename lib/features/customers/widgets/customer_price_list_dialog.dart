import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer.dart';
import '../../../models/customer_price_list.dart';
import '../../../services/api_service.dart';
import '../../pricing/widgets/price_list_detail_dialog.dart';

class CustomerPriceListDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerPriceListDialog({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<CustomerPriceListDialog> createState() => _CustomerPriceListDialogState();
}

class _CustomerPriceListDialogState extends ConsumerState<CustomerPriceListDialog> {
  List<CustomerPriceList> _priceLists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomerPriceLists();
  }

  Future<void> _loadCustomerPriceLists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ref.read(apiServiceProvider);
      final allPriceLists = await apiService.getCustomerPriceLists();
      
      // Filter price lists for this customer
      final customerPriceLists = allPriceLists.where((priceList) {
        return priceList.customer == widget.customer.id ||
               priceList.customerName.toLowerCase().contains(widget.customer.displayName.toLowerCase());
      }).toList();

      if (mounted) {
        setState(() {
          _priceLists = customerPriceLists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewPriceList() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Create a new price list for this customer
      final priceListData = {
        'customer_id': widget.customer.id,
        'customer_name': widget.customer.displayName,
        'status': 'draft',
        'created_by': 'system', // This should come from the current user
      };

      await apiService.createCustomerPriceList(priceListData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New price list created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomerPriceLists(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating price list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.price_check, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Price Lists',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.customer.displayName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadCustomerPriceLists,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading price lists',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadCustomerPriceLists,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _priceLists.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.price_check_outlined, size: 48, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No Price Lists Found',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This customer doesn\'t have any price lists yet.',
                                      style: const TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _createNewPriceList,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Price List'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2D5016),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _priceLists.length,
                              itemBuilder: (context, index) {
                                final priceList = _priceLists[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(priceList.status),
                                      child: Icon(
                                        _getStatusIcon(priceList.status),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      'Price List #${priceList.id}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Status: ${priceList.status.toUpperCase()}'),
                                        Text(
                                          'Created: ${_formatDate(priceList.generatedAt)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (priceList.status == 'draft')
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green),
                                            onPressed: () => _activatePriceList(priceList),
                                            tooltip: 'Activate',
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _editPriceList(priceList),
                                          tooltip: 'Edit',
                                        ),
                                        if (priceList.status == 'active')
                                          IconButton(
                                            icon: const Icon(Icons.send, color: Colors.blue),
                                            onPressed: () => _sendPriceList(priceList),
                                            tooltip: 'Send to Customer',
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            
            // Actions
            if (!_isLoading && _error == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _createNewPriceList,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Price List'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5016),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'draft':
        return Icons.edit;
      case 'sent':
        return Icons.send;
      case 'expired':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _activatePriceList(CustomerPriceList priceList) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.activateCustomerPriceList(priceList.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomerPriceLists(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating price list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendPriceList(CustomerPriceList priceList) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.sendCustomerPriceListToCustomer(priceList.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price list sent to customer successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCustomerPriceLists(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending price list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPriceList(CustomerPriceList priceList) {
    showDialog(
      context: context,
      builder: (context) => PriceListDetailDialog(
        priceList: priceList,
      ),
    ).then((_) {
      // Refresh the list when the dialog closes
      _loadCustomerPriceLists();
    });
  }
}
