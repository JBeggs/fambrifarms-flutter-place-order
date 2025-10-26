import 'package:flutter/material.dart';
import '../../../models/supplier.dart';

class SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onViewProducts;
  final VoidCallback? onContact;

  const SupplierCard({
    super.key,
    required this.supplier,
    this.onTap,
    this.onEdit,
    this.onViewProducts,
    this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Supplier avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: supplier.supplierTypeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: supplier.supplierTypeColor.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        supplier.supplierTypeEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Supplier info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Supplier name
                        Text(
                          supplier.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Supplier type and status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: supplier.supplierTypeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                supplier.supplierTypeDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: supplier.supplierTypeColor,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Status indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: supplier.isActive ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            
                            const SizedBox(width: 4),
                            
                            Text(
                              supplier.statusDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                color: supplier.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'products':
                          onViewProducts?.call();
                          break;
                        case 'contact':
                          onContact?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Supplier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'products',
                        child: Row(
                          children: [
                            Icon(Icons.inventory, size: 18),
                            SizedBox(width: 8),
                            Text('View Products'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'contact',
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 18),
                            SizedBox(width: 8),
                            Text('Contact'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Contact information
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.email_outlined,
                      'Email',
                      supplier.email,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildInfoItem(
                      context,
                      Icons.phone_outlined,
                      'Phone',
                      supplier.phone.isNotEmpty ? supplier.phone : 'Not provided',
                    ),
                  ),
                ],
              ),
              
              // Address (if available)
              if (supplier.address != null && supplier.address!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoItem(
                  context,
                  Icons.location_on_outlined,
                  'Address',
                  supplier.address!,
                ),
              ],
              
              // Specialties
              if (supplier.specialties.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Specialties',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              supplier.specialtiesDisplay,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Primary sales rep (if available)
              if (supplier.primarySalesRep != null) ...[
                const SizedBox(height: 12),
                _buildSalesRepInfo(context, supplier.primarySalesRep!),
              ],
              
              const SizedBox(height: 16),
              
              // Supplier statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Total Orders',
                      supplier.totalOrders.toString(),
                      Icons.shopping_cart_outlined,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Order Value',
                      'R${supplier.totalOrderValue.toStringAsFixed(0)}',
                      Icons.attach_money,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildStatItem(
                      context,
                      'Frequency',
                      supplier.orderFrequency,
                      Icons.trending_up,
                    ),
                  ),
                  
                  if (supplier.lastOrderDate != null)
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Last Order',
                        _formatLastOrderDate(supplier.lastOrderDate!),
                        Icons.schedule,
                      ),
                    ),
                ],
              ),
              
              // Metrics (if available)
              if (supplier.metrics != null) ...[
                const SizedBox(height: 16),
                _buildMetricsSection(context, supplier.metrics!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesRepInfo(BuildContext context, SalesRep salesRep) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: supplier.supplierTypeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: supplier.supplierTypeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: supplier.supplierTypeColor.withOpacity(0.2),
            child: Text(
              salesRep.name.isNotEmpty ? salesRep.name[0].toUpperCase() : 'S',
              style: TextStyle(
                color: supplier.supplierTypeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salesRep.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  salesRep.displayPosition,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Contact buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.email, size: 16),
                onPressed: () {
                  // TODO: Open email
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.phone, size: 16),
                onPressed: () {
                  // TODO: Make phone call
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, SupplierMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  'Lead Time',
                  metrics.leadTimeDisplay,
                  Icons.schedule,
                ),
              ),
              
              Expanded(
                child: _buildMetricItem(
                  context,
                  'On-Time',
                  metrics.deliveryRateDisplay,
                  Icons.check_circle,
                ),
              ),
              
              Expanded(
                child: _buildMetricItem(
                  context,
                  'Quality',
                  metrics.qualityRatingDisplay,
                  Icons.star,
                ),
              ),
              
              Expanded(
                child: _buildMetricItem(
                  context,
                  'Price',
                  metrics.competitivenessDisplay,
                  Icons.trending_down,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.blue[600]),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.blue[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatLastOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }
}

