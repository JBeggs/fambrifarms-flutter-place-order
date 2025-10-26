import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/supplier.dart';
import '../../../providers/suppliers_provider.dart';

class EditSupplierDialog extends ConsumerStatefulWidget {
  final Supplier supplier;

  const EditSupplierDialog({
    super.key,
    required this.supplier,
  });

  @override
  ConsumerState<EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends ConsumerState<EditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _leadTimeController = TextEditingController();
  final _minimumOrderValueController = TextEditingController();

  String _selectedSupplierType = 'external';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    _nameController.text = widget.supplier.name;
    _contactPersonController.text = ''; // Not available in current model
    _emailController.text = widget.supplier.email;
    _phoneController.text = widget.supplier.phone;
    _addressController.text = widget.supplier.address ?? '';
    _descriptionController.text = widget.supplier.description ?? '';
    _selectedSupplierType = widget.supplier.supplierType;
    _isActive = widget.supplier.isActive;
    
    // These fields need to be fetched from backend as they're not in the current Flutter model
    _paymentTermsController.text = '30'; // Default
    _leadTimeController.text = '3'; // Default
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _registrationNumberController.dispose();
    _taxNumberController.dispose();
    _paymentTermsController.dispose();
    _leadTimeController.dispose();
    _minimumOrderValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Edit ${widget.supplier.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D5016),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name and Supplier Type
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier Name *',
                                prefixIcon: Icon(Icons.business),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Supplier name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSupplierType,
                              decoration: const InputDecoration(
                                labelText: 'Type *',
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'internal',
                                  child: Text('🏠 Internal Farm'),
                                ),
                                DropdownMenuItem(
                                  value: 'external',
                                  child: Text('🚚 External Supplier'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedSupplierType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Contact Person and Email
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _contactPersonController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Person',
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone and Active Status
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Active'),
                              subtitle: Text(_isActive ? 'Supplier is active' : 'Supplier is inactive'),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description & Specialties',
                          prefixIcon: Icon(Icons.description),
                          hintText: 'Describe what this supplier provides...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Business Details
                      const Text(
                        'Business Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D5016),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Registration and Tax Numbers
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _registrationNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Registration Number',
                                prefixIcon: Icon(Icons.business_center),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _taxNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Tax Number',
                                prefixIcon: Icon(Icons.receipt),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Terms and Lead Time
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _paymentTermsController,
                              decoration: const InputDecoration(
                                labelText: 'Payment Terms (days)',
                                prefixIcon: Icon(Icons.schedule),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final days = int.tryParse(value);
                                  if (days == null || days < 0) {
                                    return 'Enter a valid number of days';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _leadTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Lead Time (days)',
                                prefixIcon: Icon(Icons.timer),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final days = int.tryParse(value);
                                  if (days == null || days < 0) {
                                    return 'Enter a valid number of days';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Minimum Order Value
                      TextFormField(
                        controller: _minimumOrderValueController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Order Value',
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: 'R ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final amount = double.tryParse(value);
                            if (amount == null || amount < 0) {
                              return 'Enter a valid amount';
                            }
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Order Statistics (Read-only)
                      const Text(
                        'Order Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D5016),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Total Orders',
                                    widget.supplier.totalOrders.toString(),
                                    Icons.shopping_cart,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    'Total Value',
                                    'R${widget.supplier.totalOrderValue.toStringAsFixed(2)}',
                                    Icons.attach_money,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Order Frequency',
                                    widget.supplier.orderFrequency,
                                    Icons.trending_up,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    'Last Order',
                                    widget.supplier.lastOrderDate != null
                                        ? '${DateTime.now().difference(widget.supplier.lastOrderDate!).inDays} days ago'
                                        : 'Never',
                                    Icons.schedule,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Supplier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supplierData = {
        'name': _nameController.text.trim(),
        'contact_person': _contactPersonController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'supplier_type': _selectedSupplierType,
        'registration_number': _registrationNumberController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'is_active': _isActive,
        'payment_terms_days': int.tryParse(_paymentTermsController.text.trim()) ?? 30,
        'lead_time_days': int.tryParse(_leadTimeController.text.trim()) ?? 3,
        'minimum_order_value': _minimumOrderValueController.text.isNotEmpty 
            ? double.tryParse(_minimumOrderValueController.text.trim()) 
            : null,
      };

      final success = await ref.read(suppliersProvider.notifier).updateSupplier(
        widget.supplier.id, 
        supplierData,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update supplier: ${ref.read(suppliersProvider).error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
