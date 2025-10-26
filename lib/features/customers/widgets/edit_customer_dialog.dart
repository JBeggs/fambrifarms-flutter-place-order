import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/customer.dart';
import '../../../providers/customers_provider.dart';
import '../../../services/api_service.dart';
import '../customer_orders_page.dart';
import 'customer_price_list_dialog.dart';

class EditCustomerDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const EditCustomerDialog({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends ConsumerState<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _businessRegistrationController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  final _orderPatternController = TextEditingController();
  
  bool _isPrivateCustomer = false;
  bool _isLoading = false;
  
  // Pricing rule selection
  List<Map<String, dynamic>> _pricingRules = [];
  int? _selectedPricingRuleId;
  bool _loadingPricingRules = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
    _loadPricingRules();
  }

  void _populateFields() {
    // Populate basic user fields
    _emailController.text = widget.customer.email;
    
    // Use the separate firstName and lastName fields from the Customer model
    _firstNameController.text = widget.customer.firstName.isNotEmpty 
        ? widget.customer.firstName 
        : widget.customer.name.split(' ').first;
    _lastNameController.text = widget.customer.lastName.isNotEmpty 
        ? widget.customer.lastName 
        : (widget.customer.name.split(' ').length > 1 
            ? widget.customer.name.split(' ').sublist(1).join(' ') 
            : '');
    
    // Debug: Print the populated names
    debugPrint('Populating customer fields:');
    debugPrint('  Customer name: ${widget.customer.name}');
    debugPrint('  Customer firstName: ${widget.customer.firstName}');
    debugPrint('  Customer lastName: ${widget.customer.lastName}');
    debugPrint('  First name field: ${_firstNameController.text}');
    debugPrint('  Last name field: ${_lastNameController.text}');
    debugPrint('  Email: ${_emailController.text}');
    
    _phoneController.text = widget.customer.phone;
    
    // Set customer type
    _isPrivateCustomer = widget.customer.isPrivate;
    
    // Populate profile fields if available
    if (widget.customer.profile != null) {
      final profile = widget.customer.profile!;
      _businessNameController.text = profile.businessName ?? widget.customer.name;
      _branchNameController.text = profile.branchName ?? '';
      _addressController.text = profile.deliveryAddress ?? '';
      _paymentTermsController.text = profile.paymentTermsDays != null 
          ? '${profile.paymentTermsDays} days' 
          : 'Net 30';
      _deliveryNotesController.text = profile.deliveryNotes ?? '';
      _orderPatternController.text = profile.orderPattern ?? '';
    } else {
      _businessNameController.text = widget.customer.name;
      _paymentTermsController.text = 'Net 30';
      _deliveryNotesController.text = '';
      _orderPatternController.text = '';
    }
    
    // Set default city if not available
    _cityController.text = 'Johannesburg'; // Default city
  }

  Future<void> _loadPricingRules() async {
    setState(() {
      _loadingPricingRules = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final rules = await apiService.getPricingRules(effective: true);
      
      debugPrint('Loaded ${rules.length} pricing rules');
      
      setState(() {
        _pricingRules = rules.map<Map<String, dynamic>>((rule) => {
          'id': rule.id,
          'name': rule.name,
          'customer_segment': rule.customerSegment,
          'markup_percentage': rule.baseMarkupPercentage,
        }).toList();
        
        debugPrint('Processed pricing rules: $_pricingRules');
        
        // Set default pricing rule based on customer segment
        final customerSegment = widget.customer.customerSegment ?? 'standard';
        debugPrint('Customer segment: $customerSegment');
        
        final matchingRule = _pricingRules.firstWhere(
          (rule) => rule['customer_segment'] == customerSegment,
          orElse: () => <String, Object>{},
        );
        
        if (matchingRule.isNotEmpty) {
          _selectedPricingRuleId = matchingRule['id'];
          debugPrint('Selected pricing rule ID: $_selectedPricingRuleId');
        } else {
          debugPrint('No matching pricing rule found');
        }
      });
    } catch (e) {
      debugPrint('Error loading pricing rules: $e');
    } finally {
      setState(() {
        _loadingPricingRules = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _branchNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _businessRegistrationController.dispose();
    _paymentTermsController.dispose();
    _deliveryNotesController.dispose();
    _orderPatternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900, // Wider for better experience
        height: 850, // Even taller to accommodate pricing section
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header with Customer Stats
            Row(
              children: [
                const Icon(Icons.edit, size: 28, color: Color(0xFF2D5016)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Customer',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      Text(
                        widget.customer.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Customer Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.customer.totalOrders} orders',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'R${widget.customer.totalOrderValue.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CustomerOrdersPage(customerId: widget.customer.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart, size: 16),
                    label: const Text('View Orders'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => CustomerPriceListDialog(customer: widget.customer),
                      );
                    },
                    icon: const Icon(Icons.price_check, size: 16),
                    label: const Text('Price List'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Customer info subtitle
            Text(
              'Editing: ${widget.customer.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Type Toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.business, color: Color(0xFF2D5016)),
                            const SizedBox(width: 12),
                            Text(
                              'Customer Type:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: RadioGroup<bool>(
                                groupValue: _isPrivateCustomer,
                                onChanged: (value) {
                                  setState(() {
                                    _isPrivateCustomer = value!;
                                  });
                                },
                                child: Column(
                                  children: [
                                    RadioListTile<bool>(
                                      value: false,
                                      title: const Text('Restaurant/Business'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    RadioListTile<bool>(
                                      value: true,
                                      title: const Text('Private Customer'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Personal Information Section
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Email and Phone Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address *',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // First Name and Last Name Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name *',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name *',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Business Information Section
                      Text(
                        _isPrivateCustomer ? 'Customer Information' : 'Business Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Business Name and Branch Name Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _businessNameController,
                              decoration: InputDecoration(
                                labelText: _isPrivateCustomer ? 'Display Name *' : 'Business Name *',
                                prefixIcon: Icon(_isPrivateCustomer ? Icons.person : Icons.business),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return _isPrivateCustomer ? 'Display name is required' : 'Business name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _branchNameController,
                              decoration: InputDecoration(
                                labelText: _isPrivateCustomer ? 'Nickname' : 'Branch Name',
                                prefixIcon: const Icon(Icons.location_on),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          prefixIcon: Icon(Icons.home),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // City and Postal Code Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                prefixIcon: Icon(Icons.location_city),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'City is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Postal Code',
                                prefixIcon: Icon(Icons.mail),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (!_isPrivateCustomer) ...[
                        const SizedBox(height: 16),
                        
                        // Business Registration and Payment Terms Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _businessRegistrationController,
                                decoration: const InputDecoration(
                                  labelText: 'Business Registration',
                                  prefixIcon: Icon(Icons.assignment),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _paymentTermsController,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Terms',
                                  prefixIcon: Icon(Icons.payment),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // WhatsApp Integration Section
                      Text(
                        'WhatsApp & Delivery Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Delivery Notes
                      TextFormField(
                        controller: _deliveryNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Notes',
                          prefixIcon: Icon(Icons.local_shipping),
                          border: OutlineInputBorder(),
                          hintText: 'Special delivery requirements and notes',
                        ),
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Order Pattern
                      TextFormField(
                        controller: _orderPatternController,
                        decoration: const InputDecoration(
                          labelText: 'Order Pattern',
                          prefixIcon: Icon(Icons.pattern),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Tuesday orders - Italian restaurant supplies',
                        ),
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Pricing Rule Section
                      Text(
                        'Pricing Configuration',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D5016),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Pricing Rule Selection
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Row(
                              children: [
                                const Icon(Icons.trending_up, color: Colors.blue),
                                const SizedBox(width: 12),
                                Text(
                                  'Current Pricing Rule',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Auto-Selected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            if (_loadingPricingRules)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_pricingRules.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange[600]),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text('No pricing rules available. Default pricing will be used.'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                initialValue: _selectedPricingRuleId,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                decoration: InputDecoration(
                                  labelText: 'Select Pricing Rule',
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  prefixIcon: Icon(Icons.price_change, color: Theme.of(context).colorScheme.primary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                  helperText: 'Override automatic pricing rule selection',
                                  helperStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                items: [
                                  DropdownMenuItem<int>(
                                    value: null,
                                    child: Text(
                                      'Auto-select based on customer segment',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  ..._pricingRules.map((rule) {
                                    return DropdownMenuItem<int>(
                                      value: rule['id'],
                                      child: Text(
                                        '${rule['name']} (${rule['markup_percentage']}%)',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPricingRuleId = value;
                                  });
                                },
                              ),
                            
                            // Show selected pricing rule details
                            if (_selectedPricingRuleId != null && _pricingRules.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final selectedRule = _pricingRules.firstWhere(
                                    (rule) => rule['id'] == _selectedPricingRuleId,
                                    orElse: () => <String, Object>{},
                                  );
                                  
                                  if (selectedRule.isEmpty) return const SizedBox.shrink();
                                  
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Selected: ${selectedRule['name']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${selectedRule['customer_segment'].toString().toUpperCase()} segment • ${selectedRule['markup_percentage']}% markup',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ] else if (_pricingRules.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.blue[600], size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Auto-selecting pricing rule based on customer segment',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update Customer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      // Show validation error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the validation errors before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate required fields explicitly
      final businessName = _businessNameController.text.trim();
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final email = _emailController.text.trim();
      
      if (businessName.isEmpty) {
        throw Exception('Business name is required');
      }
      if (address.isEmpty) {
        throw Exception('Address is required');
      }
      if (city.isEmpty) {
        throw Exception('City is required');
      }
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Valid email address is required');
      }

      final customerData = {
        'email': email,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': businessName,
        'branch_name': _branchNameController.text.trim(),
        'address': address,
        'city': city,
        'postal_code': _postalCodeController.text.trim(),
        'business_registration': _businessRegistrationController.text.trim(),
        'payment_terms': _paymentTermsController.text.trim(),
        'delivery_notes': _deliveryNotesController.text.trim(),
        'order_pattern': _orderPatternController.text.trim(),
        'preferred_pricing_rule_id': _selectedPricingRuleId,
        'is_private_customer': _isPrivateCustomer,
      };

      // Debug: Print the data being sent
      debugPrint('Saving customer data:');
      debugPrint('  First name: ${customerData['first_name']}');
      debugPrint('  Last name: ${customerData['last_name']}');
      debugPrint('  Business name: ${customerData['business_name']}');
      debugPrint('  Email: ${customerData['email']}');
      debugPrint('  Pricing rule ID: ${customerData['preferred_pricing_rule_id']}');
      
      // Show pricing rule info if selected
      if (_selectedPricingRuleId != null && _pricingRules.isNotEmpty) {
        final selectedRule = _pricingRules.firstWhere(
          (rule) => rule['id'] == _selectedPricingRuleId,
          orElse: () => <String, Object>{},
        );
        if (selectedRule.isNotEmpty) {
          debugPrint('  Selected pricing rule: ${selectedRule['name']} (${selectedRule['markup_percentage']}% markup)');
        }
      }

      debugPrint('[CUSTOMER_UPDATE] Calling updateCustomer with ID: ${widget.customer.id}');
      debugPrint('[CUSTOMER_UPDATE] Customer data: $customerData');
      
      await ref.read(customersProvider.notifier).updateCustomer(
        widget.customer.id,
        customerData,
      );
      
      debugPrint('[CUSTOMER_UPDATE] Update completed successfully');

      if (mounted) {
        // Store context before async operation
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        
        // Refresh the customers list to show updated data
        await ref.read(customersProvider.notifier).loadCustomers();
        
        navigator.pop(true); // Return true to indicate success
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Customer "$businessName" updated successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error updating customer';
        
        // Parse specific error messages
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('blank') || errorString.contains('required')) {
          errorMessage = 'Please fill in all required fields (Business Name, Address, City, Email)';
        } else if (errorString.contains('email') || errorString.contains('invalid')) {
          errorMessage = 'Please enter a valid email address';
        } else if (errorString.contains('400')) {
          // Try to extract specific validation errors from the API response
          if (errorString.contains('branch_name')) {
            errorMessage = 'Branch name validation error. Please check the branch name field.';
          } else if (errorString.contains('business_name')) {
            errorMessage = 'Business name is required and cannot be empty.';
          } else if (errorString.contains('address')) {
            errorMessage = 'Address is required and cannot be empty.';
          } else if (errorString.contains('city')) {
            errorMessage = 'City is required and cannot be empty.';
          } else {
            errorMessage = 'Validation error: ${e.toString()}';
          }
        } else if (errorString.contains('network') || errorString.contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else {
          errorMessage = 'Error updating customer: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(errorMessage),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitForm,
            ),
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
