import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/supplier.dart';
import '../../providers/suppliers_provider.dart';
import 'widgets/edit_supplier_dialog.dart';

class SupplierDetailPage extends ConsumerWidget {
  final int supplierId;

  const SupplierDetailPage({
    super.key,
    required this.supplierId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplier = ref.watch(supplierProvider(supplierId));

    if (supplier == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Supplier Details'),
          backgroundColor: const Color(0xFF2D5016),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Supplier not found'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(supplier.name),
        backgroundColor: const Color(0xFF2D5016),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/suppliers'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditSupplierDialog(supplier: supplier),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'deactivate':
                  _showDeactivateDialog(context, ref, supplier);
                  break;
                case 'contact':
                  _showContactInfo(context, supplier);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'contact',
                child: Row(
                  children: [
                    const Icon(Icons.contact_phone),
                    const SizedBox(width: 8),
                    Text('Contact ${supplier.primarySalesRep?.name ?? 'Supplier'}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(
                      supplier.isActive ? Icons.block : Icons.check_circle,
                      color: supplier.isActive ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(supplier.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(supplier),
            const SizedBox(height: 16),

            // Order Statistics
            _buildOrderStatsCard(supplier),
            const SizedBox(height: 16),

            // Contact Information
            _buildContactCard(supplier),
            const SizedBox(height: 16),

            // Business Details
            _buildBusinessDetailsCard(supplier),
            const SizedBox(height: 16),

            // Sales Representatives
            if (supplier.salesReps.isNotEmpty) ...[
              _buildSalesRepsCard(supplier),
              const SizedBox(height: 16),
            ],

            // Performance Metrics
            if (supplier.metrics != null) ...[
              _buildMetricsCard(supplier),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: supplier.supplierTypeColor,
              child: Text(
                supplier.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Basic Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(supplier.supplierTypeEmoji),
                      const SizedBox(width: 4),
                      Text(
                        supplier.supplierTypeDisplay,
                        style: TextStyle(
                          color: supplier.supplierTypeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: supplier.isActive ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          supplier.statusDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (supplier.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      supplier.description!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatsCard(Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Orders',
                    supplier.totalOrders.toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Value',
                    'R${supplier.totalOrderValue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
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
                    supplier.orderFrequency,
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Last Order',
                    supplier.lastOrderDate != null
                        ? '${DateTime.now().difference(supplier.lastOrderDate!).inDays} days ago'
                        : 'Never',
                    Icons.schedule,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 16),
            if (supplier.email.isNotEmpty) ...[
              _buildContactItem(Icons.email, 'Email', supplier.email),
              const SizedBox(height: 8),
            ],
            if (supplier.phone.isNotEmpty) ...[
              _buildContactItem(Icons.phone, 'Phone', supplier.phone),
              const SizedBox(height: 8),
            ],
            if (supplier.address?.isNotEmpty == true) ...[
              _buildContactItem(Icons.location_on, 'Address', supplier.address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessDetailsCard(Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailItem('Specialties', supplier.specialtiesDisplay),
            const SizedBox(height: 8),
            _buildDetailItem('Recent Supplier', supplier.isRecentSupplier ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesRepsCard(Supplier supplier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Representatives',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 16),
            ...supplier.salesReps.map((rep) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: rep.isPrimary ? const Color(0xFF2D5016) : Colors.grey,
                    child: Text(
                      rep.name.isNotEmpty ? rep.name[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              rep.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (rep.isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D5016),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          rep.displayPosition,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (rep.email.isNotEmpty)
                          Text(
                            rep.email,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(Supplier supplier) {
    final metrics = supplier.metrics!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Quality Rating',
                    metrics.qualityRatingDisplay,
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'On-Time Delivery',
                    metrics.deliveryRateDisplay,
                    Icons.schedule,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Lead Time',
                    metrics.leadTimeDisplay,
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Price Competitiveness',
                    metrics.competitivenessDisplay,
                    Icons.trending_down,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref, Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${supplier.isActive ? 'Deactivate' : 'Activate'} Supplier'),
        content: Text(
          supplier.isActive
              ? 'Are you sure you want to deactivate ${supplier.name}? They will no longer appear in active supplier lists.'
              : 'Are you sure you want to activate ${supplier.name}? They will appear in active supplier lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await ref.read(suppliersProvider.notifier).updateSupplier(
                supplier.id,
                {'is_active': !supplier.isActive},
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Supplier ${supplier.isActive ? 'deactivated' : 'activated'} successfully'
                          : 'Failed to update supplier status',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: supplier.isActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(supplier.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(BuildContext context, Supplier supplier) {
    final primaryRep = supplier.primarySalesRep;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primaryRep != null) ...[
              Text(
                'Primary Sales Rep: ${primaryRep.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (primaryRep.email.isNotEmpty)
                Text('Email: ${primaryRep.email}'),
              if (primaryRep.phone.isNotEmpty)
                Text('Phone: ${primaryRep.phone}'),
              const SizedBox(height: 12),
            ],
            const Text(
              'Supplier Contact:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (supplier.email.isNotEmpty)
              Text('Email: ${supplier.email}'),
            if (supplier.phone.isNotEmpty)
              Text('Phone: ${supplier.phone}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
