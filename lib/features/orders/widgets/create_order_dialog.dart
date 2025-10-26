import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/orders_provider.dart';
import '../../../providers/customers_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common/error_display.dart';
import '../../../models/order.dart';
import 'product_selector.dart';
import 'order_items_list.dart';

class CreateOrderDialog extends ConsumerStatefulWidget {
  const CreateOrderDialog({super.key});

  @override
  ConsumerState<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends ConsumerState<CreateOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  String? _selectedCustomerId;
  String _selectedStatus = 'received';
  DateTime _selectedDeliveryDate = DateTime.now().add(const Duration(days: 1));
  List<OrderItem> _orderItems = [];
  List<Map<String, dynamic>> _orderStatuses = [];

  @override
  void initState() {
    super.initState();
    // Load customers and products when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      _loadOrderStatuses();
    });
  }

  Future<void> _loadOrderStatuses() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final statuses = await apiService.getOrderStatuses();
      setState(() {
        _orderStatuses = statuses;
        // Set default status if current selection is not available
        if (_orderStatuses.isNotEmpty && !_orderStatuses.any((status) => status['name'] == _selectedStatus)) {
          _selectedStatus = _orderStatuses.first['name'] ?? 'received';
        }
      });
    } catch (e) {
      // Fallback to hardcoded statuses if API fails
      setState(() {
        _orderStatuses = [
          {'name': 'received', 'display_name': 'Received via WhatsApp'},
          {'name': 'parsed', 'display_name': 'AI Parsed'},
          {'name': 'confirmed', 'display_name': 'Manager Confirmed'},
          {'name': 'po_sent', 'display_name': 'PO Sent to Sales Rep'},
          {'name': 'po_confirmed', 'display_name': 'Sales Rep Confirmed'},
          {'name': 'delivered', 'display_name': 'Delivered to Customer'},
          {'name': 'cancelled', 'display_name': 'Cancelled'},
        ];
      });
    }
  }

  void _addOrderItem(OrderItem item) {
    setState(() {
      _orderItems.add(item);
    });
  }

  void _removeOrderItem(OrderItem item) {
    setState(() {
      _orderItems.removeWhere((i) => i.id == item.id);
    });
  }

  void _updateOrderItemQuantity(OrderItem item, double newQuantity) {
    setState(() {
      final index = _orderItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _orderItems[index] = OrderItem(
          id: item.id,
          product: item.product,
          quantity: newQuantity,
          unit: item.unit,
          price: item.price,
          totalPrice: item.price * newQuantity,
          originalText: item.originalText,
          confidenceScore: item.confidenceScore,
          manuallyCorrected: item.manuallyCorrected,
          notes: item.notes,
        );
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDeliveryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDeliveryDate) {
      setState(() {
        _selectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product to the order')),
      );
      return;
    }

    final orderData = {
      'restaurant': int.parse(_selectedCustomerId!),
      'status': _selectedStatus,
      'delivery_date': _selectedDeliveryDate.toIso8601String().split('T')[0],
      'notes': _notesController.text.trim(),
      'items': _orderItems.map((item) => {
        'product': item.product.id,
        'quantity': item.quantity,
        'unit': item.unit,
        'price': item.price,
        'notes': item.notes,
      }).toList(),
    };

    final ordersNotifier = ref.read(ordersProvider.notifier);
    final newOrder = await ordersNotifier.createOrder(orderData);

    if (newOrder != null && mounted) {
      Navigator.of(context).pop(newOrder);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final ordersState = ref.watch(ordersProvider);

    return AlertDialog(
      title: const Text('Create New Order'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Selection
              const Text('Customer *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(
                  hintText: 'Select a customer',
                  border: OutlineInputBorder(),
                ),
                items: customersState.customers.map((customer) {
                  // Use business name for restaurants, display name for others
                  final displayName = customer.isRestaurant && customer.profile?.businessName != null
                      ? customer.profile!.businessName!
                      : customer.displayName;
                  
                  return DropdownMenuItem<String>(
                    value: customer.id.toString(),
                    child: Text('$displayName (${customer.email})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCustomerId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a customer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Order Status
              const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: _orderStatuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status['name'],
                    child: Text(status['display_name'] ?? status['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Delivery Date
              const Text('Delivery Date', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDeliveryDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDeliveryDate.day}/${_selectedDeliveryDate.month}/${_selectedDeliveryDate.year}',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Product Selection
              ProductSelector(
                onProductAdded: _addOrderItem,
                currentItems: _orderItems,
              ),
              const SizedBox(height: 24),

              // Order Items List
              OrderItemsList(
                items: _orderItems,
                onRemoveItem: _removeOrderItem,
                onUpdateQuantity: _updateOrderItemQuantity,
              ),
              const SizedBox(height: 24),

              // Notes
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Order notes or special instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              // Error Display
              if (ordersState.error != null) ...[
                const SizedBox(height: 16),
                ErrorDisplay(
                  message: ordersState.error!,
                  onRetry: () => ref.read(ordersProvider.notifier).clearError(),
                ),
              ],

              if (customersState.error != null) ...[
                const SizedBox(height: 16),
                ErrorDisplay(
                  message: customersState.error!,
                  onRetry: () => ref.read(customersProvider.notifier).clearError(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: ordersState.isLoading ? null : _createOrder,
          child: ordersState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Order'),
        ),
      ],
    );
  }
}
